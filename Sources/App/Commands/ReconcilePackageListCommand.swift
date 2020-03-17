import Vapor
import Fluent
import FluentPostgreSQL

final class ReconcilePackageListCommand: Command
{
  static let name = "reconcile_package_list"
  
  var arguments: [CommandArgument] = []
  var options: [CommandOption] = []
  var help = ["Synchronise the database with the master package list from GitHub."]
  
  func run(using context: CommandContext) throws -> Future<Void> {
    // Grab the GitHub master package list and the database's current package list
    let masterPackageList = try fetchMasterPackageList(context)
    let currentPackageList = try fetchCurrentPackageList(context)
    
    // Reconcile the package lists and add/remove any new/deleted packages
    return masterPackageList.and(currentPackageList).flatMap { (master, current) in
      let reconciler = PackageListReconciler(masterPackageList: master, currentPackageList: current)
      
      return context.container.withPooledConnection(to: .psql) { database in
        // Add any new packages
        let packageAdditions = reconciler.packagesToAdd.map { url -> Future<Package> in
          let package = Package(url: url)
          return package.create(on: database)
        }
        
        // Delete any removed packages
        let packageDeletions = reconciler.packagesToDelete.map { url in
          return Package.findByUrl(on: database, url: url).map { package in
            return package.delete(on: database)
          }
        }
        
        let tmpUuid = UUID("00b71921-d558-48d9-92a1-0a10c5788b7b")!
        let tmpUuidFindByUuid = Package.find(tmpUuid, on: database)
          .unwrap(or: PackageError.recordNotFound)
          .map { package in
            print("package.url = \(String(describing: package.url))")
        }
        
        let tmpUrl = URL(string: "https://github.com/jpsim/SourceKitten.git")!
        let tmpUuidFindByUrl = Package.findByUrl(on: database, url: tmpUrl)
          .map { package in
            print("package.url = \(String(describing: package.url))")
        }
        
        return packageAdditions.flatten(on: database)
          //          .and(packageDeletions.flatten(on: database))
          .and(tmpUuidFindByUuid)
          .and(tmpUuidFindByUrl)
          .transform(to: ())
      }
    }
  }
  
  func fetchMasterPackageList(_ context: CommandContext) throws -> Future<[URL]>
  {
    return try context.container.client()
      .get(masterPackageListURL)
      .flatMap(to: [String].self) { response in
        // GitHub serves the file as text/plain so it needs to be forced as JSON
        response.http.contentType = .json
        return try response.content.decode([String].self)
    }.flatMap { urlStrings in
      var errorNotifications = [Future<Void>]()
      var urls = [URL]()
      
      // Loop through because we need to be able to handle errors and manage futures instead of just using a map
      for urlString in urlStrings {
        guard let url = URL(string: urlString) else {
          try errorNotifications.append(self.sendInvalidURLString(urlString, on: context))
          continue
        }
        urls.append(url)
      }
      return errorNotifications.flatten(on: context.container).transform(to: urls)
    }
  }
  
  func sendInvalidURLString(_ invalidURL: String, on context: CommandContext) throws -> Future<Void> {
    print("Found invalid URL string: \(invalidURL)")
    // We can do what we want here with sending emails/notifications to Rollbar etc
    if let rollbarAPIToken = Environment.get("ROLLBAR_API_KEY") {
      return try context.container.make(Client.self).post("https://api.rollbar.com/api/1/item/") { rollbarRequest in
        let data = try RollbarCreateItem(accessToken: rollbarAPIToken, environment: Environment.detect().name, level: .warning, body: "URL \(invalidURL) is not a valid URL")
        try rollbarRequest.content.encode(data)
      }.transform(to: ())
    } else {
      return context.container.future()
    }
  }
  
  func fetchCurrentPackageList(_ context: CommandContext) throws -> Future<[URL]>
  {
    return context.container.withPooledConnection(to: .psql) { database in
      return Package.query(on: database).all()
    }.map { packages in
      // Grab all the package URLs
      packages.compactMap { $0.url }
    }
  }
  
  var masterPackageListURL: URL {
    guard let url = URL(string: "https://raw.githubusercontent.com/daveverwer/SwiftPMLibrary/master/packages.json")
      else { preconditionFailure("Failed to create the master package list URL") }
    return url
  }
}

struct RollbarCreateItem: Content {
  
  init(accessToken: String, environment: String, level: RollbarItemLevel, body: String) {
    self.accessToken = accessToken
    let body = RollbarCreateItemData.RollbarCreateItemDataBody(message: body)
    self.data = RollbarCreateItemData(environment: environment, body: body, level: level)
  }
  
  let accessToken: String
  let data: RollbarCreateItemData
  
  enum CodingKeys: String, CodingKey {
      case accessToken = "access_token"
      case data = "data"
  }
  
  struct RollbarCreateItemData: Content {
    let environment: String
    let body: RollbarCreateItemDataBody
    let level: RollbarItemLevel
    let language = "swift"
    let framework = "vapor"
    let uuid = UUID().uuidString
    
    struct RollbarCreateItemDataBody: Content {
      init(message: String) {
        self.message = .init(body: message)
      }
      
      let message: RollbarCreateItemDataBodyMessage
      
      struct RollbarCreateItemDataBodyMessage: Content {
        let body: String
      }
    }
  }
}

enum RollbarItemLevel: String, Codable {
  case criticil = "critical"
  case error = "error"
  case warning = "warning"
  case info = "info"
  case debug = "debug"
}
