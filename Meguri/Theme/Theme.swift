import SwiftUI

enum HexColor {
    static func components(_ hex: UInt32) -> (red: Double, green: Double, blue: Double) {
        (
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Color {
    init(hex: UInt32) {
        let c = HexColor.components(hex)
        self.init(red: c.red, green: c.green, blue: c.blue)
    }

    /// 全画面のベース背景
    static let meguriBackground = Color(hex: 0xFAF8F3)
    /// カード・タブバー・セグメントコントロールのサーフェス
    static let meguriSurface = Color(hex: 0xFFFFFF)
    /// サーフェスの枠線
    static let meguriBorder = Color(hex: 0xEDE8DC)
    /// タイトル・本文
    static let meguriInk = Color(hex: 0x33302A)
    /// 場所名・キャプション・日付
    static let meguriSecondaryText = Color(hex: 0x8A9A8E)
    /// 選択状態・タブのアクティブ表示
    static let meguriSage = Color(hex: 0x6B8F71)
    /// ハイライト・地図のピン
    static let meguriTerracotta = Color(hex: 0xC98A5E)
}
