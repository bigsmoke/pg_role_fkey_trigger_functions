-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit


/**
 * CHANGELOG.md:
 *
 * - It happens often that this extension's designer wants to repeat himself
 *   rather than keep all his code as DRY as possible.  To make almost literal
 *   repetitions across and within source files easier to manage, Rowan
 *   created a new script: `wet`
 *
 *   `wet` too, like many helper scripts, will be copied between projects rather
 *   than introduced as some external dependency.  This whole-file duplication,
 *   however, will probably be managed by another, as of yet non-existent, tool:
 *   `dry`.
 */


/**
 * CHANGELOG.md:
 *
 * - The `pg_role_fkey_trigger_functions__trusted_tables()` function is no
 *   longer used by its brethern functions—
 *
 *   1. `pg_role_fkey_trigger_functions__trust_table()` and
 *   2. `pg_role_fkey_trigger_functions__trust_tables()`.
 *   ~
 *   The reason is threefold:
 *
 *   1. `pg_role_fkey_trigger_functions__trusted_tables()` was meant to _only_
 *      return the `regclass`es of the relations that currently exist, whereas
 *      its `*_trust_table()` and `*_trust_tables()` counterparts should retain
 *      trusted tables, even if they do _not_ currently exist.
 *
 *   2. The fiddling with the `search_path` within the latter two functions was
 *      still buggy and hacky anyway (though this could have been solved
 *      differently, for example, by using the `pg_catalog` instead of the
 *      `regclass::text` cast).
 *
 *   3. A fourth function could have been introduced, used by all 3 aforementioned
 *      functions, but inter-function dependencies are a bit annoying extension
 *      design anyway, because it makes it more difficult for users/developers
 *      to cherry-pick parts of an extension.
 */
create or replace function pg_role_fkey_trigger_functions__trusted_tables(
        "role$" regrole = current_user::regrole
        ,"db$" text = current_database()
        ,"db_not_role_specific$" bool = true
        ,"db_and_role_specific$" bool = true
        ,"role_not_db_specific$" bool = true
    )
    returns regclass[]
    stable
    leakproof
    parallel safe
    return (
        select
            coalesce(array_agg(to_regclass(qualified_table) order by qualified_table), '{}'::regclass[])
        from
            (
                --<WET:get-trusted-tables>
                select distinct
                    qualified_table
                from
                    pg_catalog.pg_db_role_setting
                left outer join
                    pg_catalog.pg_database
                    on pg_database.oid = pg_db_role_setting.setdatabase
                cross join lateral
                    unnest(pg_db_role_setting.setconfig) as expanded_settings(raw_setting)
                cross join lateral
                    cast(regexp_replace(expanded_settings.raw_setting, E'^[^=]+=', '') as text[]) as a
                cross join lateral
                    unnest(a) as qualified_table
                where
                    (
                        (
                            --<WET:ignore>
                            "db_not_role_specific$"
                            --</WET:ignore>
                            and pg_database.datname = "db$"
                            and pg_db_role_setting.setrole = 0::oid
                        )
                        or (
                            --<WET:ignore>
                            "db_and_role_specific$"
                            --</WET:ignore>
                            and pg_database.datname = "db$"
                            and pg_db_role_setting.setrole = "role$"
                        )
                        or (
                            --<WET:ignore>
                            "role_not_db_specific$"
                            --</WET:ignore>
                            and pg_db_role_setting.setdatabase = 0::oid
                            and pg_db_role_setting.setrole = "role$"
                        )
                    )
                    and expanded_settings.raw_setting like 'pg_role_fkey_trigger_functions.trusted_tables=%'
                --</WET:get-trusted-tables>
            ) as t
        where
            to_regclass(qualified_table) is not null
    );

/**
 * CHANGELOG.md:
 *
 * - The `comment on function pg_role_fkey_trigger_functions__trusted_tables()`
 *   was written for a signature that never existed in a released version—i.e.,
 *   the argument types had already been changed into `(regrole, rext, bool,
 *   bool, bool)` when the function was introduced in version 1.0.0 of the
 *   extension).  This comment (and hence the `README.md`) is now up to date.
 */
comment on function pg_role_fkey_trigger_functions__trusted_tables(regrole, text, bool, bool, bool) is
$md$Returns the array of relations (of type `regclass[]`) that are trusted by the `SECURITY DEFINER` trigger functions.

This function has five arguments, all of them optional:

| Arg.  | Name                     | Type       | Default value            | Description                                                |
| ----- | ------------------------ | ---------- | -------------------------| ---------------------------------------------------------- |
| `$1`  | `role$`                  | `regrole`  | `current_user::regrole`  | A role whose role-specific settings will be included.      |
| `$2`  | `db$`                    | `text`  `  | `current_database()`     | The database to look up settings for.                      |
| `$3`  | `db_not_role_specific$`  | `boolean`  | `true`                   | Include DB-level settings not bound to a role.             |
| `$4`  | `db_and_role_specific$`  | `boolean`  | `true`                   | Include settings which are specific to the role _and_ DB.  |
| `$5`  | `role_not_db_specific$`  | `boolean`  | `true`                   | Include cluster-wide role settings.                        |

See the [_Secure `pg_role_fkey_trigger_functions` usage_] section for details
as to how and why this list is maintained.

[_Secure `pg_role_fkey_trigger_functions` usage_]:
    #secure-pg_role_fkey_trigger_functions-usage
$md$;


/**
 * CHANGELOG.md:
 *
 * - The `pg_role_fkey_trigger_functions__trust_table()` function was:
 *
 *   + freed from its `pg_role_fkey_trigger_functions__trusted_tables()`
 *     dependency (as explicated more extensively above);
 *
 *   + fixed to always store fully qualified relation names, also when the
 *     `current_schema()` is identical to the `$extension_schema`; and
 *
 *   + fixed to use the `to_regclass()` rather than the `text::regclass`, so
 *     that the function doesn't crash when any of the trusted tables
 *     can not be resolved into an `oid`/`regclass`.
 */
create or replace function pg_role_fkey_trigger_functions__trust_table(
        "table$" regclass
        ,"role$" regrole = null
        ,"db$" text = current_database()
    )
    returns regclass[]
    volatile
    leakproof
    set pg_role_fkey_trigger_functions.search_path to pg_catalog
    language plpgsql
    as $$
declare
    _qualified_relation_names text[];
begin
    if "role$" is null and "db$" is null then
        raise data_exception using
            message = '"role$" and "db$" arguments to this function cannot both be `NULL`.'
        ;
    end if;

    _qualified_relation_names := array(
        select
             quote_ident(pg_namespace.nspname) || '.' || quote_ident(pg_class.relname) as qualified_table
        from
            pg_catalog.pg_class
        inner join
            pg_catalog.pg_namespace
            on pg_namespace.oid = pg_class.relnamespace
        where
            pg_class.oid = "table$"
        union
        --<WET:get-trusted-tables>
        select distinct
            qualified_table
        from
            pg_catalog.pg_db_role_setting
        left outer join
            pg_catalog.pg_database
            on pg_database.oid = pg_db_role_setting.setdatabase
        cross join lateral
            unnest(pg_db_role_setting.setconfig) as expanded_settings(raw_setting)
        cross join lateral
            cast(regexp_replace(expanded_settings.raw_setting, E'^[^=]+=', '') as text[]) as a
        cross join lateral
            unnest(a) as qualified_table
        where
            (
                (
                    --<WET:ignore>
                    -- = "db_not_role_specific$" in `pg_role_fkey_trigger_functions__trusted_tables()
                    ("db$" is not null and "role$" is null)
                    --</WET:ignore>
                    and pg_database.datname = "db$"
                    and pg_db_role_setting.setrole = 0::oid
                )
                or (
                    --<WET:ignore>
                    -- = "db_and_role_specific$" in `pg_role_fkey_trigger_functions__trusted_tables()
                    ("db$" is not null and "role$" is not null)
                    --</WET:ignore>
                    and pg_database.datname = "db$"
                    and pg_db_role_setting.setrole = "role$"
                )
                or (
                    --<WET:ignore>
                    -- = "role_not_db_specific$" in `pg_role_fkey_trigger_functions__trusted_tables()
                    ("db$" is null and "role$" is not null)
                    --</WET:ignore>
                    and pg_db_role_setting.setdatabase = 0::oid
                    and pg_db_role_setting.setrole = "role$"
                )
            )
            and expanded_settings.raw_setting like 'pg_role_fkey_trigger_functions.trusted_tables=%'
        --</WET:get-trusted-tables>
    );

    execute format(
        'ALTER %s SET pg_role_fkey_trigger_functions.trusted_tables TO %L'
        ,coalesce('ROLE ' || "role$"::text, '')
            || case when "role$" is not null and "db$" is not null then ' IN ' else '' end
            || coalesce('DATABASE ' || quote_ident("db$"), '')
        ,_qualified_relation_names::text
    );

    return (
        select
            array_agg(to_regclass(qname) order by qname)
        from
            unnest(_qualified_relation_names) as qname
        where
            to_regclass(qname) is not null
    );
end;
$$;


/**
 * CHANGELOG.md:
 *
 * - Equally, the `pg_role_fkey_trigger_functions__trust_tables()` function was
 *   also:
 *
 *   + freed from its `pg_role_fkey_trigger_functions__trusted_tables()`
 *     dependency (as explicated more extensively above);
 *
 *   + fixed to always store fully qualified relation names, also when the
 *     `current_schema()` is identical to the `$extension_schema`; and
 *
 *   + fixed to use the `to_regclass()` rather than the `text::regclass`, so
 *     that the function doesn't crash when any of the trusted tables
 *     can not be resolved into an `oid`/`regclass`.
 */
create or replace function pg_role_fkey_trigger_functions__trust_tables(
        "tables$" regclass[]
        ,"role$" regrole = null
        ,"db$" text = current_database()
    )
    returns regclass[]
    set pg_role_fkey_trigger_functions.search_path to pg_catalog
    volatile
    leakproof
    language plpgsql
    as $$
declare
    _qualified_relation_names text[];
begin
    if "role$" is null and "db$" is null then
        raise data_exception using
            message = '"role$" and "db$" arguments to this function cannot both be `NULL`.'
        ;
    end if;

    _qualified_relation_names := array(
        select
             quote_ident(pg_namespace.nspname) || '.' || quote_ident(pg_class.relname) as qualified_table
        from
            pg_catalog.pg_class
        inner join
            pg_catalog.pg_namespace
            on pg_namespace.oid = pg_class.relnamespace
        where
            pg_class.oid = any("tables$")
        union
        --<WET:get-trusted-tables>
        select distinct
            qualified_table
        from
            pg_catalog.pg_db_role_setting
        left outer join
            pg_catalog.pg_database
            on pg_database.oid = pg_db_role_setting.setdatabase
        cross join lateral
            unnest(pg_db_role_setting.setconfig) as expanded_settings(raw_setting)
        cross join lateral
            cast(regexp_replace(expanded_settings.raw_setting, E'^[^=]+=', '') as text[]) as a
        cross join lateral
            unnest(a) as qualified_table
        where
            (
                (
                    --<WET:ignore>
                    -- = "db_not_role_specific$" in `pg_role_fkey_trigger_functions__trusted_tables()
                    ("db$" is not null and "role$" is null)
                    --</WET:ignore>
                    and pg_database.datname = "db$"
                    and pg_db_role_setting.setrole = 0::oid
                )
                or (
                    --<WET:ignore>
                    -- = "db_and_role_specific$" in `pg_role_fkey_trigger_functions__trusted_tables()
                    ("db$" is not null and "role$" is not null)
                    --</WET:ignore>
                    and pg_database.datname = "db$"
                    and pg_db_role_setting.setrole = "role$"
                )
                or (
                    --<WET:ignore>
                    -- = "role_not_db_specific$" in `pg_role_fkey_trigger_functions__trusted_tables()
                    ("db$" is null and "role$" is not null)
                    --</WET:ignore>
                    and pg_db_role_setting.setdatabase = 0::oid
                    and pg_db_role_setting.setrole = "role$"
                )
            )
            and expanded_settings.raw_setting like 'pg_role_fkey_trigger_functions.trusted_tables=%'
        --</WET:get-trusted-tables>
    );

    execute format(
        'ALTER %s SET pg_role_fkey_trigger_functions.trusted_tables TO %L'
        ,coalesce('ROLE ' || "role$"::text, '')
            || case when "role$" is not null and "db$" is not null then ' IN ' else '' end
            || coalesce('DATABASE ' || quote_ident("db$"), '')
        ,_qualified_relation_names::text
    );

    return (
        select
            array_agg(to_regclass(qname) order by qname)
        from
            unnest(_qualified_relation_names) as qname
        where
            to_regclass(qname) is not null
    );
end;
$$;


/**
 * CHANGELOG.md:
 *
 * - The `test__pg_role_fkey_trigger_functions()` procedure now more explicitly
 *   test the desired behaviours of the functions that were improved in this
 *   release:
 *
 *   + `pg_role_fkey_trigger_functions__trusted_tables(regrole, text, bool, bool, bool)`,
 *   + `pg_role_fkey_trigger_functions__trust_table(regclass, regrole, test)`, and
 *   + `pg_role_fkey_trigger_functions__trust_tables(regclass[], regrole, text)`.
 */
create or replace procedure test__pg_role_fkey_trigger_functions()
    set pg_role_fkey_trigger_functions.search_path_template = '"$extension_schema", pg_catalog'
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
    create role test__youngest_intern;
    create role test__trusting_role;

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
        for each row execute function maintain_referenced_role(
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


    assert pg_role_fkey_trigger_functions__trusted_tables() = '{}'::regclass[];
    assert pg_role_fkey_trigger_functions__trusted_tables('test__trusting_role') = '{}'::regclass[];

    perform pg_role_fkey_trigger_functions__trust_table('test__customer', 'test__trusting_role');
    assert pg_role_fkey_trigger_functions__trusted_tables('test__trusting_role') = array[
        'test__customer'::regclass
    ]::regclass[], pg_role_fkey_trigger_functions__trusted_tables('test__trusting_role') ;

    <<untrusted_table>>
    declare
    begin
        insert into test__customer
            (account_owner_role, account_manager_role)
        values
            (default, 'test__account_manager'::regrole)
        returning
            account_owner_role
        into
            _inserted_account_owner_role
        ;
        raise assert_failure
            using message = 'The trigger function should have raised `insufficient_privilege`.';
    exception
        when insufficient_privilege then
    end;

    perform pg_role_fkey_trigger_functions__trust_table('test__customer');

    create table test__trusted_table_2 (dummy_col int);
    create table test__trusted_table_3 (dummy_col int);
    assert pg_role_fkey_trigger_functions__trust_tables(array[
        'test__trusted_table_2'::regclass
        ,'test__trusted_table_3'::regclass
    ]) = array[
        'test__customer',
        'test__trusted_table_2',
        'test__trusted_table_3'
    ]::regclass[];
    assert pg_role_fkey_trigger_functions__trusted_tables() = array[
        'test__customer',
        'test__trusted_table_2',
        'test__trusted_table_3'
    ]::regclass[], pg_role_fkey_trigger_functions__trusted_tables();
    drop table test__trusted_table_2;
    assert pg_role_fkey_trigger_functions__trusted_tables() = array[
        'test__customer',
        'test__trusted_table_3'
    ]::regclass[], pg_role_fkey_trigger_functions__trusted_tables();
    drop table test__trusted_table_3;
    create table test__trusted_table_4 (dummy int);
    assert pg_role_fkey_trigger_functions__trust_table('test__trusted_table_4') = array[
        'test__customer',
        'test__trusted_table_4'
    ]::regclass[];
    create table test__trusted_table_3 (dummy_col int);
    assert pg_role_fkey_trigger_functions__trusted_tables('test__trusting_role') = array[
        'test__customer',
        'test__trusted_table_3',
        'test__trusted_table_4'
    ]::regclass[], format(
        'The trusted table should have been remembered, got: %s'
        ,pg_role_fkey_trigger_functions__trusted_tables('test__trusting_role')
    );

    <<insert_invalid_role_reference>>
    declare
        _message_text text;
        _pg_exception_detail text;
        _nonexistent_role name := 'test__account_manager_that_doesnt_exist';
    begin
        insert into test__customer
            values (default, _nonexistent_role);
        raise assert_failure
            using message = 'The trigger function should have gotten upset about the missing `ROLE`.';
    exception
        when foreign_key_violation then
            get stacked diagnostics
                _message_text := message_text
                ,_pg_exception_detail := pg_exception_detail
            ;

            assert _message_text = format('Unknown database role: %I', _nonexistent_role);
            assert _pg_exception_detail = format(
                '`TRIGGER tg1_account_manager_role_fkey AFTER INSERT ON %I.test__customer FOR EACH ROW'
                ' EXECUTE FUNCTION enforce_fkey_to_db_role(%L)`'
                ,current_schema(), 'account_manager_role'
            ), format('Unexpected error detail: %s', _pg_exception_detail);
    end;

    <<insert_existing_role>>
    declare
        _role constant name := 'test__preexisting_user';
    begin
        create role test__preexisting_user;
        insert into test__customer
            values (_role, 'test__account_manager'::regrole);
        raise assert_failure using message = format(
            'The trigger function should have gotten upset about the existing `%I` role.', _role
        );
    exception
        when integrity_constraint_violation then
            assert sqlerrm = format('Role %I already exists.', _role),
                format('Unexpected `sqlerrm = %L`', sqlerrm)
            ;
    end insert_existing_role;

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

    assert pg_has_role('test__account_manager', _inserted_account_owner_role::regrole, 'USAGE'), format(
        'The %s role should have gotten access to the new %s "account_owner_role" by action of the'
        ' grant_role_in_column1_to_role_in_column2() trigger function'
        ,'test__account_manager', _inserted_account_owner_role
    );

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
    drop role test__customer_group;
    drop role test__account_manager;
    drop role test__new_account_manager;
    drop role test__trusting_role;

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;


/**
 * CHANGELOG.md:
 *
 * - The elements in the `pg_role_fkey_trigger_functions.search_path_template`
 *   settings were in the wrong order for all the functions for which this
 *   setting was set.  This order has now been reversed, from `'pg_catalog,
 *   "$extension_schema"'`, to `'"$extension_schema", pg_catalog'`.
 */
alter function grant_role_in_column1_to_role_in_column2()
    set pg_role_fkey_trigger_functions.search_path_template = '"$extension_schema", pg_catalog';
alter function revoke_role_in_column1_from_role_in_column2()
    set pg_role_fkey_trigger_functions.search_path_template = '"$extension_schema", pg_catalog';
alter function maintain_referenced_role()
    set pg_role_fkey_trigger_functions.search_path_template = '"$extension_schema", pg_catalog';
alter procedure test_dump_restore__maintain_referenced_role(text)
    set pg_role_fkey_trigger_functions.search_path_template = '"$extension_schema", pg_catalog';
call pg_role_fkey_trigger_functions__alter_routines_to_reset_search_paths();
