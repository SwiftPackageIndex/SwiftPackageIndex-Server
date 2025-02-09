import Fluent
import Plot
import Vapor
import SotoCognitoAuthenticationKit

enum PortalController {
    @Sendable 
    static func show(req: Request) async throws -> HTML {
        return Portal.View(path: req.url.path, model: Portal.Model()).document()
    }
}
