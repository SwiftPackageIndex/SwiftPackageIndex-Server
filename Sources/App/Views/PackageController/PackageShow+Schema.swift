import Foundation

extension PackageShow {
    
    struct PackageSchema: Schema {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case identifier, name, description, license, version,
                 codeRepository, url, dateCreated, dateModified
        }
        
        var context: String = "https://schema.org"
        var type: String = "SoftwareSourceCode"
        
        let identifier: String
        let name: String
        let description: String?
        let license: String?
        let version: String?
        let codeRepository: String
        let url: String
        let dateCreated: Date?
        let dateModified: Date?
        
        init?(package: Package) {
            guard
                let repository = package.repository,
                let repositoryOwner = repository.owner,
                let repositoryName = repository.name
            else {
                return nil
            }
            
            identifier = "\(repositoryOwner)/\(repositoryName)"
            name = repositoryName
            description = repository.summary
            license = repository.licenseUrl
            version = package.releaseInfo().stable?.link.label
            codeRepository = package.url.droppingGitExtension
            url = SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).absoluteURL()
            dateCreated = repository.firstCommitDate
            dateModified = repository.lastCommitDate
            
//            OrganisationSchema(legalName: repository.owner)
        }
    }
    
    fileprivate struct OrganisationSchema: Schema {
        
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case legalName
        }
        
        var context: String = "https://schema.org"
        var type: String = "Organization"
        
        let legalName: String
        
        init(legalName: String) {
            self.legalName = legalName
        }
    }
    
}
