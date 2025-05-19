# `pg_role_fkey_trigger_functions` changelog / release notes

All notable changes to the `pg_role_fkey_trigger_functions` PostgreSQL
extension will be documented in this changelog.

The format of this changelog is based on [Keep a
Changelog](https://keepachangelog.com/en/1.1.0/).
`pg_role_fkey_trigger_functions` adheres to [semantic
versioning](https://semver.org/spec/v2.0.0.html).

This changelog is **automatically generated** and is updated by running `make
CHANGELOG.md`.  This preamble is kept in `CHANGELOG.preamble.md` and the
remainded of the changelog below is synthesized (by `sql-to-changelog.md.sql`)
from special comments in the extension update scripts, put in the right sequence
with the help of the `pg_extension_update_paths()` functions (meaning that the
extension update script must be installed where Postgres can find them before an
up-to-date `CHANGELOG.md` file can be generated).

---

## [1.0.2] – 2025-05-19

[1.0.2]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v1.0.1…

- Contrary to unpopular belief, the previous bugfix release only fixed
  the then-previous `CHANGELOG.md` entry.  This time over, the extension
  author started out by accepting that releasing a new version had become
  to complicated, involving too many steps, some of which were ridiculous:

  1. committing with a `CHANGELOG.md` without a release data, to then
  2. make a release tag for the newly to be released version,
  3. remaking the `CHANGENLOG.md`,
  4. amending the last commit,
  5. deleting the tag for the commit that now no longer exists, and
  6. remaking the correct tag.

  All this while the awesome `bin/sql-to-changelog.md` script already had
  the ability to specify the release data for any of the `.sql` scripts it
  is passed on the command-line.

  This ability is now used to power a new `make tag_default_version` target,
  the implementation of which is pretty hacky, but aren't `Makefile`s nearly
  always a bit so?

- A placeholder was added to the `README.md` for Rowan to remind himself
  the document the steps involved in the development process of new
  versions.

## [1.0.1] – 2025-05-18

[1.0.1]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v1.0.0…v1.0.1

- This bugfix release only fixes the `CHANGELOG.md`, because, actually,
  version 1.0.0 _was_ released when version 1.0.0 was released.  [Except
  that then this release repeated the exact same mistake for the release
  that of _this_ version. 🤦]

## [1.0.0] – 2025-05-18

[1.0.0]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.11.9…v1.0.0

- 1.0.0 is the first “stable” release of the `pg_role_fkey_trigger_functions`
  extension—stable in the SemVer sense, not necessarily in the sense that you
  should surrender your security to it.  (The fact that this release fixed
  a rather serious security issue should be enough of a hint to thoroughly
  audit both this extension and your usage of it before employing it in a
  production environment.)
  ~
  From this release onward, breaking changes will result in increases of the
  major version number, as per the [Semantic Versioning
  2.0.0](https://semver.org/spec/v2.0.0.html):
  ~
  > 4. Major version zero (0.y.z) is for initial development. Anything MAY
  >    change at any time. The public API SHOULD NOT be considered stable.
  > 5. _Version 1.0.0 defines the public API. The way in which the version
  >    number is incremented after this release is dependent on this public
  >    API and how it changes._

- The stated `hstore` requirement, that `pg_role_fkey_trigger_functions` in
  fact never depended on, was dropped from the `META.json` file (and the
  `pg_role_fkey_trigger_functions_meta_pgxn()` with which that file is
  generated.  It was in there by accident (though the mistake was never
  reflected in the `.control` file).

- There was a pretty serious security hole in previous versions of the
  `pg_role_fkey_trigger_functions` extension: any user with `EXECUTE`
  permissions on one of the following three `SECURITY DEFINER` trigger
  functions could simmply create a temporary table with some columns
  containing the roles they wanted to be (created and) granted membership to
  whichever role they pleased:

  1. `maintain_referenced_role()`,
  2. `grant_role_in_column1_to_role_in_column2()`, and
  3. `revoke_role_in_column1_from_role_in_column2()`.

  Therefore, these three trigger functions have been amended to raise an
  `insufficient_privilege` exception unless the trigger's table's qualified
  name is present in the array of trusted table kept in the new
  `pg_role_fkey_trigger_functions.trusted_tables` setting:

  + The new setting is _not_ read using `current_setting()`, because that has
    its own associated security hazards.  Rather, it is read, by the new
    `pg_role_fkey_trigger_functions__trusted_tables()` function, directly
    from the [`pg_db_role_setting`
    catalog](https://www.postgresql.org/docs/current/catalog-pg-db-role-setting.html).

  + Tables can be registered for this list using another pair of new
    functions:

    1. `pg_role_fkey_trigger_functions__trust_table()` and
    2. `pg_role_fkey_trigger_functions__trust_tables()`.

  + When upgrading from `pg_role_fkey_trigger_functions` < 1.0.0, all existing
    tables that use one of the following trigger functions will automatically
    be added to the array of trusted tables:
    ~
    1. `maintain_referenced_role()`,
    2. `grant_role_in_column1_to_role_in_column2()`, and
    3. `revoke_role_in_column1_from_role_in_column2()`.
    ~
    Whether these settings will be applied to the database or to the role
    that owns these trigger functions (which should be the same role that
    orignally installed the `pg_role_fkey_trigger_functions` extensions)
    depends on whether the function owner is superuser or not.  In the case
    that the function owner is superuser, the tables are added to the
    dabase-level `pg_role_fkey_trigger_functions.trusted_table` setting;
    otherwise, they are added to the same-named setting at the role level.

  + The `test__pg_role_fkey_trigger_functions()` procedure tests that the
    `security definer` functions actually respect the new table trust
    mechanism.

  + The `test_dump_restore__maintain_referenced_role(text)` test procedure
    has also been adjusted to the new table trust mechanism, though it doesn't
    test its workings.
    * (Another change to `test_dump_restore__maintain_referenced_role(text)` is
      that its `search_path` has also been changed to be set automatically,
      from its `pg_role_fkey_trigger_functions.search_path_template` setting,
      as will be described below.)

- As per the above-described resoltion to the `security definer` issue, the
  `maintain_referenced_role()` trigger function was modified to refuse to
  operate on non-trusted tables.  Besides:

  + It now has an explicit `search_path`, that is set from a new setting –
    `pg_role_fkey_trigger_functions.search_path_template` – to be able to
    later add an event trigger to this extension (when installed by a
    `SUPERUSER`) to allow the `search_path`s to be reset automatically when
    the extension is relocated.
  + An extra assertion was added at the end of the function.
  + The trigger arguments have been enumerated in the function's `comment`.

- Besides the modification to `revoke_role_in_column1_from_role_in_column2()`
  to make it refuse to work on non-trusted tables, some other improvements
  were made as well:

  + It now has an explicit `search_path`, that is set from a new setting –
    `pg_role_fkey_trigger_functions.search_path_template` – to be able to
    later add an event trigger to this extension (when installed by a
    `SUPERUSER`) to allow the `search_path`s to be reset automatically when
    the extension is relocated.
  + Misplaced `WITH GRANT OPTION` part of
    `grant_role_in_column1_to_role_in_column2()` trigger function was replaced
    by correct regexp, because `GRANT <role_name> TO <role_specification>` is
    the one [`GRANT`](https://www.postgresql.org/docs/current/sql-grant.html)
    subcommand that does _not_ have a `WITH GRANT OPTION`.)
  + An extra assertion was added at the end of the function.
  + The function arguments are now also clearly described in its `COMMENT`
    (and hence in the `README.md`).

- In addition to the “trusted tables” resolution to the `security definer`
  issue implemented in the `revoke_role_in_column1_from_role_in_column2()`
  trigger function, it received some other improvements:

  + It now has an explicit `search_path`, that is set from a new setting –
    `pg_role_fkey_trigger_functions.search_path_template` – to be able to
    later add an event trigger to this extension (when installed by a
    `SUPERUSER`) to allow the `search_path`s to be reset automatically when
    the extension is relocated.
  + An extra assertion was added at the end of the function.

- The `enforce_fkey_to_db_role()` trigger function received a few minor
  improvements:

  + The `foreign_key_violation` that it throws have been extended with a
    `detail`, `schema`, `table` and `column`.
  + An explicit and restrictive `search_path` has been `set` for the funciton.
  + The trigger function's documentation has been extended to explain that,
    in many cases, you're probably better off _not_ using a trigger that
    checks for the existence of the role's `NAME` stored in a column and
    instead using a column with the `regrole` type.

- The `README.md` was extended, with a section to document its settings, as
  well as a section to document security ussage of the `SECURITY DEFINER`
  trigger functions.

- The `comment on function pg_role_fkey_trigger_functions_readme()` was
  updated to explain its ability to add the schema of an already installed
  `pg_readme` to the `search_path` itself.

- Speaking of `search_path`s: due to the new table trust mechanism implemented
  in `pg_role_fkey_trigger_functions` 1.0.0, the extension's three `security
  definer` functions now needed to be able to find the new
  `pg_role_fkey_trigger_functions__trusted_tables()` function that does the
  parsing and combining of the `pg_role_fkey_trigger_functions.trusted_tables`
  settings found in different places.  And this function is also used in the
  two new `pg_role_fkey_trigger_functions__trust_table*()` functions.
  ~
  This could have been accommodated by using `set search_path from current`.
  However, that would have meant that the `.control` file would have needed to
  state that this extension is no longer `relocatable`.
  ~
  Instead, the aforementioned function-level `*.search_path_template` setting
  was added to the functions that need to be able to find other functions from
  this same extension, and a new stored procedure was added to (re)set all the
  actual, expanded `search_paths` for functions that sport such a
  `*search_path` setting.  This new procedure is:
  `pg_role_fkey_trigger_functions__alter_routines_to_reset_search_paths()`

  + In later versions of `pg_role_fkey_trigger_functions`, an event trigger
    function will be added to catch `ALTER EXTENSION` events that involve a
    schema relocation.
  + But, for now, this new procedure must still be called explicitly after
    an extension schema relocation.
  + And the procedure is called at the end of all extension installation
    scripts for `pg_role_fkey_trigger_functions` ≥ 1.0.0.
  + Also, it must be called in extension upgrade scripts, after new functions
    with a `pg_role_fkey_trigger_functions.search_path_template` setting are
    added.

## [0.11.9] – 2024-01-05

[0.11.9]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.11.8…v0.11.9

- Some faulty `format()` specificiers in `RAISE` statements in the
  `grant_role_in_column1_to_role_in_column2()` trigger function were fixed.

## [0.11.8] – 2023-11-28

[0.11.8]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.11.7…v0.11.8

- When a `PG_CONFIG` environment variable is already set, the `Makefile`
  now respects that value instead of overriding it.

## [0.11.7] – 2023-05-13

[0.11.7]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.11.6…v0.11.7

- An author section was added to the (`comment on extension` used to
  generate) `README.md`.

## [0.11.6] – 2023-04-22

[0.11.6]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.11.5…v0.11.6

- The `revoke_role_in_column1_from_role_in_column2()` trigger function
  got much improved custom assertion exception strings.

## [0.11.5] – 2023-04-17

[0.11.5]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.11.4…v0.11.5

- The extension upgrade script from version 0.11.3 to 0.11.4 neglected to
  add role-specific settings for roles previously added by the
  `maintain_referenced_role()` trigger function.  This is now retroactively
  done by the version 0.11.4 to 0.11.5 upgrade script.

## [0.11.4] – 2023-04-17

[0.11.4]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.11.3…v0.11.4

- The `test_dump_restore__maintain_referenced_role()` now pretends to start
  with a new database (with the roles still existing), which is useful in
  development and acceptance environments.

- The `maintain_referenced_role()` is now okay with pre-existing roles, as
  long as these roles are sort of owned by the trigger, according to the
  `pg_role_fkey_trigger_functions.role_is_managed` and
  `pg_role_fkey_trigger_functions.role_fkey_col_path` settings for that role.

- The `pg_role_fkey_trigger_functions_readme()` generation function now not
  only temporarily installs the `pg_readme` extension when necessary, but
  also `pg_readme` its dependencies.

## [0.11.3] – 2023-02-27

[0.11.3]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.11.2…v0.11.3

- The `pg_role_fkey_trigger_functions` license was changed from AGPL 3.0 to
  the PostgreSQL license.

## [0.11.2] – 2023-02-27

[0.11.2]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.11.1…v0.11.2

- `maintain_referenced_role()` now correctly returns `OLD` instead of `NEW`
  on delete.

- `maintain_referenced_role()` has been changed to crash more informatively
  when, unexpectedly, the role already exists.

- Such faulty creation of pre-existing roles is now also tested as part of
  the `test__pg_role_fkey_trigger_functions()` procedure.

## [0.11.1] – 2023-02-12

[0.11.1]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.11.0…v0.11.1

- The `pg_extension_readme()` function can now also be found if the
  `pg_readme` extension was already installed outside of the
  `pg_role_fkey_trigger_functions` extension its `search_path`.

- The `comment on function pg_role_fkey_trigger_functions_readme()` synopsis
  sentence has now been squeezed entirely into the first line of the
  `comment`, because some tools (like PostgREST) treat only the first line of
  `comment`s as the synopsis.

- The `README.md` was regenerated with the latest (0.5.6) version of
  `pg_readme`.

## [0.11.0] – 2023-01-17

[0.11.0]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.10.0…v0.11.0

- Instead of guessing what to do in the case of doubt, the
  `grant_role_in_column1_to_role_in_column2()` trigger function now refuses
  to do certain work and has become very verbal about it.

- `revoke_role_in_column1_from_role_in_column2()` now looks at old _and_ new
  roles instead of just the old.  From the basis of that, it then goes ahead
  and `REVOKE`s if a change is detected.

- `revoke_role_in_column1_from_role_in_column2()` no longer checks if both
  `OLD` roles still exist and whether the grantee is still a member of the
  role in column 1, because we want to make sure that devs (building on this
  extension) get an early warning when they sequence these trigger functions
  incorrectly.

## [0.10.0] – 2023-01-16

[0.10.0]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.9.3…v0.10.0

- The `grant_role_in_column1_to_role_in_column2()` trigger function now only
  does the grant if the role in column 1 isn't already granted to the role
  in column 2.

- A new trigger function—`revoke_role_in_column1_from_role_in_column2()`—was
  added, as a counterpart to `grant_role_in_column1_to_role_in_column2()`.

- The `test__pg_role_fkey_trigger_functions()` procedure was extended to:

  + include tests for the new `revoke_role_in_column1_from_role_in_column2()`
    function;
  + perform more and better assertions; as well as
  + have more and more explicit failure messages.

## [0.9.3] – 2023-01-11

[0.9.3]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.9.2…v0.9.3

- Prior to this release, when the `enforce_fkey_to_db_role()` trigger
  function failed to produce an error, this would slip through the
  `test__pg_role_fkey_trigger_functions()` procedure unnoticed.

  + Now, the `test__pg_role_fkey_trigger_functions()` procedure _does_ fail
    if the test trigger based on `enforce_fkey_to_db_role()` fails to raise
    a `foreign_key_violation`.

  + Also, the test procedure now tests the specific error message raised by
    `enforce_fkey_to_db_role()`.

  + The `foreign_key_violation` error message produced by the
    `enforce_fkey_to_db_role()` trigger function now correctly includes the
    `_new_role` instead of the  `_role_fkey_column` value.

## [0.9.2] – 2023-01-07

[0.9.2]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.9.1…v0.9.2

- `pg_role_fkey_trigger_functions` is now also available through the
  PGXN: https://pgxn.org/dist/pg_role_fkey_trigger_functions/

  + The PGXN `META.json` file is automatically generated, simply by taking
    the output of the `pg_role_fkey_trigger_functions_meta_pgxn()` function.

- The `README.md` preamble (base on `comment on extension`) has been updated
  to:

  + finish unfinished bullet point in intro;
  + add a link to the reference; and
  + to promote flashmq.com in a new “Origin” section.

- If `pg_role_fkey_trigger_functions_readme()` finds the `pg_readme`
  extension not yet installed, instead of installing a pinned `pg_readme`
  version (0.1.3), it now installs the latest `pg_readme` version.

- The `test__pg_role_fkey_trigger_functions()` procedure body is now
  explicitly marked to be included in the object reference in the README
  (through the `pg_readme.include_this_routine_definition` setting on
  the procedure), even though this is redundant because the
  `pg_role_fkey_trigger_functions_readme()` function has
  `set pg_readme.include_routine_definitions_like to '{test__%}'.

## [0.9.1] – 2022-12-08

[0.9.1]: https://github.com/bigsmoke/pg_role_fkey_trigger_functions/compare/v0.9.0…v0.9.1

- Originally, there was an unconditional `ALTER DATABASE` statement, which
  disregarded the fact that the `.control` file of this extension states
  that this extension should be installable for non-superusers.  To fix
  this, the `ALTER DATABASE` command is now only performed when this
  extension is being installed by a role with superuser privilege.
  ~
  (The `ALTER DATABASE … SET …` command was/is not terribly important; its
  sole purpose is for the future use of cross-README links by `pg_readme`.)
