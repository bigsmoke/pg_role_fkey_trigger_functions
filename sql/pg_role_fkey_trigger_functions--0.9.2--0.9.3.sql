-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit


/**
 * CHANGELOG.md:
 *
 * - Prior to this release, when the `enforce_fkey_to_db_role()` trigger
 *   function failed to produce an error, this would slip through the
 *   `test__pg_role_fkey_trigger_functions()` procedure unnoticed.
 *
 *   + Now, the `test__pg_role_fkey_trigger_functions()` procedure _does_ fail
 *     if the test trigger based on `enforce_fkey_to_db_role()` fails to raise
 *     a `foreign_key_violation`.
 *
 *   + Also, the test procedure now tests the specific error message raised by
 *     `enforce_fkey_to_db_role()`.
 */
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

    create table test__customer (
        account_owner_role name
            primary key
            default 'user_' || gen_random_uuid()::text,
        account_manager_role name
            not null
    );

    create constraint trigger account_manager_role_fkey
        after insert or update on test__customer
        for each row
        execute function enforce_fkey_to_db_role('account_manager_role');

    create trigger account_owner_role_fkey
        after insert or update or delete on test__customer
        for each row
        execute function maintain_referenced_role(
            'account_owner_role', 'IN ROLE test__customer_group'
        );

    create trigger grant_owner_impersonation_to_account_manager
        after insert on test__customer
        for each row
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

    insert into test__customer
        (account_owner_role, account_manager_role)
    values
        (default, 'test__account_manager')
    returning
        account_owner_role
    into
        _inserted_account_owner_role
    ;

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

    -- This implicitly tests that both these roles exist
    assert pg_has_role('test__account_manager', _inserted_account_owner_role, 'USAGE');

    _updated_account_owner_role := 'test__custom_user_name';
    update test__customer
        set account_owner_role = _updated_account_owner_role;
    assert exists (select from pg_roles where rolname = _updated_account_owner_role);

    delete from test__customer;
    assert not exists (select from pg_roles where rolname = _updated_account_owner_role);

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;


/**
 * CHANGELOG.md:
 *
 *   + The `foreign_key_violation` error message produced by the
 *     `enforce_fkey_to_db_role()` trigger function now correctly includes the
 *     `_new_role` instead of the  `_role_fkey_column` value.
 */
create or replace function enforce_fkey_to_db_role()
    returns trigger
    language plpgsql
    as $$
declare
    _role_fkey_column name;
    _new_role name;
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_nargs = 1,
        'You must supply the name of the row column in the CREATE TRIGGER definition.';

    _role_fkey_column := tg_argv[0];

    execute 'SELECT $1.' || quote_ident(_role_fkey_column) into _new_role using NEW;

    if not exists (select from pg_catalog.pg_roles where pg_roles.rolname = _new_role) then
        raise foreign_key_violation
            using message = 'Unknown database role: ' || _new_role;
        return null;
    end if;

    return NEW;
end;
$$;
