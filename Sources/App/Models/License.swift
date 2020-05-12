enum License: String, Codable {

    // This is not an exhaustive list, but includes most commonly used license types
    case afl_3_0 = "afl-3.0"
    case apache_2_0 = "apache-2.0"
    case artistic_2_0 = "artistic-2.0"
    case bsd_2_clause = "bsd-2-clause"
    case bsd_3_clause = "bsd-3-clause"
    case bsd_3_clause_clear = "bsd-3-clause-clear"
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

extension License {
    init(from dto: Github.License?) {
        if let key = dto?.key {
            self = License(rawValue: key) ?? .other
        } else {
            self = .none
        }
    }
}
