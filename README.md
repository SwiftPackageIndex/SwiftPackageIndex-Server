# The Swift Package Index

Find the best Swift libraries and frameworks that support the [Swift Package Manager](https://swift.org/package-manager/).

## Concepts

This project is currently made up of two distinct parts:

* Command processes that run constantly to fetch packages from a [master package list](https://github.com/daveverwer/SwiftPMLibrary/blob/master/packages.json), parse metadata about the packages, and insert it into a database.
* A web front end that allows that database to be viewed and searched.

### Reconciliation, Ingestion, and Analysis

The command processes that fetch and parse package metadata are broken up into three separate commands.

1. **Reconciliation**: Fetch the master package list and reconciling it with the database, adding or deleting rows in the `packages` table.
2. **Ingestion**: Fetch GitHub (or in the future, other hosting services) metadata for a set of package candidates returned by `Package.fetchCandidates(app.db, for: .ingestion, limit: 10) ` and create or update rows in the `repositories` table.
3. **Analysis**: Clone or pull the full git history for a set of package candidates returned by `Package.fetchCandidates(app.db, for: .analysis, limit: 10) ` and create or replace rows in `versions` and `products`.

## Running this project

The `Makefile` defines a set of useful targets to get up and running. Make sure you have [Docker](https://www.docker.com/products/docker-desktop) installed and running, then run:

```
make db-up
```

This will bring up two Postgres database docker containers (one for development, the other for the tests). Then, run:

```
make migrate
```

This will set up the schema (or migrate it, if you've made changes) on the development database.

```
make run
```

This will bring up a local development server.

## Running the project from Xcode

Alternatively, you can open the `Package.swift` file in Xcode and run the server from there. However, it's important to set a custom working directory before running. To do this, navigate to the **Product** | **Scheme** | **Edit Scheme...** menu or press ⌘+<. Select the **Run** scheme action and select the **Options** tab. Finally, check the **Working Directory** checkbox and enter the directory where you have this source code checked out.

## Resetting the database

You can reset the database to a clean slate by tearing down the containers by running:

```
make db-reset
```

This command will *destroy* both the development, and test docker containers. Recreate them, and finally migrate the development database.

## Running an end-to-end test

Once you're all set up, run:

```
make test-e2e
```

This will kick off a local test run of the server update process (reconciliation, ingestion, and analysis) processing just *one* package. This is a good way to verify everything is working.

## Running ingestion locally

The `ingest-loop.sh` script can serve as a simple way to run a full ingestion cycle:

```
make reset        # clear dev db
make reconcile    # import package list
./ingest-loop.sh  # ingest metadata for 100 packages, pause for 10 sec, repeat
```

If you want to run ingestion for anything other than a cursory test, you'll need authenticated API calls. To do this, set a `GITHUB_TOKEN` environment variable to a [generated personal token](https://github.com/settings/tokens) which has the `public_repo` and `repo:status` scopes.

## Running analysis locally

You can run the analysis step locally by running

```
make analyze
```

This will run the analysis stage for one package (`--limit 1`).

NB: The analysis step will check out repositories to your local file system, by default into a directory `SPI-checkouts` in your project folder. You can change this location by setting the environment variable `CHECKOUTS_DIR` to another path.

## API poking

You can poke at the API using [Rester](https//github.com/finestructure/Rester) by running the Restfile `test.restfile`:

```
rester restfiles/test.testfile
```

This does not replace testing but helps with API exploration and integration testing.

## Running the full stack locally

Set up the required environment variables in an `.env` file and run

```
env VERSION=0.0.20 docker-compose up -d
```

where the `VERSION` variable references a tag name or a git sha.


## Grafana setup

Add Loki data source: `http://loki:3100`