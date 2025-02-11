
import Fluent
import Plot
import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity
import Dependencies

extension Portal {
    
    enum VerifyController {
        @Sendable
        static func show(req: Request) async throws -> HTML {
            return Verify.View(path: req.url.path, model: Verify.Model(email: "")).document()
        }
        
        @Sendable
        static func verify(req: Request) async throws -> HTML {
            @Dependency(\.cognito) var cognito
            struct VerifyInformation: Content {
                var email: String
                var confirmationCode: String
            }
            do {
                let info = try req.content.decode(VerifyInformation.self)
                try await cognito.confirmSignUp(req: req, username: info.email, confirmationCode: info.confirmationCode)
                let model = SuccessfulChange.Model(successMessage: "Successfully confirmed signup")
                return SuccessfulChange.View(path: req.url.path, model: model).document()
            } catch let error as AWSErrorType {
                let info = try req.content.decode(VerifyInformation.self)
                let errorMessage = (error.message != nil) ? "There was an error: \(error.message)" : "There was an error: \(error.localizedDescription)"
                let model = Verify.Model(email: info.email, errorMessage: errorMessage)
                return Verify.View(path: req.url.path, model: model).document()
            } catch {
                let info = try req.content.decode(VerifyInformation.self)
                let model = Verify.Model(email: info.email, errorMessage: "An unknown error occurred: \(error.localizedDescription)")
                return Verify.View(path: req.url.path, model: model).document()
            }
        }
    }
}
