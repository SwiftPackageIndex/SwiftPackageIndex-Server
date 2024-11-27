import Foundation
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
        struct UserCreds: Content {
            var email: String
            var password: String
        }
        do {
            let user = try req.content.decode(UserCreds.self)
            try await Cognito.authenticate(req: req, username: user.email, password: user.password)
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
            return Login.View(path: SiteURL.signup.relativeURL(), model: Login.Model(errorMessage: "An AWS client error occurred: \(error.errorCode)")).document().encodeResponse(status: .unauthorized)
        } catch {
            return Login.View(path: SiteURL.signup.relativeURL(), model: Login.Model(errorMessage: "An unknown error occurred: \(error.localizedDescription)")).document().encodeResponse(status: .unauthorized)
        }
        
    }
}

