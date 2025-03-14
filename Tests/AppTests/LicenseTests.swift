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

import Testing


extension AllTests.LicenseTests {

    @Test func init_from_dto() throws {
        #expect(License(from: Github.Metadata.LicenseInfo(key: "mit")) == .mit)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "agpl-3.0")) == .agpl_3_0)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "other")) == .other)
        #expect(License(from: .none) == .none)
    }

    @Test func init_from_dto_unknown() throws {
        // ensure unknown licenses are mapped to `.other`
        #expect(License(from: Github.Metadata.LicenseInfo(key: "non-existing license")) == .other)
    }

    @Test func fullName() throws {
        #expect(License.mit.fullName == "MIT License")
        #expect(License.agpl_3_0.fullName == "GNU Affero General Public License v3.0")
        #expect(License.other.fullName == "Unknown or Unrecognised License")
        #expect(License.none.fullName == "No License")
    }

    @Test func shortName() throws {
        #expect(License.mit.shortName == "MIT")
        #expect(License.agpl_3_0.shortName == "AGPL 3.0")
        #expect(License.other.shortName == "Unknown license")
        #expect(License.none.shortName == "No license")
    }

    @Test func isCompatibleWithAppStore() throws {
        #expect(License.mit.licenseKind == .compatibleWithAppStore)
        #expect(License.agpl_3_0.licenseKind == .incompatibleWithAppStore)
        #expect(License.other.licenseKind == .other)
        #expect(License.none.licenseKind == .none)
    }

}
