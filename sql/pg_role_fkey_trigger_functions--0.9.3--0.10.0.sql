-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit


/**
 * CHANGELOG.md:
 *
 * - The `grant_role_in_column1_to_role_in_column2()` trigger function now only
 *   does the grant if the role in column 1 isn't already granted to the role
 *   in column 2.
 */
create or replace function grant_role_in_column1_to_role_in_column2()
    returns trigger
    security definer
    language plpgsql
    as $$
declare
    _granted_role_col name;
    _grantee_role_col name;
    _granted_role name;
    _grantee_role name;
    _options text;
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_nargs between 2 and 3,
        'Names of the group and member columns are needed in the CREATE TRIGGER definition.';

    _granted_role_col := tg_argv[0];
    _grantee_role_col := tg_argv[1];
    if tg_nargs > 2 then
        _options := tg_argv[2];
    end if;

    execute format('SELECT $1.%I, $1.%I', _granted_role_col, _grantee_role_col)
        using NEW
        into _granted_role, _grantee_role;

    if not pg_has_role(_grantee_role, _granted_role, 'MEMBER') then
        execute 'GRANT ' || quote_ident(_granted_role) || ' TO ' || quote_ident(_grantee_role)
            || coalesce(' ' || _options,  '');
    end if;

    return NEW;
end;
$$;

comment on function grant_role_in_column1_to_role_in_column2() is
$markdown$ The `grant_role_in_column1_to_role_in_column2()` trigger function is useful if you have a table with (probably auto-generated) role names that need to be members of each other.

`grant_role_in_column1_to_role_in_column2()` requires at least 2 arguments: argument 1 will contain the name of the column that will contain the role name which the role in the column of the second argument will be automatically made a member of.

If you want the old `GRANT` to be `REVOKE`d `ON UPDATE`, use the companion trigger function: `revoke_role_in_column1_from_role_in_column2()`.

Here's a full example, that also incorporates the other two trigger functions packaged into this extension:

```sql
create role customers;

create table test__customer (
    account_owner_role name
        primary key
        default 'user_' || gen_random_uuid()::text,
    account_manager_role name
        not null
);

create constraint trigger account_manager_role_fkey
    after insert or update to test__customer
    for each row
    execute function enforce_fkey_to_db_role('account_manager_role');

create trigger account_owner_role_fkey
    after insert or update or delete to test__customer
    for each row
    execute function maintain_referenced_role(
        'account_owner_role', 'IN ROLE customers'
    );

create trigger grant_owner_impersonation_to_account_manager
    after insert to test__customer
    for each row
    execute function grant_role_in_column1_to_role_in_column2(
        'account_owner_role', 'account_manager_role'
    );
```
$markdown$;


/**
 * CHANGELOG.md:
 *
 * - A new trigger function—`revoke_role_in_column1_from_role_in_column2()`—was
 *   added, as a counterpart to `grant_role_in_column1_to_role_in_column2()`.
 */
create function revoke_role_in_column1_from_role_in_column2()
    returns trigger
    security definer
    language plpgsql
    as $$
declare
    _revoked_role_col name;
    _revokee_role_col name;
    _revoked_role name;
    _revokee_role name;
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op = 'UPDATE';
    assert tg_nargs = 2,
        'Names of the group and member columns are needed in the CREATE TRIGGER definition.';

    _revoked_role_col := tg_argv[0];
    _revokee_role_col := tg_argv[1];

    execute format('SELECT $1.%I, $1.%I', _revoked_role_col, _revokee_role_col)
        using OLD
        into _revoked_role, _revokee_role;

    if to_regrole(_revokee_role) is not null
        and to_regrole(_revoked_role) is not null
        and pg_has_role(_revokee_role, _revoked_role, 'MEMBER')
    then
        execute 'REVOKE ' || quote_ident(_revoked_role) || ' FROM ' || quote_ident(_revokee_role);
    end if;

    return NEW;
end;
$$;

comment on function revoke_role_in_column1_from_role_in_column2() is
$markdown$Use this trigger function, in concert with `grant_role_in_column1_to_role_in_column2()`, if, `ON UPDATE`, you also want to `REVOKE` the old permissions granted earlier by `grant_role_in_column1_to_role_in_column2()`.

**Beware:** This function cannot read your mind and thus will not be aware if there is still another relation that depends on the role in column 2 remaining a member of the role in column 1. As always: use at your own peril.
$markdown$;


/**
 * CHANGELOG.md:
 *
 * - The `test__pg_role_fkey_trigger_functions()` procedure was extended to:
 *
 *   + include tests for the new `revoke_role_in_column1_from_role_in_column2()`
 *     function;
 *   + perform more and better assertions; as well as
 *   + have more and more explicit failure messages.
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
    create role test__new_account_manager;

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
        after insert or update on test__customer
        for each row
        execute function grant_role_in_column1_to_role_in_column2(
            'account_owner_role', 'account_manager_role'
        );

    create trigger revoke_owner_impersonation_from_account_manager
        after update on test__customer
        for each row
        execute function revoke_role_in_column1_from_role_in_column2(
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

    _updated_account_owner_role := 'test__custom_user_name';
    update test__customer
        set account_owner_role = _updated_account_owner_role;

    assert exists (select from pg_roles where rolname = _updated_account_owner_role);
    assert not exists (select from pg_roles where rolname = _inserted_account_owner_role);
    assert pg_has_role(_updated_account_owner_role, 'test__customer_group', 'USAGE');
    assert pg_has_role('test__account_manager', _updated_account_owner_role, 'USAGE');

    update test__customer
        set account_manager_role = 'test__new_account_manager'::regrole;
    assert not pg_has_role('test__account_manager', _updated_account_owner_role, 'USAGE');
    assert pg_has_role('test__new_account_manager', _updated_account_owner_role, 'USAGE');

    delete from test__customer;
    assert not exists (select from pg_roles where rolname = _updated_account_owner_role);

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;
