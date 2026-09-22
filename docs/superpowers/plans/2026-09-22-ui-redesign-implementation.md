# UI/UX 再設計（集める図鑑）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Meguri（Megumemo）を「集める図鑑」コンセプトで再設計する。ホーム／図鑑の2タブ構成、種別（AI自動分類）・旅・場所・地図の4つの軸で振り返れる図鑑タブ、グラデーション無しのフラットな水彩ポストカード配色を実装する。

**Architecture:** 既存の3画面（一覧・詳細・撮影中）はレイアウトを変えず再配色し、新規に「図鑑」タブを追加する。旅・場所・種別のグルーピングは`Entry`配列を受け取る非永続の純粋関数として実装し、`CompendiumView`のセグメントコントロールから呼び出す。視覚トークンは`Color`拡張の静的定数に集約し、全画面から参照する。

**Tech Stack:** SwiftUI, SwiftData, MapKit, Swift Testing, Foundation Models (`@Generable`/`@Guide`)

**Spec:** [docs/superpowers/specs/2026-09-22-ui-redesign-design.md](../specs/2026-09-22-ui-redesign-design.md)

## Global Constraints

- Xcode 27.2 以降必須。プロジェクトは `Meguri.xcodeproj/project.xcproj`（JSON5形式）。XcodeGenは使わない
- ファイル追加は `xcrun xcodeproj group add-file` → `xcrun xcodeproj group include ... --phase 1` の2段階（詳細は各タスク内に記載）
- 新規`SwiftData`モデルは追加しない。`Entry`スキーマは変更しない
- `Insight.category`は既存フィールドを7種のタクソノミーに拡張する（新規フィールド追加ではない）
- ビジュアルトークンはspecの表の16進値をそのまま使う。グラデーション・光彩・ぼかしは使わない
- タブは「ホーム」「図鑑」の2つ。各タブが独立した`NavigationStack`を持つ
- 旅のグルーピングしきい値は2日（`newTripGapDays = 2`、間隔がこれを**超えたら**新しい旅に区切る＝ちょうど2日は同じ旅）
- 場所のグルーピングは`Entry.placeName`の文字列をそのままキーに使う。正規化はしない
- 地図は緯度経度を持つ`Entry`のみピン表示。塗り分けはしない
- Swift Testingで`@MainActor`と`ModelContainer.mainContext`を同時に使うとXcode 27 betaでデッドロックする。テストは`ModelContext(container)`を明示的に生成して使う（既存の`EntryTests.swift`と同じパターン）
- ソース言語は英語（`Meguri/Resources/Localizable.xcstrings`の`sourceLanguage: "en"`）。新しいUI文言はすべて英語のソース文字列＋`ja`の`translated`エントリをこのファイルに追加する（既存キー`Architecture`/`Artwork`/`Other`と同じJSON形状）

## Review Focus

- 旧タクソノミー（`landscape`など、現行7種に存在しない生の値）で保存済みの`Insight`が、種別変更後もタイトル・要約ごと消えずに読み込めること（Task 1のデコードテストで担保。表示側はTask 15で目視確認）
- `insight`が`nil`のエントリ（解析失敗・Apple Intelligence無効）がHomeグリッドでバッジ無しのまま安全に表示され、図鑑の種別ビューでは「未分類」に入ること（Task 4・Task 10でそれぞれ担保）
- `placeName`が`nil`または空文字のエントリが場所ビューでクラッシュせず、単一の「不明な場所」グループにまとまること（Task 9で担保）
- 同じしきい値内に大量のエントリがある旅（例: 1週間毎日美術館巡り）が1つの旅としてまとまり、代表地名が破綻しないこと（Task 8の境界値・複数地名テストで担保）
- ホーム⇄図鑑のタブ切り替え時、各タブの`NavigationStack`（詳細画面への遷移状態）が独立に保たれること（このアプリ初のTabViewなので自動と決め付けず、Task 15でシミュレータ実機確認する）

---

## Task 1: 種別タクソノミーの拡張とデコード互換性

**Files:**
- Modify: `Meguri/Models/Insight.swift`
- Test: `MeguriTests/InsightTests.swift`

**Interfaces:**
- Produces: `Insight.Category`（7ケース: `artwork, sculpture, architecture, nature, creature, streetscape, other`）。未知の生値は`.other`にフォールバックするカスタム`init(from:)`

- [ ] **Step 1: 失敗するテストを書く**

`MeguriTests/InsightTests.swift` を以下に置き換える:

```swift
import Foundation
import Testing

@testable import Meguri

@Suite struct InsightTests {
    @Test func roundTripsThroughJSON() throws {
        let original = Insight(
            title: "睡蓮",
            creator: "クロード・モネ",
            era: "1906年頃",
            summary: "ジヴェルニーの庭の池を描いた連作の一枚。",
            funFacts: ["連作は250点以上ある"],
            category: .artwork
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Insight.self, from: data)
        #expect(decoded == original)
    }

    @Test func decodesAllSevenCategories() throws {
        for category in Insight.Category.allCases {
            let insight = Insight(
                title: "t", creator: "", era: "", summary: "s", funFacts: [], category: category)
            let data = try JSONEncoder().encode(insight)
            let decoded = try JSONDecoder().decode(Insight.self, from: data)
            #expect(decoded.category == category)
        }
    }

    @Test func fallsBackToOtherForUnrecognizedCategoryRawValue() throws {
        let json = """
            {"title":"t","creator":"","era":"","summary":"s","funFacts":[],"category":"landscape"}
            """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Insight.self, from: json)
        #expect(decoded.category == .other)
        #expect(decoded.title == "t")
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/InsightTests`
Expected: FAIL（`decodesAllSevenCategories`は`.sculpture`等が存在せずコンパイルエラー、`fallsBackToOtherForUnrecognizedCategoryRawValue`は`DecodingError`で失敗）

- [ ] **Step 3: 最小限の実装を書く**

`Meguri/Models/Insight.swift` の `Category` enum と `category` プロパティを置き換える:

```swift
import Foundation
import FoundationModels

@Generable
struct Insight: Codable, Sendable, Equatable {
    @Generable
    enum Category: String, Codable, CaseIterable, Sendable {
        case artwork, sculpture, architecture, nature, creature, streetscape, other

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Category(rawValue: raw) ?? .other
        }
    }

    @Guide(
        description:
            "Name of the artwork or place. If unknown, a short descriptive title of what is seen.")
    var title: String

    @Guide(description: "Artist, architect, or origin. Empty string if unknown.")
    var creator: String

    @Guide(description: "Year, period, or era of creation. Empty string if unknown.")
    var era: String

    @Guide(
        description:
            "Two to three sentences explaining what it is and its background. Hedge uncertain claims."
    )
    var summary: String

    @Guide(description: "Interesting facts. At most three.", .maximumCount(3))
    var funFacts: [String]

    @Guide(
        description:
            "One of: artwork, sculpture, architecture, nature, creature, streetscape, other.")
    var category: Category
}
```

- [ ] **Step 4: テストが通ることを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/InsightTests`
Expected: PASS（3件とも）

- [ ] **Step 5: コミット**

```bash
git add Meguri/Models/Insight.swift MeguriTests/InsightTests.swift
git commit -m "$(cat <<'EOF'
種別タクソノミーを7種に拡張し、未知の値をotherにフォールバック

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: ビジュアルトークン（Theme.swift）

**Files:**
- Create: `Meguri/Theme/Theme.swift`
- Test: `MeguriTests/HexColorTests.swift`

**Interfaces:**
- Produces: `HexColor.components(_:) -> (red: Double, green: Double, blue: Double)`、`Color.meguriBackground/meguriSurface/meguriBorder/meguriInk/meguriSecondaryText/meguriSage/meguriTerracotta`

- [ ] **Step 1: 失敗するテストを書く**

`MeguriTests/HexColorTests.swift` を新規作成:

```swift
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
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/HexColorTests`
Expected: FAIL（`HexColor`が存在せずコンパイルエラー）

- [ ] **Step 3: グループを作成しファイルを追加する**

```bash
xcrun xcodeproj group add Theme --parent /Meguri
```

`Meguri/Theme/Theme.swift` を新規作成:

```swift
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
```

```bash
xcrun xcodeproj group add-file Theme.swift --group /Meguri/Theme
xcrun xcodeproj group include Theme.swift --group /Meguri/Theme --target Meguri --phase 1
```

- [ ] **Step 4: テストが通ることを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/HexColorTests`
Expected: PASS

- [ ] **Step 5: コミット**

```bash
git add Meguri/Theme/Theme.swift MeguriTests/HexColorTests.swift Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
ビジュアルトークン（フラット水彩ポストカード配色）を追加

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 種別バッジ共有コンポーネント（CategoryBadge）

**Files:**
- Create: `Meguri/Features/Shared/CategoryBadge.swift`
- Test: `MeguriTests/CategoryDisplayTests.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `Insight.Category`（Task 1）、`Color.meguriSurface/meguriBorder/meguriInk`（Task 2）
- Produces: `Insight.Category.displayName: String`、`Insight.Category.systemImageName: String`、`CategoryBadge(category:compact:)`

- [ ] **Step 1: 失敗するテストを書く**

`MeguriTests/CategoryDisplayTests.swift` を新規作成:

```swift
import Testing

@testable import Meguri

@Suite struct CategoryDisplayTests {
    @Test func everyCategoryHasNonEmptyDisplayName() {
        for category in Insight.Category.allCases {
            #expect(!category.displayName.isEmpty)
        }
    }

    @Test func everyCategoryHasNonEmptySystemImageName() {
        for category in Insight.Category.allCases {
            #expect(!category.systemImageName.isEmpty)
        }
    }

    @Test func categoriesHaveDistinctSystemImages() {
        let names = Insight.Category.allCases.map(\.systemImageName)
        #expect(Set(names).count == names.count)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/CategoryDisplayTests`
Expected: FAIL（`displayName`/`systemImageName`が存在せずコンパイルエラー）

- [ ] **Step 3: グループを作成しファイルを追加する**

```bash
xcrun xcodeproj group add Shared --parent /Meguri/Features
```

`Meguri/Features/Shared/CategoryBadge.swift` を新規作成:

```swift
import SwiftUI

extension Insight.Category {
    var displayName: String {
        switch self {
        case .artwork: String(localized: "Artwork")
        case .sculpture: String(localized: "Sculpture")
        case .architecture: String(localized: "Architecture")
        case .nature: String(localized: "Nature")
        case .creature: String(localized: "Creature")
        case .streetscape: String(localized: "Streetscape")
        case .other: String(localized: "Other")
        }
    }

    var systemImageName: String {
        switch self {
        case .artwork: "paintpalette.fill"
        case .sculpture: "cube.fill"
        case .architecture: "building.columns.fill"
        case .nature: "leaf.fill"
        case .creature: "pawprint.fill"
        case .streetscape: "signpost.right.fill"
        case .other: "questionmark.circle.fill"
        }
    }
}

struct CategoryBadge: View {
    let category: Insight.Category
    var compact: Bool = false

    var body: some View {
        Group {
            if compact {
                Image(systemName: category.systemImageName)
                    .font(.caption2.weight(.semibold))
                    .padding(6)
                    .background(Color.meguriSurface, in: Circle())
                    .overlay(Circle().stroke(Color.meguriBorder, lineWidth: 1))
            } else {
                Label(category.displayName, systemImage: category.systemImageName)
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.meguriSurface, in: Capsule())
                    .overlay(Capsule().stroke(Color.meguriBorder, lineWidth: 1))
            }
        }
        .foregroundStyle(Color.meguriInk)
        .accessibilityLabel(category.displayName)
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(Insight.Category.allCases, id: \.self) { category in
            CategoryBadge(category: category)
        }
    }
    .padding()
    .background(Color.meguriBackground)
}
```

```bash
xcrun xcodeproj group add-file CategoryBadge.swift --group /Meguri/Features/Shared
xcrun xcodeproj group include CategoryBadge.swift --group /Meguri/Features/Shared --target Meguri --phase 1
```

- [ ] **Step 4: 新しい表示文言をLocalizable.xcstringsに追加する**

```bash
python3 - <<'EOF'
import json

path = "Meguri/Resources/Localizable.xcstrings"
with open(path) as f:
    data = json.load(f)

new_entries = {
    "Sculpture": "彫刻",
    "Nature": "自然",
    "Creature": "生き物",
    "Streetscape": "街並み",
}
for en, ja in new_entries.items():
    data["strings"][en] = {
        "localizations": {"ja": {"stringUnit": {"state": "translated", "value": ja}}}
    }

data["strings"] = dict(sorted(data["strings"].items()))

with open(path, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
EOF
```

- [ ] **Step 5: テストが通ることを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/CategoryDisplayTests`
Expected: PASS

- [ ] **Step 6: コミット**

```bash
git add Meguri/Features/Shared/CategoryBadge.swift MeguriTests/CategoryDisplayTests.swift \
  Meguri/Resources/Localizable.xcstrings Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
種別バッジの共有コンポーネントを追加

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: ホーム画面の再配色（EntryCard・CollectionView）

**Files:**
- Modify: `Meguri/Features/Collection/EntryCard.swift`
- Modify: `Meguri/Features/Collection/CollectionView.swift`

**Interfaces:**
- Consumes: `Color.meguri*`（Task 2）、`CategoryBadge`（Task 3）

このタスクは既存のSwiftUI View層の変更であり、プロジェクトの既存方針（`docs/handbook/build-and-test.md`のテスト方針: 配色・レイアウトはPreview／シミュレータで確認）に従い、単体テストではなくビルド＋シミュレータ確認で検証する。

- [ ] **Step 1: EntryCardを再配色し種別バッジを重ねる**

`Meguri/Features/Collection/EntryCard.swift` を以下に置き換える:

```swift
import SwiftUI

struct EntryCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnail
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(4)
                .background(Color.meguriSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.meguriBorder, lineWidth: 1)
                )
                .overlay(alignment: .bottomTrailing) {
                    if let category = entry.insight?.category {
                        CategoryBadge(category: category, compact: true)
                            .padding(6)
                    }
                }

            Text(entry.insight?.title ?? String(localized: "Untitled"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.meguriInk)
                .lineLimit(2)

            Text(entry.placeName ?? entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(Color.meguriSecondaryText)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = UIImage(data: entry.thumbnailData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityHidden(true)
        } else {
            Color.secondary.opacity(0.2)
        }
    }
}

#Preview {
    EntryCard(entry: Entry(imageFileName: "x.jpg", thumbnailData: Data()))
        .padding()
        .background(Color.meguriBackground)
}
```

- [ ] **Step 2: CollectionViewの背景をmeguriBackgroundにする**

`Meguri/Features/Collection/CollectionView.swift` の `body` 冒頭（`NavigationStack {` の中の `Group { ... }`）の直後に `.background(...)` を追加する。`.navigationTitle("Megumemo")` の直前の行を次のように変更する:

```swift
            .background(Color.meguriBackground)
            .navigationTitle("Megumemo")
```

（`Group { if entries.isEmpty { emptyState } else { grid } }` の閉じ括弧の直後、`.navigationTitle` の直前に1行追加するだけで、他の行は変更しない）

- [ ] **Step 3: ビルドしてシミュレータで確認する**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED

シミュレータでアプリを起動し、Homeグリッドの背景がベージュ（`#FAF8F3`）になっていること、写真に白い縁取りがあること、`insight`があるエントリの右下に種別アイコンバッジが乗っていることを`mcp__Claude_Code_iOS_Simulator__control`の`screenshot`で確認する。

- [ ] **Step 4: 全テストを実行し既存テストが壊れていないことを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: 全件PASS

- [ ] **Step 5: コミット**

```bash
git add Meguri/Features/Collection/EntryCard.swift Meguri/Features/Collection/CollectionView.swift
git commit -m "$(cat <<'EOF'
ホーム画面をフラット水彩トークンで再配色し種別バッジを追加

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 詳細画面の再配色（EntryDetailView）

**Files:**
- Modify: `Meguri/Features/Detail/EntryDetailView.swift`

**Interfaces:**
- Consumes: `Color.meguri*`（Task 2）、`CategoryBadge`（Task 3）

- [ ] **Step 1: insightCard/unavailableCardの配色とバッジを置き換える**

`Meguri/Features/Detail/EntryDetailView.swift` を以下のように変更する。

`insightCard(_:)` 内、旧来のカプセル表示ブロックを置き換える:

```swift
// 旧
            Text(categoryLabel(insight.category))
                .font(.caption.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.tint.opacity(0.15), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            .background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
```

```swift
// 新
            CategoryBadge(category: insight.category)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.meguriSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.meguriBorder, lineWidth: 1)
        )
    }
```

`insightCard(_:)` 内のタイトル・本文の文字色を追加する:

```swift
// 旧
            Text(insight.title)
                .font(.title2.weight(.bold))
```

```swift
// 新
            Text(insight.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.meguriInk)
```

`byline`の文字色:

```swift
// 旧
                Text(byline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
```

```swift
// 新
                Text(byline)
                    .font(.subheadline)
                    .foregroundStyle(Color.meguriSecondaryText)
```

`summary`の文字色:

```swift
// 旧
            Text(insight.summary)
                .font(.body)
```

```swift
// 新
            Text(insight.summary)
                .font(.body)
                .foregroundStyle(Color.meguriInk)
```

`unavailableCard`の背景も同様に置き換える:

```swift
// 旧
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            .background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var metadata: some View {
```

```swift
// 新
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.meguriSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.meguriBorder, lineWidth: 1)
        )
    }

    private var metadata: some View {
```

`body`の`ScrollView`に背景を追加する:

```swift
// 旧
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
```

```swift
// 新
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
```

（`ScrollView`自体は変更なし。`.navigationTitle(...)` の直前、`.navigationBarTitleDisplayMode(.inline)` の後ろに `.background(Color.meguriBackground)` を追加する）

```swift
// 旧
        .navigationTitle(entry.insight?.title ?? String(localized: "Untitled"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
```

```swift
// 新
        .navigationTitle(entry.insight?.title ?? String(localized: "Untitled"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.meguriBackground)
        .toolbar {
```

最後に、置き換えで不要になった`categoryLabel`メソッドを削除する:

```swift
// 削除する
    private func categoryLabel(_ category: Insight.Category) -> String {
        switch category {
        case .artwork: String(localized: "Artwork")
        case .landscape: String(localized: "Landscape")
        case .architecture: String(localized: "Architecture")
        case .other: String(localized: "Other")
        }
    }

```

- [ ] **Step 2: ビルドしてシミュレータで確認する**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED（`categoryLabel`削除後も他に参照箇所が無いこと。`grep -rn "categoryLabel" Meguri/` で確認する）

既存エントリの詳細画面を開き、カードが白いサーフェス＋枠線になっていること、カテゴリバッジがラベル付きで表示されることをスクリーンショットで確認する。

- [ ] **Step 3: 全テストを実行する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: 全件PASS

- [ ] **Step 4: コミット**

```bash
git add Meguri/Features/Detail/EntryDetailView.swift
git commit -m "$(cat <<'EOF'
詳細画面をフラット水彩トークンで再配色し種別バッジを共有コンポーネントに統一

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: 撮影中画面の再配色（AnalyzingView）

**Files:**
- Modify: `Meguri/Features/Capture/AnalyzingView.swift`

**Interfaces:**
- Consumes: `Color.meguriBackground`（Task 2）

- [ ] **Step 1: 背景トークンを置き換える**

```swift
// 旧
                .background(Color(.systemBackground))
```

```swift
// 新
                .background(Color.meguriBackground)
```

- [ ] **Step 2: ビルドしてシミュレータで確認する**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED

シミュレータでは`FoundationModelsInsightGenerator`が使えない（`docs/handbook/build-and-test.md`の既知の制限）ため、AI生成そのものは確認できない。`.idle`/`.perceiving`表示中の背景色と、SwiftUI Previewでの`.failed`状態の背景色が`meguriBackground`になっていることを確認する。

- [ ] **Step 3: コミット**

```bash
git add Meguri/Features/Capture/AnalyzingView.swift
git commit -m "$(cat <<'EOF'
撮影中画面の背景をフラット水彩トークンに合わせる

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: 旅（Trip）モデルとグルーピング

**Files:**
- Create: `Meguri/Features/Compendium/Trip.swift`
- Test: `MeguriTests/TripGroupingTests.swift`

**Interfaces:**
- Consumes: `Entry`（`createdAt`, `placeName`）
- Produces: `Trip { id: Date, name: String?, dateRange: ClosedRange<Date>, entries: [Entry], displayTitle: String }`、`TripGrouping.makeTrips(from:locale:) -> [Trip]`、`TripGrouping.newTripGapDays: Int`

- [ ] **Step 1: 失敗するテストを書く**

`MeguriTests/TripGroupingTests.swift` を新規作成:

```swift
import Foundation
import Testing

@testable import Meguri

@Suite struct TripGroupingTests {
    private func makeEntry(daysFromReference days: Double, place: String? = nil) -> Entry {
        let reference = Date(timeIntervalSince1970: 1_700_000_000)
        return Entry(
            imageFileName: "\(days).jpg", thumbnailData: Data(),
            createdAt: reference.addingTimeInterval(days * 24 * 60 * 60),
            placeName: place)
    }

    @Test func emptyInputProducesNoTrips() {
        #expect(TripGrouping.makeTrips(from: []).isEmpty)
    }

    @Test func singleEntryGroupHasNoName() {
        let trips = TripGrouping.makeTrips(from: [makeEntry(daysFromReference: 0)])
        #expect(trips.count == 1)
        #expect(trips[0].name == nil)
        #expect(!trips[0].displayTitle.isEmpty)
    }

    @Test func entriesWithinThresholdMergeIntoOneTrip() {
        let entries = [
            makeEntry(daysFromReference: 0, place: "パリ"),
            makeEntry(daysFromReference: 1, place: "パリ"),
            makeEntry(daysFromReference: 1.5, place: "パリ"),
        ]
        let trips = TripGrouping.makeTrips(from: entries, locale: Locale(identifier: "ja_JP"))
        #expect(trips.count == 1)
        #expect(trips[0].entries.count == 3)
        #expect(trips[0].name?.contains("パリ") == true)
    }

    @Test func gapBeyondThresholdSplitsIntoSeparateTrips() {
        let entries = [
            makeEntry(daysFromReference: 0),
            makeEntry(daysFromReference: 1),
            makeEntry(daysFromReference: 5),
            makeEntry(daysFromReference: 5.5),
        ]
        let trips = TripGrouping.makeTrips(from: entries)
        #expect(trips.count == 2)
    }

    @Test func gapExactlyAtThresholdStaysInSameTrip() {
        let entries = [
            makeEntry(daysFromReference: 0),
            makeEntry(daysFromReference: Double(TripGrouping.newTripGapDays)),
        ]
        let trips = TripGrouping.makeTrips(from: entries)
        #expect(trips.count == 1)
    }

    @Test func newestTripIsFirstAndEntriesWithinATripAreNewestFirst() {
        let entries = [
            makeEntry(daysFromReference: 0),
            makeEntry(daysFromReference: 0.5),
            makeEntry(daysFromReference: 10),
        ]
        let trips = TripGrouping.makeTrips(from: entries)
        #expect(trips.count == 2)
        #expect(trips[0].entries.first?.imageFileName == "10.0.jpg")
        #expect(trips[1].entries.map(\.imageFileName) == ["0.5.jpg", "0.0.jpg"])
    }

    @Test func representativePlaceBreaksTiesByFirstAppearance() {
        let entries = [
            makeEntry(daysFromReference: 0, place: "浅草寺"),
            makeEntry(daysFromReference: 0.2, place: "オランジュリー美術館"),
        ]
        let trips = TripGrouping.makeTrips(from: entries, locale: Locale(identifier: "ja_JP"))
        #expect(trips[0].name?.contains("浅草寺") == true)
    }

    @Test func generatesEnglishNameForNonJapaneseLocale() {
        let entries = [
            makeEntry(daysFromReference: 0, place: "Louvre"),
            makeEntry(daysFromReference: 0.5, place: "Louvre"),
        ]
        let trips = TripGrouping.makeTrips(from: entries, locale: Locale(identifier: "en_US"))
        #expect(trips[0].name?.contains("Louvre") == true)
        #expect(trips[0].name?.contains("Trip") == true)
    }

    @Test func multiEntryTripWithoutAnyPlaceNameStillGetsAName() {
        let entries = [
            makeEntry(daysFromReference: 0, place: nil),
            makeEntry(daysFromReference: 0.5, place: nil),
        ]
        let trips = TripGrouping.makeTrips(from: entries, locale: Locale(identifier: "ja_JP"))
        #expect(trips[0].name != nil)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/TripGroupingTests`
Expected: FAIL（`Trip`/`TripGrouping`が存在せずコンパイルエラー）

- [ ] **Step 3: グループを作成し実装する**

```bash
xcrun xcodeproj group add Compendium --parent /Meguri/Features
```

`Meguri/Features/Compendium/Trip.swift` を新規作成:

```swift
import Foundation

struct Trip: Identifiable {
    var id: Date { dateRange.lowerBound }
    var name: String?
    var dateRange: ClosedRange<Date>
    var entries: [Entry]

    var displayTitle: String {
        if let name { return name }
        return Trip.singleDateFormatter.string(from: dateRange.lowerBound)
    }

    private static let singleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

enum TripGrouping {
    static let newTripGapDays = 2

    static func makeTrips(from entries: [Entry], locale: Locale = .current) -> [Trip] {
        guard !entries.isEmpty else { return [] }
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        let thresholdSeconds = TimeInterval(newTripGapDays * 24 * 60 * 60)

        var groups: [[Entry]] = []
        var current: [Entry] = [sorted[0]]
        for entry in sorted.dropFirst() {
            if let last = current.last,
                entry.createdAt.timeIntervalSince(last.createdAt) > thresholdSeconds
            {
                groups.append(current)
                current = [entry]
            } else {
                current.append(entry)
            }
        }
        groups.append(current)

        return groups.reversed().map { group in
            Trip(
                name: group.count > 1 ? generatedName(for: group, locale: locale) : nil,
                dateRange: group.first!.createdAt...group.last!.createdAt,
                entries: group.reversed()
            )
        }
    }

    private static func generatedName(for group: [Entry], locale: Locale) -> String {
        let month = monthFormatter(for: locale).string(from: group.first!.createdAt)
        guard let place = representativePlace(in: group) else {
            return isJapanese(locale) ? "\(month)の旅" : "\(month) Trip"
        }
        return isJapanese(locale) ? "\(month)の\(place)旅行" : "\(place) Trip, \(month)"
    }

    private static func representativePlace(in group: [Entry]) -> String? {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for entry in group {
            guard let name = entry.placeName, !name.isEmpty else { continue }
            if counts[name] == nil { order.append(name) }
            counts[name, default: 0] += 1
        }
        guard var best = order.first else { return nil }
        var bestCount = counts[best] ?? 0
        for name in order.dropFirst() {
            let count = counts[name] ?? 0
            if count > bestCount {
                best = name
                bestCount = count
            }
        }
        return best
    }

    private static func isJapanese(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "ja"
    }

    private static func monthFormatter(for locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter
    }
}
```

```bash
xcrun xcodeproj group add-file Trip.swift --group /Meguri/Features/Compendium
xcrun xcodeproj group include Trip.swift --group /Meguri/Features/Compendium --target Meguri --phase 1
```

- [ ] **Step 4: テストが通ることを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/TripGroupingTests`
Expected: PASS（9件全て）

- [ ] **Step 5: コミット**

```bash
git add Meguri/Features/Compendium/Trip.swift MeguriTests/TripGroupingTests.swift Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
旅(Trip)の自動クラスタリングを実装（しきい値2日、非永続）

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: 場所（Place）グルーピング

**Files:**
- Create: `Meguri/Features/Compendium/PlaceGrouping.swift`
- Test: `MeguriTests/PlaceGroupingTests.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `Entry.placeName`
- Produces: `PlaceGroup { id: String, name: String, entries: [Entry] }`、`PlaceGrouping.makeGroups(from:) -> [PlaceGroup]`、`PlaceGrouping.unknownPlaceName: String`

- [ ] **Step 1: 失敗するテストを書く**

`MeguriTests/PlaceGroupingTests.swift` を新規作成:

```swift
import Foundation
import Testing

@testable import Meguri

@Suite struct PlaceGroupingTests {
    private func makeEntry(place: String?, order: Int) -> Entry {
        Entry(imageFileName: "\(order).jpg", thumbnailData: Data(), placeName: place)
    }

    @Test func emptyInputProducesNoGroups() {
        #expect(PlaceGrouping.makeGroups(from: []).isEmpty)
    }

    @Test func groupsEntriesBySamePlaceName() {
        let entries = [makeEntry(place: "浅草寺", order: 0), makeEntry(place: "浅草寺", order: 1)]
        let groups = PlaceGrouping.makeGroups(from: entries)
        #expect(groups.count == 1)
        #expect(groups[0].entries.count == 2)
    }

    @Test func entriesWithoutPlaceNameFallIntoUnknownGroup() {
        let entries = [makeEntry(place: nil, order: 0)]
        let groups = PlaceGrouping.makeGroups(from: entries)
        #expect(groups.count == 1)
        #expect(groups[0].name == PlaceGrouping.unknownPlaceName)
    }

    @Test func emptyPlaceNameAlsoFallsIntoUnknownGroup() {
        let entries = [makeEntry(place: "", order: 0)]
        let groups = PlaceGrouping.makeGroups(from: entries)
        #expect(groups.count == 1)
        #expect(groups[0].name == PlaceGrouping.unknownPlaceName)
    }

    @Test func preservesFirstAppearanceOrderAcrossDistinctPlaces() {
        let entries = [
            makeEntry(place: "浅草寺", order: 0),
            makeEntry(place: "オランジュリー美術館", order: 1),
            makeEntry(place: "浅草寺", order: 2),
        ]
        let groups = PlaceGrouping.makeGroups(from: entries)
        #expect(groups.map(\.name) == ["浅草寺", "オランジュリー美術館"])
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/PlaceGroupingTests`
Expected: FAIL（`PlaceGroup`/`PlaceGrouping`が存在せずコンパイルエラー）

- [ ] **Step 3: 実装する**

`Meguri/Features/Compendium/PlaceGrouping.swift` を新規作成:

```swift
import Foundation

struct PlaceGroup: Identifiable {
    var id: String { name }
    var name: String
    var entries: [Entry]
}

enum PlaceGrouping {
    static let unknownPlaceName = String(localized: "Unknown place")

    static func makeGroups(from entries: [Entry]) -> [PlaceGroup] {
        var order: [String] = []
        var buckets: [String: [Entry]] = [:]
        for entry in entries {
            let key = (entry.placeName?.isEmpty == false) ? entry.placeName! : unknownPlaceName
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(entry)
        }
        return order.map { PlaceGroup(name: $0, entries: buckets[$0] ?? []) }
    }
}
```

```bash
xcrun xcodeproj group add-file PlaceGrouping.swift --group /Meguri/Features/Compendium
xcrun xcodeproj group include PlaceGrouping.swift --group /Meguri/Features/Compendium --target Meguri --phase 1
```

- [ ] **Step 4: 「Unknown place」の文言をLocalizable.xcstringsに追加する**

```bash
python3 - <<'EOF'
import json

path = "Meguri/Resources/Localizable.xcstrings"
with open(path) as f:
    data = json.load(f)

data["strings"]["Unknown place"] = {
    "localizations": {"ja": {"stringUnit": {"state": "translated", "value": "不明な場所"}}}
}
data["strings"] = dict(sorted(data["strings"].items()))

with open(path, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
EOF
```

- [ ] **Step 5: テストが通ることを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/PlaceGroupingTests`
Expected: PASS（5件全て）

- [ ] **Step 6: コミット**

```bash
git add Meguri/Features/Compendium/PlaceGrouping.swift MeguriTests/PlaceGroupingTests.swift \
  Meguri/Resources/Localizable.xcstrings Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
場所(Place)グルーピングを実装し、不明な場所のフォールバックを追加

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: 種別（Category）グルーピング

**Files:**
- Create: `Meguri/Features/Compendium/CategoryGrouping.swift`
- Test: `MeguriTests/CategoryGroupingTests.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `Entry.insight?.category`（Task 1）、`Insight.Category.displayName`（Task 3）
- Produces: `CategoryGroup { id: String, category: Insight.Category?, entries: [Entry], displayTitle: String }`、`CategoryGrouping.makeGroups(from:) -> [CategoryGroup]`

- [ ] **Step 1: 失敗するテストを書く**

`MeguriTests/CategoryGroupingTests.swift` を新規作成:

```swift
import Foundation
import Testing

@testable import Meguri

@Suite struct CategoryGroupingTests {
    private func makeEntry(category: Insight.Category?, order: Int) -> Entry {
        let entry = Entry(imageFileName: "\(order).jpg", thumbnailData: Data())
        if let category {
            entry.insight = Insight(
                title: "t", creator: "", era: "", summary: "s", funFacts: [], category: category)
        }
        return entry
    }

    @Test func emptyInputProducesNoGroups() {
        #expect(CategoryGrouping.makeGroups(from: []).isEmpty)
    }

    @Test func groupsFollowFixedTaxonomyOrderRegardlessOfInputOrder() {
        let entries = [
            makeEntry(category: .other, order: 0),
            makeEntry(category: .artwork, order: 1),
        ]
        let groups = CategoryGrouping.makeGroups(from: entries)
        #expect(groups.map(\.category) == [.artwork, .other])
    }

    @Test func entriesWithoutInsightGoToUnclassifiedGroupAtTheEnd() {
        let entries = [
            makeEntry(category: .artwork, order: 0),
            makeEntry(category: nil, order: 1),
        ]
        let groups = CategoryGrouping.makeGroups(from: entries)
        #expect(groups.count == 2)
        #expect(groups.last?.category == nil)
        #expect(groups.last?.entries.count == 1)
        #expect(groups.last?.displayTitle == "Unclassified")
    }

    @Test func omitsEmptyCategoriesFromTaxonomy() {
        let entries = [makeEntry(category: .nature, order: 0)]
        let groups = CategoryGrouping.makeGroups(from: entries)
        #expect(groups.count == 1)
        #expect(groups[0].category == .nature)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/CategoryGroupingTests`
Expected: FAIL（`CategoryGroup`/`CategoryGrouping`が存在せずコンパイルエラー）

- [ ] **Step 3: 実装する**

`Meguri/Features/Compendium/CategoryGrouping.swift` を新規作成:

```swift
import Foundation

struct CategoryGroup: Identifiable {
    var id: String { category?.rawValue ?? "unclassified" }
    var category: Insight.Category?
    var entries: [Entry]

    var displayTitle: String {
        category?.displayName ?? String(localized: "Unclassified")
    }
}

enum CategoryGrouping {
    static func makeGroups(from entries: [Entry]) -> [CategoryGroup] {
        var buckets: [Insight.Category: [Entry]] = [:]
        var unclassified: [Entry] = []
        for entry in entries {
            if let category = entry.insight?.category {
                buckets[category, default: []].append(entry)
            } else {
                unclassified.append(entry)
            }
        }
        var groups = Insight.Category.allCases.compactMap { category -> CategoryGroup? in
            guard let bucket = buckets[category], !bucket.isEmpty else { return nil }
            return CategoryGroup(category: category, entries: bucket)
        }
        if !unclassified.isEmpty {
            groups.append(CategoryGroup(category: nil, entries: unclassified))
        }
        return groups
    }
}
```

```bash
xcrun xcodeproj group add-file CategoryGrouping.swift --group /Meguri/Features/Compendium
xcrun xcodeproj group include CategoryGrouping.swift --group /Meguri/Features/Compendium --target Meguri --phase 1
```

- [ ] **Step 4: 「Unclassified」の文言をLocalizable.xcstringsに追加する**

```bash
python3 - <<'EOF'
import json

path = "Meguri/Resources/Localizable.xcstrings"
with open(path) as f:
    data = json.load(f)

data["strings"]["Unclassified"] = {
    "localizations": {"ja": {"stringUnit": {"state": "translated", "value": "未分類"}}}
}
data["strings"] = dict(sorted(data["strings"].items()))

with open(path, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
EOF
```

- [ ] **Step 5: テストが通ることを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/CategoryGroupingTests`
Expected: PASS（4件全て）

- [ ] **Step 6: コミット**

```bash
git add Meguri/Features/Compendium/CategoryGrouping.swift MeguriTests/CategoryGroupingTests.swift \
  Meguri/Resources/Localizable.xcstrings Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
種別(Category)グルーピングを実装（固定タクソノミー順、未分類バケット付き）

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: 図鑑タブの共有リスト表示（EntryGroupSection・EntryGroupListView）

**Files:**
- Create: `Meguri/Features/Compendium/EntryGroupSection.swift`

**Interfaces:**
- Consumes: `EntryCard`（Task 4で再配色済み）、`Color.meguri*`（Task 2）
- Produces: `EntryGroupSection { id: String, title: String, entries: [Entry] }`、`EntryGroupListView(sections:)`

旅・場所・種別の3ビューは同じ「見出し＋ミニグリッド」の形なので、共通の表示構造体とビューに集約する（重複実装を避ける）。純粋なマッピングのみでロジックはTask 7〜9のテストで担保済みのため、単体テストは追加せずビルド確認のみとする。

- [ ] **Step 1: 実装する**

`Meguri/Features/Compendium/EntryGroupSection.swift` を新規作成:

```swift
import SwiftUI

struct EntryGroupSection: Identifiable {
    let id: String
    let title: String
    let entries: [Entry]
}

struct EntryGroupListView: View {
    let sections: [EntryGroupSection]

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.headline)
                            .foregroundStyle(Color.meguriInk)

                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(section.entries) { entry in
                                NavigationLink(value: entry) {
                                    EntryCard(entry: entry)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}
```

```bash
xcrun xcodeproj group add-file EntryGroupSection.swift --group /Meguri/Features/Compendium
xcrun xcodeproj group include EntryGroupSection.swift --group /Meguri/Features/Compendium --target Meguri --phase 1
```

- [ ] **Step 2: ビルドが通ることを確認する**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED（この時点では`EntryGroupListView`を呼び出す画面がまだ無いため、未使用の警告が出ても問題ない）

- [ ] **Step 3: コミット**

```bash
git add Meguri/Features/Compendium/EntryGroupSection.swift Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
図鑑タブ共通の見出し+ミニグリッド表示(EntryGroupListView)を追加

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: 地図ビュー（EntryMapView）

**Files:**
- Create: `Meguri/Features/Compendium/EntryMapView.swift`

**Interfaces:**
- Consumes: `Entry.latitude/longitude`、`Color.meguriTerracotta`（Task 2）
- Produces: `EntryMapView(entries:)`（`NavigationLink(value:)`で`Entry`を発行。呼び出し元のNavigationStackが`navigationDestination(for: Entry.self)`を持つ前提）

- [ ] **Step 1: 実装する**

`Meguri/Features/Compendium/EntryMapView.swift` を新規作成:

```swift
import MapKit
import SwiftUI

struct EntryMapView: View {
    let entries: [Entry]

    private var located: [Entry] {
        entries.filter { $0.latitude != nil && $0.longitude != nil }
    }

    var body: some View {
        Map {
            ForEach(located) { entry in
                Annotation(
                    entry.insight?.title ?? "",
                    coordinate: CLLocationCoordinate2D(
                        latitude: entry.latitude!, longitude: entry.longitude!)
                ) {
                    NavigationLink(value: entry) {
                        Circle()
                            .fill(Color.meguriTerracotta)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                    }
                }
            }
        }
    }
}
```

```bash
xcrun xcodeproj group add-file EntryMapView.swift --group /Meguri/Features/Compendium
xcrun xcodeproj group include EntryMapView.swift --group /Meguri/Features/Compendium --target Meguri --phase 1
```

- [ ] **Step 2: ビルドが通ることを確認する**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: コミット**

```bash
git add Meguri/Features/Compendium/EntryMapView.swift Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
地図ビュー(EntryMapView)を追加。位置情報を持つエントリのみピン表示

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: 図鑑タブ本体（CompendiumView）

**Files:**
- Create: `Meguri/Features/Compendium/CompendiumView.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `TripGrouping`（Task 7）、`PlaceGrouping`（Task 8）、`CategoryGrouping`（Task 9）、`EntryGroupListView`（Task 10）、`EntryMapView`（Task 11）、`EntryDetailView`（既存）
- Produces: `CompendiumView`（`@Query(Entry.newestFirst)`で独立にフェッチし、独自の`NavigationStack`を持つ）

- [ ] **Step 1: 実装する**

`Meguri/Features/Compendium/CompendiumView.swift` を新規作成:

```swift
import SwiftData
import SwiftUI

struct CompendiumView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case trips, places, categories, map
        var id: String { rawValue }

        var label: String {
            switch self {
            case .trips: String(localized: "Trips")
            case .places: String(localized: "Places")
            case .categories: String(localized: "Categories")
            case .map: String(localized: "Map")
            }
        }
    }

    @Query(Entry.newestFirst) private var entries: [Entry]
    @State private var mode: Mode = .trips

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                content
            }
            .background(Color.meguriBackground)
            .navigationTitle(String(localized: "Compendium"))
            .navigationDestination(for: Entry.self) { entry in
                EntryDetailView(entry: entry)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "Nothing collected yet"), systemImage: "books.vertical")
            }
        } else {
            switch mode {
            case .trips:
                EntryGroupListView(sections: tripSections)
            case .places:
                EntryGroupListView(sections: placeSections)
            case .categories:
                EntryGroupListView(sections: categorySections)
            case .map:
                EntryMapView(entries: entries)
            }
        }
    }

    private var tripSections: [EntryGroupSection] {
        TripGrouping.makeTrips(from: entries).map {
            EntryGroupSection(id: $0.id.description, title: $0.displayTitle, entries: $0.entries)
        }
    }

    private var placeSections: [EntryGroupSection] {
        PlaceGrouping.makeGroups(from: entries).map {
            EntryGroupSection(id: $0.id, title: $0.name, entries: $0.entries)
        }
    }

    private var categorySections: [EntryGroupSection] {
        CategoryGrouping.makeGroups(from: entries).map {
            EntryGroupSection(id: $0.id, title: $0.displayTitle, entries: $0.entries)
        }
    }
}

#Preview {
    CompendiumView()
        .modelContainer(for: Entry.self, inMemory: true)
}
```

```bash
xcrun xcodeproj group add-file CompendiumView.swift --group /Meguri/Features/Compendium
xcrun xcodeproj group include CompendiumView.swift --group /Meguri/Features/Compendium --target Meguri --phase 1
```

- [ ] **Step 2: 新しい表示文言をLocalizable.xcstringsに追加する**

```bash
python3 - <<'EOF'
import json

path = "Meguri/Resources/Localizable.xcstrings"
with open(path) as f:
    data = json.load(f)

new_entries = {
    "Trips": "旅",
    "Places": "場所",
    "Categories": "種別",
    "Map": "地図",
    "Compendium": "図鑑",
    "Nothing collected yet": "まだ何も集まっていません",
}
for en, ja in new_entries.items():
    data["strings"][en] = {
        "localizations": {"ja": {"stringUnit": {"state": "translated", "value": ja}}}
    }

data["strings"] = dict(sorted(data["strings"].items()))

with open(path, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
EOF
```

- [ ] **Step 3: ビルドしてシミュレータで確認する**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED

この時点では`CompendiumView`はまだどこからも呼ばれていない（Task 13でTabViewに組み込む）ため、SwiftUI Previewでのみ4セグメント（旅／場所／種別／地図）が正しく切り替わることを確認する。

- [ ] **Step 4: 全テストを実行する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: 全件PASS

- [ ] **Step 5: コミット**

```bash
git add Meguri/Features/Compendium/CompendiumView.swift Meguri/Resources/Localizable.xcstrings \
  Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
図鑑タブ本体を実装（旅/場所/種別/地図のセグメントコントロール）

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: TabView統合（MeguriApp）

**Files:**
- Modify: `Meguri/MeguriApp.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `CollectionView`（既存）、`CompendiumView`（Task 12）、`Color.meguriSage`（Task 2）

- [ ] **Step 1: TabViewでホーム・図鑑を統合する**

`Meguri/MeguriApp.swift` を以下に置き換える:

```swift
import SwiftData
import SwiftUI

@main
struct MeguriApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                CollectionView()
                    .tabItem { Label(String(localized: "Home"), systemImage: "house.fill") }
                CompendiumView()
                    .tabItem {
                        Label(String(localized: "Compendium"), systemImage: "books.vertical.fill")
                    }
            }
            .tint(Color.meguriSage)
        }
        .modelContainer(for: Entry.self)
    }
}
```

- [ ] **Step 2: 「Home」の文言をLocalizable.xcstringsに追加する**

```bash
python3 - <<'EOF'
import json

path = "Meguri/Resources/Localizable.xcstrings"
with open(path) as f:
    data = json.load(f)

data["strings"]["Home"] = {
    "localizations": {"ja": {"stringUnit": {"state": "translated", "value": "ホーム"}}}
}
data["strings"] = dict(sorted(data["strings"].items()))

with open(path, "w") as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
    f.write("\n")
EOF
```

- [ ] **Step 3: ビルドしてシミュレータで確認する**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED

シミュレータで起動し、下部タブに「ホーム」「図鑑」が表示され、タップで切り替わること、図鑑タブの4セグメントが動作することを確認する。

- [ ] **Step 4: 全テストを実行する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: 全件PASS

- [ ] **Step 5: コミット**

```bash
git add Meguri/MeguriApp.swift Meguri/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
ホーム・図鑑の2タブ構成に統合

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: 最終確認（Review Focusの目視確認・全体回帰）

**Files:** なし（確認のみ）

- [ ] **Step 1: 全テストを実行する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: 全件PASS

- [ ] **Step 2: ビルドする**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: シミュレータでReview Focusの5項目を目視確認する**

`mcp__Claude_Code_iOS_Simulator__control` の `attach`/`launch`/`screenshot` を使い、以下を確認しスクリーンショットを残す:

1. 旧タクソノミーの`category`（例: `landscape`）を持つエントリがあれば、詳細画面でタイトル・要約が消えず「その他」バッジで表示されること（無ければ、テストで担保済みのためスキップ可）
2. `insight`が`nil`のエントリがHomeグリッドでバッジ無しで正常表示され、図鑑の種別タブで「未分類」セクションに現れること
3. 位置情報が無いエントリが図鑑の場所タブで「不明な場所」セクションにまとまること
4. Homeで複数枚撮影後、図鑑の旅タブで1つの旅としてまとまること
5. Homeタブでエントリ詳細を開いた状態のまま図鑑タブに切り替え、ホームタブに戻ってもHome側の詳細画面が維持されていること（各タブが独立した`NavigationStack`を持つことの確認）

- [ ] **Step 4: 未使用コードが残っていないか確認する**

Run: `grep -rn "categoryLabel\|Color(.systemBackground)" Meguri/`
Expected: 一致なし（Task 5・6で置き換え済み）

- [ ] **Step 5: コミット（確認のみでコード変更が無ければスキップ）**

このタスクはコード変更を伴わない確認作業のため、通常はコミット不要。目視確認中に軽微な修正が必要になった場合のみ、該当ファイルをコミットする。

---

## Self-Review Notes

- **Spec coverage**: 背景・画面構成・種別・旅・場所・地図・ビジュアルスタイル・画面ごとの変更・データ影響・テストの各節をTask 1〜13でカバーした。スコープ外（外部LLM API設定、写真保存先選択、場所名正規化、地図塗り分け、旅の手動作成、種別の手動編集）はこのプランに含めていない
- **既存データ互換性**: spec の未決事項「既存エントリへの種別マイグレーション方針」は、Task 1のデコード時フォールバック（未知の値は`.other`）で解決した。一括マイグレーションは不要
- **未決事項の残り**: 「旅の名前を後から編集できるようにするか」はスコープ外のまま（specの通り、手動編集UIは実装しない）。「図鑑タブの英語ローカライズ文言」は各タスクでソース文字列（英語）＋`ja`翻訳を追加する形で解決した
