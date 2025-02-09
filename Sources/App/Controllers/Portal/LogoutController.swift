import Foundation
import Fluent
import Plot
import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

enum LogoutController {
    @Sendable
    static func logout(req: Request) async throws -> Response {
        req.auth.logout(AuthenticatedUser.self)
        req.session.unauthenticate(AuthenticatedUser.self)
        req.session.destroy()
        return req.redirect(to: SiteURL.home.relativeURL())
    }
}

