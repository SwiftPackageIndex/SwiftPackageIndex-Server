import Foundation
import Dependencies
import Fluent
import Plot
import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

extension Portal {
    
    enum DeleteAccountController {
        @Sendable
        static func deleteAccount(req: Request) async throws -> Response {
            @Dependency(\.cognito) var cognito
            do {
                try await cognito.deleteUser(req: req)
                req.auth.logout(AuthenticatedUser.self)
                req.session.unauthenticate(AuthenticatedUser.self)
                req.session.destroy()
                return req.redirect(to: SiteURL.home.relativeURL())
            } catch {
                return PortalPage.View(path: SiteURL.portal.relativeURL(), model: PortalPage.Model(errorMessage: "An unknown error occurred: \(error.localizedDescription)")).document().encodeResponse(status: .internalServerError)
            }
        }
    }
}
