-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- This was originally an unconditional `ALTER DATABASE` statement, which disregarded the facts that the
-- `.control` file of this extension states that this extension should be installable for non-superusers.
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
