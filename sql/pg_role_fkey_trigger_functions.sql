begin transaction;

create schema role_fkey_trigger_functions;

create extension pg_role_fkey_trigger_functions
    with schema role_fkey_trigger_functions
    cascade;

call role_fkey_trigger_functions.test__pg_role_fkey_trigger_functions();

rollback transaction;
