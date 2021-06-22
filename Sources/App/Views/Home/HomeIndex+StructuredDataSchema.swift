import Foundation

extension HomeIndex {
    
    struct IndexSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case url, potentialAction
        }
        
        var context: String = "https://schema.org"
        var type: String = "WebSite"
        
        let url: String
        let potentialAction: SearchActionSchema
        
        init() {
            self.url = SiteURL.home.absoluteURL()
            self.potentialAction = .init(
                target: .init(
                    urlTemplate: SiteURL.search.absoluteURL(parameters: [
                        .init(key: "query", value: "{search_term_string}")
                    ], encodeParameters: false)
                ),
                queryInput: "required name=search_term_string"
            )
        }
    }
    
    struct SearchActionSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case target, queryInput = "query-input"
        }
        
        var context: String = "https://schema.org"
        var type: String = "SearchAction"
        
        let target: EntryPointSchema
        let queryInput: String
        
        init(target: EntryPointSchema, queryInput: String) {
            self.target = target
            self.queryInput = queryInput
        }
    }
    
    struct EntryPointSchema: Encodable {
        enum CodingKeys: String, CodingKey {
            case context = "@context", type = "@type"
            case urlTemplate
        }
        
        var context: String = "https://schema.org"
        var type: String = "EntryPoint"
        
        let urlTemplate: String
        
        init(urlTemplate: String) {
            self.urlTemplate = urlTemplate
        }
    }
}
