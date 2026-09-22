# Handbook — 運用ナレッジ

- 読み手: このリポジトリで作業する自分・エージェント
- 目的: 現在のビルド・テスト・リリース手順の正本（変わったら同じページを更新する）

## ドキュメント一覧

| ドキュメント | 用途 |
|---|---|
| [build-and-test.md](build-and-test.md) | ファイル追加・ビルド・テストの実行、既知の制限 |
| [release.md](release.md) | TestFlight / 審査提出までの手順 |

## どこが正本か（早見表）

| やること | 正本 |
|---|---|
| プロジェクトへのファイル追加・削除 | `Meguri.xcodeproj`（Xcode GUI か `xcodeproj` CLI で直接編集。[ADR-0004](../adr/0004-json-project-format-without-xcodegen.md)） |
| 機能の設計 | `docs/superpowers/specs/` |
| 実装計画 | `docs/superpowers/plans/` |
| アーキテクチャ判断の記録 | [../adr/README.md](../adr/README.md) |
| ビルド・テスト・リリース手順 | このディレクトリ |
| iOS 配信ツールの選定など複数アプリ共通の話 | [hq の docs](https://github.com/akidon0000/hq/tree/main/docs) |
