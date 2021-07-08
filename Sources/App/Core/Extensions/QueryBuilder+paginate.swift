import Fluent


extension QueryBuilder {
    /// Add `offset` and `limit` to the query corresponding to the give page. NB: the number of elements returned can be up to `pageSize + 1`. Therefore ensure to limit the results via `.prefix(pageSize)`.
    /// The point of this is to be able to tell if there are more results without having to run a count or any other subsequent query.
    /// - Parameters:
    ///   - page: requested page, first page is 1
    ///   - pageSize: number of elements per page
    /// - Returns: a `QueryBuilder`
    func paginate(page: Int, pageSize: Int) -> Self {
        // page is one-based, clamp it to ensure we get a >=0 offset
        let page = page.clamped(to: 1...)
        let offset = (page - 1) * pageSize
        let limit = pageSize + 1  // fetch one more so we can determine `hasMoreResults`
        return self
            .offset(offset)
            .limit(limit)
    }
}
