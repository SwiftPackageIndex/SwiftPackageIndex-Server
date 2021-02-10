// Hat tip https://www.swiftbysundell.com/articles/custom-query-functions-using-key-paths/

prefix func !<T>(keyPath: KeyPath<T, Bool>) -> (T) -> Bool {
    return { !$0[keyPath: keyPath] }
}
