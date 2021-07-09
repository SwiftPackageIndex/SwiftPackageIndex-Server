@testable import App

import XCTVapor


class PackageReleasesModelTests: XCTestCase {

    func test_dateFormatting() throws {
        let currentDate = Date(timeIntervalSince1970: 500)
        let targetDate = Date(timeIntervalSince1970: 0)
        
        XCTAssertEqual(PackageReleases.Model.formatDate(targetDate, currentDate: currentDate),
                       "Released 8 minutes ago on 1 January 1970")
        
        XCTAssertNil(PackageReleases.Model.formatDate(nil, currentDate: currentDate))
    }
    
    func test_removeDuplicateHeader() throws {
        
        do { // First header is removed if it contains the version (positive case)
            let descriptionHTML = """
            <h2>Header for v1.0.0</h2>
            <h2>Second Header for v1.0.0</h2>
            """
            
            XCTAssertEqual(PackageReleases.Model.updateDescription(descriptionHTML, replacingTitle: "v1.0.0"),
                           "<h2>Second Header for v1.0.0</h2>")
        }
        
        do { // First header is *only* removed if it contains the version
            let descriptionHTML = """
            <h2>Header for version 1</h2>
            <h2>Second Header for v1.0.0</h2>
            """
            
            XCTAssertEqual(PackageReleases.Model.updateDescription(descriptionHTML, replacingTitle: "v1.0.0"),
                            """
                            <h2>Header for version 1</h2> 
                            <h2>Second Header for v1.0.0</h2>
                            """)
        }
        
        do { // Supports all header versions (h1-h6)
            ["h1", "h2", "h3", "h4", "h5", "h6"].forEach { header in
                let descriptionHTML = "<\(header)>v1.0.0</\(header)>"
                XCTAssertEqual(PackageReleases.Model.updateDescription(descriptionHTML, replacingTitle: "v1.0.0"), "")
            }
        }
    }
    
    func test_descriptionIsTrimmed() throws {
        XCTAssertEqual(PackageReleases.Model.updateDescription(nil, replacingTitle: ""), nil)
        XCTAssertEqual(PackageReleases.Model.updateDescription("", replacingTitle: ""), nil)
        XCTAssertEqual(PackageReleases.Model.updateDescription(" ", replacingTitle: ""), nil)
        XCTAssertEqual(PackageReleases.Model.updateDescription("""

          
        """, replacingTitle: ""), nil)
    }
}
