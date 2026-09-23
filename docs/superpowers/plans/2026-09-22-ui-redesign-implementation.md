# UI/UX 再設計（集める図鑑）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Meguri（Megumemo）を「集める図鑑」コンセプトで再設計する。ホーム／図鑑の2タブ構成、種別（AI自動分類）・旅・場所・地図の4つの軸で振り返れる図鑑タブ、撮影直後に旅を選ぶモーダル、グラデーション無しのフラットな水彩ポストカード配色を実装する。

**Architecture:** 既存の3画面（一覧・詳細・撮影中）はレイアウトを変えず再配色し、新規に「図鑑」タブを追加する。旅は撮影直後のモーダルでユーザーが選ぶ永続`Trip`モデルとして管理し、未割り当て（`trip == nil`）のエントリだけを従来通り非永続のクラスタリング関数で補助的に表示する。場所・種別のグルーピングは`Entry`配列を受け取る非永続の純粋関数として実装し、`CompendiumView`のセグメントコントロールから呼び出す。視覚トークンは`Color`拡張の静的定数に集約し、全画面から参照する。

**Tech Stack:** SwiftUI, SwiftData, MapKit, Swift Testing, Foundation Models (`@Generable`/`@Guide`)

**Spec:** [docs/superpowers/specs/2026-09-22-ui-redesign-design.md](../specs/2026-09-22-ui-redesign-design.md)

## Global Constraints

- Xcode 27.2 以降必須。プロジェクトは `Meguri.xcodeproj/project.xcproj`（JSON5形式）。XcodeGenは使わない
- ファイル追加は `xcrun xcodeproj group add-file` → `xcrun xcodeproj group include ... --phase 1` の2段階（詳細は各タスク内に記載）
- 新規`SwiftData`モデルは`Trip`（`id`, `name`）のみ追加する。`Entry`には`trip: Trip?`（`@Relationship(deleteRule: .nullify)`）を追加する
- `Insight.category`は既存フィールドを7種のタクソノミーに拡張する（新規フィールド追加ではない）
- ビジュアルトークンはspecの表の16進値をそのまま使う。グラデーション・光彩・ぼかしは使わない
- タブは「ホーム」「図鑑」の2つ。各タブが独立した`NavigationStack`を持つ
- 旅の管理は撮影直後のモーダルでユーザーが選ぶ（永続`Trip`）。「直前に使った旅」の提案とデフォルト選択の有効期限、および未割り当てエントリの非永続クラスタリングは、どちらも同じ2日のしきい値を使う
- 場所のグルーピングは`Entry.placeName`の文字列をそのままキーに使う。正規化はしない
- 地図は緯度経度を持つ`Entry`のみピン表示。塗り分けはしない。位置情報付きエントリが0件のときは専用の空状態を表示する
- 汎用の設定画面は新設しない（旅のしきい値は2日固定で、UI上の変更項目は設けない）
- Swift Testingで`@MainActor`と`ModelContainer.mainContext`を同時に使うとXcode 27 betaでデッドロックする。テストは`ModelContext(container)`を明示的に生成して使う（既存の`EntryTests.swift`と同じパターン）
- ソース言語は英語（`Meguri/Resources/Localizable.xcstrings`の`sourceLanguage: "en"`）。新しいUI文言はすべて英語のソース文字列＋`ja`の`translated`エントリをこのファイルに追加する（既存キー`Architecture`/`Artwork`/`Other`と同じJSON形状）
- シミュレータでは`Vision`/`Foundation Models`が動かないため（`docs/handbook/build-and-test.md`）、撮影→解析→旅を選ぶモーダルの一連の流れはシミュレータでは`.done`状態に到達できず確認できない。モーダル単体の見た目はSwiftUI Previewで確認し、実機での一連の流れの確認はユーザーに委ねる

## Review Focus

- 旧タクソノミー（`landscape`など、現行7種に存在しない生の値）で保存済みの`Insight`が、種別変更後もタイトル・要約ごと消えずに読み込めること（Task 1のデコードテストで担保。表示側はTask 19で目視確認）
- `insight`が`nil`のエントリ（解析失敗・Apple Intelligence無効）がHomeグリッドでバッジ無しのまま安全に表示され、図鑑の種別ビューでは「未分類」に入ること（Task 4・Task 10でそれぞれ担保）
- `placeName`が`nil`または空文字のエントリが場所ビューでクラッシュせず、単一の「不明な場所」グループにまとまること（Task 9で担保）
- 旅のデフォルト提案が2日のしきい値を厳密に守り、古い旅を誤って提案しないこと（1週間前の旅行から帰った直後に無関係な写真を撮っても、その旅行が勝手にデフォルト選択されない）。Task 11の境界値テストで担保する
- ホーム⇄図鑑のタブ切り替え時、各タブの`NavigationStack`（詳細画面への遷移状態）が独立に保たれること（このアプリ初のTabViewなので自動と決め付けず、Task 19でシミュレータ実機確認する）

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

## Task 7: Tripモデルの追加とEntryへの関連付け

**Files:**
- Create: `Meguri/Models/Trip.swift`
- Modify: `Meguri/Models/Entry.swift`
- Modify: `Meguri/MeguriApp.swift`
- Modify: `MeguriTests/EntryTests.swift`

**Interfaces:**
- Produces: `Trip`（`@Model`, `id: UUID`, `name: String`）、`Entry.trip: Trip?`

旅を「撮影直後にユーザーが選ぶ永続モデル」に変更する最初のステップとして、データモデルだけを先に用意する。

- [ ] **Step 1: 失敗するテストを書く**

`MeguriTests/EntryTests.swift` の `makeContext()` を `Trip.self` も登録するように変更し、新しいテストを追加する:

```swift
// 旧
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Entry.self, configurations: config)
        return ModelContext(container)
    }
```

```swift
// 新
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Entry.self, Trip.self, configurations: config)
        return ModelContext(container)
    }
```

`@Suite struct EntryTests` の末尾（最後の `}` の直前）に新しいテストを追加する:

```swift
    @Test func persistsTripRelationship() throws {
        let context = try makeContext()
        let trip = Trip(name: "パリ旅行")
        let entry = Entry(imageFileName: "a.jpg", thumbnailData: Data([1, 2, 3]))
        entry.trip = trip
        context.insert(trip)
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Entry>())
        #expect(fetched.first?.trip?.name == "パリ旅行")
    }

    @Test func tripIsNilByDefault() throws {
        let entry = Entry(imageFileName: "b.jpg", thumbnailData: Data())
        #expect(entry.trip == nil)
    }
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/EntryTests`
Expected: FAIL（`Trip`型・`Entry.trip`プロパティが存在せずコンパイルエラー）

- [ ] **Step 3: Tripモデルを実装する**

`Meguri/Models/Trip.swift` を新規作成:

```swift
import Foundation
import SwiftData

@Model
final class Trip {
    @Attribute(.unique) var id: UUID
    var name: String

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}
```

```bash
xcrun xcodeproj group add-file Trip.swift --group /Meguri/Models
xcrun xcodeproj group include Trip.swift --group /Meguri/Models --target Meguri --phase 1
```

- [ ] **Step 4: Entryにtripプロパティを追加する**

`Meguri/Models/Entry.swift` の `recognizedTexts` プロパティの直後に追加する:

```swift
// 旧
    var perceivedLabels: [String]
    var recognizedTexts: [String]

    init(
```

```swift
// 新
    var perceivedLabels: [String]
    var recognizedTexts: [String]
    @Relationship(deleteRule: .nullify) var trip: Trip?

    init(
```

- [ ] **Step 5: MeguriAppのmodelContainerにTripを登録する**

```swift
// 旧
        .modelContainer(for: Entry.self)
```

```swift
// 新
        .modelContainer(for: [Entry.self, Trip.self])
```

- [ ] **Step 6: テストが通ることを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/EntryTests`
Expected: PASS（5件全て）

- [ ] **Step 7: 全テストを実行する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: 全件PASS

- [ ] **Step 8: コミット**

```bash
git add Meguri/Models/Trip.swift Meguri/Models/Entry.swift Meguri/MeguriApp.swift \
  MeguriTests/EntryTests.swift Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
永続Tripモデルを追加し、Entryとの関連付けを実装

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: 旅の命名ロジックと未割り当てクラスタリング（TripNaming・UnassignedClustering）

**Files:**
- Create: `Meguri/Features/Compendium/TripNaming.swift`
- Create: `Meguri/Features/Compendium/UnassignedClustering.swift`
- Test: `MeguriTests/UnassignedClusteringTests.swift`

**Interfaces:**
- Consumes: `Entry`（`createdAt`, `placeName`, `trip`）（Task 7）
- Produces: `TripNaming.suggestedName(for:locale:) -> String`（日付＋代表地名からの命名。Task 11のモーダル提案でも再利用する）、`UnassignedCluster { id: Date, name: String?, dateRange: ClosedRange<Date>, entries: [Entry], displayTitle: String }`、`UnassignedClustering.makeClusters(from:locale:) -> [UnassignedCluster]`、`UnassignedClustering.newClusterGapDays: Int`

`trip == nil`のエントリ（この機能の導入前の既存エントリ、または撮影時に「旅に追加しない」を選んだエントリ）だけを対象に、従来の日付間隔クラスタリングで補助的にまとめる。命名ロジックは、後述のTask 11（新しい旅の名前提案）とここで共有するため`TripNaming`として切り出す。

- [ ] **Step 1: 失敗するテストを書く**

`MeguriTests/UnassignedClusteringTests.swift` を新規作成:

```swift
import Foundation
import Testing

@testable import Meguri

@Suite struct UnassignedClusteringTests {
    private let reference = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeEntry(
        daysFromReference days: Double, place: String? = nil, trip: Trip? = nil
    ) -> Entry {
        let entry = Entry(
            imageFileName: "\(days).jpg", thumbnailData: Data(),
            createdAt: reference.addingTimeInterval(days * 24 * 60 * 60),
            placeName: place)
        entry.trip = trip
        return entry
    }

    @Test func emptyInputProducesNoClusters() {
        #expect(UnassignedClustering.makeClusters(from: []).isEmpty)
    }

    @Test func singleEntryClusterHasNoName() {
        let clusters = UnassignedClustering.makeClusters(from: [makeEntry(daysFromReference: 0)])
        #expect(clusters.count == 1)
        #expect(clusters[0].name == nil)
        #expect(!clusters[0].displayTitle.isEmpty)
    }

    @Test func entriesWithinThresholdMergeIntoOneCluster() {
        let entries = [
            makeEntry(daysFromReference: 0, place: "パリ"),
            makeEntry(daysFromReference: 1, place: "パリ"),
            makeEntry(daysFromReference: 1.5, place: "パリ"),
        ]
        let clusters = UnassignedClustering.makeClusters(
            from: entries, locale: Locale(identifier: "ja_JP"))
        #expect(clusters.count == 1)
        #expect(clusters[0].entries.count == 3)
        #expect(clusters[0].name?.contains("パリ") == true)
    }

    @Test func gapBeyondThresholdSplitsIntoSeparateClusters() {
        let entries = [
            makeEntry(daysFromReference: 0),
            makeEntry(daysFromReference: 1),
            makeEntry(daysFromReference: 5),
            makeEntry(daysFromReference: 5.5),
        ]
        let clusters = UnassignedClustering.makeClusters(from: entries)
        #expect(clusters.count == 2)
    }

    @Test func gapExactlyAtThresholdStaysInSameCluster() {
        let entries = [
            makeEntry(daysFromReference: 0),
            makeEntry(daysFromReference: Double(UnassignedClustering.newClusterGapDays)),
        ]
        let clusters = UnassignedClustering.makeClusters(from: entries)
        #expect(clusters.count == 1)
    }

    @Test func newestClusterIsFirstAndEntriesWithinAClusterAreNewestFirst() {
        let entries = [
            makeEntry(daysFromReference: 0),
            makeEntry(daysFromReference: 0.5),
            makeEntry(daysFromReference: 10),
        ]
        let clusters = UnassignedClustering.makeClusters(from: entries)
        #expect(clusters.count == 2)
        #expect(clusters[0].entries.first?.imageFileName == "10.0.jpg")
        #expect(clusters[1].entries.map(\.imageFileName) == ["0.5.jpg", "0.0.jpg"])
    }

    @Test func representativePlaceBreaksTiesByFirstAppearance() {
        let entries = [
            makeEntry(daysFromReference: 0, place: "浅草寺"),
            makeEntry(daysFromReference: 0.2, place: "オランジュリー美術館"),
        ]
        let clusters = UnassignedClustering.makeClusters(
            from: entries, locale: Locale(identifier: "ja_JP"))
        #expect(clusters[0].name?.contains("浅草寺") == true)
    }

    @Test func generatesEnglishNameForNonJapaneseLocale() {
        let entries = [
            makeEntry(daysFromReference: 0, place: "Louvre"),
            makeEntry(daysFromReference: 0.5, place: "Louvre"),
        ]
        let clusters = UnassignedClustering.makeClusters(
            from: entries, locale: Locale(identifier: "en_US"))
        #expect(clusters[0].name?.contains("Louvre") == true)
        #expect(clusters[0].name?.contains("Trip") == true)
    }

    @Test func entriesAssignedToATripAreExcludedFromClusters() {
        let trip = Trip(name: "既存の旅")
        let entries = [
            makeEntry(daysFromReference: 0, trip: trip),
            makeEntry(daysFromReference: 0.5),
        ]
        let clusters = UnassignedClustering.makeClusters(from: entries)
        #expect(clusters.count == 1)
        #expect(clusters[0].entries.count == 1)
        #expect(clusters[0].entries[0].imageFileName == "0.5.jpg")
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/UnassignedClusteringTests`
Expected: FAIL（`UnassignedCluster`/`UnassignedClustering`が存在せずコンパイルエラー）

- [ ] **Step 3: グループを作成し実装する**

```bash
xcrun xcodeproj group add Compendium --parent /Meguri/Features
```

`Meguri/Features/Compendium/TripNaming.swift` を新規作成:

```swift
import Foundation

enum TripNaming {
    static func suggestedName(for entries: [Entry], locale: Locale = .current) -> String {
        let sorted = entries.sorted { $0.createdAt < $1.createdAt }
        guard let first = sorted.first else { return "" }
        let month = monthFormatter(for: locale).string(from: first.createdAt)
        guard let place = representativePlace(in: entries) else {
            return isJapanese(locale) ? "\(month)の旅" : "\(month) Trip"
        }
        return isJapanese(locale) ? "\(month)の\(place)旅行" : "\(place) Trip, \(month)"
    }

    static func representativePlace(in entries: [Entry]) -> String? {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for entry in entries {
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

    static func isJapanese(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "ja"
    }

    static func monthFormatter(for locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter
    }
}
```

`Meguri/Features/Compendium/UnassignedClustering.swift` を新規作成:

```swift
import Foundation

struct UnassignedCluster: Identifiable {
    var id: Date { dateRange.lowerBound }
    var name: String?
    var dateRange: ClosedRange<Date>
    var entries: [Entry]

    var displayTitle: String {
        if let name { return name }
        return UnassignedCluster.singleDateFormatter.string(from: dateRange.lowerBound)
    }

    private static let singleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

enum UnassignedClustering {
    static let newClusterGapDays = 2

    static func makeClusters(from entries: [Entry], locale: Locale = .current) -> [UnassignedCluster]
    {
        let unassigned = entries.filter { $0.trip == nil }
        guard !unassigned.isEmpty else { return [] }
        let sorted = unassigned.sorted { $0.createdAt < $1.createdAt }
        let thresholdSeconds = TimeInterval(newClusterGapDays * 24 * 60 * 60)

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
            UnassignedCluster(
                name: group.count > 1 ? TripNaming.suggestedName(for: group, locale: locale) : nil,
                dateRange: group.first!.createdAt...group.last!.createdAt,
                entries: group.reversed()
            )
        }
    }
}
```

```bash
xcrun xcodeproj group add-file TripNaming.swift --group /Meguri/Features/Compendium
xcrun xcodeproj group include TripNaming.swift --group /Meguri/Features/Compendium --target Meguri --phase 1
xcrun xcodeproj group add-file UnassignedClustering.swift --group /Meguri/Features/Compendium
xcrun xcodeproj group include UnassignedClustering.swift --group /Meguri/Features/Compendium --target Meguri --phase 1
xcrun xcodeproj group add-file UnassignedClusteringTests.swift --group /MeguriTests
xcrun xcodeproj group include UnassignedClusteringTests.swift --group /MeguriTests --target MeguriTests --phase 1
```

- [ ] **Step 4: テストが通ることを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/UnassignedClusteringTests`
Expected: PASS（9件全て）

- [ ] **Step 5: コミット**

```bash
git add Meguri/Features/Compendium/TripNaming.swift Meguri/Features/Compendium/UnassignedClustering.swift \
  MeguriTests/UnassignedClusteringTests.swift Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
未割り当てエントリの自動クラスタリングを実装（しきい値2日、非永続）

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: 場所（Place）グルーピング

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

## Task 10: 種別（Category）グルーピング

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
        #expect(groups.last?.displayTitle == String(localized: "Unclassified"))
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

## Task 11: 旅のデフォルト選択ロジック（TripDefaultSelection）

**Files:**
- Create: `Meguri/Features/Capture/TripDefaultSelection.swift`
- Test: `MeguriTests/TripDefaultSelectionTests.swift`

**Interfaces:**
- Consumes: `Trip`（Task 7）、`TripNaming.suggestedName(for:locale:)`（Task 8）
- Produces: `TripSuggestion`（`.existing(id: UUID, name: String)` / `.newTrip(suggestedName: String)`）、`TripDefaultSelection.suggest(for:among:now:locale:) -> TripSuggestion`、`TripDefaultSelection.recentWindowDays: Int`

撮影直後のモーダル（Task 12）が「どれをデフォルト選択にするか」を決めるための純粋関数。直前に使った旅の最新エントリが2日以内ならそれを、そうでなければ新しい旅の作成（名前は新規エントリの日付・地名から提案）を返す。

- [ ] **Step 1: 失敗するテストを書く**

`MeguriTests/TripDefaultSelectionTests.swift` を新規作成:

```swift
import Foundation
import Testing

@testable import Meguri

@Suite struct TripDefaultSelectionTests {
    private let reference = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeEntry(
        daysFromReference days: Double, place: String? = nil, trip: Trip? = nil
    ) -> Entry {
        let entry = Entry(
            imageFileName: "\(days).jpg", thumbnailData: Data(),
            createdAt: reference.addingTimeInterval(days * 24 * 60 * 60),
            placeName: place)
        entry.trip = trip
        return entry
    }

    @Test func suggestsNewTripWhenNoEntryHasATripYet() {
        let newEntry = makeEntry(daysFromReference: 10, place: "浅草寺")
        let suggestion = TripDefaultSelection.suggest(
            for: newEntry, among: [newEntry], now: reference.addingTimeInterval(10 * 24 * 60 * 60),
            locale: Locale(identifier: "ja_JP"))
        guard case .newTrip(let name) = suggestion else {
            Issue.record("expected .newTrip, got \(suggestion)")
            return
        }
        #expect(name.contains("浅草寺"))
    }

    @Test func suggestsLastUsedTripWhenWithinRecentWindow() {
        let trip = Trip(name: "パリ旅行")
        let assigned = makeEntry(daysFromReference: 0, trip: trip)
        let newEntry = makeEntry(daysFromReference: 1.5)
        let now = reference.addingTimeInterval(1.5 * 24 * 60 * 60)
        let suggestion = TripDefaultSelection.suggest(
            for: newEntry, among: [assigned, newEntry], now: now)
        #expect(suggestion == .existing(id: trip.id, name: "パリ旅行"))
    }

    @Test func suggestsNewTripWhenLastUsedTripIsBeyondRecentWindow() {
        let trip = Trip(name: "パリ旅行")
        let assigned = makeEntry(daysFromReference: 0, trip: trip)
        let newEntry = makeEntry(daysFromReference: 10, place: "東京タワー")
        let now = reference.addingTimeInterval(10 * 24 * 60 * 60)
        let suggestion = TripDefaultSelection.suggest(
            for: newEntry, among: [assigned, newEntry], now: now, locale: Locale(identifier: "ja_JP")
        )
        guard case .newTrip(let name) = suggestion else {
            Issue.record("expected .newTrip, got \(suggestion)")
            return
        }
        #expect(name.contains("東京タワー"))
    }

    @Test func staysWithinWindowAtExactlyTheThreshold() {
        let trip = Trip(name: "パリ旅行")
        let assigned = makeEntry(daysFromReference: 0, trip: trip)
        let newEntry = makeEntry(daysFromReference: Double(TripDefaultSelection.recentWindowDays))
        let now = reference.addingTimeInterval(
            Double(TripDefaultSelection.recentWindowDays) * 24 * 60 * 60)
        let suggestion = TripDefaultSelection.suggest(
            for: newEntry, among: [assigned, newEntry], now: now)
        #expect(suggestion == .existing(id: trip.id, name: "パリ旅行"))
    }

    @Test func ignoresTheNewEntryItselfWhenFindingTheLastUsedTrip() {
        let trip = Trip(name: "自己参照テスト")
        let newEntry = makeEntry(daysFromReference: 0, trip: trip)
        let suggestion = TripDefaultSelection.suggest(
            for: newEntry, among: [newEntry], now: reference)
        guard case .newTrip = suggestion else {
            Issue.record("expected .newTrip, got \(suggestion)")
            return
        }
    }
}
```

- [ ] **Step 2: テストが失敗することを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/TripDefaultSelectionTests`
Expected: FAIL（`TripSuggestion`/`TripDefaultSelection`が存在せずコンパイルエラー）

- [ ] **Step 3: 実装する**

`Meguri/Features/Capture/TripDefaultSelection.swift` を新規作成:

```swift
import Foundation

enum TripSuggestion: Equatable {
    case existing(id: UUID, name: String)
    case newTrip(suggestedName: String)
}

enum TripDefaultSelection {
    static let recentWindowDays = 2

    static func suggest(
        for newEntry: Entry, among entries: [Entry], now: Date = .now, locale: Locale = .current
    ) -> TripSuggestion {
        let threshold = TimeInterval(recentWindowDays * 24 * 60 * 60)
        let lastAssigned = entries
            .filter { $0.trip != nil && $0.id != newEntry.id }
            .max { $0.createdAt < $1.createdAt }

        if let lastAssigned, let trip = lastAssigned.trip,
            now.timeIntervalSince(lastAssigned.createdAt) <= threshold
        {
            return .existing(id: trip.id, name: trip.name)
        }
        return .newTrip(suggestedName: TripNaming.suggestedName(for: [newEntry], locale: locale))
    }
}
```

`Capture`グループは既存の撮影機能（`AnalyzeViewModel.swift`等）が既に入っているため、新規に作成しない。そのままファイルだけ追加する:

```bash
xcrun xcodeproj group add-file TripDefaultSelection.swift --group /Meguri/Features/Capture
xcrun xcodeproj group include TripDefaultSelection.swift --group /Meguri/Features/Capture --target Meguri --phase 1
```

- [ ] **Step 4: テストが通ることを確認する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:MeguriTests/TripDefaultSelectionTests`
Expected: PASS（5件全て）

- [ ] **Step 5: コミット**

```bash
git add Meguri/Features/Capture/TripDefaultSelection.swift MeguriTests/TripDefaultSelectionTests.swift \
  Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
旅のデフォルト選択ロジックを実装（直前の旅が2日以内ならそれを提案）

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: 旅を選ぶモーダル（TripAssignmentView）

**Files:**
- Create: `Meguri/Features/Capture/TripAssignmentView.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `Trip`（Task 7）、`TripSuggestion`/`TripDefaultSelection`（Task 11）
- Produces: `TripAssignmentView(entry:onFinish:)`

SwiftUI View層のため、Task 4と同じ方針でビルド＋シミュレータ／Preview確認のみとする（デフォルト選択ロジック自体はTask 11でテスト済み）。

- [ ] **Step 1: 実装する**

`Meguri/Features/Capture/TripAssignmentView.swift` を新規作成:

```swift
import SwiftData
import SwiftUI

struct TripAssignmentView: View {
    let entry: Entry
    let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query(Entry.newestFirst) private var allEntries: [Entry]
    @Query(sort: \Trip.name) private var trips: [Trip]

    @State private var newTripName = ""
    @State private var showsNewTripField = false

    private var suggestion: TripSuggestion {
        TripDefaultSelection.suggest(for: entry, among: allEntries)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        confirm(with: suggestion)
                    } label: {
                        Label(suggestionLabel, systemImage: "checkmark.circle.fill")
                    }
                }

                if !trips.isEmpty {
                    Section(String(localized: "Other trips")) {
                        ForEach(trips) { trip in
                            Button(trip.name) { assign(to: trip) }
                                .foregroundStyle(Color.meguriInk)
                        }
                    }
                }

                Section {
                    if showsNewTripField {
                        TextField(String(localized: "New trip name"), text: $newTripName)
                        Button(String(localized: "Create")) {
                            let trimmed = newTripName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trip = Trip(name: trimmed.isEmpty ? suggestedNewTripName : trimmed)
                            modelContext.insert(trip)
                            assign(to: trip)
                        }
                    } else {
                        Button(String(localized: "Create a different trip")) {
                            newTripName = suggestedNewTripName
                            showsNewTripField = true
                        }
                        .foregroundStyle(Color.meguriInk)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        entry.trip = nil
                        try? modelContext.save()
                        onFinish()
                    } label: {
                        Text(String(localized: "Don't add to a trip"))
                    }
                }
            }
            .navigationTitle(String(localized: "Add to a trip"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var suggestedNewTripName: String {
        TripNaming.suggestedName(for: [entry], locale: .current)
    }

    private var suggestionLabel: String {
        switch suggestion {
        case .existing(_, let name):
            String(format: String(localized: "Add to \"%@\""), name)
        case .newTrip(let name):
            String(format: String(localized: "Start a new trip: \"%@\""), name)
        }
    }

    private func confirm(with suggestion: TripSuggestion) {
        switch suggestion {
        case .existing(let id, _):
            if let trip = trips.first(where: { $0.id == id }) {
                assign(to: trip)
            }
        case .newTrip(let name):
            let trip = Trip(name: name)
            modelContext.insert(trip)
            assign(to: trip)
        }
    }

    private func assign(to trip: Trip) {
        entry.trip = trip
        try? modelContext.save()
        onFinish()
    }
}

#Preview {
    TripAssignmentView(entry: Entry(imageFileName: "x.jpg", thumbnailData: Data())) {}
        .modelContainer(for: [Entry.self, Trip.self], inMemory: true)
}
```

```bash
xcrun xcodeproj group add-file TripAssignmentView.swift --group /Meguri/Features/Capture
xcrun xcodeproj group include TripAssignmentView.swift --group /Meguri/Features/Capture --target Meguri --phase 1
```

- [ ] **Step 2: 新しい表示文言をLocalizable.xcstringsに追加する**

```bash
python3 - <<'EOF'
import json

path = "Meguri/Resources/Localizable.xcstrings"
with open(path) as f:
    data = json.load(f)

new_entries = {
    "Other trips": "他の旅",
    "New trip name": "旅の名前",
    "Create": "作成",
    "Create a different trip": "別の旅を作る",
    "Don't add to a trip": "旅に追加しない",
    "Add to a trip": "旅に追加",
    "Add to \"%@\"": "「%@」に追加",
    "Start a new trip: \"%@\"": "新しい旅にする：「%@」",
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

- [ ] **Step 3: ビルドしてPreviewで確認する**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED

この時点では`TripAssignmentView`はまだどこからも呼ばれていない（Task 13でAnalyzingViewに組み込む）ため、SwiftUI Previewで「デフォルト提案のワンタップ確定」「他の旅から選ぶ」「新しい旅を作る」「旅に追加しない」の4系統が表示されることを確認する。

- [ ] **Step 4: 全テストを実行する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: 全件PASS

- [ ] **Step 5: コミット**

```bash
git add Meguri/Features/Capture/TripAssignmentView.swift Meguri/Resources/Localizable.xcstrings \
  Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
旅を選ぶモーダル(TripAssignmentView)を実装

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: 撮影フローへのモーダル組み込み（AnalyzingView）

**Files:**
- Modify: `Meguri/Features/Capture/AnalyzingView.swift`

**Interfaces:**
- Consumes: `TripAssignmentView`（Task 12）

- [ ] **Step 1: 解析完了後にモーダルを挟む**

`Meguri/Features/Capture/AnalyzingView.swift` を以下に置き換える:

```swift
import SwiftUI

struct AnalyzingView: View {
    let image: UIImage
    @State var viewModel: AnalyzeViewModel
    let onFinish: () -> Void

    @State private var pendingTripEntry: Entry?

    var body: some View {
        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.meguriBackground)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onFinish)
                    }
                }
        }
        .task {
            viewModel.start(image)
        }
        .onChange(of: isDone) { _, isDone in
            guard isDone, case .done(let entry) = viewModel.phase else { return }
            pendingTripEntry = entry
        }
        .sheet(item: $pendingTripEntry) { entry in
            TripAssignmentView(entry: entry) {
                pendingTripEntry = nil
            }
        }
    }

    private var isDone: Bool {
        if case .done = viewModel.phase { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .perceiving:
            progress(String(localized: "Looking at the photo…"))
        case .generating:
            progress(String(localized: "Finding out what it is…"))
        case .done(let entry):
            EntryDetailView(entry: entry)
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't read this photo", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Close", action: onFinish)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func progress(_ title: String) -> some View {
        VStack(spacing: 24) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)
                .accessibilityHidden(true)
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: ビルドする**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED

シミュレータでは`Vision`/`Foundation Models`が動かないため（`docs/handbook/build-and-test.md`）、解析が`.done`まで到達せずモーダルの実機確認はできない。ビルドが通ることとPreviewでの見た目確認に留め、実機での一連の流れの確認はユーザーに依頼する旨を完了報告に含める。

- [ ] **Step 3: 全テストを実行する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: 全件PASS

- [ ] **Step 4: コミット**

```bash
git add Meguri/Features/Capture/AnalyzingView.swift
git commit -m "$(cat <<'EOF'
解析完了後に旅を選ぶモーダルを挟むよう撮影フローを変更

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: 図鑑タブの共有リスト表示（EntryGroupSection・EntryGroupListView）

**Files:**
- Create: `Meguri/Features/Compendium/EntryGroupSection.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `EntryCard`（Task 4で再配色済み）、`Color.meguri*`（Task 2）
- Produces: `EntryGroupSection { id: String, title: String, entries: [Entry], tripID: UUID? }`、`EntryGroupListView(sections:onRenameTrip:)`

旅・場所・種別の3ビューは同じ「見出し＋ミニグリッド」の形なので、共通の表示構造体とビューに集約する（重複実装を避ける）。旅セクションだけ後から名前を変更できるように、`tripID`とリネーム用の閉包を最初から持たせておく（Task 16で配線する）。純粋なマッピングのみでロジックはTask 8〜11のテストで担保済みのため、単体テストは追加せずビルド確認のみとする。

- [ ] **Step 1: 実装する**

`Meguri/Features/Compendium/EntryGroupSection.swift` を新規作成:

```swift
import SwiftUI

struct EntryGroupSection: Identifiable {
    let id: String
    let title: String
    let entries: [Entry]
    var tripID: UUID? = nil
}

struct EntryGroupListView: View {
    let sections: [EntryGroupSection]
    var onRenameTrip: ((UUID, String) -> Void)? = nil

    @State private var renamingSection: EntryGroupSection?
    @State private var renameText = ""

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(Color.meguriInk)

                            if section.tripID != nil, onRenameTrip != nil {
                                Button {
                                    renameText = section.title
                                    renamingSection = section
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .foregroundStyle(Color.meguriSecondaryText)
                                }
                            }
                        }

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
        .alert(String(localized: "Rename trip"), isPresented: renamingBinding) {
            TextField(String(localized: "New trip name"), text: $renameText)
            Button(String(localized: "Create")) {
                if let tripID = renamingSection?.tripID {
                    onRenameTrip?(tripID, renameText)
                }
                renamingSection = nil
            }
            Button(String(localized: "Cancel"), role: .cancel) { renamingSection = nil }
        }
    }

    private var renamingBinding: Binding<Bool> {
        Binding(get: { renamingSection != nil }, set: { if !$0 { renamingSection = nil } })
    }
}
```

（保存ボタンのラベルはTask 12で追加した「Create」を再利用する。新規カタログキーは「Rename trip」「Cancel」の2つだけ）

```bash
xcrun xcodeproj group add-file EntryGroupSection.swift --group /Meguri/Features/Compendium
xcrun xcodeproj group include EntryGroupSection.swift --group /Meguri/Features/Compendium --target Meguri --phase 1
```

- [ ] **Step 2: 新しい表示文言をLocalizable.xcstringsに追加する**

```bash
python3 - <<'EOF'
import json

path = "Meguri/Resources/Localizable.xcstrings"
with open(path) as f:
    data = json.load(f)

new_entries = {
    "Rename trip": "旅の名前を変更",
    "Cancel": "キャンセル",
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

- [ ] **Step 3: ビルドが通ることを確認する**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED（この時点では`EntryGroupListView`を呼び出す画面がまだ無いため、未使用の警告が出ても問題ない）

- [ ] **Step 4: コミット**

```bash
git add Meguri/Features/Compendium/EntryGroupSection.swift Meguri/Resources/Localizable.xcstrings \
  Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
図鑑タブ共通の見出し+ミニグリッド表示(EntryGroupListView)を追加し、旅のリネーム導線を用意

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: 地図ビュー（EntryMapView）

**Files:**
- Create: `Meguri/Features/Compendium/EntryMapView.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `Entry.latitude/longitude`、`Color.meguriTerracotta`（Task 2）
- Produces: `EntryMapView(entries:)`（`NavigationLink(value:)`で`Entry`を発行。呼び出し元のNavigationStackが`navigationDestination(for: Entry.self)`を持つ前提）

- [ ] **Step 1: 実装する（位置情報付きが0件のときの空状態を含む）**

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
        if located.isEmpty {
            ContentUnavailableView {
                Label(String(localized: "No located entries"), systemImage: "map")
            } description: {
                Text(String(localized: "Entries with a location will show up here as pins."))
            }
        } else {
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
}
```

```bash
xcrun xcodeproj group add-file EntryMapView.swift --group /Meguri/Features/Compendium
xcrun xcodeproj group include EntryMapView.swift --group /Meguri/Features/Compendium --target Meguri --phase 1
```

- [ ] **Step 2: 新しい表示文言をLocalizable.xcstringsに追加する**

```bash
python3 - <<'EOF'
import json

path = "Meguri/Resources/Localizable.xcstrings"
with open(path) as f:
    data = json.load(f)

new_entries = {
    "No located entries": "位置情報付きのエントリがありません",
    "Entries with a location will show up here as pins.": "位置情報を持つエントリがここにピンで表示されます。",
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

- [ ] **Step 3: ビルドが通ることを確認する**

Run: `xcodebuild build -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: コミット**

```bash
git add Meguri/Features/Compendium/EntryMapView.swift Meguri/Resources/Localizable.xcstrings \
  Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
地図ビュー(EntryMapView)を追加。位置情報0件のときは空状態を表示

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: 図鑑タブ本体（CompendiumView）

**Files:**
- Create: `Meguri/Features/Compendium/CompendiumView.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `UnassignedClustering`（Task 8）、`PlaceGrouping`（Task 9）、`CategoryGrouping`（Task 10）、`EntryGroupListView`（Task 14）、`EntryMapView`（Task 15）、`EntryDetailView`（既存）、`Trip`（Task 7）
- Produces: `CompendiumView`（`@Query(Entry.newestFirst)`・`@Query(sort: \Trip.name)`で独立にフェッチし、独自の`NavigationStack`を持つ）

旅セグメントは「永続Tripの一覧（各Tripの最新エントリの日付が新しい順）」＋「未割り当てクラスタ」の2段構成にする。旅の名前は`EntryGroupListView`の鉛筆アイコンから変更できる。

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

    @Environment(\.modelContext) private var modelContext
    @Query(Entry.newestFirst) private var entries: [Entry]
    @Query(sort: \Trip.name) private var trips: [Trip]
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
                EntryGroupListView(sections: tripSections, onRenameTrip: renameTrip)
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
        let byTrip = Dictionary(grouping: entries.filter { $0.trip != nil }) { $0.trip!.id }
        let assignedSections = trips.compactMap { trip -> (Date, EntryGroupSection)? in
            guard let members = byTrip[trip.id], !members.isEmpty else { return nil }
            let latest = members.map(\.createdAt).max() ?? .distantPast
            return (
                latest,
                EntryGroupSection(
                    id: trip.id.uuidString, title: trip.name, entries: members, tripID: trip.id)
            )
        }
        .sorted { $0.0 > $1.0 }
        .map(\.1)

        let unassignedSections = UnassignedClustering.makeClusters(from: entries).map {
            EntryGroupSection(id: $0.id.description, title: $0.displayTitle, entries: $0.entries)
        }

        return assignedSections + unassignedSections
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

    private func renameTrip(id: UUID, newName: String) {
        guard let trip = trips.first(where: { $0.id == id }), !newName.isEmpty else { return }
        trip.name = newName
        try? modelContext.save()
    }
}

#Preview {
    CompendiumView()
        .modelContainer(for: [Entry.self, Trip.self], inMemory: true)
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

この時点では`CompendiumView`はまだどこからも呼ばれていない（Task 18でTabViewに組み込む）ため、SwiftUI Previewで4セグメント（旅／場所／種別／地図）が正しく切り替わること、旅セグメントで永続Tripと未割り当てクラスタが両方表示されることを確認する。

- [ ] **Step 4: 全テストを実行する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: 全件PASS

- [ ] **Step 5: コミット**

```bash
git add Meguri/Features/Compendium/CompendiumView.swift Meguri/Resources/Localizable.xcstrings \
  Meguri.xcodeproj/project.xcproj
git commit -m "$(cat <<'EOF'
図鑑タブ本体を実装（永続Trip一覧+未割り当てクラスタ/場所/種別/地図）

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: 詳細画面から旅を変更できるようにする

**Files:**
- Modify: `Meguri/Features/Detail/EntryDetailView.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `Trip`（Task 7）

撮影時にモーダルで決めた旅の割り当てを、後から詳細画面で変更できるようにする（specの「撮影時の割り当てを最終としない」を満たす）。

- [ ] **Step 1: Tripのクエリとメニューを追加する**

`Meguri/Features/Detail/EntryDetailView.swift` の先頭のプロパティ宣言に追加する:

```swift
// 旧
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: Entry
```

```swift
// 新
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Bindable var entry: Entry
    @Query(sort: \Trip.name) private var trips: [Trip]
```

`metadata` の末尾にメニューを追加する:

```swift
// 旧
            if !entry.recognizedTexts.isEmpty {
                Label(
                    entry.recognizedTexts.joined(separator: " / "), systemImage: "text.viewfinder"
                )
                .lineLimit(3)
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
```

```swift
// 新
            if !entry.recognizedTexts.isEmpty {
                Label(
                    entry.recognizedTexts.joined(separator: " / "), systemImage: "text.viewfinder"
                )
                .lineLimit(3)
            }
            tripMenu
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var tripMenu: some View {
        Menu {
            Button(String(localized: "No trip")) { assignTrip(nil) }
            ForEach(trips) { trip in
                Button(trip.name) { assignTrip(trip) }
            }
        } label: {
            Label(entry.trip?.name ?? String(localized: "No trip"), systemImage: "case.fill")
        }
    }

    private func assignTrip(_ trip: Trip?) {
        entry.trip = trip
        try? modelContext.save()
    }
```

- [ ] **Step 2: 「No trip」の文言をLocalizable.xcstringsに追加する**

```bash
python3 - <<'EOF'
import json

path = "Meguri/Resources/Localizable.xcstrings"
with open(path) as f:
    data = json.load(f)

data["strings"]["No trip"] = {
    "localizations": {"ja": {"stringUnit": {"state": "translated", "value": "旅なし"}}}
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

詳細画面を開き、メタデータ末尾に旅メニューが表示されること、既存の旅を選ぶと詳細画面のメニュー表示が更新されること、図鑑タブの旅セグメントに反映されることをスクリーンショットで確認する。

- [ ] **Step 4: 全テストを実行する**

Run: `xcodebuild test -project Meguri.xcodeproj -scheme Meguri -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
Expected: 全件PASS

- [ ] **Step 5: コミット**

```bash
git add Meguri/Features/Detail/EntryDetailView.swift Meguri/Resources/Localizable.xcstrings
git commit -m "$(cat <<'EOF'
詳細画面から旅の割り当てを後から変更できるようにする

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 18: TabView統合（MeguriApp）

**Files:**
- Modify: `Meguri/MeguriApp.swift`
- Modify: `Meguri/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `CollectionView`（既存）、`CompendiumView`（Task 16）、`Color.meguriSage`（Task 2）

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
        .modelContainer(for: [Entry.self, Trip.self])
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

## Task 19: 最終確認（Review Focusの目視確認・全体回帰）

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
4. Homeタブでエントリ詳細を開いた状態のまま図鑑タブに切り替え、ホームタブに戻ってもHome側の詳細画面が維持されていること（各タブが独立した`NavigationStack`を持つことの確認）
5. 図鑑タブの旅セグメントで、既存の`Trip`一覧（新しい活動順）と未割り当てクラスタが両方表示され、鉛筆アイコンから旅の名前を変更できること

- [ ] **Step 4: 撮影→旅を選ぶモーダルの流れは実機のみで確認できることを完了報告に明記する**

シミュレータでは`Vision`/`Foundation Models`が動かないため、Task 12/13で実装したモーダルの実際の動作（デフォルト提案の内容、新規旅の作成、詳細画面への反映）は実機でのみ確認できる。ユーザーに実機での確認を依頼する。

- [ ] **Step 5: 未使用コードが残っていないか確認する**

Run: `grep -rn "categoryLabel\|Color(.systemBackground)" Meguri/`
Expected: 一致なし（Task 5・6で置き換え済み）

- [ ] **Step 6: コミット（確認のみでコード変更が無ければスキップ）**

このタスクはコード変更を伴わない確認作業のため、通常はコミット不要。目視確認中に軽微な修正が必要になった場合のみ、該当ファイルをコミットする。

---

## Self-Review Notes

- **Spec coverage**: 背景・画面構成・種別・旅（撮影時モーダル＋未割り当てクラスタ）・場所・地図（空状態含む）・ビジュアルスタイル・画面ごとの変更・データ影響・テストの各節をTask 1〜18でカバーした。スコープ外（外部LLM API設定、写真保存先選択、場所名正規化、地図塗り分け、旅の並び替えUI、種別の手動編集、汎用設定画面）はこのプランに含めていない
- **旅の管理方式の転換**: pv-grill-meでの深掘りにより、旅を「自動クラスタリングのみ・非永続」から「撮影直後のモーダルでユーザーが選ぶ永続`Trip`モデル」に変更した。既存の自動クラスタリングは無駄にせず、未割り当てエントリの補助表示として`UnassignedClustering`に改名して残している（Task 8）
- **既存データ互換性**: 旧タクソノミー（`landscape`）の実データは存在しないことを確認済み（pv-grill-meでの確認）。Task 1のデコード時フォールバックは保険として機能する
- **未決事項の残り**: 「AIが種別を確信を持って判定できない場合のフォールバック」はAI生成側の挙動に依存するためこのプランのスコープ外のまま。「モーダルの具体的なレイアウト（既存の旅一覧の見せ方）」はTask 12で`List`ベースの素朴な実装として決定した
