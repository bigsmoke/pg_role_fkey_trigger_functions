-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Set search_path to also find `pg_extension_readme()` if the `pg_readme` extension was already installed
-- (outside of the function's own `search_path`) prior to running this function.
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
    $markdown$This function utilizes the `pg_readme` extension to generate a thorough README for this extension, based on the `pg_catalog` and the `COMMENT` objects found therein.
$markdown$;

--------------------------------------------------------------------------------------------------------------
