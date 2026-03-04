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
        #expect(License(from: Github.Metadata.LicenseInfo(key: "0bsd")) == .bsd_0_clause)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "blueoak-1.0.0")) == .blueoak_1_0_0)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "bsd-2-clause-patent")) == .bsd_2_clause_patent)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "cecill-2.1")) == .cecill_2_1)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "cern-ohl-s-2.0")) == .cern_ohl_s_2_0)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "epl-2.0")) == .epl_2_0)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "eupl-1.2")) == .eupl_1_2)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "gfdl-1.3")) == .gfdl_1_3)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "lppl-1.3c")) == .lppl_1_3c)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "mit-0")) == .mit_0)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "ms-rl")) == .ms_rl)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "mulanpsl-2.0")) == .mulanpsl_2_0)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "odbl-1.0")) == .odbl_1_0)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "ofl-1.1")) == .ofl_1_1)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "upl-1.0")) == .upl_1_0)
        #expect(License(from: Github.Metadata.LicenseInfo(key: "vim")) == .vim)
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
        // Compatible
        #expect(License.mit.licenseKind == .compatibleWithAppStore)
        #expect(License.mit_0.licenseKind == .compatibleWithAppStore)
        #expect(License.apache_2_0.licenseKind == .compatibleWithAppStore)
        #expect(License.blueoak_1_0_0.licenseKind == .compatibleWithAppStore)
        #expect(License.bsd_2_clause_patent.licenseKind == .compatibleWithAppStore)
        #expect(License.epl_2_0.licenseKind == .compatibleWithAppStore)
        #expect(License.cern_ohl_p_2_0.licenseKind == .compatibleWithAppStore)
        #expect(License.upl_1_0.licenseKind == .compatibleWithAppStore)
        // Incompatible
        #expect(License.agpl_3_0.licenseKind == .incompatibleWithAppStore)
        #expect(License.cecill_2_1.licenseKind == .incompatibleWithAppStore)
        #expect(License.cern_ohl_s_2_0.licenseKind == .incompatibleWithAppStore)
        #expect(License.cern_ohl_w_2_0.licenseKind == .incompatibleWithAppStore)
        #expect(License.eupl_1_1.licenseKind == .incompatibleWithAppStore)
        #expect(License.eupl_1_2.licenseKind == .incompatibleWithAppStore)
        #expect(License.gfdl_1_3.licenseKind == .incompatibleWithAppStore)
        #expect(License.gpl_2_0.licenseKind == .incompatibleWithAppStore)
        #expect(License.lgpl_3_0.licenseKind == .incompatibleWithAppStore)
        #expect(License.lppl_1_3c.licenseKind == .incompatibleWithAppStore)
        #expect(License.ms_rl.licenseKind == .incompatibleWithAppStore)
        #expect(License.osl_3_0.licenseKind == .incompatibleWithAppStore)
        // Special
        #expect(License.other.licenseKind == .other)
        #expect(License.none.licenseKind == .none)
    }

}
