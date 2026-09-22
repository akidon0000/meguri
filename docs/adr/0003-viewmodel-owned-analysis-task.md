# ADR-0003: 解析処理は ViewModel 保持の Task で実行する

- 読み手: このリポジトリで作業する自分・エージェントセッション
- 目的: `AnalyzeViewModel` が SwiftUI の `.task` に処理を委ねず、自前で `Task` を起票する理由を記録する
- 状態: **有効**
- 決定日: 2026-09-22

## 決定

`AnalyzeViewModel.start(_:)` が自前で `Task` を起票し、その中で `analyze(_:)` を実行する。
`AnalyzingView` の `.task { viewModel.start(image) }` は起動のトリガーとしてのみ使い、
解析処理そのものを `.task` のクロージャに直接書かない。

## 背景

`AnalyzingView` を `fullScreenCover` で表示する構成で実装した際、SwiftUI が `.task` を
キャンセル・再実行するケースがあり、Vision → Foundation Models の生成中に
`Swift.CancellationError` が発生し、かつ解析が2重に走って `Entry` が重複保存される不具合を
実機・シミュレータの両方で確認した。

## 却下した案

| 案 | 却下理由 |
|---|---|
| `.task { await viewModel.analyze(image) }` で直接呼ぶ（当初の実装） | 上記のキャンセル・再実行で CancellationError と二重保存が発生した |
| `.task` に `Task.detached` を渡す | View のライフサイクルと `Task` の生存期間の結合を切るという意図は同じだが、`@MainActor` の ViewModel を detached task から安全に触るための隔離が必要になり、`AnalyzeViewModel` 自身が Task を保持する方が構造として単純 |

## 実装のポイント

- `AnalyzeViewModel.analyze(_:)` は `guard case .idle = phase else { return }` で多重実行を防ぐ
- `start(_:)` は `runningTask` が既にあれば何もしない（`guard runningTask == nil else { return }`）

## 参考

- 発生条件を確認したコミット: [e26b675](https://github.com/akidon0000/meguri/commit/e26b675)
- 実装: [AnalyzeViewModel.swift](https://github.com/akidon0000/meguri/blob/main/Meguri/Features/Capture/AnalyzeViewModel.swift)
