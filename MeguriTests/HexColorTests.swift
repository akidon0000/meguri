import Testing

@testable import Meguri

@Suite struct HexColorTests {
    @Test func convertsWhite() {
        let c = HexColor.components(0xFFFFFF)
        #expect(c.red == 1.0)
        #expect(c.green == 1.0)
        #expect(c.blue == 1.0)
    }

    @Test func convertsBlack() {
        let c = HexColor.components(0x000000)
        #expect(c.red == 0)
        #expect(c.green == 0)
        #expect(c.blue == 0)
    }

    @Test func convertsKnownBackgroundToken() {
        let c = HexColor.components(0xFAF8F3)
        #expect(c.red == Double(0xFA) / 255)
        #expect(c.green == Double(0xF8) / 255)
        #expect(c.blue == Double(0xF3) / 255)
    }
}
