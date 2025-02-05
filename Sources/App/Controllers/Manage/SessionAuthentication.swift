import Vapor
import Dependencies
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

struct AuthenticatedUser {
    var accessToken: String
}

extension AuthenticatedUser: SessionAuthenticatable {
    var sessionID: String {
        self.accessToken
    }
}

struct UserSessionAuthenticator: AsyncSessionAuthenticator {
    func authenticate(sessionID: String, for request: Vapor.Request) async throws {
        @Dependency(\.cognito) var cognito
        do {
            try await cognito.authenticateToken(req: request, sessionID: sessionID, accessToken: sessionID)
            request.auth.login(User(accessToken: sessionID))
        } catch _ as SotoCognitoError {
            // TODO: .unauthorized SotoCognitoError with reason "invalid token", attempt to refresh using
            // req.application.cognito.authenticatable.refresh(), which requires the username and refresh
            // token, both returned upon initial successful login.
        }
    }
    typealias User = AuthenticatedUser
}
