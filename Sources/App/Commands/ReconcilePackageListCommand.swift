import Vapor

final class ReconcilePackageListCommand: Command
{
  static let name = "reconcile_package_list"

  var arguments: [CommandArgument] = []
  var options: [CommandOption] = []
  var help = ["Synchronise the database with the master package list from GitHub."]

  func run(using context: CommandContext) throws -> Future<Void> {
    context.console.print("Hello, world!")
    return .done(on: context.container)
  }
}
