import XCTest
@testable import LastfmModern

final class LastfmAPIErrorTests: XCTestCase {
    func testInvalidSessionHasReauthHint() {
        let error = LastfmAPIError.invalidSession
        XCTAssertEqual(error.recoverySuggestion, "Sign in again to refresh your Last.fm session.")
    }

    func testNetworkUnavailableMentionsAutoRetry() {
        let error = LastfmAPIError.networkUnavailable
        XCTAssertTrue(error.recoverySuggestion.contains("retry automatically"))
    }
}
