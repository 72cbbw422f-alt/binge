import Foundation
import XCTest
@testable import BingeLog

final class JellyfinLibraryRequestTests: XCTestCase {
    override func tearDown() {
        MockJellyfinURLProtocol.reset()
        super.tearDown()
    }

    func testLibraryItemsFetchesEveryPageAndUsesToken() async throws {
        MockJellyfinURLProtocol.install { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let start = Int(components.queryItems?.first(where: { $0.name == "StartIndex" })?.value ?? "") ?? -1
            let limit = Int(components.queryItems?.first(where: { $0.name == "Limit" })?.value ?? "") ?? -1

            guard request.url?.path == "/jellyfin/Users/user-123/Items",
                  request.value(forHTTPHeaderField: "Authorization")?.contains("Token=\"secret-token\"") == true,
                  limit == 200 else {
                return (400, Data())
            }

            let count = start == 400 ? 25 : 200
            let items = (start..<(start + count)).map { index in
                "{\"Id\":\"item-\(index)\",\"Name\":\"Title \(index)\",\"Type\":\"Movie\"}"
            }.joined(separator: ",")
            let json = "{\"Items\":[\(items)],\"TotalRecordCount\":425}"
            return (200, Data(json.utf8))
        }

        let service = JellyfinService(session: makeSession())
        let items = try await service.libraryItems(
            server: "https://media.example.com/jellyfin/",
            userID: "user-123",
            token: "secret-token"
        )

        XCTAssertEqual(items.count, 425)
        XCTAssertEqual(items.first?.id, "item-0")
        XCTAssertEqual(items.last?.id, "item-424")
        XCTAssertEqual(MockJellyfinURLProtocol.capturedStartIndexes, [0, 200, 400])
    }

    func testLibraryItemsStopsWhenServerReturnsShortPageWithoutTotal() async throws {
        MockJellyfinURLProtocol.install { request in
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let start = Int(components.queryItems?.first(where: { $0.name == "StartIndex" })?.value ?? "") ?? -1
            let items = (0..<3).map { index in
                "{\"Id\":\"item-\(start + index)\",\"Name\":\"Title\",\"Type\":\"Series\"}"
            }.joined(separator: ",")
            return (200, Data("{\"Items\":[\(items)]}".utf8))
        }

        let service = JellyfinService(session: makeSession())
        let items = try await service.libraryItems(
            server: "http://media.example.com",
            userID: "user-123",
            token: "secret-token"
        )

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(MockJellyfinURLProtocol.capturedStartIndexes, [0])
    }

    func testAuthenticateSendsCredentialsAndDecodesUserAndToken() async throws {
        MockJellyfinURLProtocol.install { _ in
            let json = """
            {
              "AccessToken": "returned-token",
              "User": { "Id": "user-123", "Name": "Niklas" }
            }
            """
            return (200, Data(json.utf8))
        }

        let service = JellyfinService(session: makeSession())
        let result = try await service.authenticate(
            serverAddress: "https://media.example.com/jellyfin/",
            username: "niklas",
            password: "test-password"
        )

        XCTAssertEqual(result.accessToken, "returned-token")
        XCTAssertEqual(result.user.id, "user-123")
        XCTAssertEqual(result.user.name, "Niklas")

        let request = try XCTUnwrap(MockJellyfinURLProtocol.capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/jellyfin/Users/AuthenticateByName")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization")?.contains("Client=\"BingeLog\"") == true)
        let body = try XCTUnwrap(MockJellyfinURLProtocol.capturedRequestBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(object["Username"], "niklas")
        XCTAssertEqual(object["Pw"], "test-password")
    }

    func testAuthenticateRejectsEmptyAuthenticationFields() async {
        let invalidResponses = [
            #"{"AccessToken":"","User":{"Id":"user-123","Name":"Niklas"}}"#,
            #"{"AccessToken":"token","User":{"Id":"   ","Name":"Niklas"}}"#,
            #"{"AccessToken":"token","User":{"Id":"user-123","Name":"  "}}"#
        ]

        for responseBody in invalidResponses {
            MockJellyfinURLProtocol.install { _ in (200, Data(responseBody.utf8)) }
            let service = JellyfinService(session: makeSession())

            do {
                _ = try await service.authenticate(
                    serverAddress: "https://media.example.com",
                    username: "niklas",
                    password: "test-password"
                )
                XCTFail("Expected an invalid-response error for: \\(responseBody)")
            } catch let error as JellyfinError {
                guard case .invalidResponse = error else {
                    return XCTFail("Unexpected Jellyfin error: \\(error)")
                }
            } catch {
                XCTFail("Unexpected error: \\(error)")
            }
        }
    }

    func testAuthenticateRejectsInvalidCredentialsFromServer() async {
        MockJellyfinURLProtocol.install { _ in (401, Data()) }
        let service = JellyfinService(session: makeSession())

        do {
            _ = try await service.authenticate(
                serverAddress: "https://media.example.com",
                username: "niklas",
                password: "wrong-password"
            )
            XCTFail("Expected an authentication error")
        } catch let error as JellyfinError {
            guard case .httpStatus(401) = error else {
                return XCTFail("Unexpected Jellyfin error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLibraryItemsThrowsForHTTPError() async {
        MockJellyfinURLProtocol.install { _ in (401, Data()) }
        let service = JellyfinService(session: makeSession())

        do {
            _ = try await service.libraryItems(
                server: "https://media.example.com",
                userID: "user-123",
                token: "bad-token"
            )
            XCTFail("Expected an HTTP status error")
        } catch let error as JellyfinError {
            guard case .httpStatus(401) = error else {
                return XCTFail("Unexpected Jellyfin error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockJellyfinURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockJellyfinURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) -> (Int, Data)

    private static let lock = NSLock()
    private static var storedHandler: Handler?
    private static var storedStartIndexes: [Int] = []
    private static var storedRequest: URLRequest?
    private static var storedRequestBody: Data?

    static var capturedRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return storedRequest
    }

    static var capturedRequestBody: Data? {
        lock.lock()
        defer { lock.unlock() }
        return storedRequestBody
    }

    static var capturedStartIndexes: [Int] {
        lock.lock()
        defer { lock.unlock() }
        return storedStartIndexes
    }

    static func install(handler: @escaping Handler) {
        lock.lock()
        storedHandler = handler
        storedStartIndexes = []
        storedRequest = nil
        storedRequestBody = nil
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        storedHandler = nil
        storedStartIndexes = []
        storedRequest = nil
        storedRequestBody = nil
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let bodyData = request.httpBody ?? Self.readBody(request.httpBodyStream)
        Self.lock.lock()
        let handler = Self.storedHandler
        Self.storedRequest = request
        Self.storedRequestBody = bodyData
        if let value = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "StartIndex" })?.value.flatMap(Int.init) {
            Self.storedStartIndexes.append(value)
        }
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let (status, data) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static func readBody(_ stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data.isEmpty ? nil : data
    }

    override func stopLoading() {}
}
