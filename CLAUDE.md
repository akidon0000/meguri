# Meguri

写真（絵画・建物・風景）を撮ると Vision + Foundation Models で説明カードを作り、SwiftData に溜める iOS アプリ。

正本は [docs/](docs/README.md)。**構成・手順・アーキテクチャ判断を変更したら docs への記録もセットで行う。**

- 設計・実装計画 → `docs/superpowers/specs/` `docs/superpowers/plans/`
- アーキテクチャ判断の記録 → [docs/adr/](docs/adr/README.md) に新番号で起票（索引も更新）
- ビルド・テスト・リリース手順の変化 → [docs/handbook/](docs/handbook/README.md) の該当ページを更新

## 開発ループ

- superpowers（brainstorming → writing-plans → TDD → verification）で進める。spec と plan を先に置いてから書く
- ビルド・テストは [docs/handbook/build-and-test.md](docs/handbook/build-and-test.md)
- リリースは [docs/handbook/release.md](docs/handbook/release.md)（審査提出まではエージェントが自動で進めてよい。ストア公開はユーザーが手動）
