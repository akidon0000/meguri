# ADR-0001: XcodeGen でプロジェクト管理し、SPM ビルドプラグインは外す

- 読み手: このリポジトリで作業する自分・エージェントセッション
- 目的: `.xcodeproj` の管理方式と、テンプレート同梱の SPM ビルドプラグインを外した理由を記録する
- 状態: **有効**
- 決定日: 2026-09-22

## 決定

`project.yml` を正本として [XcodeGen](https://github.com/yonaskolb/XcodeGen) で `Meguri.xcodeproj` を生成する。
`ios-project-template` / `XprojGen` が標準で組み込む R.swift・SwiftLintPlugins の
SPM ビルドツールプラグインは `project.yml` に引き継がず、使わない。

ファイルを追加・変更したら `xcodegen generate` を実行し、生成された `.xcodeproj` ごとコミットする。

## 背景

このアプリは深夜の無人実行（ユーザー就寝中の自律開発）で立ち上げた。SPM のビルドツールプラグインは
初回ビルド時に Xcode の GUI 承認（"Xcode found a plugin that needs to be enabled"）を要求し、
`xcodebuild` からは恒久的に回避できない。無人の `xcodebuild build` / `test` がここで止まってしまう。

## 比較

| 案 | 結果 |
|---|---|
| **XcodeGen + プラグインなし（採用）** | `xcodebuild` が承認待ちなしで完走する。R.swift の型安全リソースアクセスは使えないが MVP では未使用 |
| テンプレート標準のままプラグイン維持 | 無人ビルドが承認待ちで止まる。有人でも初回セットアップの手間が増える |
| `.xcodeproj` を手書き管理（XcodeGen 不使用） | ファイル追加のたびに pbxproj を手で編集する必要があり、エージェントの自動化に向かない |

## 却下した案

| 案 | 却下理由 |
|---|---|
| プラグインを残し `xcodebuild -skipPackagePluginValidation` 等のフラグで回避 | そのようなフラグは無く、CLI からの恒久回避策が見つからなかった |

## 再評価のタイミング

- R.swift の型安全リソースアクセスが必要になったら、有人環境での初回承認を前提にプラグインを戻す
- SwiftLint は現状 GitHub Actions（`swift-lint-check.yml`）側で担保しているため、ローカルの lint 精度に不満が出たら見直す

## 参考

- テンプレート側の構成: [ios-project-template](https://github.com/akidon0000/ios-project-template)
- `project.yml` の実体: [project.yml](https://github.com/akidon0000/meguri/blob/main/project.yml)
