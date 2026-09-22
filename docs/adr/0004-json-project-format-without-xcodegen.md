# ADR-0004: XcodeGen をやめ、Xcode 27.2 の JSON プロジェクト形式を `xcodeproj` CLI で直接編集する

- 読み手: このリポジトリで作業する自分・エージェントセッション
- 目的: `.xcodeproj` の管理方式を XcodeGen から Xcode ネイティブの JSON 形式に切り替えた理由を記録する
- 状態: **有効**（[ADR-0001](0001-xcodegen-without-build-plugins.md) を置き換える）
- 決定日: 2026-09-22

## 決定

`Meguri.xcodeproj` の内部設定ファイルを、Xcode 27.2 Beta が対応した JSON5 形式
（`project.xcproj`。旧来の `.pbxproj` の代替）に変換し、これを正本として直接コミットする。
`project.yml`（XcodeGen の入力）は廃止した。

ファイルの追加・削除・ターゲットへの組み込みは、Xcode 27.2 に同梱される `xcodeproj` CLI
（`xcrun xcodeproj group add-file` / `group include` / `target ...`）で行う。Xcode の GUI で
ファイルをドラッグ&ドロップしても同じ `project.xcproj` が更新される。

## 背景

[ADR-0001](0001-xcodegen-without-build-plugins.md) では無人ビルドを通すために XcodeGen +
プラグインなし構成を採用していた。今回 Xcode 27.2 Beta で `.pbxproj` を JSON5 化する
`-convert-project` 機能を検証したところ、XcodeGen は常に `.pbxproj` 形式で書き出す仕様のため
（`xcodegen generate` を再実行するたびに JSON5 形式が `.pbxproj` に巻き戻る）、両立できないことが
分かった。JSON 化のメリット（diff の改善、ファイルサイズ削減、可読性）を活かすには XcodeGen を
手放す必要がある。

`xcodeproj` CLI がスクリプトからのファイル追加・ターゲット組み込みを完全にカバーしていることを
実機で確認済みで、エージェントによる自動編集（GUI 操作なし）は引き続き可能。

## 比較

| 案 | diff の質 | ファイル追加の自動化 | 備考 |
|---|---|---|---|
| **JSON プロジェクト形式 + `xcodeproj` CLI（採用）** | 良い（記事実測で約60%のサイズ削減、変更箇所が1箇所に集約） | `xcodeproj group add-file` / `include` で可能。実機で smoke test 済み | Xcode 27+ が前提。Beta 機能 |
| XcodeGen 継続（ADR-0001 のまま） | `.pbxproj` のまま（ID参照が複数箇所に散る） | `project.yml` 編集 + `xcodegen generate` | 実績があり枯れているが JSON 化の恩恵を受けられない |
| 両方維持（generate 後に毎回 `-convert-project` し直す） | JSON のまま保てる | 二重管理になる | 検討したが、`project.yml` の記述と `.xcproj` の実体が二重の正本になり、どちらを見ればよいか曖昧になるため見送り |

## 制約・リスク

- Xcode 27.2 は Beta。正式版で仕様が変わる可能性がある
- `xcodebuild -convert-project` で使えるフォーマット名は Xcode 27.1 では未提供（`Xcode 27.0` までしか
  一覧に出ない）。**Xcode 27.2 以降が必須**
- 往復変換（JSON → pbxproj → JSON）をすると ID が再生成され元のファイルと一致しない。今後 `.pbxproj`
  に戻すことになった場合、diff は綺麗に出ない
- この変更は Meguri 単体の判断。[ios-project-template](https://github.com/akidon0000/ios-project-template)
  や `XprojGen` は XcodeGen を使い続けており、新規アプリは引き続き `.pbxproj` で生成される
  （テンプレート側への展開は別途判断する）
- **CI でのビルド・テストが組めない**: GitHub Actions の macOS ランナーイメージ（`actions/runner-images`
  の `xcode-27-arm64`）は 2026-09-22 時点で Xcode 27.0 のみを収録しており、27.2 Beta は未収録。
  そもそも本リポジトリには build/test を行う CI ワークフローが無く（lint・format のみ）、
  この制約により当面追加もできない。ビルド・テストはローカルで確認してから push する運用が前提になる
  （[handbook/build-and-test.md](../handbook/build-and-test.md) 参照）

## 再評価のタイミング

- Xcode 27.2 が正式版になったとき、変換手順・フォーマット名（`Xcode Project`）に変更がないか確認する
- XcodeGen が JSON 形式の直接出力に対応したら、XcodeGen 復帰を検討する
- `xcodeproj` CLI での運用が実際に回らない（agent が使いこなせない、頻繁な手戻りが出る等）と分かったら
  XcodeGen 継続案に戻す

## 参考

- 元記事: [Xcodeのプロジェクトファイルの新しいJSON形式について](https://zenn.dev/d_date/articles/b1a7baa74b77da)
- 変換コマンド: `xcodebuild -project Meguri.xcodeproj -convert-project "Xcode Project"`
- ファイル追加のスモークテスト: `xcrun xcodeproj group add-file` → `group include` → `xcodebuild build`
  を実行し、ビルド成功・テスト20本 green を確認（2026-09-22）
