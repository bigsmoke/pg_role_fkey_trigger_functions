-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- CHANGE: Instead of guessing what to do, refuse to do certain work and be very verbal about it.
create or replace function grant_role_in_column1_to_role_in_column2()
    returns trigger
    security definer
    language plpgsql
    as $$
declare
    _granted_role_col name;
    _grantee_role_col name;
    _new_granted_role name;
    _new_grantee_role name;
    _old_granted_role name;
    _old_grantee_role name;
    _options text;
    _options_regexp text := '^\s*(WITH GRANT OPTION)?\s*(?:GRANTED BY\s+(.+))?$';
    _with_grant_option bool := false;
    _grantor_role name;
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
        assert _options !~ _options_regexp,
            'These are not valid options for GRANT <role_name> TO <role_specification>: ' || _options;
        _with_grant_option := (regexp_match(_options, _options_regexp))[1] is not null;
        _grantor_role := (regexp_match(_options, _options_regexp))[3];
    end if;

    execute format('SELECT $1.%1$I, $1.%2$I, $2.%1$I, $2.%2$I', _granted_role_col, _grantee_role_col)
        using OLD, NEW
        into _old_granted_role, _old_grantee_role, _new_granted_role, _new_grantee_role;

    if tg_op = 'UPDATE'
    and _old_granted_role is not distinct from _new_granted_role
    and _old_grantee_role is not distinct from _new_grantee_role
    then
        raise assert_failure using
            message = format(
                '%I AFTER UPDATE trigger executed without any changes to %I (column 1) or %I (column 2).',
                tg_name,
                _granted_role_col,
                _grantee_role_col
            )
            ,hint = format(
                'Add a WHEN condition to the AFTER UPDATE trigger to make sure that this trigger'
                ' is only executed WHEN NEW.%1$I IS DISTINCT FROM OLD.%1$I OR NEW.%2$I IS DISTINCT'
                ' FROM OLD.%2$I.  When %1%I or %2%I is managed by the maintain_referenced_role()'
                ' trigger function',
                _granted_role_col,
                _grantee_role_col
            )
            ,table = tg_table_name
            ,schema = tg_table_schema;
    end if;

    if tg_op = 'UPDATE'
    and exists (
        select
        from
            pg_catalog.pg_auth_members
        where
            pg_auth_members.roleid = _new_granted_role::regrole
            and pg_auth_members.member = _new_grantee_role::regrole
            and (_grantor_role is null or pg_auth_members.grantor = _grantor_role::regrole)
            and pg_auth_members.admin_option = _with_grant_option
    )
    then
        raise assert_failure using
            message = format(
                'The exact required role membership of %I (NEW.%I / column 2) in %I (NEW.%I / column 1)'
                ' already exists.',
                _new_grantee_role, _grantee_role_col, _new_granted_role, _granted_role_col
            )
            ,detail = format(
                case
                    when to_regrole(_old_grantee_role) is null or to_regrole(_old_granted_role) is null
                    then case
                            when to_regrole(_old_grantee_role) is null
                            then ' Role %1$L (OLD.%2$I / column 2) no longer exists.'
                            else ''
                        end
                        || case
                            when to_regrole(_old_granted_role) is null
                            then ' Role %3$L (OLD.%4$I / column 1) no longer exists.'
                            else ''
                        end
                    else
                        'The old roles still exist as well. OLD.%2$I = %1$L; OLD.%4$I = %3$L.'
                        || case when pg_has_role(_old_grantee_role, _old_granted_role, 'MEMBER')
                                then ' Also, %2$L is still a member of %4$L.'
                                else ''
                        end || ' Curious…'
                end,
               _old_grantee_role, _grantee_role_col, _old_granted_role, _granted_role_col
            )
            ,hint = format(
                'Possibly, the WHEN condition of the %1$I trigger definition is not specific enough.'
                ' Note that, if one of (or both) %I (column 1) or %I (column 2) is managed by the'
                ' maintain_referenced_role() trigger function, you will mostly likely not want to'
                ' apply grant_role_in_column1_to_role_in_column2() on changes to that column as well;'
                ' maintain_referenced_role() does a role rename when its managed column value changes.',
                tg_name, _granted_role_col, _grantee_role_col
            )
            ,table = tg_table_name
            ,schema = tg_table_schema;
    end if;

    execute 'GRANT ' || quote_ident(_new_granted_role) || ' TO ' || quote_ident(_new_grantee_role)
        || coalesce(' ' || _options,  '');

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

See the `test__pg_role_fkey_trigger_functions()` procedure for a more extensive example.
$markdown$;

--------------------------------------------------------------------------------------------------------------

-- Look at old and new roles instead of just the old. From there, go ahead and REVOKE if a change is detected.
-- We no longer check if both OLD roles still exist and whether the grantee is still a member of the role in
-- column 1, because we want to make sure that devs get an early warning when they sequence these trigger
-- functions incorrectly.
create or replace function revoke_role_in_column1_from_role_in_column2()
    returns trigger
    security definer
    language plpgsql
    as $$
declare
    _granted_role_col name;
    _grantee_role_col name;
    _new_granted_role name;
    _new_grantee_role name;
    _old_granted_role name;
    _old_grantee_role name;
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op in ('UPDATE', 'DELETE');
    assert tg_nargs = 2,
        'Names of the group and member columns are needed in the CREATE TRIGGER definition.';

    _granted_role_col := tg_argv[0];
    _grantee_role_col := tg_argv[1];

    execute format('SELECT $1.%1$I, $1.%2$I, $2.%1$I, $2.%2$I', _granted_role_col, _grantee_role_col)
        using OLD, NEW
        into _old_granted_role, _old_grantee_role, _new_granted_role, _new_grantee_role;

    if tg_op = 'UPDATE'
    and _old_granted_role is not distinct from _new_granted_role
    and _old_grantee_role is not distinct from _new_grantee_role
    then
        raise assert_failure using
            message = format(
                '%I AFTER UPDATE trigger executed without any changes to %I (column 1) or %I (column 2).',
                tg_name,
                _granted_role_col,
                _grantee_role_col
            )
            ,hint = format(
                'Add a WHEN condition to the AFTER UPDATE trigger to make sure that this trigger'
                ' is only executed WHEN NEW.%1$I IS DISTINCT FROM OLD.%1$I OR NEW.%2$I IS DISTINCT'
                ' FROM OLD.%2$I.  When %1%I or %2%I is managed by the maintain_referenced_role()'
                ' trigger function',
                _granted_role_col,
                _grantee_role_col
            )
            ,table = tg_table_name
            ,schema = tg_table_schema;
    end if;

    execute 'REVOKE ' || quote_ident(_old_granted_role) || ' FROM ' || quote_ident(_old_grantee_role);

    return NEW;
end;
$$;

--------------------------------------------------------------------------------------------------------------

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
