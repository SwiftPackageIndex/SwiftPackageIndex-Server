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

enum License: String, Codable, Equatable, CaseIterable {

    // This is not an exhaustive list, but includes most commonly used license types
    case afl_3_0 = "afl-3.0"
    case apache_2_0 = "apache-2.0"
    case artistic_2_0 = "artistic-2.0"
    case bsd_2_clause = "bsd-2-clause"
    case bsd_3_clause = "bsd-3-clause"
    case bsd_3_clause_clear = "bsd-3-clause-clear"
    case bsl_1_0 = "bsl-1.0"
    case cc
    case cc0_1_0 = "cc0-1.0"
    case cc_by_4_0 = "cc-by-4.0"
    case cc_by_sa_4_0 = "cc-by-sa-4.0"
    case wtfpl
    case ecl_2_0 = "ecl-2.0"
    case epl_1_0 = "epl-1.0"
    case eupl_1_1 = "eupl-1.1"
    case agpl_3_0 = "agpl-3.0"
    case gpl
    case gpl_2_0 = "gpl-2.0"
    case gpl_3_0 = "gpl-3.0"
    case lgpl
    case lgpl_2_1 = "lgpl-2.1"
    case lgpl_3_0 = "lgpl-3.0"
    case isc
    case ms_pl = "ms-pl"
    case mit
    case mpl_2_0 = "mpl-2.0"
    case osl_3_0 = "osl-3.0"
    case postgresql
    case ncsa
    case unlicense // NB: This is an actual license and *not* a typo of "unlicensed"
    case zlib

    // These are special cases, not license types
    case other // An unknown or unidentified license
    case none // Actually unlicensed code!

    var fullName: String {
        switch self {
            case .afl_3_0: return "Academic Free License v3.0"
            case .apache_2_0: return "Apache License 2.0"
            case .artistic_2_0: return "Artistic License 2.0"
            case .bsd_2_clause: return "BSD 2-clause \"Simplified\" license"
            case .bsd_3_clause: return "BSD 3-clause \"New\" or \"Revised\" license"
            case .bsd_3_clause_clear: return "BSD 3-clause Clear license"
            case .bsl_1_0: return "Boost Software License 1.0"
            case .cc: return "Creative Commons License"
            case .cc0_1_0: return "Creative Commons Zero v1.0 Universal"
            case .cc_by_4_0: return "Creative Commons Attribution 4.0"
            case .cc_by_sa_4_0: return "Creative Commons Attribution Share Alike 4.0"
            case .wtfpl: return "Do What The F**k You Want To Public License"
            case .ecl_2_0: return "Educational Community License v2.0"
            case .epl_1_0: return "Eclipse Public License 1.0"
            case .eupl_1_1: return "European Union Public License 1.1"
            case .agpl_3_0: return "GNU Affero General Public License v3.0"
            case .gpl: return "GNU General Public License family"
            case .gpl_2_0: return "GNU General Public License v2.0"
            case .gpl_3_0: return "GNU General Public License v3.0"
            case .lgpl: return "GNU Lesser General Public License family"
            case .lgpl_2_1: return "GNU Lesser General Public License v2.1"
            case .lgpl_3_0: return "GNU Lesser General Public License v3.0"
            case .isc: return "ISC License"
            case .ms_pl: return "Microsoft Public License"
            case .mit: return "MIT License"
            case .mpl_2_0: return "Mozilla Public License 2.0"
            case .osl_3_0: return "Open Software License 3.0"
            case .postgresql: return "PostgreSQL License"
            case .ncsa: return "University of Illinois/NCSA Open Source License"
            case .unlicense: return "The Unlicense"
            case .zlib: return "zLib License"

            case .other: return "Unknown or Unrecognised License"
            case .none: return "No License"
        }
    }

    var shortName: String {
        switch self {
            case .afl_3_0: return "AFL 3.0"
            case .apache_2_0: return "Apache 2.0"
            case .artistic_2_0: return "Artistic 2.0"
            case .bsd_2_clause: return "BSD 2-Clause"
            case .bsd_3_clause: return "BSD 3-Clause"
            case .bsd_3_clause_clear: return "BSD 3-Clause Clear"
            case .bsl_1_0: return "Boost 1.0"
            case .cc: return "CC"
            case .cc0_1_0: return "CC Zero 1.0"
            case .cc_by_4_0: return "CC Attribution 4.0"
            case .cc_by_sa_4_0: return "CC Attribution SA 4.0"
            case .wtfpl: return "DWTFYWTPL"
            case .ecl_2_0: return "ECL 2.0"
            case .epl_1_0: return "EPL 1.0"
            case .eupl_1_1: return "EUPL 1.1"
            case .agpl_3_0: return "AGPL 3.0"
            case .gpl: return "GPL"
            case .gpl_2_0: return "GPL 2.0"
            case .gpl_3_0: return "GPL 3.0"
            case .lgpl: return "LGPL"
            case .lgpl_2_1: return "LGPL 2.1"
            case .lgpl_3_0: return "LGPL 3.0"
            case .isc: return "ISC"
            case .ms_pl: return "MSPL"
            case .mit: return "MIT"
            case .mpl_2_0: return "MPL 2.0"
            case .osl_3_0: return "OSL 3.0"
            case .postgresql: return "PostgreSQL"
            case .ncsa: return "NCSA"
            case .unlicense: return "The Unlicense"
            case .zlib: return "zLib"

            case .other: return "Unknown license"
            case .none: return "No license"
        }
    }

    var licenseKind: Kind {
        switch self {
            case .other:
                return .other
            case .none:
                return .none
            case .agpl_3_0,
                 .gpl,
                 .gpl_2_0,
                 .gpl_3_0,
                 .lgpl,
                 .lgpl_2_1,
                 .lgpl_3_0: return .incompatibleWithAppStore
            default: return .compatibleWithAppStore
        }
    }

    enum Kind: String {
        case none
        case other
        case incompatibleWithAppStore = "incompatible"
        case compatibleWithAppStore = "compatible"

        var userFacingString: String {
            switch self {
            case .none: return "not defined"
            case .other: return "unknown"
            case .incompatibleWithAppStore: return "incompatible with the App Store"
            case .compatibleWithAppStore: return "compatible with the App Store"
            }
        }
    }
}

extension License {
    init(from dto: Github.Metadata.LicenseInfo?) {
        if let key = dto?.key {
            self = License(rawValue: key) ?? .other
        } else {
            self = .none
        }
    }
}
