/**
 * CHANGELOG.md:
 *
 * - Contrary to unpopular belief, the previous bugfix release only fixed
 *   the then-previous `CHANGELOG.md` entry.  This time over, the extension
 *   author started out by accepting that releasing a new version had become
 *   to complicated, involving too many steps, some of which were ridiculous:
 *
 *   1. committing with a `CHANGELOG.md` without a release data, to then
 *   2. make a release tag for the newly to be released version,
 *   3. remaking the `CHANGENLOG.md`,
 *   4. amending the last commit,
 *   5. deleting the tag for the commit that now no longer exists, and
 *   6. remaking the correct tag.
 *
 *   All this while the awesome `bin/sql-to-changelog.md` script already had
 *   the ability to specify the release data for any of the `.sql` scripts it
 *   is passed on the command-line.
 *
 *   This ability is now used to power a new `make tag_default_version` target,
 *   the implementation of which is pretty hacky, but aren't `Makefile`s nearly
 *   always a bit so?
 */


/**
 * CHANGELOG.md:
 *
 * - A placeholder was added to the `README.md` for Rowan to remind himself
 *   the document the steps involved in the development process of new
 *   versions.
 */
comment on extension pg_role_fkey_trigger_functions is
$markdown$
# The `pg_role_fkey_trigger_functions` extension for PostgreSQL


## Overview of `pg_role_fkey_trigger_functions` functionality

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


## `pg_role_fkey_trigger_functions` development and release process

[To be written.]


<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;
