import Foundation
import XCTest
@testable import BingeLog

final class JellyfinAuthResponseValidationTests: XCTestCase {
    func testAuthenticateRejectsEmptyRequiredResponseFields() async {
        let invalidResponses = [
            #"{ "AccessToken": "", "User": { "Id": "user-123", "Name": "Niklas" } }"#,
            #"{ "AccessToken": "token", "User": { "Id": "   ", "Name": "Niklas" } }"#,
            #"{ "AccessToken": "token", "User": { "Id": "user-123", "Name": "  " } }"#
        ]

        for responseBody in invalidResponses {
            MockJellyfinAuthURLProtocol.install(responseBody: responseBody)
            let service = JellyfinService(session: makeSession())

            do {
                _ = try await service.authenticate(
                    serverAddress: "https://media.example.com",
                    username: "niklas",
                    password: "test-password"
                )
                XCTFail("Expected invalidResponse for payload: \(responseBody)")
            } catch let error as JellyfinError {
                guard case .invalidResponse = error else {
                    XCTFail("Unexpected Jellyfin error: \(error)")
                    continue
                }
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testAuthenticateAcceptsCompleteResponse() async throws {
        MockJellyfinAuthURLProtocol.install(
            responseBody: #"{"AccessToken":"valid-token","User":{"Id":"user-123","Name":"Niklas"}}"#
        )
        let service = JellyfinService(session: makeSession())

        let result = try await service.authenticate(
            serverAddress: "https://media.example.com",
            username: "niklas",
            password: "test-password"
        )

        XCTAssertEqual(result.accessToken, "valid-token")
        XCTAssertEqual(result.user.id, "user-123")
        XCTAssertEqual(result.user.name, "Niklas")
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockJellyfinAuthURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockJellyfinAuthURLProtocol: URLProtocol {
    private static var responseData = Data()

    static func install(responseBody: String) {
        responseData = Data(responseBody.utf8)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
              ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
