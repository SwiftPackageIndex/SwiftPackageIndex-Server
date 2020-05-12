
enum License: String, Codable {
    case agpl_3_0 = "agpl-3.0"
    case apache_2_0 = "apache-2.0"
    case bsd_2_clause = "bsd-2-clause"
    case bsd_3_clause = "bsd-3-clause"
    case cc0_1_0 = "cc0-1.0"
    case epl_1_0 = "epl-1.0"
    case gpl_3_0 = "gpl-3.0"
    case isc
    case lgpl_2_1 = "lgpl-2.1"
    case lgpl_3_0 = "lgpl-3.0"
    case mit
    case mpl_2_0 = "mpl-2.0"
    case other
    case unlicense  // NB: this is an actual license and *not* a typo of "unlicensed"
    case zlib
    case none
}


extension License {
    init(from dto: Github.License?) {
        if let key = dto?.key {
            self = License(rawValue: key) ?? .other
        } else {
            self = .none
        }
    }
}
