import Foundation
import Testing

@testable import Meguri

@Suite struct TaskTimeoutTests {
    @Test func returnsOperationResultWhenFasterThanTimeout() async {
        let result = await withTimeout(.seconds(1)) { "fast" }
        #expect(result == "fast")
    }

    @Test func returnsNilWhenOperationExceedsTimeout() async {
        let result = await withTimeout(.milliseconds(20)) {
            try? await Task.sleep(for: .seconds(5))
            return "slow"
        }
        #expect(result == nil)
    }

    @Test func returnsNilWhenOperationItselfReturnsNil() async {
        let result: String? = await withTimeout(.seconds(1)) { nil }
        #expect(result == nil)
    }
}
