import XCTest
@testable import BingeLog

final class MDBListDecodingTests: XCTestCase {
    func testDecodesNestedTMDBProviderID() throws {
        let item = try decodeItem("""
        {
          "id": 10,
          "ids": { "tmdb": 12345 },
          "mediatype": "movie",
          "title": "Example Film"
        }
        """)

        XCTAssertEqual(item.tmdbID, 12345)
        XCTAssertEqual(item.importMediaType, "movie")
        XCTAssertEqual(item.title, "Example Film")
    }

    func testDecodesFlatTMDBIDAsIntegerOrString() throws {
        let integerID = try decodeItem("""
        { "id": 11, "tmdbid": 67890, "mediatype": "show", "title": "Series A" }
        """)
        let stringID = try decodeItem("""
        { "id": 12, "tmdbid": "24680", "mediatype": "tv", "title": "Series B" }
        """)

        XCTAssertEqual(integerID.tmdbID, 67890)
        XCTAssertEqual(stringID.tmdbID, 24680)
    }

    func testNormalizesSupportedMediaTypes() throws {
        let cases: [(String, String)] = [
            ("movie", "movie"),
            ("MOVIES", "movie"),
            ("show", "show"),
            ("tv", "show"),
            ("series", "show")
        ]

        for (input, expected) in cases {
            let item = try decodeItem("""
            { "id": 1, "tmdbid": 99, "mediatype": "\(input)", "title": "Title" }
            """)
            XCTAssertEqual(item.importMediaType, expected, "Input: \(input)")
        }
    }

    func testRejectsUnknownOrMissingMediaType() throws {
        let unknown = try decodeItem("""
        { "id": 1, "tmdbid": 99, "mediatype": "person", "title": "Unknown" }
        """)
        let missing = try decodeItem("""
        { "id": 2, "tmdbid": 100, "title": "Missing type" }
        """)

        XCTAssertNil(unknown.importMediaType)
        XCTAssertNil(missing.importMediaType)
    }

    func testSupportsTitleAndNameFallbacksAndYearFormats() throws {
        let title = try decodeItem("""
        {
          "id": 1, "tmdbid": 10, "mediatype": "movie",
          "title": "Preferred title", "name": "Fallback name",
          "release_year": 2024
        }
        """)
        let name = try decodeItem("""
        {
          "id": 2, "tmdbid": 11, "mediatype": "show",
          "name": "Name fallback", "year": "2022"
        }
        """)

        XCTAssertEqual(title.title, "Preferred title")
        XCTAssertEqual(title.year, 2024)
        XCTAssertEqual(name.title, "Name fallback")
        XCTAssertEqual(name.year, 2022)
    }

    func testMissingOrMalformedTMDBIDRemainsNil() throws {
        let missing = try decodeItem("""
        { "id": 1, "mediatype": "movie", "title": "No provider ID" }
        """)
        let malformed = try decodeItem("""
        { "id": 2, "tmdbid": "not-a-number", "mediatype": "movie", "title": "Bad ID" }
        """)

        XCTAssertNil(missing.tmdbID)
        XCTAssertNil(malformed.tmdbID)
    }

    func testItemsResponseCombinesMoviesAndShows() throws {
        let json = """
        {
          "movies": [
            { "id": 1, "tmdbid": 101, "mediatype": "movie", "title": "Film" }
          ],
          "shows": [
            { "id": 2, "tmdbid": 202, "mediatype": "show", "title": "Series" }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(MDBListItemsResponse.self, from: json)

        XCTAssertEqual(response.allItems.count, 2)
        XCTAssertEqual(response.allItems.compactMap(\.tmdbID), [101, 202])
    }

    private func decodeItem(_ json: String) throws -> MDBListItem {
        try JSONDecoder().decode(MDBListItem.self, from: Data(json.utf8))
    }
}
