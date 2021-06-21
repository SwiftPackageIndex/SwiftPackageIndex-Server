@testable import App
import XCTVapor

class PackageShowSchemaTests: SnapshotTestCase {

    func test_schema_initialiser() throws {
        let schema = PackageShow.PackageSchema(
            repositoryOwner: "Owner",
            repositoryName: "Name",
            organisationName: "OrganisationName",
            summary: "Summary",
            licenseUrl: "License",
            version: "Version",
            repositoryUrl: "URL",
            dateCreated: Date(timeIntervalSince1970: 0),
            dateModified: Date(timeIntervalSinceReferenceDate: 0)
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
        XCTAssertEqual(schema.dateCreated, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(schema.dateModified, Date(timeIntervalSinceReferenceDate: 0))
        
        XCTAssertEqual(schema.sourceOrganization.type, "Organization")
        XCTAssertEqual(schema.sourceOrganization.legalName, "OrganisationName")
        
        XCTAssertEqual(schema.programmingLanguage.type, "ComputerLanguage")
        XCTAssertEqual(schema.programmingLanguage.name, "Swift")
        XCTAssertEqual(schema.programmingLanguage.url, "https://swift.org/")
    }
    
}
