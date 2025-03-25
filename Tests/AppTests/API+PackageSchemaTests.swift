// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
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

@testable import App

import Testing


extension AllTests.API_PackageSchemaTests {

    @Test func PackageSchema_init() throws {
        let schema = API.PackageSchema(
            repositoryOwner: "Owner",
            repositoryName: "Name",
            organisationName: "OrganisationName",
            summary: "Summary",
            licenseUrl: "License",
            version: "Version",
            repositoryUrl: "URL",
            datePublished: .t0,
            dateModified: .t1,
            keywords: ["foo", "bar", "baz"]
        )

        #expect(schema.context == "https://schema.org")
        #expect(schema.type == "SoftwareSourceCode")
        #expect(schema.identifier == "Owner/Name")
        #expect(schema.name == "Name")
        #expect(schema.description == "Summary")
        #expect(schema.license == "License")
        #expect(schema.version == "Version")
        #expect(schema.codeRepository == "URL")
        #expect(schema.url == "http://localhost:8080/Owner/Name")
        #expect(schema.datePublished == .t0)
        #expect(schema.dateModified == .t1)
        #expect(schema.keywords == ["foo", "bar", "baz"])

        #expect(schema.sourceOrganization.type == "Organization")
        #expect(schema.sourceOrganization.legalName == "OrganisationName")

        #expect(schema.programmingLanguage.type == "ComputerLanguage")
        #expect(schema.programmingLanguage.name == "Swift")
        #expect(schema.programmingLanguage.url == "https://swift.org/")
    }

}
