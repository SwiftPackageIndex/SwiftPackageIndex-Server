## Getting started

The `Makefile` defines a set of useful targets to get up and running.

Make sure you have Docker installed and running, then run

```
make db-up
```

to bring up the Postgres databases (one for development, the other for the unit tests).

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

Running

```
make test-e2e
```

will kick off a local test run of the server update process (reconciliation, ingestion, etc).

The `ingest-loop.sh` script can serve as a simple way to run a full ingestion cycle:

```
make reset        # clear dev db
make reconcile    # import package list
./ingest-loop.sh  # ingest metadata for 100 packages, pause for 10 sec, repeat
```

## API poking

You can poke at the API using [Rester](https//github.com/finestructure/Rester) by running the Restfile `test.restfile`:

```
rester test.testfile
```

This does not replace testing but helps with API exploration and integration testing.
