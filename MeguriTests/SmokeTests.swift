import Testing

@Suite struct SmokeTests {
    @Test func truthy() {
        #expect(true)
    }
}
