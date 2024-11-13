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
        let request = try CognitoIdentityProvider.DeleteUserRequest(accessToken: req.auth.require(AuthenticatedUser.self).sessionID)
        try await req.application.cognito.authenticatable.configuration.cognitoIDP.deleteUser(request)
        req.auth.logout(AuthenticatedUser.self)
        req.session.unauthenticate(AuthenticatedUser.self)
        req.session.destroy()
        return req.redirect(to: SiteURL.home.relativeURL())
    }
}
