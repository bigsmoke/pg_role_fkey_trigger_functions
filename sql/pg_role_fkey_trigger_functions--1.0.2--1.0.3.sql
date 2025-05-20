-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit


/**
 * CHANGELOG.md:
 *
 * - In `pg_role_fkey_trigger_functions` 1.0.0 through 1.0.2, the
 *   `search_path_template`s were not actually being applied, due to a buggy
 *   `SELECT` query in the stored procedure that was supposed to do this work:
 *   `pg_role_fkey_trigger_functions__alter_routines_to_reset_search_paths()`.
 *   ~
 *   This stored procedure has now been fixed.  However, the testing was done
 *   manually, because there is as of yet no testing done outside of the
 *   `search_path` scope in which this extension is installed, and how to do
 *   this remains a difficult choice, which may involve ditching some of Rowan's
 *   ideosyncratic testing methods for some of the same (Perl-based) stuff
 *   that's also used to test Postgres' core and contrib stuff.
 */
create or replace procedure pg_role_fkey_trigger_functions__alter_routines_to_reset_search_paths()
    set search_path to pg_catalog
    language plpgsql
    as $$
declare
    _regprocedure regprocedure;
    _routine_kind text;
    _search_path_template text;
    _old_search_path text;
    _new_search_path text;
    _alter_command text;
begin
    for _regprocedure, _routine_kind, _search_path_template, _old_search_path, _new_search_path in
        select
            pg_proc.oid
            ,case when pg_proc.prokind = 'f' then 'FUNCTION' when pg_proc.prokind = 'p' then 'PROCEDURE' end
            ,search_path_template
            ,"search_path"
            ,regexp_replace(search_path_template, '"\$extension_schema"', quote_ident(pg_namespace.nspname))
        from
            pg_catalog.pg_extension
        inner join
            pg_catalog.pg_namespace
            on pg_namespace.oid = pg_extension.extnamespace
        inner join
            pg_catalog.pg_depend
            on pg_depend.refclassid = 'pg_extension'::regclass
            and pg_depend.refobjid = pg_extension.oid
            and pg_depend.classid = 'pg_proc'::regclass
            --and pg_depend.deptype = 'e'
        inner join
            pg_catalog.pg_proc
            on pg_proc.oid = pg_depend.objid
        cross join lateral
            (
                select
                    substring(raw_cfg_item from '(?<==).+$') as search_path_template
                from
                    unnest(pg_proc.proconfig) as raw_cfg_item
                where
                    raw_cfg_item like 'pg_role_fkey_trigger_functions.search_path_template=%'
            ) as extract_search_path_template
        left join lateral
            (
                select
                    substring(raw_cfg_item from '(?<==).+$') as "search_path"
                from
                    unnest(pg_proc.proconfig) as raw_cfg_item
                where
                    raw_cfg_item like 'pg_role_fkey_trigger_functions.search_path=%'
            ) as extract_search_path
            on true
        where
            pg_extension.extname = 'pg_role_fkey_trigger_functions'
    loop
        _alter_command = format(
            'ALTER %s %s SET search_path to %s'
            ,_routine_kind
            ,_regprocedure
            ,_new_search_path
        );
        if _new_search_path is distinct from _old_search_path then
            --raise notice using message = _alter_command;
            execute _alter_command;
        end if;
    end loop;
end;
$$;

call pg_role_fkey_trigger_functions__alter_routines_to_reset_search_paths();
