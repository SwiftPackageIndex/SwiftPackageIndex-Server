// Copyright 2020-2021 Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

extension PackageShow {
    
    struct PackageSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case identifier, name, description, license, version,
                 codeRepository, url, dateCreated, dateModified,
                 sourceOrganization, programmingLanguage, keywords
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
        let keywords: [String]
        
        init(
            repositoryOwner: String,
            repositoryName: String,
            organisationName: String?,
            summary: String?,
            licenseUrl: String?,
            version: String?,
            repositoryUrl: String,
            dateCreated: Date?,
            dateModified: Date?,
            keywords: [String]
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
            self.keywords = keywords
        }
        
        init?(package jprvb: JPRVB) {
            let package = jprvb.model
            let versions = jprvb.versions
            guard
                let repository = jprvb.repository,
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
                version: PackageShow.releaseInfo(packageUrl: package.url, versions: versions).stable?.link.label,
                repositoryUrl: package.url.droppingGitExtension,
                dateCreated: repository.firstCommitDate,
                dateModified: repository.lastCommitDate,
                keywords: repository.keywords
            )
        }
    }
    
    struct OrganisationSchema: Encodable {
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
    
    struct ComputerLanguageSchema: Encodable {
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


extension PackageShow {
    static func releaseInfo(packageUrl: String, versions: [Version]) -> PackageShow.Model.ReleaseInfo {
        let versions = [Version.Kind.release, .preRelease, .defaultBranch]
            .map {
                versions.latest(for: $0)
                    .flatMap {
                        JPRVB.makeDatedLink(packageUrl: packageUrl,
                                            version: $0,
                                            keyPath: \.commitDate)
                    }
            }
        return .init(stable: versions[0],
                     beta: versions[1],
                     latest: versions[2])
    }
}
