import Foundation

extension PackageShow {
    
    struct PackageSchema: Schema {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case identifier, name, description, license, version,
                 codeRepository, url, dateCreated, dateModified,
                 programmingLanguage
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
        let sourceOrganization: OrganisationSchema
        let programmingLanguage: ComputerLanguageSchema
        
        init(
            repositoryOwner: String,
            repositoryName: String,
            organisationName: String?,
            summary: String?,
            licenseUrl: String?,
            version: String?,
            repositoryUrl: String,
            dateCreated: Date?,
            dateModified: Date?
        ) {
            self.identifier = "\(repositoryOwner)/\(repositoryName)"
            self.name = repositoryName
            self.description = summary
            self.license = licenseUrl
            self.version = version
            self.codeRepository = repositoryUrl
            self.url = SiteURL.package(.value(repositoryOwner), .value(repositoryName), .none).absoluteURL()
            self.dateCreated = dateCreated
            self.dateModified = dateModified
            self.sourceOrganization = OrganisationSchema(legalName: organisationName ?? repositoryOwner)
            self.programmingLanguage = ComputerLanguageSchema(name: "Swift", url: "https://swift.org/")
        }
        
        init?(package: Package) {
            guard
                let repository = package.repository,
                let repositoryOwner = repository.owner,
                let repositoryName = repository.name
            else {
                return nil
            }
            
            self.init(
                repositoryOwner: repositoryOwner,
                repositoryName: repositoryName,
                organisationName: repository.ownerName,
                summary: repository.summary,
                licenseUrl: repository.licenseUrl,
                version: package.releaseInfo().stable?.link.label,
                repositoryUrl: package.url.droppingGitExtension,
                dateCreated: repository.firstCommitDate,
                dateModified: repository.lastCommitDate
            )
        }
    }
    
    struct OrganisationSchema: Schema {
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
    
    struct ComputerLanguageSchema: Schema {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case name, url
        }
        
        var context: String = "https://schema.org"
        var type: String = "ComputerLanguage"
        
        let name: String
        let url: String
        
        init(name: String, url: String) {
            self.name = name
            self.url = url
        }
    }
}
