@testable import MoyeoTrip
import XCTest

final class CachedRemoteImageTests: XCTestCase {
    func testCacheKeyUsesDecodedFileName() throws {
        let url = try XCTUnwrap(URL(string: "https://cdn.example.com/profile/%EC%97%AC%ED%96%89%20%EC%B9%9C%EA%B5%AC.png?version=2"))

        XCTAssertEqual(MoyeoImageRepository.cacheKey(for: url), "여행_친구.png")
        XCTAssertEqual(MoyeoImageRepository.maximumAttempts, 3)
    }
}
