import Fluent
import Plot
import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

enum ResetController {
    @Sendable
    static func show(req: Request) async throws -> HTML {
        return Reset.View(path: req.url.path, model: Reset.Model()).document()
    }
    
    @Sendable
    static func resetPassword(req: Request) async throws -> HTML {
        struct UserInfo: Content {
            var email: String
            var password: String
            var confirmationCode: String
        }
        do {
            let user = try req.content.decode(UserInfo.self)
            try await Cognito.resetPassword(req: req, username: user.email, password: user.password, confirmationCode: user.confirmationCode)
            let model = SuccessfulChange.Model(successMessage: "Successfully changed password")
            return SuccessfulChange.View(path: req.url.path, model: model).document()
        } catch let error as AWSErrorType {
            let model = Reset.Model(errorMessage: error.message ?? "There was an error.")
            return Reset.View(path: req.url.path, model: model).document()
        } catch {
            let model = Reset.Model(errorMessage: "An unknown error occurred: \(error.localizedDescription)")
            return Reset.View(path: req.url.path, model: model).document()
        }
    }
}
