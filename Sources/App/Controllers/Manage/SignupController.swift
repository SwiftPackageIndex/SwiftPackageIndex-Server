import Fluent
import Dependencies
import Plot
import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

enum SignupController {
    @Sendable
    static func show(req: Request) async throws -> HTML {
        return Signup.View(path: req.url.path, model: Signup.Model(errorMessage: "")).document()
    }
    
    @Sendable
    static func signup(req: Request) async throws -> HTML {
        @Dependency(\.cognito) var cognito
        struct UserCreds: Content {
            var email: String
            var password: String
        }
        do {
            let user = try req.content.decode(UserCreds.self)
            try await cognito.signup(req: req, username: user.email, password: user.password)
            return Verify.View(path: SiteURL.verify.relativeURL(), model: Verify.Model(email: user.email)).document()
        } catch let error as AWSErrorType {
            let errorMessage = (error.message != nil) ? "There was an error: \(error.message)" : "There was an error: \(error.localizedDescription)"
            let model = Signup.Model(errorMessage: errorMessage)
            return Signup.View(path: req.url.path, model: model).document()
        } catch {
            return Signup.View(path: SiteURL.signup.relativeURL(), model: Signup.Model(errorMessage: "An unknown error occurred: \(error.localizedDescription)")).document()
        }
        
    }
}

