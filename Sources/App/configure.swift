import FluentPostgreSQL
import Vapor

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws
{
  // Register providers first
  try services.register(FluentPostgreSQLProvider())

  // Register routes to the router
  let router = EngineRouter.default()
  try routes(router)
  services.register(router, as: Router.self)

  // Register middleware
  var middlewares = MiddlewareConfig()
  middlewares.use(FileMiddleware.self)
  middlewares.use(ErrorMiddleware.self)
  services.register(middlewares)

  // Configure the database
  var databases = DatabasesConfig()
  let database = PostgreSQLDatabase(config: databaseConfig(env))
  databases.add(database: database, as: .psql)
  if Environment.get("ENABLE_LOGGING") != nil {
    databases.enableLogging(on: .psql)
  }
  services.register(databases)

  // Run migrations on the database
  var migrations = MigrationConfig()
  migrations.add(model: Package.self, database: .psql)
  services.register(migrations)

  // Add the built in Fluent commands, and all commands in this project
  var commandConfig = CommandConfig.default()
  commandConfig.useFluentCommands()
  commandConfig.use(ReconcilePackageListCommand(), as: ReconcilePackageListCommand.name)
  services.register(commandConfig)
}

func databaseConfig(_ env: Environment) -> PostgreSQLDatabaseConfig
{
  func databaseName() -> String
  {
    switch env {
      case .development: return "swiftpackageindex_dev"
      case .testing: return "swiftpackageindex_test"
      case .production: return "swiftpackageindex_prod"
      default: preconditionFailure("Unknown application environment")
    }
  }

  func databasePort() -> Int
  {
    if let environmentPort = Environment.get("DATABASE_PORT") {
      return Int(environmentPort) ?? 5432
    }

    switch env {
      case .development: return 5432
      case .testing: return 5433
      case .production: return 5432
      default: preconditionFailure("Unknown application environment")
    }
  }

  return PostgreSQLDatabaseConfig(
    hostname: Environment.get("DATABASE_HOST") ?? "localhost",
    port: databasePort(),
    username: Environment.get("DATABASE_USERNAME") ?? "swiftpackageindex",
    database: databaseName(),
    password: Environment.get("DATABASE_PASSWORD") ?? "password",
    transport: .cleartext
  )
}
