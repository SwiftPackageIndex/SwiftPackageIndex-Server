@testable import App

import JWT
import Vapor
import XCTest


struct TestPayload: JWTPayload {
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case isAdmin = "admin"
    }

    var subject: SubjectClaim
    var expiration: ExpirationClaim
    var isAdmin: Bool

    func verify(using signer: JWTSigner) throws {
        try expiration.verifyNotExpired()
    }
}


class AuthTests: AppTestCase {

    func test_builderToken() throws {
        // setup
        app.group(User.TokenAuthenticator(), User.guardMiddleware()) { protected in
            protected.get("resource") { req -> HTTPStatus in
                return .ok
            }
        }

        let token = "secr3t"
        Current.builderToken = { token }

        // MUT - valid token
        try app.test(.GET,
                     "resource",
                     headers: .init([("Authorization", "Bearer \(token)")])) { res in
            // validation
            XCTAssertEqual(res.status, .ok)
        }

        // MUT - invalid token
        try app.test(.GET,
                     "resource",
                     headers: .init([("Authorization", "Bearer bad-token")])) { res in
            // validation
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func test_jwt_verify() throws {
        app.jwt.signers.use(.hs256(key: "secret"))

        struct TestUser: Content, Authenticatable, JWTPayload {
            var email: String

            func verify(using signer: JWTSigner) throws {}
        }

        app.get("me") { req -> HTTPStatus in
            let payload = try req.jwt.verify(as: TestUser.self)
            XCTAssertEqual(payload.email, "foo@bar.com")
            return .ok
        }

        // {
        //     "email": "foo@bar.com"
        // }
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6ImZvb0BiYXIuY29tIn0.ucr0yHm0-NYQhfQ00z8_OumKYyHYWOJdT2R3QoVns_c"

        // MUT - valid token
        try app.test(.GET,
                     "me",
                     headers: .init([("Authorization", "Bearer \(token)")])) { res in
            XCTAssertEqual(res.status, .ok)
        }

        // MUT - invalid token
        try app.test(.GET,
                     "me",
                     headers: .init([("Authorization", "Bearer bad-token")])) { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func test_jwt_authenticator() throws {
        app.jwt.signers.use(.hs256(key: "secret"))

        struct TestUser: Content, Authenticatable, JWTPayload {
            var email: String
            func verify(using signer: JWTSigner) throws {}
        }

        struct JWTBearerAuthenticator: BearerAuthenticator {
            typealias User = TestUser

            func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
                do {
                    let user = try request.jwt.verify(bearer.token, as: TestUser.self)
                    request.auth.login(user)
                    return request.eventLoop.future()
                } catch {
                    return request.eventLoop.future()
                }
            }
        }

        app.group(JWTBearerAuthenticator(),
                  TestUser.guardMiddleware()) { proteced in
            proteced.get("me") { req -> HTTPStatus in
                let payload = try req.auth.require(TestUser.self)
                XCTAssertEqual(payload.email, "foo@bar.com")
                return .ok
            }
        }

        // {
        //     "email": "foo@bar.com"
        // }
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJlbWFpbCI6ImZvb0BiYXIuY29tIn0.ucr0yHm0-NYQhfQ00z8_OumKYyHYWOJdT2R3QoVns_c"

        // MUT - valid token
        try app.test(.GET,
                     "me",
                     headers: .init([("Authorization", "Bearer \(token)")])
        ) { res in
            XCTAssertEqual(res.status, .ok)
        }

        // MUT - invalid token
        try app.test(.GET,
                     "me",
                     headers: .init([("Authorization", "Bearer bad-token")])
        ) { res in
            XCTAssertEqual(res.status, .unauthorized)
        }
    }

    func test_login() throws {
        app.jwt.signers.use(.hs256(key: "secret"))

        struct TestUser: Content, Authenticatable, JWTPayload {
            var email: String
            func verify(using signer: JWTSigner) throws {}
        }

        struct JWTBearerAuthenticator: BearerAuthenticator {
            typealias User = TestUser

            func authenticate(bearer: BearerAuthorization, for request: Request) -> EventLoopFuture<Void> {
                do {
                    let user = try request.jwt.verify(bearer.token, as: TestUser.self)
                    request.auth.login(user)
                    return request.eventLoop.future()
                } catch {
                    return request.eventLoop.future()
                }
            }
        }

        struct LoginDTO: Content {
            var email: String
            var password: String
        }

        let passwordHash = try Bcrypt.hash("mypass")

        app.post("login") { req -> EventLoopFuture<[String: String]> in
            let dto = try req.content.decode(LoginDTO.self)

            // FIXME: lookup password hash from db
            let users = ["some@example.com": passwordHash]

            guard
                let storedPasswordHash = users[dto.email],
                try Bcrypt.verify(dto.password, created: storedPasswordHash) else {
                return req.eventLoop.future(error: Abort(.unauthorized))
            }
            return req.eventLoop.future(
                ["token": try req.jwt.sign(TestUser(email: dto.email))]
            )
        }
        app.group(JWTBearerAuthenticator(),
                  TestUser.guardMiddleware()) { proteced in
            proteced.get("me") { req -> HTTPStatus in
                let payload = try req.auth.require(TestUser.self)
                XCTAssertEqual(payload.email, "some@example.com")
                return .ok
            }
        }

        let body: ByteBuffer = .init(data: try JSONEncoder().encode(
                                        LoginDTO(email: "some@example.com",
                                                 password: "mypass")))
        try app.test(.POST, "login",
                     headers: .init([("Content-Type", "application/json")]),
                     body: body) { res in
            XCTAssertEqual(res.status, .ok)
            let dto = try JSONDecoder().decode([String: String].self, from: res.body)
            let token = try XCTUnwrap(dto["token"])
            let user = try app.jwt.signers.verify(token, as: TestUser.self)
            XCTAssertEqual(user.email, "some@example.com")

            try app.test(.GET, "me",
                         headers: .init([("Authorization", "Bearer \(token)")])) { res in
                XCTAssertEqual(res.status, .ok)
            }
        }
    }

}
