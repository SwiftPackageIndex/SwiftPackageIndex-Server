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
            try await cognito.signup(req: req, username: user.email, password: user.password)
            try await awsClient.shutdown()
            return Verify.View(path: SiteURL.verify.relativeURL(), model: Verify.Model(email: user.email)).document()
        } catch let error as AWSErrorType {
            let model = Signup.Model(errorMessage: error.message ?? "There was an error.")
            try await awsClient.shutdown()
            return Signup.View(path: req.url.path, model: model).document()
        } catch {
            try await awsClient.shutdown()
            return Signup.View(path: SiteURL.signup.relativeURL(), model: Signup.Model(errorMessage: "An unknown error occurred: \(error.localizedDescription)")).document()
        }
        
    }
}

