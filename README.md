---
pg_extension_name: pg_role_fkey_trigger_functions
pg_extension_version: 1.0.1
pg_readme_generated_at: 2025-05-18 13:27:38.24398+01
pg_readme_version: 0.7.0
---

# The `pg_role_fkey_trigger_functions` extension for PostgreSQL

The `pg_role_fkey_trigger_functions` PostgreSQL extension offers a
bunch of trigger functions to help establish and/or maintain referential
integrity for columns that reference PostgreSQL `ROLE` `NAME`s.

`pg_role_fkey_trigger_functions` contains trigger functions for either
_checking_ or _establishing_ referential integrity pertaining to roles
referenced from table columns:

1. [`enforce_fkey_to_db_role()`] _enforces_ referential integrity by getting
   angry when you try to `INSERT`, `UPDATE`, or `COPY` a row value that is not an
   existing `ROLE`.
2. [`maintain_referenced_role()`] _establishes_ referential integrity by
   `CREATE`ing, `ALTER`ing, and `DROP`ing `ROLE`s to stay in sync with the
   value(s) in the column(s) being watched by the trigger function.

Thus:

1. `enforce_fkey_to_db_role()` works very much like foreign keys normally work;
   while
2. `maintain_referenced_role()` works exactly in the opposite direction that
   foreign keys normally work.

In addition to `maintain_referenced_role()`, there are a couple of trigger
functions to maintain dynamic role membership:

* [`grant_role_in_column1_to_role_in_column2()`], and its counterpart
* [`revoke_role_in_column1_from_role_in_column2()`].

Note that these `*_role_in_column1_(to|from)_role_in_column2()` functions are
only necesary if you need anything beyond the membership options that can be
specified as static arguments to the [`maintain_referenced_role()` trigger
function](#function-maintain_referenced_role).

The [`grant_role_in_column1_to_role_in_column2()`] trigger function
documentation features an example that builds on all 3 trigger functions.

[`enforce_fkey_to_db_role()`]:
    #function-enforce_fkey_to_db_role

[`maintain_referenced_role()`]:
    #function-maintain_referenced_role

[`grant_role_in_column1_to_role_in_column2()`]:
    #function-grant_role_in_column1_to_role_in_column2

[`revoke_role_in_column1_from_role_in_column2()`]:
    #function-revoke_role_in_column1_from_role_in_column2

## Secure `pg_role_fkey_trigger_functions` usage

[`maintain_referenced_role()`], [`grant_role_in_column1_to_role_in_column2()`]
and [`revoke_role_in_column1_from_role_in_column2()`] are all `SECURITY DEFINER`
functions.  That means that whoever was granted `EXECUTE` permission on
these functions could grant themselves membership in whichever role they wished
simply by creating a temporary table and creating a couple of triggers.

To mitigate this ~~risk~~<ins>certainty</ins>, `pg_role_fkey_trigger_functions`
version 1.0.0 introduced a new `pg_role_fkey_trigger_functions.trusted_tables`
setting.  The aforementioned `SECURITY DEFINER` trigger functions will refuse to
function [pun intended] on tabled that are not part of the array of trusted
tables stored in this setting (as a `text` string, like all settings must be).

The best way to add tables to this list of trusted tables, is to execute the
[`pg_role_fkey_trigger_functions__trust_table(regclass, regrole)`] function.

To retrieve the list of currently trusted tables, there's the
[`pg_role_fkey_trigger_functions__trusted_tables()`] function. This is also the
function that is used internally by `pg_role_fkey_trigger_functions`
instead of `current_setting()`.  `current_setting()` is never used because the
list of trusted tables could then be overridden for the current session or
transaction simply by calling the [`set_config()`] function or [`SET` command]:

```sql
-- Using the `SET` command:
set pg_role_fkey_trigger_functions.trusted_tables TO '{pg_temp.evil_temp_tbl}';

-- Using the `set_config()` function:
select set_config(
    'pg_role_fkey_trigger_functions.trusted_tables',
    '{pg_temp.evil_temp_tbl}',
    false
);

-- Or, appending to instead of replacing the list of trusted tables:
select set_config(
    'pg_role_fkey_trigger_functions.trusted_tables',
    coalesce(
        current_setting('pg_role_fkey_trigger_functions.trusted_tables', true),
        '{}'
    )::text[] || 'pg_temp.evil_temp_tbl',
    false
);
```

See the opening section of [the README of the `pg_safer_settings` extension]
for a complete exposition of how and why that extension's `pg_db_setting()`
function and the [`pg_role_fkey_trigger_functions__trusted_tables()`] function
(modelled after that `pg_db_setting()` function) bypasses that problem.

[`pg_role_fkey_trigger_functions__trust_table(regclass, regrole)`]:
    #function-pg_role_fkey_trigger_functions__trust_table-regclass-regrole

[`pg_role_fkey_trigger_functions__trusted_tables()`]:
    #function-pg_role_fkey_trigger_functions__trusted_tables-bool-regrole

[`set_config()`]:
    https://www.postgresql.org/docs/current/functions-admin.html#FUNCTIONS-ADMIN-SET

[`SET` command]:
    https://www.postgresql.org/docs/current/sql-set.html

[the README of the `pg_safer_settings` extension]:
    https://github.com/bigsmoke/pg_safer_settings/blob/master/README.md

## `pg_role_fkey_trigger_functions` settings

| Setting name                                           | Description                                                | Example value                       |
| ------------------------------------------------------ | ---------------------------------------------------------- | ----------------------------------- |
| `pg_role_fkey_trigger_functions.trusted_tables`        | See [_Secure `pg_role_fkey_trigger_functions` usage_].     | `'{schema_a.tbl_1,schema_a.tbl_2}'` |
| `pg_role_fkey_trigger_functions.search_path_template`  | Template to (re)set the function's `search_path`.          | `'pg_catalog, "$extension_schema"'` |
| `pg_role_fkey_trigger_functions.readme_url`            | The (online) location to find this extension's `README.md` | `'http://example.com/README.html'`  |

[_Secure `pg_role_fkey_trigger_functions` usage_]:
    #secure-pg_role_fkey_trigger_functions-usage

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

## Authors and contributors

* [Rowan](https://www.bigsmoke.us/) originated this extension in 2022 while
  developing the PostgreSQL backend for the [FlashMQ SaaS MQTT cloud
  broker](https://www.flashmq.com/).  Rowan does not like to see himself as a
  tech person or a tech writer, but, much to his chagrin, [he
  _is_](https://blog.bigsmoke.us/category/technology). Some of his chagrin
  about remaining stuck in the IT industry for too long he poured into a book:
  [_Why Programming Still Sucks_](https://www.whyprogrammingstillsucks.com/).
  Much more than a “tech bro”, he identifies as a garden gnome, fairy and ork
  rolled into one, and his passion is really to [regreen and reenchant his
  environment](https://sapienshabitat.com/).  One of his proudest achievements
  is to be the third generation ecological gardener to grow the wild garden
  around his beautiful [family holiday home in the forest of Norg, Drenthe,
  the Netherlands](https://www.schuilplaats-norg.nl/) (available for rent!).

## Object reference

### Routines

#### Function: `enforce_fkey_to_db_role()`

The `enforce_fkey_to_db_role()` trigger function is meant to be used for constraint triggers that raise a `foreign_key_violation` exception when you are trying to `INSERT` or `UPDATE` a value in the given column that is not a valid `ROLE` name.

`enforce_fkey_to_db_role()` takes one argument: the name of a column that is to
be treated as a foreign key to a database `ROLE`.

The following example establishes a constraint trigger such that you can only
set values for the `row_owner_role` column that are valid row names; anything
else will cause a `foreign_key_violation` to be raised:

```sql
create table test__tbl (
    id int
        primary key,
    row_owner_role name
        not null unique
);

create constraint trigger row_owner_role_must_exist
    after insert or update on test__tbl
    for each row
    execute function enforce_fkey_to_db_role('row_owner_role');
```

Sadly, it is (presently, with PostgreSQL 17) not possible to provide support
for `ON DELETE` and `ON UPDATE` options because PostgreSQL event triggers do
not catch DDL commands that `CREATE`, `ALTER`, and `DROP` roles.  Otherwise, we
could have an event trigger that also gets upset if you invalidate the FK role
relationship _after_ `INSERT`ing or `UPDATE`ing a initially valid `ROLE` name.

The renaming of roles _can_ be accomodated, by _not_ using this trigger function
and instead using the `regrole` `oid`-ish type rather than `name` for the
foreign key column:

```sql
create table my_table (
    id int
        primary key,
    row_owner_role regrole
        not null unique
);

create role "Piet-Joris";
assert to_regrole('Piet-Joris') is not null;  -- So, `"piet-joris"` exists.
assert to_regrole('Jan-Pieter') is null;      -- But, `"jan-pieter"` does not.

-- And thus the following will work, due to the implicit conversion of
-- `'Piet-Joris'::text` to `regrole`:
insert into my_table (id, row_owner_role) values (12, 'Piet-Joris');

-- Yet, the following will crash, during the attempted conversion from
-- `'Jan-Pieter'::text` to `regrole`:
insert into my_table (id, row_owner_role) values (13, 'Jan-Pieter');
```

Function return type: `trigger`

Function-local settings:

  *  `SET search_path TO pg_catalog`

#### Function: `grant_role_in_column1_to_role_in_column2()`

The `grant_role_in_column1_to_role_in_column2()` trigger function is useful if
you have a table with (probably auto-generated) role names that need to be
members of each other.

| Trigger arg.  | required  | Example value                                   |
| ------------- | --------- | ----------------------------------------------- |
| `tg_argv[0]`  | yes       | `a_column`                                      |
| `tg_argv[1]`  | yes       | `another_column`                                |
| `tg_argv[2]`  | no        | `WITH ADMIN OPTION, SET TRUE GRANTED BY user_x` |

`grant_role_in_column1_to_role_in_column2()` requires at least 2 arguments:
argument 1 will contain the name of the column that will contain the role name
which the role in the column of the second argument will be automatically made
a member of.

The optional third argument will be passed on in whole to each `ALTER ROLE`
statement and can contain `WITH` options or a `GRANTED BY role_specification`.

If you want the old `GRANT` to be `REVOKE`d `ON UPDATE`, use the companion
trigger function: `revoke_role_in_column1_from_role_in_column2()`.

Here's a full example, that also incorporates the other two trigger functions
packaged into this extension:

```sql
create role customers;

create table test__customer (
    account_owner_role name
        primary key
        default 'user_' || gen_random_uuid()::text,
    account_manager_role name
        not null
);

create constraint trigger account_manager_role_fkey
    after insert or update to test__customer
    for each row
    execute function enforce_fkey_to_db_role('account_manager_role');

create trigger account_owner_role_fkey
    after insert or update or delete to test__customer
    for each row
    execute function maintain_referenced_role(
        'account_owner_role', 'IN ROLE customers'
    );

create trigger grant_owner_impersonation_to_account_manager
    after insert to test__customer
    for each row
    execute function grant_role_in_column1_to_role_in_column2(
        'account_owner_role', 'account_manager_role'
    );
```

See the `test__pg_role_fkey_trigger_functions()` procedure for a more extensive example.

Function return type: `trigger`

Function attributes: `SECURITY DEFINER`

Function-local settings:

  *  `SET pg_role_fkey_trigger_functions.search_path_template TO pg_catalog, "$extension_schema"`

#### Function: `maintain_referenced_role()`

The `maintain_referenced_role()` trigger function performs an `CREATE`, `ALTER`, or `DROP ROLE`, depending on (changes to) the column value which must point to a valid `ROLE` name.

| Trigger arg.  | Description                                | Example value         |
| ------------- | ------------------------------------------ | ----------------------|
| `tg_argv[0]`  | The name of the column with the role name. | `'dynamic_role'`      |
| `tg_argv[1]`  | `CREATE ROLE` command options.             | `'WITH ADMIN rowan'`  |

`maintain_referenced_role()` takes at least one argument: the name of the
column (of type `NAME`) in which the `ROLE` name will be stored.

Additionally, `maintain_referenced_role()` can take a second argument: the
options which will be passed to the `CREATE` and `ALTER ROLE` commands exeuted
by this function.

This trigger function is meant for roles that are to be dynamically created,
altered and dropped, not for verifying the relational integrity of existing
roles; see `enforce_fkey_to_db_role()` for the latter.

The following example will first make `test__owner` pop into existence on
`INSERT`, then be renamed automaticall to `test__new_owner` on `UPDATE` and
finally dropped again, triggered by the `DELETE`.:

```sql
create table test__tbl (
    owner_role name
);

create trigger maintain_owner_role
    after insert or update on test__tbl
    for each row
    execute function maintain_referenced_role('owner_role', 'WITH NOLOGIN');

insert into test__tbl (owner_role)
    values ('test__owner');

update test__tbl
    set owner_role = 'test__new_owner';

delete from test__tbl
    where rolname = 'test__new_owner';
```

Function return type: `trigger`

Function attributes: `SECURITY DEFINER`

Function-local settings:

  *  `SET pg_role_fkey_trigger_functions.search_path_template TO pg_catalog, "$extension_schema"`

#### Procedure: `pg_role_fkey_trigger_functions__alter_routines_to_reset_search_()`

Procedure-local settings:

  *  `SET search_path TO pg_catalog`

#### Function: `pg_role_fkey_trigger_functions_meta_pgxn()`

Returns the JSON meta data that has to go into the `META.json` file needed for PGXN—PostgreSQL Extension Network—packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

And indeed, `pg_role_fkey_trigger_functions` can be found on the
[PGXN—PostgreSQL Extension Network](https://pgxn.org/):
https://pgxn.org/dist/pg_role_fkey_trigger_functions/

Function return type: `jsonb`

Function attributes: `STABLE`

#### Function: `pg_role_fkey_trigger_functions_readme()`

This function utilizes the `pg_readme` extension to generate a thorough README for this extension, based on the `pg_catalog` and the `COMMENT` objects found therein.

The schema in which `pg_readme` was installed doesn't need to be in the
`search_path` when executing this function.  It takes care of that itself.

Function return type: `text`

Function-local settings:

  *  `SET search_path TO role_fkey_trigger_functions, pg_temp`
  *  `SET pg_readme.include_view_definitions TO true`
  *  `SET pg_readme.include_routine_definitions_like TO {test__%}`

#### Function: `pg_role_fkey_trigger_functions__trusted_tables (regrole, text, boolean, boolean, boolean)`

Returns the array of relations (of type `regclass[]`) that are trusted by the `SECURITY DEFINER` trigger functions.

This function has two arguments, both optional:

| Arg.  | Type       | Default value            | Description                                            |
| ----- | ---------- | -------------------------| ------------------------------------------------------ |
| `$1`  | `regrole`  | `current_user::regrole`  | A role whose role-specific settings will be included.  |
| `$2`  | `text`  `  | `current_database()`     | Whether to include database-wide settings or not.      |

See the [_Secure `pg_role_fkey_trigger_functions` usage_] section for details
as to how and why this list is maintained.

[_Secure `pg_role_fkey_trigger_functions` usage_]:
    #secure-pg_role_fkey_trigger_functions-usage

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `role$`                                                           | `regrole`                                                            | `(CURRENT_USER)::regrole` |
|   `$2` |       `IN` | `db$`                                                             | `text`                                                               | `current_database()` |
|   `$3` |       `IN` | `db_not_role_specific$`                                           | `boolean`                                                            | `true` |
|   `$4` |       `IN` | `db_and_role_specific$`                                           | `boolean`                                                            | `true` |
|   `$5` |       `IN` | `role_not_db_specific$`                                           | `boolean`                                                            | `true` |

Function return type: `regclass[]`

Function attributes: `STABLE`, `LEAKPROOF`, `PARALLEL SAFE`

Function-local settings:

  *  `SET search_path TO pg_catalog`

#### Function: `pg_role_fkey_trigger_functions__trust_table (regclass, regrole, text)`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `table$`                                                          | `regclass`                                                           |  |
|   `$2` |       `IN` | `role$`                                                           | `regrole`                                                            | `NULL::regrole` |
|   `$3` |       `IN` | `db$`                                                             | `text`                                                               | `current_database()` |

Function return type: `regclass[]`

Function attributes: `LEAKPROOF`

Function-local settings:

  *  `SET pg_role_fkey_trigger_functions.search_path_template TO pg_catalog, "$extension_schema"`

#### Function: `pg_role_fkey_trigger_functions__trust_tables (regclass[], regrole, text)`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `tables$`                                                         | `regclass[]`                                                         |  |
|   `$2` |       `IN` | `role$`                                                           | `regrole`                                                            | `NULL::regrole` |
|   `$3` |       `IN` | `db$`                                                             | `text`                                                               | `current_database()` |

Function return type: `regclass[]`

Function attributes: `LEAKPROOF`

Function-local settings:

  *  `SET pg_role_fkey_trigger_functions.search_path_template TO pg_catalog, "$extension_schema"`

#### Function: `revoke_role_in_column1_from_role_in_column2()`

Use this trigger function, in concert with `grant_role_in_column1_to_role_in_column2()`, if, `ON UPDATE`, you also want to `REVOKE` the old permissions granted earlier by `grant_role_in_column1_to_role_in_column2()`.

For this trigger function to work, the

**Beware:** This function cannot read your mind and thus will not be aware if there is still another relation that depends on the role in column 2 remaining a member of the role in column 1. As always: use at your own peril.

Function return type: `trigger`

Function attributes: `SECURITY DEFINER`

Function-local settings:

  *  `SET pg_role_fkey_trigger_functions.search_path_template TO pg_catalog, "$extension_schema"`

#### Procedure: `test_dump_restore__maintain_referenced_role (text)`

Procedure arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `test_stage$`                                                     | `text`                                                               |  |

Procedure-local settings:

  *  `SET pg_role_fkey_trigger_functions.search_path_template TO pg_catalog, "$extension_schema"`
  *  `SET plpgsql.check_asserts TO true`
  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE PROCEDURE test_dump_restore__maintain_referenced_role(IN "test_stage$" text)
 LANGUAGE plpgsql
 SET "pg_search_path_template" TO 'pg_catalog, "$extension_schema"'
 SET "plpgsql.check_asserts" TO 'true'
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
declare
    _inserted_account_owner_role name;
begin
    assert test_stage$ in ('pre-dump', 'post-restore');

    if test_stage$ = 'pre-dump' then
        create role test__customer_group;
        create role test__account_manager;

        create table test__customer (
            account_owner_role name
                primary key
                default 'user_' || gen_random_uuid()::text,
            account_manager_role name
                not null
        );
        perform pg_role_fkey_trigger_functions__trust_table('test__customer');

        create trigger account_owner_role_fkey
            after insert or update or delete on test__customer
            for each row
            execute function maintain_referenced_role(
                'account_owner_role', 'IN ROLE test__customer_group'
            );

        create trigger account_manager_role_fkey
            after insert or update on test__customer
            for each row
            execute function enforce_fkey_to_db_role(
                'account_manager_role'
            );

        insert into test__customer
            (account_owner_role, account_manager_role)
        values
            (default, 'test__account_manager'::regrole)
        returning
            account_owner_role
        into
            _inserted_account_owner_role
        ;

        assert exists (select from pg_roles where rolname = _inserted_account_owner_role),
            'The role should have been created by the maintain_referenced_role() trigger function.';

    elsif test_stage$ = 'post-restore' then
        assert (select count(*) from test__customer) = 1,
            'Records should have been recreated without crashing.';

        _inserted_account_owner_role := (select account_owner_role from test__customer);

        -- Now, let's lazily pretend that the database has been dropped and recreated
        truncate table test__customer;  -- This should not trigger the `account_owner_role_fkey` trigger.

        insert into test__customer
            (account_owner_role, account_manager_role)
        values
            (_inserted_account_owner_role, 'test__account_manager'::regrole)
        ;
    end if;
end;
$procedure$
```

#### Procedure: `test__pg_role_fkey_trigger_functions()`

Procedure-local settings:

  *  `SET pg_role_fkey_trigger_functions.search_path_template TO pg_catalog, "$extension_schema"`
  *  `SET plpgsql.check_asserts TO true`
  *  `SET pg_readme.include_this_routine_definition TO true`

```sql
CREATE OR REPLACE PROCEDURE test__pg_role_fkey_trigger_functions()
 LANGUAGE plpgsql
 SET "pg_search_path_template" TO 'pg_catalog, "$extension_schema"'
 SET "plpgsql.check_asserts" TO 'true'
 SET "pg_readme.include_this_routine_definition" TO 'true'
AS $procedure$
declare
    _inserted_account_owner_role name;
    _updated_account_owner_role name;
begin
    create role test__customer_group;
    create role test__account_manager;
    create role test__new_account_manager;
    create role test__youngest_intern;
    create role test__trusting_role;

    create table test__customer (
        account_owner_role name
            primary key
            default 'user_' || gen_random_uuid()::text,
        account_manager_role name
            not null
    );

    create constraint trigger tg1_account_manager_role_fkey
        after insert or update on test__customer
        for each row
        execute function enforce_fkey_to_db_role('account_manager_role');

    create trigger tg2_account_owner_role_fkey
        after insert or update or delete on test__customer
        for each row execute function maintain_referenced_role(
            'account_owner_role', 'IN ROLE test__customer_group'
        );

    create trigger tg3_grant_owner_impersonation_to_account_manager
        after insert on test__customer
        for each row
        execute function grant_role_in_column1_to_role_in_column2(
            'account_owner_role', 'account_manager_role'
        );

    create trigger tg4_revoke_owner_impersonation_from_old_account_manager
        after update on test__customer
        for each row
        when (NEW.account_manager_role is distinct from OLD.account_manager_role)
        execute function revoke_role_in_column1_from_role_in_column2(
            'account_owner_role', 'account_manager_role'
        );

    create trigger tg5_grant_owner_impersonation_to_new_account_manager
        after update on test__customer
        for each row
        when (NEW.account_manager_role is distinct from OLD.account_manager_role)
        execute function grant_role_in_column1_to_role_in_column2(
            'account_owner_role', 'account_manager_role'
        );

    assert pg_role_fkey_trigger_functions__trusted_tables() = '{}'::regclass[];
    assert pg_role_fkey_trigger_functions__trusted_tables('test__trusting_role') = '{}'::regclass[];
    perform pg_role_fkey_trigger_functions__trust_table('test__customer', 'test__trusting_role');
    assert pg_role_fkey_trigger_functions__trusted_tables('test__trusting_role') = array[
        'test__customer'::regclass
    ]::regclass[], pg_role_fkey_trigger_functions__trusted_tables('test__trusting_role') ;

    <<untrusted_table>>
    declare
    begin
        insert into test__customer
            (account_owner_role, account_manager_role)
        values
            (default, 'test__account_manager'::regrole)
        returning
            account_owner_role
        into
            _inserted_account_owner_role
        ;
        raise assert_failure
            using message = 'The trigger function should have raised `insufficient_privilege`.';
    exception
        when insufficient_privilege then
    end;

    perform pg_role_fkey_trigger_functions__trust_table('test__customer');

    <<insert_invalid_role_reference>>
    declare
        _message_text text;
        _pg_exception_detail text;
        _nonexistent_role name := 'test__account_manager_that_doesnt_exist';
    begin
        insert into test__customer
            values (default, _nonexistent_role);
        raise assert_failure
            using message = 'The trigger function should have gotten upset about the missing `ROLE`.';
    exception
        when foreign_key_violation then
            get stacked diagnostics
                _message_text := message_text
                ,_pg_exception_detail := pg_exception_detail
            ;

            assert _message_text = format('Unknown database role: %I', _nonexistent_role);
            assert _pg_exception_detail = format(
                '`TRIGGER tg1_account_manager_role_fkey AFTER INSERT ON %I.test__customer FOR EACH ROW'
                ' EXECUTE FUNCTION enforce_fkey_to_db_role(%L)`'
                ,current_schema(), 'account_manager_role'
            ), format('Unexpected error detail: %s', _pg_exception_detail);
    end;

    <<insert_existing_role>>
    declare
        _role constant name := 'test__preexisting_user';
    begin
        create role test__preexisting_user;
        insert into test__customer
            values (_role, 'test__account_manager'::regrole);
        raise assert_failure using message = format(
            'The trigger function should have gotten upset about the existing `%I` role.', _role
        );
    exception
        when integrity_constraint_violation then
            assert sqlerrm = format('Role %I already exists.', _role),
                format('Unexpected `sqlerrm = %L`', sqlerrm)
            ;
    end insert_existing_role;

    insert into test__customer
        (account_owner_role, account_manager_role)
    values
        (default, 'test__account_manager'::regrole)
    returning
        account_owner_role
    into
        _inserted_account_owner_role
    ;

    assert exists (select from pg_roles where rolname = _inserted_account_owner_role),
        'The role should have been created by the maintain_referenced_role() trigger function.';

    assert pg_has_role(_inserted_account_owner_role, 'test__customer_group', 'USAGE'),
        'The new role should have became a member of the "test__customer_group".';

    assert pg_has_role('test__account_manager', _inserted_account_owner_role::regrole, 'USAGE'), format(
        'The %s role should have gotten access to the new %s "account_owner_role" by action of the'
        ' grant_role_in_column1_to_role_in_column2() trigger function'
        ,'test__account_manager', _inserted_account_owner_role
    );

    <<set_invalid_role_reference>>
    begin
        update test__customer
            set account_manager_role = 'test__invalid_account_manager';
        raise assert_failure
            using message = 'The trigger function should have gotten upset about the missing `ROLE`.';
    exception
        when foreign_key_violation then
            assert sqlerrm = 'Unknown database role: test__invalid_account_manager';
    end;

    -- Dummy update, to check for rogue trigger behaviour
    update test__customer
        set account_manager_role = account_manager_role;

    _updated_account_owner_role := 'test__custom_user_name';
    update test__customer
        set account_owner_role = _updated_account_owner_role;

    assert exists (select from pg_roles where rolname = _updated_account_owner_role);
    assert not exists (select from pg_roles where rolname = _inserted_account_owner_role);
    assert pg_has_role(_updated_account_owner_role, 'test__customer_group', 'USAGE');
    assert pg_has_role('test__account_manager', _updated_account_owner_role, 'USAGE');

    update test__customer
        set account_manager_role = 'test__new_account_manager'::regrole;
    assert not pg_has_role('test__account_manager', _updated_account_owner_role, 'USAGE'),
        'The old account manager should have lost impersonation rights on this customer.';
    assert pg_has_role('test__new_account_manager', _updated_account_owner_role, 'USAGE'),
        'The new account manager should have gotten impersonation rights on this customer.';

    delete from test__customer;
    assert not exists (select from pg_roles where rolname = _updated_account_owner_role);
    drop role test__customer_group;
    drop role test__account_manager;
    drop role test__new_account_manager;
    drop role test__trusting_role;

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$procedure$
```

## Colophon

This `README.md` for the `pg_role_fkey_trigger_functions` extension was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.
