# Docs — ナレッジ索引

- 読み手: このリポジトリで作業する自分・エージェント
- 目的: Meguri の設計・意思決定・運用手順の正本への入口

## 構成

| ディレクトリ | 内容 |
|---|---|
| [adr/](adr/README.md) | 意思決定記録（なぜこの構成なのか） |
| [handbook/](handbook/README.md) | 現在の正本・運用手順（どう使う・どう変えるか） |
| [roadmap.md](roadmap.md) | 今後の機能候補と論点（まだ着手していないもの） |
| [superpowers/specs/](superpowers/specs/) | 機能ごとの設計仕様（brainstorming の成果物） |
| [superpowers/plans/](superpowers/plans/) | 実装計画（writing-plans の成果物） |

## まず読むもの

| 順 | ドキュメント | 内容 |
|---|---|---|
| 1 | [../CLAUDE.md](../CLAUDE.md) | このリポジトリで作業するときの要約 |
| 2 | [handbook/README.md](handbook/README.md) | ビルド・テスト・リリースの手順 |
| 3 | [adr/README.md](adr/README.md) | アーキテクチャ判断の経緯 |

## 使い分け

| 置き場所 | 入れるもの |
|---|---|
| `docs/adr/` | このアプリ固有のアーキテクチャ判断と理由。覆すときは新番号で起票 |
| `docs/handbook/` | 現在のビルド・テスト・リリース手順（変わったら同じページを更新） |
| `docs/roadmap.md` | まだ着手していない機能候補と論点。着手したら該当項目を spec/plan に昇華させる |
| `docs/superpowers/specs/` `docs/superpowers/plans/` | 機能単位の設計・実装計画（superpowers の brainstorming / writing-plans） |

エージェント環境（skills・MCP・iOS 配信ツールの選定など複数リポジトリ共通の話）は
[akidon0000/hq](https://github.com/akidon0000/hq) の docs が正本。ここには Meguri というアプリ固有の判断だけを置く。
