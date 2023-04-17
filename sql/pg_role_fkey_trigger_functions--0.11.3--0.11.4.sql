-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Pretend to start with a new database (with the roles still existing).  (This is useful in development
-- and acceptance environments.)
create or replace procedure test_dump_restore__maintain_referenced_role(test_stage$ text)
    set search_path from current
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
declare
    _inserted_account_owner_role name;
begin
    assert test_stage$ in ('pre-dump', 'post-restore');

    if test_stage$ = 'pre-dump' then
        create role test__customer_group;
        create role test__account_manager;

        create table test__customer (
            account_owner_role name
                primary key
                default 'user_' || gen_random_uuid()::text,
            account_manager_role name
                not null
        );

        create trigger account_owner_role_fkey
            after insert or update or delete on test__customer
            for each row
            execute function maintain_referenced_role(
                'account_owner_role', 'IN ROLE test__customer_group'
            );

        create trigger account_manager_role_fkey
            after insert or update on test__customer
            for each row
            execute function enforce_fkey_to_db_role(
                'account_manager_role'
            );

        insert into test__customer
            (account_owner_role, account_manager_role)
        values
            (default, 'test__account_manager'::regrole)
        returning
            account_owner_role
        into
            _inserted_account_owner_role
        ;

        assert exists (select from pg_roles where rolname = _inserted_account_owner_role),
            'The role should have been created by the maintain_referenced_role() trigger function.';

    elsif test_stage$ = 'post-restore' then
        assert (select count(*) from test__customer) = 1,
            'Records should have been recreated without crashing.';

        _inserted_account_owner_role := (select account_owner_role from test__customer);

        -- Now, let's lazily pretend that the database has been dropped and recreated
        truncate table test__customer;  -- This should not trigger the `account_owner_role_fkey` trigger.

        insert into test__customer
            (account_owner_role, account_manager_role)
        values
            (_inserted_account_owner_role, 'test__account_manager'::regrole)
        ;
    end if;
end;
$$;

--------------------------------------------------------------------------------------------------------------

-- Be okay with the fact when the role already exists, as long as it is sort of owned by the trigger.
create or replace function maintain_referenced_role()
    returns trigger
    security definer
    set search_path to 'pg_catalog'
    language plpgsql
    as $$
declare
    _role_fkey_column name;
    _create_role_options text;
    _old_role name;
    _new_role name;
    _new_regrole regrole;
    _existing_role_is_managed bool;
    _existing_role_fkey_col_path text;
    _role_fkey_col_path text;
begin
    -- When used as a 'BEFORE' trigger, `pg_restore` would fail while trying to `CREATE` the already existing
    -- role on `COPY`/`INSERT`. (`BEFORE` triggers are recreated _before_ the table data is restored, whereas
    -- `AFTER` triggers are recreated _after_ the table data is restored.
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE', 'DELETE');
    assert tg_nargs >= 1,
        'You must supply the name of the row column in the `CREATE TRIGGER` definition.';

    _role_fkey_column := tg_argv[0];

    if tg_nargs > 1 then
        _create_role_options := tg_argv[1];
    end if;

    execute 'SELECT $1.' || quote_ident(_role_fkey_column) || ', $2.' || quote_ident(_role_fkey_column)
        into _new_role, _old_role
        using NEW, OLD;

    if _old_role is null and _new_role is not null then
        _new_regrole := to_regrole(_new_role);

        with parsed_setting as (
            select
                split_part(r.raw_setting, '=', 1) as setting_name
                ,split_part(r.raw_setting, '=', 2) as setting_value
            from
                pg_catalog.pg_db_role_setting as s
            cross join lateral
                unnest(s.setconfig) as r(raw_setting)
            where
                s.setrole = _new_regrole
        )
        select
            coalesce(
                (
                    select
                        setting_value::bool
                    from
                        parsed_setting
                    where
                        setting_name = 'pg_role_fkey_trigger_functions.role_is_managed'
                )
                ,false
            ) as role_is_managed
            ,(

                select
                    setting_value
                from
                    parsed_setting
                where
                    setting_name = 'pg_role_fkey_trigger_functions.role_fkey_col_path'
            ) as role_fkey_col
        into
            _existing_role_is_managed
            ,_existing_role_fkey_col_path
        ;
        _role_fkey_col_path := quote_ident(current_database()) || '.' || quote_ident(tg_table_schema)
            || '.' || quote_ident(tg_table_name) || '.' || quote_ident(_role_fkey_column);

        if _new_regrole is not null and (
            (not _existing_role_is_managed)
            or _existing_role_fkey_col_path != _role_fkey_col_path
        )
        then
            raise integrity_constraint_violation using
                message= format('Role %I already exists.', _new_role)
                ,detail = format(
                    'The `%I` trigger on `%I.%I` expects to itself `INSERT` its requisite roles.'
                    ,tg_name
                    ,tg_table_schema
                    ,tg_table_name
                );
        end if;
        if _new_regrole is null then
            execute 'CREATE ROLE ' || quote_ident(_new_role) || COALESCE(' ' || _create_role_options, '');
            execute 'ALTER ROLE ' || quote_ident(_new_role)
                || ' SET pg_role_fkey_trigger_functions.role_is_managed TO ' || true::text;
            execute 'ALTER ROLE ' || quote_ident(_new_role)
                || ' SET pg_role_fkey_trigger_functions.role_fkey_col_path TO '
                || quote_literal(_role_fkey_col_path);
        end if;
    end if;

    if _old_role is not null and _new_role is not null and _old_role != _new_role then
        execute 'ALTER ROLE ' || quote_ident(_old_role) || ' RENAME TO ' || quote_ident(_new_role);
    end if;

    if _old_role is not null and _new_role is null then
        execute 'DROP ROLE ' || quote_ident(_old_role);
    end if;

    if tg_op in ('INSERT', 'UPDATE') then
        return NEW;
    else
        return OLD;
    end if;
end;
$$;

--------------------------------------------------------------------------------------------------------------

-- Also include `pg_readme` dependencies when required.
create or replace function pg_role_fkey_trigger_functions_readme()
    returns text
    volatile
    set search_path from current
    set pg_readme.include_view_definitions to 'true'
    set pg_readme.include_routine_definitions_like to '{test__%}'
    language plpgsql
    as $plpgsql$
declare
    _readme text;
begin
    create extension if not exists pg_readme cascade;

    -- Make sure that the `search_path` includes the schema in which the `pg_readme` extension was
    -- installed previously (in case it was indeed already installed previously).
    perform set_config(
        'search_path'
        ,(
            select
                string_agg(
                    extnamespace::regnamespace::text
                    ,', '
                    order by e.pos
                )
            from
                unnest(array['pg_role_fkey_trigger_functions', 'pg_readme'])
                    with ordinality as e (name, pos)
            inner join
                pg_catalog.pg_extension
                on pg_extension.extname = e.name
        )
        ,true
    );

    _readme := pg_extension_readme('pg_role_fkey_trigger_functions'::name);

    raise transaction_rollback;  -- to `DROP EXTENSION` if we happened to `CREATE EXTENSION` for just this.
exception
    when transaction_rollback then
        return _readme;
end;
$plpgsql$;

--------------------------------------------------------------------------------------------------------------
