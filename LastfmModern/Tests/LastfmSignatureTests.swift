import XCTest
@testable import LastfmModern

final class LastfmSignatureTests: XCTestCase {
    func testSignatureIsStableAndSorted() {
        let params = [
            "username": "user",
            "method": "auth.getMobileSession",
            "password": "pass",
            "api_key": "KEY"
        ]

        let signature = LastfmSignature.make(params: params, sharedSecret: "SECRET")
        XCTAssertEqual(signature, "49c7a0a556c0bef5db6f4155a2b15685")
    }
}
