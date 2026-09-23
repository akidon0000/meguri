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

    /// ライト/ダークモードで異なる16進カラーを切り替える
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traitCollection in
            let hex = traitCollection.userInterfaceStyle == .dark ? dark : light
            let c = HexColor.components(hex)
            return UIColor(red: c.red, green: c.green, blue: c.blue, alpha: 1)
        })
    }

    /// 全画面のベース背景
    static let meguriBackground = Color(light: 0xF7F5F0, dark: 0x171613)
    /// カード・タブバー・セグメントコントロールのサーフェス
    static let meguriSurface = Color(light: 0xFFFFFF, dark: 0x221F1A)
    /// サーフェスの枠線
    static let meguriBorder = Color(light: 0xE3DFD3, dark: 0x37332B)
    /// タイトル・本文
    static let meguriInk = Color(light: 0x1F1D19, dark: 0xF2EFE8)
    /// 場所名・キャプション・日付
    static let meguriSecondaryText = Color(light: 0x6B6862, dark: 0xA6A199)
    /// 選択状態・タブのアクティブ表示・地図のピン（唯一のアクセントカラー、瑠璃色）
    static let meguriAccent = Color(light: 0x1C5FC4, dark: 0x4F8FE8)
}
