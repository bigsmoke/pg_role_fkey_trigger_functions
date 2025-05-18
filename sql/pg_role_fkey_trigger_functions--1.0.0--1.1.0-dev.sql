-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit


create function pg_role_fkey_trigger_functions_managed_role_membership(group_role$ regrole = null)
    returns table (
        pg_authid
        ,pg_auth_members
    );

create function pg_role_fkey_trigger_functions_managed_role(regclass = null, name = null)
    returns table (
        relation_regclass regclass
        ,role_column name
        ,role_record pg_catalog.pg_authid
    );


/**
 * CHANGELOG.md:
 */
create function pg_role_fkey_trigger_functions__catch_extension_relocation()
    returns event_trigger
    language plpgsql
    as $$
declare
    _obj record;
begin
    select obj in select * from pg_event_trigger_ddl_commands()
    loop
    end loop;
end;
$$;

-- TODO: Only install event trigger if superuser
create event trigger pg_role_fkey_trigger_functions__catch_extension_relocation
    on ddl_command_start
    when (TAG = 'ALTER EXTENSION')
    execute function pg_role_fkey_trigger_functions__catch_extension_relocation();


/**
 * CHANGELOG.md:
 *
 * - `pg_authid(regrole)` is a similar convenience constructor, for constructing
 *   rows of the the [`pg_authid` system catalog
 *   type](https://www.postgresql.org/docs/current/catalog-pg-authid.html).
 */
create function pg_authid(regrole)
    returns pg_catalog.pg_authid
    stable
    leakproof
    parallel safe
    return (
        select
            row(pg_authid.*)::pg_catalog.pg_authid
        from
            pg_catalog.pg_authid
        where
            pg_authid.oid = $1
    );




create function pg_auth_members(
        "granted_role$" regrole
        ,"grantee_role$" regrole
        ,"grantor_role$" regrole = current_role
        ,"admin_option$" bool = false
        ,"inherit_option$" bool = null
        ,"set_option$" bool = true
    )
    returns pg_catalog.pg_auth_members
    immutable
    leakproof
    parallel safe
    set search_path to pg_catalog
    language sql
    return row(
        null::oid
        "granted_role$"
        ,"grantee_role$"
        ,"grantor_role$"
        ,"admin_option$"
        ,"inherit_option$"
        ,"set_option$"
    )::pg_catalog.pg_auth_members;


create function manage(
        "new$" pg_catalog.pg_auth_members
        ,"old$" pg_catalog.pg_auth_members
        ,"managed_role_members_setting$" text
            default 'pg_role_fkey_trigger_functions.managed_role_members'
    )
    returns pg_catalog.pg_auth_members
    volatile
    set search_path to 'pg_catalog'
    language plpgsql
    as $$
begin
end;
$$;

create function grant_role_in_column1_to_role_in_column2(
        "new$" anynonarray
        ,"old$" anynonarray
        ,"granted_role_col$" name
        ,"grantee_role_col$" name
        ,"grantor_role$" name = null
        ,"with_admin_option$" bool = false
        ,"with_inherit_option$" bool = null
        ,"with_set_option$" bool = true
    )
    returns anynonarray
    language plpgsql
    as $$
declare
    _new_granted_role name;
    _new_grantee_role name;
    _old_granted_role name;
    _old_grantee_role name;
begin
    -- Extract the role names from the column values into variables:
    execute format('SELECT $1.%1$I, $1.%2$I, $2.%1$I, $2.%2$I', "granted_role_col$", "grantee_role_col$")
        using "old$", "new$"
        into _old_granted_role, _old_grantee_role, _new_granted_role, _new_grantee_role;

    if (tg_op = 'UPDATE'
        and _old_granted_role is not distinct from _new_granted_role
        and _old_grantee_role is not distinct from _new_grantee_role
    ) then
        raise assert_failure using
            message = format(
                '%I AFTER UPDATE trigger executed without any changes to %I (column 1) or %I (column 2).',
                tg_name,
                "granted_role_col$",
                "grantee_role_col$"
            )
            ,hint = format(
                'Add a WHEN condition to the AFTER UPDATE trigger on %3$s to make sure that this trigger'
                ' is only executed WHEN (NEW.%1$I IS DISTINCT FROM OLD.%1$I OR NEW.%2$I IS DISTINCT'
                ' FROM OLD.%2$I).',
                "granted_role_col$",
                "grantee_role_col$",
                tg_relid::regclass
            )
            ,table = tg_table_name
            ,schema = tg_table_schema
        ;
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
            and pg_auth_members.admin_option = _with_admin_option
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
end;
$$;

comment on function grant_role_in_column1_to_role_in_column2(
        anynonarray, anynonarray, name,  name, text, name
    ) is
$md$A helper function to use in your own trigger functions with which to grant the role from one column to the role in another column.

This function, with its 6 arguments, is very similar to the ready-made
[`grant_role_in_column1_to_role_in_column2()`] trigger function.  There are a
couple of reasons why you may want to use the presently described
`grant_role_in_column1_to_role_in_column2(anynonarray, anynonarray, name, name,
text, name)` function instead of the ready-made
[`grant_role_in_column1_to_role_in_column2()`] trigger function:

1. When you write your own trigger function around
   `grant_role_in_column1_to_role_in_column2(anynonarray, anynonarray, name,
    name, text, name)`, you can give the owner of that function a more narrow
   set of permissions.  For instance, if your custom trigger function only
   does the granting and/or revoking (through
   `revoke_role_in_column1_from_role_in_column2(anynonarray, anynonarray, name,
    name, text, name)`), it won't need the global `CREATEROLE` permission
   and only the `WITH ADMIN` option on the role membership grant of the role
   that owns the custom trigger function on the roles that it will in turn
   dynamically grant membership to.

2. You may wish to combine more or even all of the dynamic role creating,
   granting and revoking in a single trigger function, which is especially
   useful if you like to keep this logic together and prefer a procedural
   programming style over event-based thinking.

See also the description of [`grant_role_in_column1_to_role_in_column2()`] for
more general explanation that applies to both functions.

[`grant_role_in_column1_to_role_in_column2()`]:
    #function-grant_role_in_column1_to_role_in_column2
$md$;


/**
 * CHANGELOG.md:
 *
 * - Some functionality of the `maintain_referenced_role()` trigger function has
 *   been duplicated into a same-named function that can be used in custom trigger
 *   functions.  `maintain_referenced_role(anynonarray, anynonarray, name, text)`
 *   function takes as arguments:
 *
 *   1. the `NEW` record;
 *   2. the `OLD` record;
 *   3. the column name with the role names; and,
 *   4. optionally, the options for the `CREATE ROLE`/`ALTER ROLE` statements.
 */
create function maintain_referenced_role(anynonarray, anynonarray, name, text = '')
    returns anynonarray
    set pg_role_fkey_trigger_functions.search_path_template = 'pg_catalog, "$extension_schema"'
    language plpgsql
    as $$
declare
    _new alias for $1;
    _old alias for $2;
    _role_fkey_column alias for $3;
    _create_role_options alias for $4;
    _old_role name;
    _new_role name;
    _new_regrole regrole;
    _existing_role_is_managed bool;
    _existing_role_fkey_col_path text;
    _role_fkey_col_path text;
    _table_schema name;
    _table_name name;
    _table_regclass regclass;
begin
    -- NOTE: When you edit this function, edit the other `maintain_referenced_role()` function(s) accordingly.

    execute 'SELECT $1.' || quote_ident(_role_fkey_column) || ', $2.' || quote_ident(_role_fkey_column)
        into _new_role, _old_role
        using _new, _old;

    select
        pg_namespace.nspname
        ,pg_class.relname
        ,pg_class.oid
    into
        _table_schema
        ,_table_name
        ,_table_regclass
    from
        pg_catalog.pg_class
    join
        pg_catalog.pg_namespace
        on pg_namespace.oid = pg_class.relnamespace
    where
        reltype = pg_typeof(_new)
        and relkind in ('r', 'v', 'p')
    ;

    if not _table_regclass = any(pg_role_fkey_trigger_functions__trusted_tables()) then
        raise insufficient_privilege using
            message = format(
                '`%I.%I` is not present in the `pg_role_fkey_trigger_functions.trusted_tables` setting.'
                ,_table_schema, _table_name
            )
            ,hint = format(
                'To add `%I.%I` as a trusted table for `%I()`, run'
                ' `SELECT pg_role_fkey_trigger_functions__trust_table(%L, %L)`.'
                ' Omit the second argument if you want the trust to be database-wide, not role-specific.'
                ,_table_schema, _table_name,
                'revoke_role_in_column1_from_role_in_column2'
                ,_table_regclass::text, current_user
            )
        ;
    end if;

    if _table_schema is null or _table_name is null then
        raise invalid_parameter_value using message = format(
            'The first and second argument should be of some table(ish) type, not of type `%s`.'
            ,pg_typeof(_new)
        );
    end if;

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
        _role_fkey_col_path := quote_ident(current_database()) || '.' || quote_ident(_table_schema)
            || '.' || quote_ident(_table_name) || '.' || quote_ident(_role_fkey_column);

        if _new_regrole is not null and (
            (not _existing_role_is_managed)
            or _existing_role_fkey_col_path != _role_fkey_col_path
        )
        then
            raise integrity_constraint_violation using
                message= format('Role %I already exists.', _new_role)
                ,detail = '`maintain_referenced_role()` expects to itself `INSERT` its requisite roles.';
        end if;
        if _new_regrole is null then
            execute 'CREATE ROLE ' || quote_ident(_new_role) || COALESCE(' ' || _create_role_options, '');
            execute 'ALTER ROLE ' || quote_ident(_new_role)
                || ' SET pg_role_fkey_trigger_functions.role_is_managed TO ' || true::text;
            execute 'ALTER ROLE ' || quote_ident(_new_role)
                || ' SET pg_role_fkey_trigger_functions.role_fkey_col_path TO '
                || quote_literal(_role_fkey_col_path);
        end if;
        assert to_regrole(_new_role) is not null;
    end if;

    if _old_role is not null and _new_role is not null and _old_role != _new_role then
        execute 'ALTER ROLE ' || quote_ident(_old_role) || ' RENAME TO ' || quote_ident(_new_role);
    end if;

    if _old_role is not null and _new_role is null then
        execute 'DROP ROLE ' || quote_ident(_old_role);
    end if;

    if _new is not null then
        return _new;
    end if;
    return _old;
end;
$$;

comment on function maintain_referenced_role(anynonarray, anynonarray, name, text) is
$md$This function is split off from [`maintain_referenced_role()`] trigger function for when you need one of its arguments to be dynamic.

The different `maintain_referenced_role()` functions intentionally suffer code
duplication, for:

1. performance, and for
2. more convenient copy-pasting.

[`maintain_referenced_role()`]: #function-maintain_referenced_role
$md$;

comment on function maintain_referenced_role() is
$md$The `maintain_referenced_role()` trigger function performs an `CREATE`, `ALTER`, or `DROP ROLE`, depending on (changes to) the column value which must point to a valid `ROLE` name.

| Trigger arg.  | Description                                | Example value         |
| ------------- | ------------------------------------------ | ----------------------|
| `tg_argv[0]`  | The name of the column with the role name. | `'dynamic_role'`      |
| `tg_argv[1]`  | `CREATE ROLE` command options.             | `'WITH ADMIN rowan'`  |

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

If you need the functionality of this trigger function, but with dynamic
arguments, you can use its spin-off [`maintain_referenced_role(anynonarray,
    anynonarray, name, text)`] from one of your own trigger functions.

The different `maintain_referenced_role()` functions intentionally suffer code
duplication, for:

1. performance, and for
2. more convenient copy-pasting.

[`maintain_referenced_role(anynonarray, anynonarray, name, text)`]:
#function-maintain_referenced_role-anynonarray-anynonarray-name-text
$md$;

--------------------------------------------------------------------------------------------------------------


/**
 * CHANGELOG.md:
 *
 * - `manage(pg_authid, pg_authid, jsonb, jsonpath)` is a new, more generic, function to manage roles from
 *   within, for example, custom trigger functions.
 */
create function manage(
        ,"new$" pg_catalog.pg_authid
        ,"old$" pg_catalog.pg_authid
        ,"role_is_managed_setting$" text = 'pg_role_fkey_trigger_functions.role_is_managed'
    )
    returns pg_catalog.pg_authid
    volatile
    set search_path to 'pg_catalog'
    language plpgsql
    as $$
declare
    _setting_name text;
    _setting_value text;
    _old_settings jsonb;
    _old_pg_authid pg_catalog.pg_authid;
begin
    if "role_settings$" is not json object then
        raise invalid_parameter_value using
            message = 'The 3rd argument with role configuration parameters should be a JSON object.'
        ;
    end if;
    if "pg_authid$".rolname is null and "pg_authid$".oid is null then
        raise invalid_parameter_value using
            message = '`pg_authid.rolname` and `pg_authid.oid` cannot both be `NULL`.'
        ;
    end if;

    if "pg_authid$".oid is not null then
        select
            pg_authid.*
        into
            _old_pg_authid
        from
            pg_catalog.pg_authid
        where
            pg_authid.oid = "pg_authid$".oid
        ;
    elsif "pg_authid$".rolname is not null then
        select
            row(pg_authid.*)::pg_authid
        into
            _old_pg_authid
        from
            pg_catalog.pg_authid
        where
            pg_authid.rolname = "pg_authid$".rolname
        ;
        "pg_authid$".oid := coalesce("pg_authid$".oid, _old_pg_authid.oid);
    end if;

    -- XXX: Is `_old_settings` not (to be) used?
    if _old_pg_authid is not null then
        select
            jsonb_object_agg(setting_name, setting_value)
        into
            _old_settings
        from
            pg_catalog.pg_db_role_setting
        cross join lateral
            unnest(pg_db_role_setting.setconfig) as r(raw_setting)
        cross join lateral
            (
                select
                    split_part(r.raw_setting, '=', 1) as setting_name
                    ,split_part(r.raw_setting, '=', 2) as setting_value
            ) as parsed_setting
        where
            pg_db_role_setting = pg_authid$.oid
        ;

        -- TODO: perform "assert_config$"
        if true then
            raise integrity_constraint_violation using
                message = format(
                );
        end if;
    end if;

    if _old_pg_authid.oid is null then
        execute 'CREATE ROLE ' || quote_ident("new_name$") || COALESCE(' ' || "role_options$", '');
    end if;

    if _old_pg_authid.oid is not null
        and "pg_authid$".rolname is not null
        and _old_pg_authid.rolname != "pg_authid$".rolname
    then
        execute 'ALTER ROLE ' || _old_pg_authid.rolname || ' RENAME TO ' || quote_ident("pg_authid$".rolname);
    end if;

    if "pg_authid$".oid is not null and "pg_authid$" is null then
        execute 'DROP ROLE ' || "pg_authid$"::text;
    end if;

    if "pg_authid$" is not null and "pg_authid$" is not null then
        for _setting_name, _setting_value in select key, value from jsonb_each_text("role_settings$") loop
            execute format('ALTER ROLE %I SET %s TO %L', "pg_authid$".rolname, _setting_name, _setting_value);
        end loop;
    end if;

    select pg_authid.* into "pg_authid$" from pg_catalog.pg_authid where pg_authid.oid = "pg_authid$".oid;

    select
        jsonb_object_agg(setting_name, setting_value)
    into
        role_settings$
    from
        pg_catalog.pg_db_role_setting
    cross join lateral
        unnest(pg_db_role_setting.setconfig) as r(raw_setting)
    cross join lateral (
        select
            split_part(r.raw_setting, '=', 1) as setting_name
            ,split_part(r.raw_setting, '=', 2) as setting_value
    )   parsed_setting
    where
        pg_db_role_setting = pg_authid$.oid
    ;

    -- TODO: perform "assert_config$"
    if true then
        raise integrity_constraint_violation using
            message = format(
            );
    end if;
end;
$$;

comment on function manage(pg_authid, pg_authid, jsonb, jsonpath) is
$md$Create, alter, or delete a role and its settings as needed.

This function operates in different modes, depending on the input parameters
and state of the given role in the database:

* If the `regrole` argument is null and  `pg_authid` is given, a new role is
  [`create`d](https://www.postgresql.org/docs/current/sql-createrole.html), with
  the settings as specified by the `jsonb` argument.
* If the `regrole` argument is not null and `pg_authid` is also given, that
  means that the role already exists, and it will be
  [`alter`ed](https://www.postgresql.org/docs/current/sql-alterrole.html) as
  needed.
* If the `regrole` argument is not null and `pg_authid` _is_ null, the role will
  be [`drop`ped](https://www.postgresql.org/docs/current/sql-droprole.html).
$md$;


/**
 * CHANGELOG.md:
 *
 * - The `test__pg_role_fkey_trigger_functions()` procedure was modifed to call
 *   itself recursively in two distinct modes:
 *
 *   1. one pass to test the `maintain_referenced_role()` trigger function, and
 *   2. another pass to test with a custom wrapper around the new utility
 *      `maintain_referenced_role(anynonarray, anynonarray, name, text)`
 *      function.
 *
 */
drop procedure test__pg_role_fkey_trigger_functions();
create procedure test__pg_role_fkey_trigger_functions(use_nontrigger_functions$ bool = null)
    set pg_role_fkey_trigger_functions.search_path_template = 'pg_catalog, "$extension_schema"'
    set plpgsql.check_asserts to true
    set pg_readme.include_this_routine_definition to true
    language plpgsql
    as $$
begin
    if use_nontrigger_functions$ is null then
        raise notice 'CALL test__pg_role_fkey_trigger_functions(use_nontrigger_functions$ => false)  -- Recurse';
        call test__pg_role_fkey_trigger_functions(false);
        raise notice 'CALL test__pg_role_fkey_trigger_functions(use_nontrigger_functions$ => true)  -- Recurse';
        call test__pg_role_fkey_trigger_functions(true);
        return;
    end if;

    if use_nontrigger_functions$ then
        create function maintain_referenced_role_wrapper()
            returns trigger
            set search_path from current
            language plpgsql
            as $plpgsql$
            begin
                perform maintain_referenced_role(
                    NEW, OLD, 'account_owner_role', 'IN ROLE test__customer_group'
                );
                return NEW;
            end;
            $plpgsql$;
        create trigger tg2_account_owner_role_fkey
            after insert or update or delete on test__customer
            for each row execute function maintain_referenced_role_wrapper();
    else
        create trigger tg2_account_owner_role_fkey
            after insert or update or delete on test__customer
            for each row execute function maintain_referenced_role(
                'account_owner_role', 'IN ROLE test__customer_group'
            );
    end if;

    -- […]
end;
$$;
