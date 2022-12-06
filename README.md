---
pg_extension_name: pg_role_fkey_trigger_functions
pg_extension_version: 0.9.0
pg_readme_generated_at: 2022-12-06 12:38:41.869655+00
pg_readme_version: 0.1.3
---

The `pg_role_fkey_trigger_functions` PostgreSQL extension offers a
bunch of trigger functions to help establish and/or maintain referential
integrity for columns that reference PostgreSQL `ROLE` `NAME`s.

`pg_role_fkey_trigger_functions` contains two trigger functions
which can be applied as a table `CONSTRAINT TRIGGER`:

1. `enforce_fkey_to_db_role()` _enforces_ referential integrity by getting angry
   when you try to `INSERT` or `UPDATE` a row value that is not an existing
   `ROLE`.
2. `maintain_referenced_role()` _establishes_ referential integrity by
   `CREATE`ing, `ALTER`ing, and `DROP`ing `ROLE`s whenever

Thus:

1. `enforce_fkey_to_db_role()` works very much like foreign keys normally works;
   while
2. `maintain_referenced_role()` works exactly in the opposite direction that
   foreign keys normally work.

There is also a third trigger function, to maintain role inter-relationships:
`grant_role_in_column1_to_role_in_column2()`.

See the documentation for the `grant_role_in_column1_to_role_in_column2()`
trigger function for an example that builds on all 3 trigger functions.

## Object reference

### Routines

#### Function: `role_fkey_trigger_functions.enforce_fkey_to_db_role()`

The `enforce_fkey_to_db_role()` trigger function is meant to be used for
constraint triggers that raise a `foreign_key_violation` exception when you
are trying to `INSERT` or `UPDATE` a value in the given column that is not a
valid `ROLE` name.

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

Sadly, it is (presently, with PostgreSQL 15) not possible to provide support
for `ON DELETE` and `ON UPDATE` options because PostgreSQL event triggers do
not catch DDL commands that `CREATE`, `ALTER`, and `DROP` roles.  Otherwise, we
could have an event trigger that also gets upset if you invalidate the FK role
relationship _after_ `INSERT`ing or `UPDATE`ing a initially valid `ROLE` name.

#### Function: `role_fkey_trigger_functions.grant_role_in_column1_to_role_in_column2()`

The `grant_role_in_column1_to_role_in_column2()` trigger function is useful if
you have a table with (probably auto-generated) role names that need to be
members of each other.

`grant_role_in_column1_to_role_in_column2()` requires at least 2 arguments:
argument 1 will contain the name of the column that will contain the role name
which the role in the column of the second argument will be automatically made
a member of.

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

#### Function: `role_fkey_trigger_functions.maintain_referenced_role()`

The `maintain_referenced_role()` trigger function performs an `CREATE`,
`ALTER`, or `DROP ROLE`, depending on (changes to) the column value which must
point to a valid `ROLE` name.

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

#### Function: `role_fkey_trigger_functions.pg_role_fkey_trigger_functions_readme()`

This function utilizes the `pg_readme` extension to generate a thorough README
for this extension, based on the `pg_catalog` and the `COMMENT` objects found
therein.

#### Procedure: `role_fkey_trigger_functions.test__pg_role_fkey_trigger_functions()`

## Colophon

This `README.md` for the `pg_role_fkey_trigger_functions` `extension` was automatically generated using the
[`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL
extension.
