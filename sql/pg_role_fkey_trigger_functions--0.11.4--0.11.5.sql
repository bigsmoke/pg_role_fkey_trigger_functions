-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit


/**
 * CHANGELOG.md:
 *
 * - The extension upgrade script from version 0.11.3 to 0.11.4 neglected to
 *   add role-specific settings for roles previously added by the
 *   `maintain_referenced_role()` trigger function.  This is now retroactively
 *   done by the version 0.11.4 to 0.11.5 upgrade script.
 */
do $$
declare
    _role name;
    _role_fkey_col_path text;
    _schema name;
    _table name;
    _column name;
begin

    for
        _role_fkey_col_path
        ,_schema
        ,_table
        ,_column
    in
        select
            quote_ident(current_database())
                || '.' || pg_class.relnamespace::regnamespace::text
                || '.' || quote_ident(pg_class.relname)
                || '.' || split_part(encode(pg_trigger.tgargs, 'escape'), '\000', 1)
            ,pg_class.relnamespace::regnamespace
            ,pg_class.relname
            ,split_part(encode(pg_trigger.tgargs, 'escape'), '\000', 1)
        from
            pg_trigger
        inner join
            pg_class
            on pg_class.oid = pg_trigger.tgrelid
        where
            pg_trigger.tgfoid = 'maintain_referenced_role()'::regprocedure
    loop
        for
            _role
        in execute format('SELECT %I FROM %I.%I' , _column, _schema, _table)
        loop
            execute 'ALTER ROLE ' || quote_ident(_role)
                || ' SET pg_role_fkey_trigger_functions.role_is_managed TO ' || true::text;
            execute 'ALTER ROLE ' || quote_ident(role)
                || ' SET pg_role_fkey_trigger_functions.role_fkey_col_path TO '
                || quote_literal(_role_fkey_col_path);
        end loop;
    end loop;
end;
$$;
