/*
This file is part of the `pg_role_fkey_trigger_functions` PostgreSQL extension.
Copyright © 2022 Rowan Rodrik van der Molen.

`pg_role_fkey_trigger_functions` is free software: you can redistribute it
and/or modify it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

 `pg_role_fkey_trigger_functions` is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General
Public License for more details.

You should have received a copy of the GNU Affero General Public License along
with `pg_role_fkey_trigger_functions`. If not, see
<https://www.gnu.org/licenses/>.
*/

--------------------------------------------------------------------------------------------------------------

-- complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment
    on extension pg_role_fkey_trigger_functions
    is $markdown$
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

<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------

create or replace function pg_role_fkey_trigger_functions_readme()
    returns text
    volatile
    set search_path from current
    set pg_readme.include_view_definitions to 'true'
    set pg_readme.include_routine_definitions to 'false'
    language plpgsql
    as $plpgsql$
declare
    _readme text;
begin
    create extension if not exists pg_readme
        with version '0.1.3';

    _readme := pg_extension_readme('pg_role_fkey_trigger_functions'::name);

    raise transaction_rollback;  -- to `DROP EXTENSION` if we happened to `CREATE EXTENSION` for just this.
exception
    when transaction_rollback then
        return _readme;
end;
$plpgsql$;
comment
    on function pg_role_fkey_trigger_functions_readme()
    is $markdown$
This function utilizes the `pg_readme` extension to generate a thorough README
for this extension, based on the `pg_catalog` and the `COMMENT` objects found
therein.

$markdown$;

--------------------------------------------------------------------------------------------------------------

create function enforce_fkey_to_db_role()
    returns trigger
    language plpgsql
    as $$
declare
    _role_fkey_column name;
    _new_role name;
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE');
    assert tg_nargs = 1,
        'You must supply the name of the row column in the CREATE TRIGGER definition.';

    _role_fkey_column := tg_argv[0];

    execute 'SELECT $1.' || quote_ident(_role_fkey_column) into _new_role using NEW;

    if not exists (select from pg_catalog.pg_roles where pg_roles.rolname = _new_role) then
        raise foreign_key_violation
            using message = 'Unknown database role: ' || _role_fkey_column;
        return null;
    end if;

    return NEW;
end;
$$;
comment
    on function enforce_fkey_to_db_role()
    is $markdown$
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

$markdown$;

--------------------------------------------------------------------------------------------------------------

create function maintain_referenced_role()
    returns trigger
    security definer
    language plpgsql
    as $$
declare
    _role_fkey_column name;
    _create_role_options text;
    _old_role name;
    _new_role name;
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op in ('INSERT', 'UPDATE', 'DELETE');
    assert tg_nargs >= 1,
        'You must supply the name of the row column in the `CREATE TRIGGER` definition.';

    _role_fkey_column := tg_argv[0];

    if tg_nargs > 1 then
        _create_role_options := tg_argv[1];
    end if;

    execute 'SELECT $1.' || quote_ident(_role_fkey_column) || ', $2.' || quote_ident(_role_fkey_column)
        into _new_role, _old_role using NEW, OLD;

    if _old_role is null and _new_role is not null then
        execute 'CREATE ROLE ' || quote_ident(_new_role) || COALESCE(' ' || _create_role_options, '');
    end if;

    if _old_role is not null and _new_role is not null and _old_role != _new_role then
        execute 'ALTER ROLE ' || quote_ident(_old_role) || ' RENAME TO ' || quote_ident(_new_role);
    end if;

    if _old_role is not null and _new_role is null then
        execute 'DROP ROLE ' || quote_ident(_old_role);
    end if;

    return NEW;
end;
$$;
comment
    on function maintain_referenced_role
    is $markdown$
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

$markdown$;

--------------------------------------------------------------------------------------------------------------

create function grant_role_in_column1_to_role_in_column2()
    returns trigger
    security definer
    language plpgsql
    as $$
declare
    _granted_role_col name;
    _grantee_role_col name;
    _granted_role name;
    _grantee_role name;
    _options text;
begin
    assert tg_when = 'AFTER';
    assert tg_level = 'ROW';
    assert tg_op = 'INSERT';
    assert tg_nargs between 2 and 3,
        'Names of the group and member columns are needed in the CREATE TRIGGER definition.';

    _granted_role_col := tg_argv[0];
    _grantee_role_col := tg_argv[1];
    if tg_nargs > 2 then
        _options := tg_argv[2];
    end if;

    execute format('SELECT $1.%I, $1.%I', _granted_role_col, _grantee_role_col)
        using NEW
        into _granted_role, _grantee_role;

    execute 'GRANT ' || quote_ident(_granted_role) || ' TO ' || quote_ident(_grantee_role)
        || coalesce(' ' || _options,  '');

    return NEW;
end;
$$;

comment
    on function grant_role_in_column1_to_role_in_column2()
    is $markdown$
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

$markdown$;

--------------------------------------------------------------------------------------------------------------

create procedure test__pg_role_fkey_trigger_functions()
    set search_path from current
    set plpgsql.check_asserts to true
    language plpgsql
    as $$
declare
    _inserted_account_owner_role name;
    _updated_account_owner_role name;
begin
    create role test__customer_group;
    create role test__account_manager;

    create table test__customer (
        account_owner_role name
            primary key
            default 'user_' || gen_random_uuid()::text,
        account_manager_role name
            not null
    );

    create constraint trigger account_manager_role_fkey
        after insert or update on test__customer
        for each row
        execute function enforce_fkey_to_db_role('account_manager_role');

    create trigger account_owner_role_fkey
        after insert or update or delete on test__customer
        for each row
        execute function maintain_referenced_role(
            'account_owner_role', 'IN ROLE test__customer_group'
        );

    create trigger grant_owner_impersonation_to_account_manager
        after insert on test__customer
        for each row
        execute function grant_role_in_column1_to_role_in_column2(
            'account_owner_role', 'account_manager_role'
        );

    <<insert_invalid_role_reference>>
    begin
        insert into test__customer
            values (default, 'test__account_manager_that_doesnt_exist');
    exception
        when foreign_key_violation then
    end;

    insert into test__customer
        (account_owner_role, account_manager_role)
    values
        (default, 'test__account_manager')
    returning
        account_owner_role
    into
        _inserted_account_owner_role
    ;

    <<set_invalid_role_reference>>
    begin
        update test__customer
            set account_manager_role = 'test__invalid_account_manager';
    exception
        when foreign_key_violation then
    end;

    -- This implicitly tests that both these roles exist
    assert pg_has_role('test__account_manager', _inserted_account_owner_role, 'USAGE');

    _updated_account_owner_role := 'test__custom_user_name';
    update test__customer
        set account_owner_role = _updated_account_owner_role;
    assert exists (select from pg_roles where rolname = _updated_account_owner_role);

    delete from test__customer;
    assert not exists (select from pg_roles where rolname = _updated_account_owner_role);

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;

--------------------------------------------------------------------------------------------------------------
