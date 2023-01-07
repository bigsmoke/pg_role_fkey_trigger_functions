-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

do $$
begin
    execute 'ALTER DATABASE ' || current_database()
        || ' SET pg_role_fkey_trigger_functions.readme_urls TO '
        || quote_literal('https://github.com/bigsmoke/pg_role_fkey_trigger_functions/blob/master/README.md');
end;
$$;

--------------------------------------------------------------------------------------------------------------
