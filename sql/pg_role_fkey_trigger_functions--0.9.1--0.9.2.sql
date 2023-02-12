-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

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
        ,'gpl_3'
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
                "file": "pg_role_fkey_trigger_functions--0.9.0.sql",
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

--------------------------------------------------------------------------------------------------------------

comment
    on function pg_role_fkey_trigger_functions_meta_pgxn()
    is $markdown$
Returns the JSON meta data that has to go into the `META.json` file needed for
[PGXN—PostgreSQL Extension Network](https://pgxn.org/) packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

And indeed, `pg_role_fkey_trigger_functions` can be found on PGXN:
https://pgxn.org/dist/pg_role_fkey_trigger_functions/
$markdown$;

--------------------------------------------------------------------------------------------------------------

comment
    on extension pg_role_fkey_trigger_functions
    is $markdown$
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
    create extension if not exists pg_readme;

    _readme := pg_extension_readme('pg_role_fkey_trigger_functions'::name);

    raise transaction_rollback;  -- to `DROP EXTENSION` if we happened to `CREATE EXTENSION` for just this.
exception
    when transaction_rollback then
        return _readme;
end;
$plpgsql$;

comment
    on function pg_role_fkey_trigger_functions_readme()
    is $markdown$
This function utilizes the `pg_readme` extension to generate a thorough README
for this extension, based on the `pg_catalog` and the `COMMENT` objects found
therein.

$markdown$;

--------------------------------------------------------------------------------------------------------------

alter procedure test__pg_role_fkey_trigger_functions()
    set pg_readme.include_this_routine_definition to true;

--------------------------------------------------------------------------------------------------------------
