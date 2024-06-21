@preconcurrency import Cache

typealias CurrentReferenceCache = ExpiringCache<String, String>

extension CurrentReferenceCache {
    static let live = CurrentReferenceCache(duration: .minutes(5))

    subscript(owner owner: String, repository repository: String) -> String? {
        get {
            let key = "\(owner)/\(repository)".lowercased()
            return self[key]
        }
        set {
            let key = "\(owner)/\(repository)".lowercased()
            self[key] = newValue
        }
    }
}
