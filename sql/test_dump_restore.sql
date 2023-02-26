\o /dev/null
select not :{?test_stage} as test_stage_missing, not :{?extension_name} as extension_name_missing;
\o
\gset
\if :test_stage_missing
    \warn 'Missing `:test_stage` variable.'
    \quit
\endif
\if :extension_name_missing
    \warn 'Missing `:extension_name` variable.'
    \quit
\endif
\o /dev/null
select :'test_stage' = 'pre-dump' as in_pre_dump_stage;
\o
\gset

\set SHOW_CONTEXT 'errors'

\if :in_pre_dump_stage
    create extension pg_role_fkey_trigger_functions with cascade;
\endif

call test_dump_restore__maintain_referenced_role(:'test_stage'::text);
