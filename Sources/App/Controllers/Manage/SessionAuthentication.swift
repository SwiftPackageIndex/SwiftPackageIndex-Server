import Vapor
import Dependencies
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

struct AuthenticatedUser {
    var accessToken: String
    var refreshToken: String?
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
            // TODO: handle response, refresh token
            try await cognito.authenticateToken(req: request, sessionID: sessionID, accessToken: sessionID, eventLoop: request.eventLoop)
            request.auth.login(User(accessToken: sessionID))
        } catch let error as SotoCognitoError { // TODO: handle error
            return
        }
    }
    typealias User = AuthenticatedUser
}
