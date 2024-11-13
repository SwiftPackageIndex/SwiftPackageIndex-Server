
import Fluent
import Plot
import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

enum VerifyController {
    @Sendable
    static func show(req: Request) async throws -> HTML {
        return Verify.View(path: req.url.path, model: Verify.Model(email: "")).document()
    }
    
    @Sendable
    static func verify(req: Request) async throws -> HTML {
        struct VerifyInformation: Content {
            var email: String
            var confirmationCode: String
        }
        let info = try req.content.decode(VerifyInformation.self)
        do {
            try await req.application.cognito.authenticatable.confirmSignUp(username: info.email, confirmationCode: info.confirmationCode)
            let model = SuccessfulChange.Model(successMessage: "Successfully confirmed signup")
            return SuccessfulChange.View(path: req.url.path, model: model).document()
        } catch let error as AWSErrorType {
            let model = Verify.Model(email: info.email, errorMessage: error.message ?? "There was an error.")
            return Verify.View(path: req.url.path, model: model).document()
        } catch {
            let model = Verify.Model(email: info.email, errorMessage: "An unknown error occurred.")
            return Verify.View(path: req.url.path, model: model).document()
        }
    }
}
