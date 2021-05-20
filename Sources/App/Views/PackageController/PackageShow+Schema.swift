import Foundation

extension PackageShow {
    
    struct PackageSchema: Schema {
        enum CodingKeys: String, CodingKey {
            case context = "@context"
            case type = "@type"
            case codeRepository
        }
        
        var context: String = "https://schema.org"
        var type: String = "SoftwareSourceCode"
        
        let codeRepository: String
        
        init(model: Model) {
            codeRepository = model.url
        }
    }
    
}
