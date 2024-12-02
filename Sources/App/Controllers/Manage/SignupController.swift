import Fluent
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
        struct UserCreds: Content {
            var email: String
            var password: String
        }
        do {
            let user = try req.content.decode(UserCreds.self)
            try await Cognito.signup(req: req, username: user.email, password: user.password)
            return Verify.View(path: SiteURL.verify.relativeURL(), model: Verify.Model(email: user.email)).document()
        } catch let error as AWSErrorType {
            let model = Signup.Model(errorMessage: error.message ?? "There was an error.")
            return Signup.View(path: req.url.path, model: model).document()
        } catch { 
            return Signup.View(path: SiteURL.signup.relativeURL(), model: Signup.Model(errorMessage: "An unknown error occurred: \(error.localizedDescription)")).document()
        }
        
    }
}

