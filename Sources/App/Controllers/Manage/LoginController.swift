import Foundation
import Dependencies
import Fluent
import Plot
import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

enum LoginController {
    @Sendable
    static func show(req: Request) async throws -> HTML {
        return Login.View(path: req.url.path, model: Login.Model(errorMessage: "")).document()
    }
    
    @Sendable
    static func login(req: Request) async throws -> Response {
        @Dependency(\.cognito) var cognito
        struct UserCreds: Content {
            var email: String
            var password: String
        }
        do {
            let user = try req.content.decode(UserCreds.self)
            let response = try await cognito.authenticate(req: req, username: user.email, password: user.password)
            switch response {
            case .authenticated(let authenticatedResponse):
                let user = AuthenticatedUser(accessToken: authenticatedResponse.accessToken!, refreshToken: authenticatedResponse.refreshToken!)
                req.auth.login(user)
            case .challenged(let challengedResponse): // with the current pool configuration, a challenge response is not expected
                break
            }
            return req.redirect(to: SiteURL.portal.relativeURL(), redirectType: .normal)
        } catch let error as SotoCognitoError {
            var model = Login.Model(errorMessage: "There was an error. Please try again.")
            switch error {
            case .unauthorized(let reason):
                model = Login.Model(errorMessage: reason ?? "There was an error. Please try again.")
            case .unexpectedResult(let reason):
                model = Login.Model(errorMessage: reason ?? "There was an error. Please try again.")
            case .invalidPublicKey:
                break
            }
            return Login.View(path: req.url.path, model: model).document().encodeResponse(status: .unauthorized)
        } catch let error as AWSClientError {
            return Login.View(path: SiteURL.login.relativeURL(), model: Login.Model(errorMessage: "An AWS client error occurred: \(error.errorCode)")).document().encodeResponse(status: .unauthorized)
        } catch {
            return Login.View(path: SiteURL.login.relativeURL(), model: Login.Model(errorMessage: "An unknown error occurred: \(error.localizedDescription)")).document().encodeResponse(status: .unauthorized)
        }
        
    }
}

