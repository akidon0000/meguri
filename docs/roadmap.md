# ロードマップ

- 読み手: このリポジトリで作業する自分・エージェント
- 目的: 今後やるかもしれない機能候補と、着手前に詰めるべき論点を残す
- 位置づけ: これは実装計画ではない。各項目に着手するときは `superpowers:brainstorming` から
  改めて spec（`docs/superpowers/specs/`）と plan（`docs/superpowers/plans/`）を起票する

## 候補

### 外部 LLM API を選べるようにする

**何を**: 設定画面でユーザー自身の API キー（Anthropic の Claude API 等）を入力すると、
説明生成に Foundation Models の代わりにそちらを使えるようにする。

**なぜ**: Foundation Models は端末非対応・Apple Intelligence 未有効・モデル準備中などで
使えないことがある（[ADR-0002](adr/0002-on-device-ai-only.md)）。また、実機未検証だが
外部 LLM の方が同定精度が高い可能性がある。

**論点（着手時に詰める）**:

| 論点 | メモ |
|---|---|
| 既定はどちらか | Foundation Models を既定のままにし、外部 API は任意のオプトインにするのが「無料でAI」という当初のコンセプトに沿う |
| 対応プロバイダ | Anthropic 限定か、複数プロバイダを見据えた抽象化にするか |
| キーの保存場所 | Keychain。SwiftData や UserDefaults には置かない |
| 課金の扱い | 外部 API はユーザー自身の課金になる旨をUIで明示する。App Store 審査上の注意点も確認する |
| 実装の当たり | `InsightGenerating` protocol（[FoundationModelsInsightGenerator.swift](../Meguri/Services/FoundationModelsInsightGenerator.swift)）は既に差し替え可能な形になっている。`ClaudeAPIInsightGenerator` 等を追加し `AppDependencies` で選択する設計で収まりそう |

### 写真の保存先をユーザーが選べるようにする

**何を**: 撮った写真の保存先を「アプリ内（現状）」と「純正 Photos アプリ」からユーザーが選べるようにする。

**なぜ**: 自分の写真ライブラリと一体で管理したい人と、アプリ内に閉じたい人の両方に対応する。

**論点（着手時に詰める）**:

| 論点 | メモ |
|---|---|
| 現状の実装 | `ImageStoring` protocol（[FileImageStore.swift](../Meguri/Services/FileImageStore.swift)）がアプリ内保存を担う。Photos 保存版の実装を追加する形になりそう |
| Photos 保存時のデータモデル | `PHAsset` の `localIdentifier` を `Entry` に持たせ、表示は `PHImageManager` 経由で取得する形に変わる。`Entry`（[Entry.swift](../Meguri/Models/Entry.swift)）のスキーマ変更を伴う可能性 |
| 権限 | 読み取りに `NSPhotoLibraryUsageDescription`、保存に `NSPhotoLibraryAddUsageDescription` が必要（現在の `Info.plist` にはどちらも無い） |
| 削除時の挙動 | アプリ内の `Entry` を削除したとき、Photos 側の写真は残すか一緒に消すか |
| 設定画面 | まだ存在しない。この機能を作るなら設定画面そのものの新規実装が前提になる |

### タブで「旅ごと」「場所ごと」に一覧できるようにする

**何を**: 現状の単一グリッド（`CollectionView`）をタブ構成にし、1つのタブは旅（トリップ）の名前でグルーピングした一覧、
もう1つのタブは `Entry.placeName` でグルーピングした一覧にする。説明文は生成済みのものをそのまま表示するだけで、
生成ロジック自体は変えない。

**なぜ**: 撮り溜めたエントリが増えるほど単一グリッドでは目的の記録を探しにくくなる。旅単位・場所単位という
2つの自然な軸で振り返れるようにしたい。

**論点（着手時に詰める）**:

| 論点 | メモ |
|---|---|
| 「旅」の定義 | 現在のデータモデルに「旅」という概念が無い（`Entry` は `placeName` と `createdAt` のみ）。ユーザーが手動で旅を作って名前を付け、エントリを割り当てる方式にするか、日付・場所の近さから自動でクラスタリングして旅として扱う（名前は日付や地域から自動生成）方式にするかで実装規模が大きく変わる |
| 場所ごとの一覧のキー | `Entry.placeName` は自由文字列（[LocationService.swift](../Meguri/Services/CoreLocationService.swift) が生成）なので、表記揺れ（同じ場所でも文言が微妙に違う）をそのままグループキーにしてよいか |
| 旅に属さないエントリの扱い | 自動クラスタリングにせよ手動にせよ、「旅」タブに出せない・未分類のエントリをどう見せるか |
| タブ構成 | `TabView` を導入する初のケース。現状ナビゲーションは `CollectionView` の `NavigationStack` 1本のみで、タブ切り替えとナビゲーション状態の共存を設計する必要がある |
