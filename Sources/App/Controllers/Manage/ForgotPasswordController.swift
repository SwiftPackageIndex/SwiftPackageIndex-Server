import Fluent
import Plot
import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

enum ForgotPasswordController {
    @Sendable
    static func show(req: Request) async throws -> HTML {
        return ForgotPassword.View(path: req.url.path, model: ForgotPassword.Model()).document()
    }
    
    @Sendable
    static func forgotPasswordEmail(req: Request) async throws ->  HTML {
        struct Credentials: Content {
            var email: String
        }
        let user = try req.content.decode(Credentials.self)
        do {
            try await req.application.cognito.authenticatable.forgotPassword(username: user.email)
            return Reset.View(path: SiteURL.resetPassword.relativeURL(), model: Reset.Model(email: user.email)).document()
        } catch {
            return ForgotPassword.View(path: req.url.path, model: ForgotPassword.Model(errorMessage: "An error occurred: \(error.localizedDescription)")).document()
        }
    }
}
