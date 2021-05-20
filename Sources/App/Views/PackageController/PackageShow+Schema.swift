import Foundation

extension PackageShow {
    
    struct PackageSchema: Schema {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case identifier, name, description, license, version, codeRepository
        }
        
        var context: String = "https://schema.org"
        var type: String = "SoftwareSourceCode"
        
        let identifier: String
        let name: String
        let description: String?
        let license: String?
        let version: String?
        let codeRepository: String
        
        init(model: Model) {
            identifier = "\(model.repositoryOwner)/\(model.repositoryName)"
            name = model.repositoryName
            description = model.summary
            license = model.licenseUrl
            version = model.releases.stable?.link.label
            codeRepository = model.url.droppingGitExtension
        }
    }
    
}
