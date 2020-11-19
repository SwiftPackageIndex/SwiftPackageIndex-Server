import cmark

struct MarkdownHTMLConverter {
    
    enum ConversionError: Error {
        case markdownToASTError
        case astRenderError
        case htmlToStringFailed
    }
    
    let markdown: String
    let options = CMARK_OPT_SAFE
    
    func toHTML() throws -> String {
        let tree = markdown.withCString { (document: UnsafePointer<Int8>) -> OpaquePointer? in
            let stringLength = Int(strlen(document))
            return cmark_parse_document(document, stringLength, options)
        }
        
        guard let ast = tree else {
            throw ConversionError.markdownToASTError
        }
        
        guard let cString = cmark_render_html(ast, options) else {
            throw ConversionError.astRenderError
        }
        
        defer {
            free(cString)
        }
        
        guard let htmlString = String(cString: cString, encoding: .utf8) else {
            throw ConversionError.htmlToStringFailed
        }
        
        return htmlString
    }
    
}
