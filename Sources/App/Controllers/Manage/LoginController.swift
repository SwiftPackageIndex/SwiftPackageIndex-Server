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
        let awsClient = AWSClient(httpClientProvider: .shared(req.application.http.client.shared))
        let awsCognitoConfiguration = CognitoConfiguration(
            userPoolId: Environment.get("POOL_ID")!,
            clientId: Environment.get("CLIENT_ID")!,
            clientSecret: Environment.get("CLIENT_SECRET")!,
            cognitoIDP: CognitoIdentityProvider(client: awsClient, region: .useast2),
            adminClient: true
        )
        req.application.cognito.authenticatable = CognitoAuthenticatable(configuration: awsCognitoConfiguration)
        struct UserCreds: Content {
            var email: String
            var password: String
        }
        do {
            let user = try req.content.decode(UserCreds.self)
            try await cognito.authenticate(req: req, username: user.email, password: user.password)
            try await awsClient.shutdown()
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
            try await awsClient.shutdown()
            return Login.View(path: req.url.path, model: model).document().encodeResponse(status: .unauthorized)
        } catch let error as AWSClientError {
            try await awsClient.shutdown()
            return Login.View(path: SiteURL.signup.relativeURL(), model: Login.Model(errorMessage: "An AWS client error occurred: \(error.errorCode)")).document().encodeResponse(status: .unauthorized)
        } catch {
            try await awsClient.shutdown()
            return Login.View(path: SiteURL.signup.relativeURL(), model: Login.Model(errorMessage: "An unknown error occurred: \(error.localizedDescription)")).document().encodeResponse(status: .unauthorized)
        }
        
    }
}

