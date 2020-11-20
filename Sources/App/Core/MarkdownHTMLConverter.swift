import libcmark_gfm


enum MarkdownHTMLConverter {
    
    enum ConversionError: Error {
        case failedToCreateParser
        case markdownToASTError
        case astRenderError
        case htmlToStringFailed
    }
    
    static let options = CMARK_OPT_SAFE
    
    private static func createCommonMarkNode(markdown: String) throws -> UnsafeMutablePointer<cmark_node> {
        let tree = markdown.withCString { (document: UnsafePointer<Int8>) -> UnsafeMutablePointer<cmark_node>? in
            let stringLength = Int(strlen(document))
            return cmark_parse_document(document, stringLength, options)
        }
        
        guard let ast = tree else {
            throw ConversionError.markdownToASTError
        }
        
        return ast
    }
    
    private static func createGFMCommonMarkNode(markdown: String) throws -> UnsafeMutablePointer<cmark_node> {
        cmark_gfm_core_extensions_ensure_registered()
        
        guard let parser = cmark_parser_new(options) else {
            throw ConversionError.failedToCreateParser
        }
        
        defer {
            cmark_parser_free(parser)
        }
        
        ["table", "strikethrough", "tasklist", "tagfilter", "autolink"].forEach {
            if let syntaxExtension = cmark_find_syntax_extension($0) {
                cmark_parser_attach_syntax_extension(parser, syntaxExtension)
            }
        }
        
        let tree = markdown.withCString { (document: UnsafePointer<Int8>) -> UnsafeMutablePointer<cmark_node>? in
            let stringLength = Int(strlen(document))
            cmark_parser_feed(parser, document, stringLength)
            return cmark_parser_finish(parser)
        }
        
        guard let ast = tree else {
            throw ConversionError.markdownToASTError
        }
        
        return ast
    }
    
    static func html(from markdown: String, enableGFM: Bool = true) throws -> String {
        let markdown = markdown.replaceShorthandEmojis()
        let ast = enableGFM ? try createGFMCommonMarkNode(markdown: markdown) :
                              try createCommonMarkNode(markdown: markdown)
        
        guard let cString = cmark_render_html(ast, options, nil) else {
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
