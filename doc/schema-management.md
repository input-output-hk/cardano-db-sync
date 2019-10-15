# Schema Management

Schema management for the Cardano Explorer database is a little more complicated than we would like,
but the scheme chosen allows for easy development, evolution and management of the database.

The database schema is defined in three stages, each stage consisting of one or more SQL migrations.
The stages are:

1. Hand written SQL to set up custom SQL data types (using `DOMAIN` statements) and schema
   versioning.
2. SQL generated using the schema defined as Haskell data types (using the [Persistent][Persistent]
   library) to create the database tables.
3. Hand written SQL to create views into the tables defined in stage 2.

All of the schema migrations in these three stages are written to be idempotent (so that they
"know" if they have already been applied).

The migration files all have file names of the form:
```
migration-1-0000-20190730.sql
```
where the `1` denotes "stage 1" of the SQL migration, the `0000` is the migration version and the
last number is the date. Listing the directory containing the schema and sorting the list will
order them in the correct order for applying to the database.



[Persistent]: https://hackage.haskell.org/package/persistent