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

@testable import App
import XCTVapor

class PackageShowSchemaTests: SnapshotTestCase {

    func test_schema_initialiser() throws {
        let schema = API.PackageSchema(
            repositoryOwner: "Owner",
            repositoryName: "Name",
            organisationName: "OrganisationName",
            summary: "Summary",
            licenseUrl: "License",
            version: "Version",
            repositoryUrl: "URL",
            datePublished: Date(timeIntervalSince1970: 0),
            dateModified: Date(timeIntervalSinceReferenceDate: 0),
            keywords: ["foo", "bar", "baz"]
        )

        XCTAssertEqual(schema.context, "https://schema.org")
        XCTAssertEqual(schema.type, "SoftwareSourceCode")
        XCTAssertEqual(schema.identifier, "Owner/Name")
        XCTAssertEqual(schema.name, "Name")
        XCTAssertEqual(schema.description, "Summary")
        XCTAssertEqual(schema.license, "License")
        XCTAssertEqual(schema.version, "Version")
        XCTAssertEqual(schema.codeRepository, "URL")
        XCTAssertEqual(schema.url, "http://localhost:8080/Owner/Name")
        XCTAssertEqual(schema.datePublished, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(schema.dateModified, Date(timeIntervalSinceReferenceDate: 0))
        XCTAssertEqual(schema.keywords, ["foo", "bar", "baz"])

        XCTAssertEqual(schema.sourceOrganization.type, "Organization")
        XCTAssertEqual(schema.sourceOrganization.legalName, "OrganisationName")

        XCTAssertEqual(schema.programmingLanguage.type, "ComputerLanguage")
        XCTAssertEqual(schema.programmingLanguage.name, "Swift")
        XCTAssertEqual(schema.programmingLanguage.url, "https://swift.org/")
    }

}
