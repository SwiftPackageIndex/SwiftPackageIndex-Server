import Vapor
import SotoCognitoAuthentication
import SotoCognitoIdentityProvider
import SotoCognitoIdentity

struct Cognito {
    @Sendable
    static func authenticate(req: Request, username: String, password: String) async throws -> CognitoAuthenticateResponse {
        let awsClient = AWSClient(httpClientProvider: .shared(req.application.http.client.shared))
        let awsCognitoConfiguration = CognitoConfiguration(
            userPoolId: Environment.get("AWS_COGNITO_POOL_ID")!,
            clientId: Environment.get("AWS_COGNITO_CLIENT_ID")!,
            clientSecret: Environment.get("AWS_COGNITO_CLIENT_SECRET")!,
            cognitoIDP: CognitoIdentityProvider(client: awsClient, region: .useast2),
            adminClient: true
        )
        req.application.cognito.authenticatable = CognitoAuthenticatable(configuration: awsCognitoConfiguration)
        let response = try await req.application.cognito.authenticatable.authenticate(username: username, password: password)
        try awsClient.syncShutdown()
        return response
    }
    
    @Sendable
    static func authenticateToken(req: Request, sessionID: String, accessToken: String, on eventLoop: EventLoop) async throws -> Void {
        let awsClient = AWSClient(httpClientProvider: .shared(req.application.http.client.shared))
        let awsCognitoConfiguration = CognitoConfiguration(
            userPoolId: Environment.get("AWS_COGNITO_POOL_ID")!,
            clientId: Environment.get("AWS_COGNITO_CLIENT_ID")!,
            clientSecret: Environment.get("AWS_COGNITO_CLIENT_SECRET")!,
            cognitoIDP: CognitoIdentityProvider(client: awsClient, region: .useast2),
            adminClient: true
        )
        req.application.cognito.authenticatable = CognitoAuthenticatable(configuration: awsCognitoConfiguration)
        let _ = try await req.application.cognito.authenticatable.authenticate(accessToken: sessionID, on: req.eventLoop)
        try awsClient.syncShutdown()
    }
    
    @Sendable
    static func signup(req: Request, username: String, password: String) async throws {
        let awsClient = AWSClient(httpClientProvider: .shared(req.application.http.client.shared))
        let awsCognitoConfiguration = CognitoConfiguration(
            userPoolId: Environment.get("AWS_COGNITO_POOL_ID")!,
            clientId: Environment.get("AWS_COGNITO_CLIENT_ID")!,
            clientSecret: Environment.get("AWS_COGNITO_CLIENT_SECRET")!,
            cognitoIDP: CognitoIdentityProvider(client: awsClient, region: .useast2),
            adminClient: true
        )
        req.application.cognito.authenticatable = CognitoAuthenticatable(configuration: awsCognitoConfiguration)
        try await req.application.cognito.authenticatable.signUp(username: username, password: password, attributes: [:], on:req.eventLoop)
        try awsClient.syncShutdown()
    }
    
    @Sendable
    static func forgotPassword(req: Request, username: String) async throws {
        let awsClient = AWSClient(httpClientProvider: .shared(req.application.http.client.shared))
        let awsCognitoConfiguration = CognitoConfiguration(
            userPoolId: Environment.get("AWS_COGNITO_POOL_ID")!,
            clientId: Environment.get("AWS_COGNITO_CLIENT_ID")!,
            clientSecret: Environment.get("AWS_COGNITO_CLIENT_SECRET")!,
            cognitoIDP: CognitoIdentityProvider(client: awsClient, region: .useast2),
            adminClient: true
        )
        req.application.cognito.authenticatable = CognitoAuthenticatable(configuration: awsCognitoConfiguration)
        try await req.application.cognito.authenticatable.forgotPassword(username: username)
        try awsClient.syncShutdown()
    }
    
    @Sendable
    static func resetPassword(req: Request, username: String, password: String, confirmationCode: String) async throws {
        let awsClient = AWSClient(httpClientProvider: .shared(req.application.http.client.shared))
        let awsCognitoConfiguration = CognitoConfiguration(
            userPoolId: Environment.get("AWS_COGNITO_POOL_ID")!,
            clientId: Environment.get("AWS_COGNITO_CLIENT_ID")!,
            clientSecret: Environment.get("AWS_COGNITO_CLIENT_SECRET")!,
            cognitoIDP: CognitoIdentityProvider(client: awsClient, region: .useast2),
            adminClient: true
        )
        req.application.cognito.authenticatable = CognitoAuthenticatable(configuration: awsCognitoConfiguration)
        try await req.application.cognito.authenticatable.confirmForgotPassword(username: username, newPassword: password, confirmationCode: confirmationCode)
        try awsClient.syncShutdown()
    }
    
    @Sendable
    static func confirmSignUp(req: Request, username: String, confirmationCode: String) async throws {
        let awsClient = AWSClient(httpClientProvider: .shared(req.application.http.client.shared))
        let awsCognitoConfiguration = CognitoConfiguration(
            userPoolId: Environment.get("AWS_COGNITO_POOL_ID")!,
            clientId: Environment.get("AWS_COGNITO_CLIENT_ID")!,
            clientSecret: Environment.get("AWS_COGNITO_CLIENT_SECRET")!,
            cognitoIDP: CognitoIdentityProvider(client: awsClient, region: .useast2),
            adminClient: true
        )
        req.application.cognito.authenticatable = CognitoAuthenticatable(configuration: awsCognitoConfiguration)
        try await req.application.cognito.authenticatable.confirmSignUp(username: username, confirmationCode: confirmationCode)
        try awsClient.syncShutdown()
    }
    
    @Sendable
    static func deleteUser(req: Request) async throws {
        let awsClient = AWSClient(httpClientProvider: .shared(req.application.http.client.shared))
        let awsCognitoConfiguration = CognitoConfiguration(
            userPoolId: Environment.get("AWS_COGNITO_POOL_ID")!,
            clientId: Environment.get("AWS_COGNITO_CLIENT_ID")!,
            clientSecret: Environment.get("AWS_COGNITO_CLIENT_SECRET")!,
            cognitoIDP: CognitoIdentityProvider(client: awsClient, region: .useast2),
            adminClient: true
        )
        req.application.cognito.authenticatable = CognitoAuthenticatable(configuration: awsCognitoConfiguration)
        let request = try CognitoIdentityProvider.DeleteUserRequest(accessToken: req.auth.require(AuthenticatedUser.self).sessionID)
        try await req.application.cognito.authenticatable.configuration.cognitoIDP.deleteUser(request)
        try awsClient.syncShutdown()
    }
}
