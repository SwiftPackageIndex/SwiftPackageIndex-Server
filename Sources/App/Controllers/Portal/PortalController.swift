import Fluent
import Plot
import Vapor
import SotoCognitoAuthenticationKit

enum PortalController {
    @Sendable 
    static func show(req: Request) async throws -> HTML {
        return PortalPage.View(path: req.url.path, model: PortalPage.Model()).document()
    }
}
