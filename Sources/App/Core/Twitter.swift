import Vapor
import TwitterVapor

struct TwitterFirehose {
    
    enum TwitterError: Error {
        case invalidPackageData
    }
    
    func buildFirehosePost(package: Package) throws -> String {
        guard let repo = package.repository,
              let version = Package.findRelease(package.versions),
              let semVer = version.reference?.semVer,
              let repoName = repo.name
        else {
            throw TwitterError.invalidPackageData
        }
        
        // summary = '- repo summary goes here' or ''
        let summary = repo.summary?.isEmpty != false ? "" : "- " + (repo.summary ?? "")
        let url = SiteURL.package(.value(repo.owner ?? ""), .value(repoName), .none).absoluteURL()
        
        return "\(repoName) just released v\(semVer.description) \(summary)\n\n\(url)"
    }
    
    func postToFirehose(package: Package, application: Application) -> EventLoopFuture<Void> {
        do {
            let message = try buildFirehosePost(package: package)
            return application.twitter
                .post(message)
                .transform(to: ())
                .flatMapError { error in
                    // If something goes wrong with the Twitter integration - we don't want to hang up any of the other systems
                    // As such we'll log the error but then report a 'successful' void response upstream.
                    application.logger.report(error: error)
                    return application.eventLoopGroup.future()
                }
        } catch {
            return application.eventLoopGroup.future(error: error)
        }
    }
    
}
