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

    // License identifiers match GitHub's API keys from choosealicense.com
    case bsd_0_clause = "0bsd"
    case afl_3_0 = "afl-3.0"
    case agpl_3_0 = "agpl-3.0"
    case apache_2_0 = "apache-2.0"
    case artistic_2_0 = "artistic-2.0"
    case blueoak_1_0_0 = "blueoak-1.0.0"
    case bsd_2_clause = "bsd-2-clause"
    case bsd_2_clause_patent = "bsd-2-clause-patent"
    case bsd_3_clause = "bsd-3-clause"
    case bsd_3_clause_clear = "bsd-3-clause-clear"
    case bsd_4_clause = "bsd-4-clause"
    case bsl_1_0 = "bsl-1.0"
    case cc
    case cc_by_4_0 = "cc-by-4.0"
    case cc_by_sa_4_0 = "cc-by-sa-4.0"
    case cc0_1_0 = "cc0-1.0"
    case cecill_2_1 = "cecill-2.1"
    case cern_ohl_p_2_0 = "cern-ohl-p-2.0"
    case cern_ohl_s_2_0 = "cern-ohl-s-2.0"
    case cern_ohl_w_2_0 = "cern-ohl-w-2.0"
    case ecl_2_0 = "ecl-2.0"
    case epl_1_0 = "epl-1.0"
    case epl_2_0 = "epl-2.0"
    case eupl_1_1 = "eupl-1.1"
    case eupl_1_2 = "eupl-1.2"
    case gfdl_1_3 = "gfdl-1.3"
    case gpl
    case gpl_2_0 = "gpl-2.0"
    case gpl_3_0 = "gpl-3.0"
    case isc
    case lgpl
    case lgpl_2_1 = "lgpl-2.1"
    case lgpl_3_0 = "lgpl-3.0"
    case lppl_1_3c = "lppl-1.3c"
    case mit
    case mit_0 = "mit-0"
    case mpl_2_0 = "mpl-2.0"
    case ms_pl = "ms-pl"
    case ms_rl = "ms-rl"
    case mulanpsl_2_0 = "mulanpsl-2.0"
    case ncsa
    case odbl_1_0 = "odbl-1.0"
    case ofl_1_1 = "ofl-1.1"
    case osl_3_0 = "osl-3.0"
    case postgresql
    case upl_1_0 = "upl-1.0"
    case unlicense // NB: This is an actual license and *not* a typo of "unlicensed"
    case vim
    case wtfpl
    case zlib

    // These are special cases, not license types
    case other // An unknown or unidentified license
    case none // Actually unlicensed code!

    var fullName: String {
        switch self {
            case .bsd_0_clause: return "BSD Zero Clause License"
            case .afl_3_0: return "Academic Free License v3.0"
            case .agpl_3_0: return "GNU Affero General Public License v3.0"
            case .apache_2_0: return "Apache License 2.0"
            case .artistic_2_0: return "Artistic License 2.0"
            case .blueoak_1_0_0: return "Blue Oak Model License 1.0.0"
            case .bsd_2_clause: return "BSD 2-Clause \"Simplified\" License"
            case .bsd_2_clause_patent: return "BSD 2-Clause Plus Patent License"
            case .bsd_3_clause: return "BSD 3-Clause \"New\" or \"Revised\" License"
            case .bsd_3_clause_clear: return "BSD 3-Clause Clear License"
            case .bsd_4_clause: return "BSD 4-Clause \"Original\" License"
            case .bsl_1_0: return "Boost Software License 1.0"
            case .cc: return "Creative Commons License"
            case .cc_by_4_0: return "Creative Commons Attribution 4.0"
            case .cc_by_sa_4_0: return "Creative Commons Attribution Share Alike 4.0"
            case .cc0_1_0: return "Creative Commons Zero v1.0 Universal"
            case .cecill_2_1: return "CeCILL Free Software License Agreement v2.1"
            case .cern_ohl_p_2_0: return "CERN Open Hardware Licence Version 2 - Permissive"
            case .cern_ohl_s_2_0: return "CERN Open Hardware Licence Version 2 - Strongly Reciprocal"
            case .cern_ohl_w_2_0: return "CERN Open Hardware Licence Version 2 - Weakly Reciprocal"
            case .ecl_2_0: return "Educational Community License v2.0"
            case .epl_1_0: return "Eclipse Public License 1.0"
            case .epl_2_0: return "Eclipse Public License 2.0"
            case .eupl_1_1: return "European Union Public License 1.1"
            case .eupl_1_2: return "European Union Public License 1.2"
            case .gfdl_1_3: return "GNU Free Documentation License v1.3"
            case .gpl: return "GNU General Public License family"
            case .gpl_2_0: return "GNU General Public License v2.0"
            case .gpl_3_0: return "GNU General Public License v3.0"
            case .isc: return "ISC License"
            case .lgpl: return "GNU Lesser General Public License family"
            case .lgpl_2_1: return "GNU Lesser General Public License v2.1"
            case .lgpl_3_0: return "GNU Lesser General Public License v3.0"
            case .lppl_1_3c: return "LaTeX Project Public License v1.3c"
            case .mit: return "MIT License"
            case .mit_0: return "MIT No Attribution License"
            case .mpl_2_0: return "Mozilla Public License 2.0"
            case .ms_pl: return "Microsoft Public License"
            case .ms_rl: return "Microsoft Reciprocal License"
            case .mulanpsl_2_0: return "Mulan Permissive Software License, Version 2"
            case .ncsa: return "University of Illinois/NCSA Open Source License"
            case .odbl_1_0: return "Open Data Commons Open Database License v1.0"
            case .ofl_1_1: return "SIL Open Font License 1.1"
            case .osl_3_0: return "Open Software License 3.0"
            case .postgresql: return "PostgreSQL License"
            case .upl_1_0: return "Universal Permissive License v1.0"
            case .unlicense: return "The Unlicense"
            case .vim: return "Vim License"
            case .wtfpl: return "Do What The F**k You Want To Public License"
            case .zlib: return "zLib License"

            case .other: return "Unknown or Unrecognised License"
            case .none: return "No License"
        }
    }

    var shortName: String {
        switch self {
            case .bsd_0_clause: return "0BSD"
            case .afl_3_0: return "AFL 3.0"
            case .agpl_3_0: return "AGPL 3.0"
            case .apache_2_0: return "Apache 2.0"
            case .artistic_2_0: return "Artistic 2.0"
            case .blueoak_1_0_0: return "BlueOak 1.0.0"
            case .bsd_2_clause: return "BSD 2-Clause"
            case .bsd_2_clause_patent: return "BSD 2-Clause Patent"
            case .bsd_3_clause: return "BSD 3-Clause"
            case .bsd_3_clause_clear: return "BSD 3-Clause Clear"
            case .bsd_4_clause: return "BSD 4-Clause"
            case .bsl_1_0: return "Boost 1.0"
            case .cc: return "CC"
            case .cc_by_4_0: return "CC Attribution 4.0"
            case .cc_by_sa_4_0: return "CC Attribution SA 4.0"
            case .cc0_1_0: return "CC Zero 1.0"
            case .cecill_2_1: return "CeCILL 2.1"
            case .cern_ohl_p_2_0: return "CERN OHL-P 2.0"
            case .cern_ohl_s_2_0: return "CERN OHL-S 2.0"
            case .cern_ohl_w_2_0: return "CERN OHL-W 2.0"
            case .ecl_2_0: return "ECL 2.0"
            case .epl_1_0: return "EPL 1.0"
            case .epl_2_0: return "EPL 2.0"
            case .eupl_1_1: return "EUPL 1.1"
            case .eupl_1_2: return "EUPL 1.2"
            case .gfdl_1_3: return "GFDL 1.3"
            case .gpl: return "GPL"
            case .gpl_2_0: return "GPL 2.0"
            case .gpl_3_0: return "GPL 3.0"
            case .isc: return "ISC"
            case .lgpl: return "LGPL"
            case .lgpl_2_1: return "LGPL 2.1"
            case .lgpl_3_0: return "LGPL 3.0"
            case .lppl_1_3c: return "LPPL 1.3c"
            case .mit: return "MIT"
            case .mit_0: return "MIT-0"
            case .mpl_2_0: return "MPL 2.0"
            case .ms_pl: return "MSPL"
            case .ms_rl: return "MSRL"
            case .mulanpsl_2_0: return "MulanPSL 2.0"
            case .ncsa: return "NCSA"
            case .odbl_1_0: return "ODbL 1.0"
            case .ofl_1_1: return "OFL 1.1"
            case .osl_3_0: return "OSL 3.0"
            case .postgresql: return "PostgreSQL"
            case .upl_1_0: return "UPL 1.0"
            case .unlicense: return "The Unlicense"
            case .vim: return "Vim"
            case .wtfpl: return "DWTFYWTPL"
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
                 .cecill_2_1,
                 .cern_ohl_s_2_0,
                 .cern_ohl_w_2_0,
                 .eupl_1_1,
                 .eupl_1_2,
                 .gfdl_1_3,
                 .gpl,
                 .gpl_2_0,
                 .gpl_3_0,
                 .lgpl,
                 .lgpl_2_1,
                 .lgpl_3_0,
                 .lppl_1_3c,
                 .ms_rl,
                 .osl_3_0: return .incompatibleWithAppStore
            default: return .compatibleWithAppStore
        }
    }

    enum Kind: String, Codable {
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
