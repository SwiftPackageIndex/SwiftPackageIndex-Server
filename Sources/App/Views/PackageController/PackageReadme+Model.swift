import Foundation
import Plot
import Vapor


extension PackageReadme {
    
    struct Model: Equatable {
        var readme: String?
        var readmeBaseUrl: String?

        internal init?(package: Package, readme: String? = nil) {
            self.readme = readme
            self.readmeBaseUrl = package.repository?.readmeUrl
                .flatMap(URL.init(string:))?
                .deletingLastPathComponent()
                .absoluteString
        }
    }

}
