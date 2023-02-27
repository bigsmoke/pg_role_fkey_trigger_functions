
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
