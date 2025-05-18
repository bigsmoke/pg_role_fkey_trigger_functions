-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit


/**
 * CHANGELOG.md:
 *
 * - Some faulty `format()` specificiers in `RAISE` statements in the
 *   `grant_role_in_column1_to_role_in_column2()` trigger function were fixed.
 */
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
                'Add a WHEN condition to the AFTER UPDATE trigger on %3$s to make sure that this trigger'
                ' is only executed WHEN (NEW.%1$I IS DISTINCT FROM OLD.%1$I OR NEW.%2$I IS DISTINCT'
                ' FROM OLD.%2$I).',
                _granted_role_col,
                _grantee_role_col,
                tg_relid::regclass
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
