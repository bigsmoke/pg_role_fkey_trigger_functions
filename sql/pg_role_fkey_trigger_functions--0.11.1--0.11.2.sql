-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- First pg_dump/pg_restore test procedure for this extension.
create procedure test_dump_restore__maintain_referenced_role(test_stage$ text)
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
    end if;
end;
$$;

--------------------------------------------------------------------------------------------------------------

-- Crash more informatively when role already exists.
-- Return `OLD` instead of `NOW` on `DELETE`.
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
        if to_regrole(_new_role) is null then
            execute 'CREATE ROLE ' || quote_ident(_new_role) || COALESCE(' ' || _create_role_options, '');
        else
            raise integrity_constraint_violation using
                message= format('Role %I already exists.', _new_role)
                ,detail = format(
                    'The `%I` trigger on `%I.%I` expects to itself `INSERT` its requisite roles.'
                    ,tg_name
                    ,tg_table_schema
                    ,tg_table_name
                );
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

comment on function maintain_referenced_role is
$markdown$The `maintain_referenced_role()` trigger function performs an `CREATE`, `ALTER`, or `DROP ROLE`, depending on (changes to) the column value which must point to a valid `ROLE` name.

`maintain_referenced_role()` takes at least one argument: the name of the
column (of type `NAME`) in which the `ROLE` name will be stored.

Additionally, `maintain_referenced_role()` can take a second argument: the
options which will be passed to the `CREATE` and `ALTER ROLE` commands exeuted
by this function.

This trigger function is meant for roles that are to be dynamically created,
altered and dropped, not for verifying the relational integrity of existing
roles; see `enforce_fkey_to_db_role()` for the latter.

The following example will first make `test__owner` pop into existence on
`INSERT`, then be renamed automaticall to `test__new_owner` on `UPDATE` and
finally dropped again, triggered by the `DELETE`.:

```sql
create table test__tbl (
    owner_role name
);

create trigger maintain_owner_role
    after insert or update on test__tbl
    for each row
    execute function maintain_referenced_role('owner_role', 'WITH NOLOGIN');

insert into test__tbl (owner_role)
    values ('test__owner');

update test__tbl
    set owner_role = 'test__new_owner';

delete from test__tbl
    where rolname = 'test__new_owner';
```
$markdown$;

--------------------------------------------------------------------------------------------------------------

-- Add test for trying to trigger creation of pre-existing role.
create or replace procedure test__pg_role_fkey_trigger_functions()
    set search_path from current
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
declare
    _inserted_account_owner_role name;
    _updated_account_owner_role name;
begin
    create role test__customer_group;
    create role test__account_manager;
    create role test__new_account_manager;

    create table test__customer (
        account_owner_role name
            primary key
            default 'user_' || gen_random_uuid()::text,
        account_manager_role name
            not null
    );

    create constraint trigger tg1_account_manager_role_fkey
        after insert or update on test__customer
        for each row
        execute function enforce_fkey_to_db_role('account_manager_role');

    create trigger tg2_account_owner_role_fkey
        after insert or update or delete on test__customer
        for each row
        execute function maintain_referenced_role(
            'account_owner_role', 'IN ROLE test__customer_group'
        );

    create trigger tg3_grant_owner_impersonation_to_account_manager
        after insert on test__customer
        for each row
        execute function grant_role_in_column1_to_role_in_column2(
            'account_owner_role', 'account_manager_role'
        );

    create trigger tg4_revoke_owner_impersonation_from_old_account_manager
        after update on test__customer
        for each row
        when (NEW.account_manager_role is distinct from OLD.account_manager_role)
        execute function revoke_role_in_column1_from_role_in_column2(
            'account_owner_role', 'account_manager_role'
        );

    create trigger tg5_grant_owner_impersonation_to_new_account_manager
        after update on test__customer
        for each row
        when (NEW.account_manager_role is distinct from OLD.account_manager_role)
        execute function grant_role_in_column1_to_role_in_column2(
            'account_owner_role', 'account_manager_role'
        );

    <<insert_invalid_role_reference>>
    begin
        insert into test__customer
            values (default, 'test__account_manager_that_doesnt_exist');
        raise assert_failure
            using message = 'The trigger function should have gotten upset about the missing `ROLE`.';
    exception
        when foreign_key_violation then
            assert sqlerrm = 'Unknown database role: test__account_manager_that_doesnt_exist';
    end;

    <<insert_existing_role>>
    begin
        create role test__preexisting_user;
        insert into test__customer
            values ('test__preexisting_user', 'test__account_manager'::regrole);
        raise assert_failure
            using message = 'The trigger function should have gotten upset about the existing `ROLE`.';
    exception
        when integrity_constraint_violation then
            assert sqlerrm = 'Role test__preexisting_user already exists.',
                sqlerrm;
    end;

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

    assert pg_has_role(_inserted_account_owner_role, 'test__customer_group', 'USAGE'),
        'The new role should have became a member of the "test__customer_group".';

    assert pg_has_role('test__account_manager'::regrole, _inserted_account_owner_role, 'USAGE'),
        'The account manager should have gotten access to the new owner role by action of the'
        ' grant_role_in_column1_to_role_in_column2() trigger function';

    <<set_invalid_role_reference>>
    begin
        update test__customer
            set account_manager_role = 'test__invalid_account_manager';
        raise assert_failure
            using message = 'The trigger function should have gotten upset about the missing `ROLE`.';
    exception
        when foreign_key_violation then
            assert sqlerrm = 'Unknown database role: test__invalid_account_manager';
    end;

    -- Dummy update, to check for rogue trigger behaviour
    update test__customer
        set account_manager_role = account_manager_role;

    _updated_account_owner_role := 'test__custom_user_name';
    update test__customer
        set account_owner_role = _updated_account_owner_role;

    assert exists (select from pg_roles where rolname = _updated_account_owner_role);
    assert not exists (select from pg_roles where rolname = _inserted_account_owner_role);
    assert pg_has_role(_updated_account_owner_role, 'test__customer_group', 'USAGE');
    assert pg_has_role('test__account_manager', _updated_account_owner_role, 'USAGE');

    update test__customer
        set account_manager_role = 'test__new_account_manager'::regrole;
    assert not pg_has_role('test__account_manager', _updated_account_owner_role, 'USAGE'),
        'The old account manager should have lost impersonation rights on this customer.';
    assert pg_has_role('test__new_account_manager', _updated_account_owner_role, 'USAGE'),
        'The new account manager should have gotten impersonation rights on this customer.';

    delete from test__customer;
    assert not exists (select from pg_roles where rolname = _updated_account_owner_role);

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------
