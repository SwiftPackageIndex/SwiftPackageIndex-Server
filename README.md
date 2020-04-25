## Getting started

The `Makefile` defines a set of useful targets to get up and running.

Make sure you have Docker installed and running, then run

```
make db-up
```

to bring up the Postgres database.

```
make migrate
```

will set up the schema (or migrate it if you've made changes).

```
make run
```

to bring up the server locally.

You can reset the database to a clean slate by tearing down the containers with

```
make db-reset
```

## API poking

You can poke at the API using [Rester](https//github.com/finestructure/Rester) by running the Restfile `test.restfile`:

```
rester test.testfile
```

This does not replace testing but helps with API exploration and integration testing.
