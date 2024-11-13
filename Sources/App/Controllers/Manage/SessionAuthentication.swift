import Vapor
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
        do {
            // TODO: handle response, refresh token
            let response = try await request.application.cognito.authenticatable.authenticate(accessToken: sessionID, on: request.eventLoop)
            request.auth.login(User(accessToken: sessionID))
        } catch let error as SotoCognitoError { // TODO: handle error 
            return
        }
    }
    typealias User = AuthenticatedUser
}
