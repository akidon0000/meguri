# ADR-0002: AI 推論は Foundation Models + Vision のみを使う

- 読み手: このリポジトリで作業する自分・エージェントセッション
- 目的: 絵画・風景の説明生成に外部 LLM API を使わず Apple 純正 AI に絞った理由を記録する
- 状態: **有効**（実機での精度検証は未実施、[再評価のタイミング](#再評価のタイミング)参照）
- 決定日: 2026-09-22

## 決定

説明文の生成は Foundation Models framework（`LanguageModelSession` + `@Generable`）のみで行う。
Foundation Models は画像を直接受け取れないため、Vision（`ClassifyImageRequest` でラベル、
`RecognizeTextRequest` で案内板・キャプションの文字）で写真をテキスト化し、それを
プロンプト（`PromptBuilder`）経由で渡す 2 段構成にする。Claude API 等の外部 LLM は呼ばない。

## 背景

個人開発アプリとして「無料・オフライン・課金なしで動く」ことを最優先にした。Apple Intelligence /
Foundation Models framework は iOS 26 以降で端末上（または Private Cloud Compute 経由）で
無料に使え、外部 API キーの管理や従量課金が要らない。

## 比較

| 案 | 精度 | コスト・運用 |
|---|---|---|
| **Foundation Models + Vision（採用）** | 未検証（シミュレータでは動作しないため実機でのみ確認可能） | 無料、オフライン可、キー管理不要 |
| Claude API 等の外部 LLM | 高いと想定される | API キー管理・従量課金が発生。「無料で AI」という前提から外れる |
| Foundation Models を主、外部 API をフォールバック | 未検証を補える可能性 | 実装・鍵管理の複雑さが増す。判別不能時のみ呼ぶ設計は現時点の MVP には過剰 |

## 制約

- Foundation Models は端末・設定（Apple Intelligence 未有効等）によって使えないことがある
  （`SystemLanguageModel.default.availability`）。使えないときは理由を表示し、コレクション保存自体は続行する
- シミュレータでは Vision の分類器と Foundation Models の生成がどちらも失敗する。実機でしか AI 部分は検証できない
  （[handbook/build-and-test.md](../handbook/build-and-test.md) 参照）

## 再評価のタイミング

- 実機で Foundation Models の絵画同定精度を確認し、実用に耐えないと分かった場合、
  Claude API 等を任意のフォールバックとして併用する設計に見直す
