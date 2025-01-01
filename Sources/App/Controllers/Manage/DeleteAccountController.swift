import Foundation
import Fluent
import Plot
import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

enum DeleteAccountController {
    @Sendable
    static func deleteAccount(req: Request) async throws -> Response {
        do {
            try await Cognito.deleteUser(req: req, accessToken: req.auth.require(AuthenticatedUser.self).sessionID)
            req.auth.logout(AuthenticatedUser.self)
            req.session.unauthenticate(AuthenticatedUser.self)
            req.session.destroy()
            return req.redirect(to: SiteURL.home.relativeURL())
        } catch {
            return Portal.View(path: SiteURL.portal.relativeURL(), model: Portal.Model(errorMessage: "An unknown error occurred: \(error.localizedDescription)")).document().encodeResponse(status: .internalServerError)
        }
    }
}
