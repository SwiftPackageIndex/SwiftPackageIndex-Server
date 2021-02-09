import Foundation
import Plot


extension MaintainerInfoIndex {

    struct Model {
        var packageName: String
        var repositoryOwner: String
        var repositoryName: String

        init?(package: Package) {
            guard let packageName = package.name(),
                  let repositoryOwner = package.repository?.owner,
                  let repositoryName = package.repository?.name else { return nil }

            self.init(packageName: packageName, repositoryOwner: repositoryOwner, repositoryName: repositoryName)
        }

        internal init(packageName: String, repositoryOwner: String, repositoryName: String) {
            self.packageName = packageName
            self.repositoryOwner = repositoryOwner
            self.repositoryName = repositoryName
        }

        func badgeURL(for type: Package.BadgeType) -> String {
            let characterSet = CharacterSet.urlHostAllowed.subtracting(.init(charactersIn: "=:"))
            let url = SiteURL.api(.packages(.value(repositoryOwner), .value(repositoryName), .badge)).absoluteURL(parameters: ["type": type.rawValue])
            let escaped = url.addingPercentEncoding(withAllowedCharacters: characterSet) ?? url
            return "https://img.shields.io/endpoint?url=\(escaped)"
        }

        func badgeMarkdown(for type: Package.BadgeType) -> String {
            let spiPackageURL = SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).absoluteURL()
            return "[![](\(badgeURL(for: type)))](\(spiPackageURL))"
        }
    }
}
