# Contributing to the Swift Package Index

This project welcomes contributions, we're looking forward to working with you!

## Where Should Contributions Start?

To keep our issues list under control, most bug reports or feature requests work best started as a [discussion in our forum](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/discussions). After a discussion, we can promote it into an issue and start work on a pull request from there.

We also have a Discord server, if you'd like to join then [use this invite](https://discord.gg/vQRb6KkYRw)!

## Code of Conduct

All participation in this project, whether it be contributing code, discussions, issues, or pull requests are subject to our code of conduct. Please read [CODE_OF_CONDUCT.md](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/blob/main/CODE_OF_CONDUCT.md) for more information.

## Licensing

The Swift Package Index is licensed under the Apache 2.0 open-source license. Before your contributions can be accepted, you'll need to sign the standard Apache 2.0 Contributor License Agreement. We will organise this during your first pull request.

## Configuring a Local Development Environment

To run the project on your local machine, you'll need the [latest non-beta version of Xcode](https://developer.apple.com/xcode/resources/) and [Docker Desktop for macOS](https://www.docker.com/products/docker-desktop) installed.

It is not possible to run the [build system](https://blog.swiftpackageindex.com/posts/launching-language-and-platform-package-compatibility/) locally due to its reliance on the infrastructure in which it runs. If you have any feature requests or bug reports relating to the build or compatibility system, [please start a discussion](https://github.com/SwiftPackageIndex/SwiftPackageIndex-Server/discussions).

### Setup the Back End

Once you have the project cloned locally, the `Makefile` defines a set of useful targets to get you up and running. You'll need some environment variables configured, but the project has template files in `.env.testing.template` and `.env.development.template`. Your first step should be to take copies of these files as copy these files as `.env.testing` and `.env.development` and review their content in case your setup deviates from the default.

Then, to create Postgres databases in Docker for your development and test environments, run:

```
make db-up
```

Then, to set up the schema and migrate the database to the latest version, run:

```
make migrate
```

Then, either run `make run` to start the server, or in most situations you'll find working with Xcode easier at this stage. Open the project with Xcode and open the Product menu, select "Scheme", and "Manage Schemes…".

![A screenshot of Xcode showing the Manage Schemes window.]()

Then, select the "Run" scheme and click the "Edit…" button. Select the "Run" scheme action from the source list and switch to the "Options" tab. Find the "Working Directory" setting and tick "Use a custom working directory:", then select the directory where your working copy of the project is located.

![A screenshot of Xcode showing the Edit Scheme window with the Run scheme action selected.]()

Close the scheme editor, ensure that the "Run" scheme is selected in the Xcode toolbar and run the project with Xcode!

When the development server starts, you should see this output in the Xcode console:

```
[ NOTICE ] Server starting on http://127.0.0.1:8080 [component: server]
```

### Setup the Front End

Once the back end is set up and the server is running, if you visit it in a web browser you'll see the CSS is missing! The next step is to set up the front end.

We use [yarn](https://yarnpkg.com) and [rollup.js](https://rollupjs.org) to build our front end CSS and JavaScript. However, you do not need to install `node` or `yarn` locally as the build scripts run through Docker. If you just want to build the front end once so the site has valid CSS and JavaScript, run:

```
make build-front-end
```

If you want to set up the front end for active development, run a local front end server with:

```
make build-front-end
```

**Note:** If you are doing extensive work with the front end, you may want to install `node` and `yarn` locally rather than running them via Docker. This is not necessary, though.

### Check Everything Works!

Navigate to `http://127.0.0.1:8080` with a web browser and the site should be up and running locally with CSS and JavaScript working!

## Environment Variables

We check for the presence of some environment variables to control various aspects of building and testing:

| Environment variable     | Description                                       |
| ------------------------ | ------------------------------------------------- |
| RUN_IMAGE_SNAPSHOT_TESTS | Enable/disable image snapshots during testing.    |
| GITHUB_WORKFLOW          | Enable/disable certain tests in a CI environment. |

## Reconciliation, Ingestion, and Analysis

There are three main background processes which take care of adding/removing packages and keeping package metadata updated:

1. **Reconciliation** fetches the [package list](https://github.com/SwiftPackageIndex/PackageList) and reconciles it with the current list of packageds, adding or deleting rows in the `packages` table.
2. **Ingestion** fetches metadata from GitHub (and potentially other hosting services in the future) and creates or updates rows in the `repositories` table.
3. **Analysis** clones/pulls the full git history for packages and creates or replaces rows in the `versions` and `products` tables.

### Running Reconciliation and Ingestion Locally

**Note:** You will not need to run reconciliation, ingestion, or analysis locally unless you're working on these parts of the system.

The `ingest-loop.sh` script can serve as a simple way to run a full ingestion cycle:

```
make reset                # Delete and re-creating the development and test databases.
make reconcile            # Import all packages in the package list.
./scripts/ingest-loop.sh  # Ingest metadata for 100 packages, pause for 10 sec, and repeat.
```

If you want to run ingestion for anything other than a cursory test, you'll need to use authenticated GitHub API calls. To do this, set a `GITHUB_TOKEN` environment variable to a [generated personal token](https://github.com/settings/tokens) which has the `public_repo` and `repo:status` scopes.

### Running Analysis Locally

To run analysis locally, run:

```
make analyze
```

This will run the analysis stage for a single package. To analyse more than one package, use the `--limit` parameter.

**Note:** Analysis checks out repositories into to your local file system. By default, into a directory `SPI-checkouts` in your project folder. You can change this location by setting the environment variable `CHECKOUTS_DIR` to another path.

## Running the Full Stack Locally

**Note:** You will not need to run the full stack locally unless you're working on hosting the server.

The application stack is defined in the `app.yml` docker compose file. The only other required component is the database which can be brought up via `make db-up-dev` and populated via the processing steps or a database dump.

If you connect to a locally running database, either one brought up via `make db-up-dev` or one running directly on your machine, make sure to specify the `DATABASE_HOST` variable as `host.docker.internal`, which is the hostname of the machine running docker as seen from within a container and automatically configured by docker's networking.

Set up any of the other required environment variables in an `.env` file and run

```
env VERSION=2.47.11 docker-compose -f app.yml up -d
```

to bring up the full stack. The `VERSION` variable references a tag name or a git SHA. You can either rely on docker pulling a previously built image from the registry or build and tag a version you want to run locally:

```
$ make docker-build
No VERSION provided, defaulting to d64a881019662aced6fa0a3748b754dffa9fad29
docker build -t registry.gitlab.com/finestructure/swiftpackageindex:d64a881019662aced6fa0a3748b754dffa9fad29 .
Sending build context to Docker daemon  536.1MB
...
```

Use the logged `VERSION` for the `docker-compose` command.

Note that this will launch quite a number of services defined in `app.yml`, including the services that continuously process packages. In order to limit this to just the Vapor app, run

```
env VERSION=... docker-compose -f app.yml up -d server
```
