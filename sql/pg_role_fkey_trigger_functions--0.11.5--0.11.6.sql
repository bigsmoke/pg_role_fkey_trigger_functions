-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

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
                ' FROM OLD.%2$I.  If %1$I or %2$I is managed by the maintain_referenced_role()'
                ' trigger function, make sure that this present trigger is executed _after_ the'
                ' trigger that executes `maintain_referenced_role()`.',
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
