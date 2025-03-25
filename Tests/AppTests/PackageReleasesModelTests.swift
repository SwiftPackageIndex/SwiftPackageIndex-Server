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

import Dependencies
import Testing


extension AllTests.PackageReleasesModelTests {

    @Test func initialise() async throws {
        // Setup

        // Work-around to set the local time zone for time sensitive
        // tests. Sets the explicit default time zone to UTC for the duration
        // of this test.
        let explicitGMTTimeZone = TimeZone(identifier: "Etc/UTC")!
        let oldDefault = NSTimeZone.default
        NSTimeZone.default = explicitGMTTimeZone
        defer {
            NSTimeZone.default = oldDefault
        }

        try await withDependencies {
            $0.date.now = .spiBirthday
        } operation: {
            try await withApp { app in
                let pkg = Package(id: UUID(), url: "1".asGithubUrl.url)
                try await pkg.save(on: app.db)
                
                try await Repository(package: pkg, releases: [
                    .mock(description: "Release Notes", descriptionHTML: "Release Notes",
                          publishedAt: 2, tagName: "1.0.0", url: "some url"),
                    
                        .mock(description: nil, descriptionHTML: nil,
                              publishedAt: 1, tagName: "0.0.1", url: "some url"),
                ]).save(on: app.db)
                let jpr = try await Package.fetchCandidate(app.db, id: pkg.id!)
                
                
                // MUT
                let model = try #require(PackageReleases.Model(package: jpr))
                
                // Validate
                #expect(model.releases == [
                    .init(title: "1.0.0", date: "Released 50 years ago on 1 January 1970",
                          html: "Release Notes", link: "some url"),
                    
                        .init(title: "0.0.1", date: "Released 50 years ago on 1 January 1970",
                              html: nil, link: "some url"),
                ])
                // NOTE(heckj): test is sensitive to local time zones, breaks when run at GMT-7
                // resolves as `31 December 1969`
            }
        }
    }

    @Test func dateFormatting() throws {

        // Work-around to set the local time zone for time sensitive
        // tests. Sets the explicit default time zone to UTC for the duration
        // of this test.
        let explicitGMTTimeZone = TimeZone(identifier: "Etc/UTC")!
        let oldDefault = NSTimeZone.default
        NSTimeZone.default = explicitGMTTimeZone
        defer {
            NSTimeZone.default = oldDefault
        }

        let currentDate = Date(timeIntervalSince1970: 500)
        let targetDate = Date(timeIntervalSince1970: 0)

        #expect(PackageReleases.Model.formatDate(targetDate, currentDate: currentDate) == "Released 8 minutes ago on 1 January 1970")
        // NOTE(heckj): test is sensitive to local time zones, breaks when run at GMT-7
        // resolves as `31 December 1969`

        #expect(PackageReleases.Model.formatDate(nil, currentDate: currentDate) == nil)
    }

    @Test func removeDuplicateHeader() throws {

        do { // First header is removed if it contains the version (positive case)
            let descriptionHTML = """
            <h2>Header for v1.0.0</h2>
            <h2>Second Header for v1.0.0</h2>
            """

            #expect(PackageReleases.Model.updateDescription(descriptionHTML, replacingTitle: "v1.0.0") == "<h2>Second Header for v1.0.0</h2>")
        }

        do { // First header is *only* removed if it contains the version
            let descriptionHTML = """
            <h2>Header for version 1</h2>
            <h2>Second Header for v1.0.0</h2>
            """

            #expect(PackageReleases.Model.updateDescription(descriptionHTML, replacingTitle: "v1.0.0") == "<h2>Header for version 1</h2> \n<h2>Second Header for v1.0.0</h2>")
        }

        do { // Supports all header versions (h1-h6)
            ["h1", "h2", "h3", "h4", "h5", "h6"].forEach { header in
                let descriptionHTML = "<\(header)>v1.0.0</\(header)>"
                #expect(PackageReleases.Model.updateDescription(descriptionHTML, replacingTitle: "v1.0.0") == "")
            }
        }
    }

    @Test func descriptionIsTrimmed() throws {
        #expect(PackageReleases.Model.updateDescription(nil, replacingTitle: "") == nil)
        #expect(PackageReleases.Model.updateDescription("", replacingTitle: "") == nil)
        #expect(PackageReleases.Model.updateDescription(" ", replacingTitle: "") == nil)
        #expect(PackageReleases.Model.updateDescription("""


        """, replacingTitle: "") == nil)
    }
}
