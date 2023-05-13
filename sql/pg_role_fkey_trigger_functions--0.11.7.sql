-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment on extension pg_role_fkey_trigger_functions is
$markdown$
# The `pg_role_fkey_trigger_functions` extension for PostgreSQL

The `pg_role_fkey_trigger_functions` PostgreSQL extension offers a
bunch of trigger functions to help establish and/or maintain referential
integrity for columns that reference PostgreSQL `ROLE` `NAME`s.

`pg_role_fkey_trigger_functions` contains two trigger functions
which can be applied as a table `CONSTRAINT TRIGGER`:

1. `enforce_fkey_to_db_role()` _enforces_ referential integrity by getting angry
   when you try to `INSERT` or `UPDATE` a row value that is not an existing
   `ROLE`.
2. `maintain_referenced_role()` _establishes_ referential integrity by
   `CREATE`ing, `ALTER`ing, and `DROP`ing `ROLE`s to stay in sync with the
   value(s) in the column(s) being watched by the trigger function.

Thus:

1. `enforce_fkey_to_db_role()` works very much like foreign keys normally works;
   while
2. `maintain_referenced_role()` works exactly in the opposite direction that
   foreign keys normally work.

There is also a third trigger function, to maintain role inter-relationships:
`grant_role_in_column1_to_role_in_column2()`.

See the documentation for the
[`grant_role_in_column1_to_role_in_column2()`](#function-grant_role_in_column1_to_role_in_column2)
trigger function for an example that builds on all 3 trigger functions.

## The origins of the `pg_role_fkey_trigger_functions` extension

`pg_role_fkey_trigger_functions`, together with quite a sizeable bunch of other
PostgreSQL extensions, originated from the stables of the super-scalable
[FlashMQ](https://www.flashmq.com) managed MQTT hosting platform.  Its author,
responsible for the PostgreSQL backend of flashmq.com, found that a lot of the
Postgres functionality that started within the walls of that project deserved
wider exposure, even if just to make it easier for him and his colleagues to
reuse their craftwork across different projects.

And public release turns out to improve discipline:

- around the polishing of rough edges;
- around documentation completeness and up-to-dateness; and
- around keeping the number of interdependencies to a minimum (thus improving
  the architecture of the system using those extensions).

## Authors and contributors

* [Rowan](https://www.bigsmoke.us/) originated this extension in 2022 while
  developing the PostgreSQL backend for the [FlashMQ SaaS MQTT cloud
  broker](https://www.flashmq.com/).  Rowan does not like to see himself as a
  tech person or a tech writer, but, much to his chagrin, [he
  _is_](https://blog.bigsmoke.us/category/technology). Some of his chagrin
  about remaining stuck in the IT industry for too long he poured into a book:
  [_Why Programming Still Sucks_](https://www.whyprogrammingstillsucks.com/).
  Much more than a “tech bro”, he identifies as a garden gnome, fairy and ork
  rolled into one, and his passion is really to [regreen and reenchant his
  environment](https://sapienshabitat.com/).  One of his proudest achievements
  is to be the third generation ecological gardener to grow the wild garden
  around his beautiful [family holiday home in the forest of Norg, Drenthe,
  the Netherlands](https://www.schuilplaats-norg.nl/) (available for rent!).


<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------

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

comment on function pg_role_fkey_trigger_functions_readme() is
$md$This function utilizes the `pg_readme` extension to generate a thorough README for this extension, based on the `pg_catalog` and the `COMMENT` objects found therein.
$md$;

--------------------------------------------------------------------------------------------------------------

do $$
declare
    _ddl_cmd_to_set_pg_role_fkey_trigger_functions_url text;
begin
    _ddl_cmd_to_set_pg_role_fkey_trigger_functions_url := format(
        'ALTER DATABASE %I SET pg_role_fkey_trigger_functions.readme_url = %L'
        ,current_database()
        ,'https://github.com/bigsmoke/pg_role_fkey_trigger_functions/blob/master/README.md'
    );
    execute _ddl_cmd_to_set_pg_role_fkey_trigger_functions_url;
exception
    when insufficient_privilege then
        -- We say `superuser = false` in the control file; so let's just whine a little instead of crashing.
        raise warning using
            message = format(
                'Because you''re installing the pg_role_fkey_trigger_functions extension as non-superuser'
                ' and because you are also not the owner of the %I DB, the database-level'
                ' `pg_role_fkey_trigger_functions.readme_url` setting has not been set.',
                current_database()
            )
            ,detail = 'Settings of the form `<extension_name>.readme_url` are used by `pg_readme` to'
                || ' cross-link between extensions their README files.'
            ,hint = 'If you want full inter-extension README cross-linking, you can ask your friendly'
                || E' neighbourhood DBA to execute the following statement:\n'
                || _ddl_cmd_to_set_pg_role_fkey_trigger_functions_url || ';';
end;
$$;

--------------------------------------------------------------------------------------------------------------

create or replace function pg_role_fkey_trigger_functions_meta_pgxn()
    returns jsonb
    stable
    language sql
    return jsonb_build_object(
        'name'
        ,'pg_role_fkey_trigger_functions'
        ,'abstract'
        ,'A bunch of trigger functions to help establish and/or maintain referential integrity for columns'
            ' that reference PostgreSQL ROLE NAMEs.'
        ,'description'
        ,'The pg_role_fkey_trigger_functions PostgreSQL extension offers a bunch of trigger functions to'
            ' help establish and/or maintain referential integrity for columns that reference PostgreSQL'
            ' ROLE NAMEs.'
        ,'version'
        ,(
            select
                pg_extension.extversion
            from
                pg_catalog.pg_extension
            where
                pg_extension.extname = 'pg_role_fkey_trigger_functions'
        )
        ,'maintainer'
        ,array[
            'Rowan Rodrik van der Molen <rowan@bigsmoke.us>'
        ]
        ,'license'
        ,'postgresql'
        ,'prereqs'
        ,'{
            "runtime": {
                "requires": {
                    "hstore": 0
                }
            },
            "test": {
                "requires": {
                    "pgtap": 0
                }
            },
            "develop": {
                "recommends": {
                    "pg_readme": 0
                }
            }
        }'::jsonb
        ,'provides'
        ,('{
            "pg_role_fkey_trigger_functions": {
                "file": "pg_role_fkey_trigger_functions--0.11.7.sql",
                "version": "' || (
                    select
                        pg_extension.extversion
                    from
                        pg_catalog.pg_extension
                    where
                        pg_extension.extname = 'pg_role_fkey_trigger_functions'
                ) || '",
                "docfile": "README.md"
            }
        }')::jsonb
        ,'resources'
        ,'{
            "homepage": "https://blog.bigsmoke.us/tag/pg_role_fkey_trigger_functions",
            "bugtracker": {
                "web": "https://github.com/bigsmoke/pg_role_fkey_trigger_functions/issues"
            },
            "repository": {
                "url": "https://github.com/bigsmoke/pg_role_fkey_trigger_functions.git",
                "web": "https://github.com/bigsmoke/pg_role_fkey_trigger_functions",
                "type": "git"
            }
        }'::jsonb
        ,'meta-spec'
        ,'{
            "version": "1.0.0",
            "url": "https://pgxn.org/spec/"
        }'::jsonb
        ,'generated_by'
        ,'`select pg_role_fkey_trigger_functions_meta_pgxn()`'
        ,'tags'
        ,array[
            'function',
            'functions',
            'plpgsql',
            'foreign key',
            'referential integrity',
            'trigger'
        ]
    );

comment on function pg_role_fkey_trigger_functions_meta_pgxn() is
$md$Returns the JSON meta data that has to go into the `META.json` file needed for PGXN—PostgreSQL Extension Network—packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

And indeed, `pg_role_fkey_trigger_functions` can be found on the
[PGXN—PostgreSQL Extension Network](https://pgxn.org/):
https://pgxn.org/dist/pg_role_fkey_trigger_functions/
$md$;

--------------------------------------------------------------------------------------------------------------

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

comment on function enforce_fkey_to_db_role() is
$md$The `enforce_fkey_to_db_role()` trigger function is meant to be used for constraint triggers that raise a `foreign_key_violation` exception when you are trying to `INSERT` or `UPDATE` a value in the given column that is not a valid `ROLE` name.

`enforce_fkey_to_db_role()` takes one argument: the name of a column that is to
be treated as a foreign key to a database `ROLE`.

The following example establishes a constraint trigger such that you can only
set values for the `row_owner_role` column that are valid row names; anything
else will cause a `foreign_key_violation` to be raised:

```sql
create table test__tbl (
    id int
        primary key,
    row_owner_role name
        not null unique
);

create constraint trigger row_owner_role_must_exist
    after insert or update on test__tbl
    for each row
    execute function enforce_fkey_to_db_role('row_owner_role');
```

Sadly, it is (presently, with PostgreSQL 15) not possible to provide support
for `ON DELETE` and `ON UPDATE` options because PostgreSQL event triggers do
not catch DDL commands that `CREATE`, `ALTER`, and `DROP` roles.  Otherwise, we
could have an event trigger that also gets upset if you invalidate the FK role
relationship _after_ `INSERT`ing or `UPDATE`ing a initially valid `ROLE` name.
$md$;

--------------------------------------------------------------------------------------------------------------

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
$md$ The `grant_role_in_column1_to_role_in_column2()` trigger function is useful if you have a table with (probably auto-generated) role names that need to be members of each other.

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
$md$;

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

comment on function revoke_role_in_column1_from_role_in_column2() is
$md$Use this trigger function, in concert with `grant_role_in_column1_to_role_in_column2()`, if, `ON UPDATE`, you also want to `REVOKE` the old permissions granted earlier by `grant_role_in_column1_to_role_in_column2()`.

**Beware:** This function cannot read your mind and thus will not be aware if there is still another relation that depends on the role in column 2 remaining a member of the role in column 1. As always: use at your own peril.
$md$;

--------------------------------------------------------------------------------------------------------------

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

comment on function maintain_referenced_role is
$md$The `maintain_referenced_role()` trigger function performs an `CREATE`, `ALTER`, or `DROP ROLE`, depending on (changes to) the column value which must point to a valid `ROLE` name.

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
$md$;

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
