-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`.
\echo Use "CREATE EXTENSION pg_role_fkey_trigger_functions" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Add author section
comment on extension pg_role_fkey_trigger_functions is
$markdown$
# The `pg_role_fkey_trigger_functions` extension for PostgreSQL

The `pg_role_fkey_trigger_functions` PostgreSQL extension offers a
bunch of trigger functions to help establish and/or maintain referential
integrity for columns that reference PostgreSQL `ROLE` `NAME`s.

`pg_role_fkey_trigger_functions` contains two trigger functions
which can be applied as a table `CONSTRAINT TRIGGER`:

1. `enforce_fkey_to_db_role()` _enforces_ referential integrity by getting angry
   when you try to `INSERT` or `UPDATE` a row value that is not an existing
   `ROLE`.
2. `maintain_referenced_role()` _establishes_ referential integrity by
   `CREATE`ing, `ALTER`ing, and `DROP`ing `ROLE`s to stay in sync with the
   value(s) in the column(s) being watched by the trigger function.

Thus:

1. `enforce_fkey_to_db_role()` works very much like foreign keys normally works;
   while
2. `maintain_referenced_role()` works exactly in the opposite direction that
   foreign keys normally work.

There is also a third trigger function, to maintain role inter-relationships:
`grant_role_in_column1_to_role_in_column2()`.

See the documentation for the
[`grant_role_in_column1_to_role_in_column2()`](#function-grant_role_in_column1_to_role_in_column2)
trigger function for an example that builds on all 3 trigger functions.

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


<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------
