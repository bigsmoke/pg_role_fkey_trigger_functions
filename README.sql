\pset tuples_only
\pset format unaligned

begin;

create schema role_fkey_trigger_functions;

create extension pg_role_fkey_trigger_functions
    with schema role_fkey_trigger_functions
    cascade;

select role_fkey_trigger_functions.pg_role_fkey_trigger_functions_readme();

rollback;
