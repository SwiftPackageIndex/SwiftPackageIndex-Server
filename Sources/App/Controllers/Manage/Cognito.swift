import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

struct Cognito {
    @Sendable
    static func authenticate(req: Request, username: String, password: String) async throws {
        let awsClient = AWSClient(httpClientProvider: .shared(req.application.http.client.shared))
        let awsCognitoConfiguration = CognitoConfiguration(
            userPoolId: Environment.get("POOL_ID")!,
            clientId: Environment.get("CLIENT_ID")!,
            clientSecret: Environment.get("CLIENT_SECRET")!,
            cognitoIDP: CognitoIdentityProvider(client: awsClient, region: .useast2),
            adminClient: true
        )
        req.application.cognito.authenticatable = CognitoAuthenticatable(configuration: awsCognitoConfiguration)
        let response = try await req.application.cognito.authenticatable.authenticate(username: username, password: password)
        switch response {
        case .authenticated(let authenticatedResponse):
            let user = AuthenticatedUser(accessToken: authenticatedResponse.accessToken!, refreshToken: authenticatedResponse.refreshToken!)
            req.auth.login(user)
        case .challenged(let challengedResponse): // TODO: handle challenge
            break
        }
        try awsClient.syncShutdown()
    }
}
