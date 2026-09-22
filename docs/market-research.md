# 市場調査とターゲット像

- 読み手: このリポジトリで作業する自分・エージェント
- 目的: 機能の優先順位を判断するための、競合とターゲット像の言語化
- 位置づけ: 2026-09-22 に Web 調査を元に作成。実装計画ではない。示唆は [roadmap.md](roadmap.md) に反映する

## 結論

Meguri の空いている位置は「**AI による同定・解説**」と「**個人の旅の記録**」の掛け合わせ。
既存アプリはどちらか一方しかやっていない。

- Artlas・Smartify・PINTOR は「その場で解説を読んで終わり」。撮った記録が自分のコレクションとして
  蓄積される設計ではない
- たびのしるし・経県値は「行った場所を記録して振り返る」が、写真に写っている対象が何かを教えてはくれない
- Meguri は同定・解説をした上でそれを `Entry` としてローカルに蓄積し、後から見返せる。この組み合わせを
  やっているアプリは調査した範囲では見つからなかった

もう一つの軸は **完全オンデバイス** であること。Artlas 等は自社サーバー経由の AI 処理が前提とみられるが、
Meguri は Foundation Models のみで完結し、写真が端末外に出ない（[ADR-0002](adr/0002-on-device-ai-only.md)）。
Apple が 2026 年もプライバシーを軸に on-device AI を推している追い風はあるが、裏を返すと
**Apple Intelligence 対応端末（iOS 26+・対応機種）しか使えない** という配布上の制約でもある。

## 競合

| アプリ | やること | Meguri との違い |
|---|---|---|
| [Artlas](https://www.artlas.art/ja) | 撮影→AI音声ガイドで作者・背景を解説。500+施設対応、多言語、オフライン対応 | 記録として蓄積されない。AI処理はサーバー側とみられる |
| [Smartify](https://paintingrecognition.com/blog/artscan-vs-smartify-museum-app-comparison.html) | 提携700施設限定の公式音声ガイド | 提携施設でしか使えない。Meguri は場所を問わない |
| ArtScan | AI画像認識でどの絵画かを同定（提携不要） | 絵画限定。風景・建物は対象外 |
| [PINTOR](https://apps.apple.com/jp/app/id1482655341) | 8000人・10万作品からのレコメンド、様式やモチーフで探索 | 検索・発見が主目的で、自分で撮った写真の記録ではない |
| [たびのしるし](https://tabinosirusi.click/) / 経県値 | 訪れた都道府県・国を地図で塗って可視化 | 「何を見たか」ではなく「どこに行ったか」の記録。写真の中身は問わない |

## ターゲットペルソナ

### ペルソナ1: 旅先で足を止めるが、説明を読まずに通り過ぎる人

美術館や旅先で気になる作品・建物に出会うが、キャプションを読む・音声ガイドを借りるほどではないと感じて
そのまま通り過ぎ、後で「あれは何だったんだろう」となる層。写真だけは撮っている。
Meguri のコア体験（撮る→即座に解説→自動で記録に残る）が最も刺さる。

### ペルソナ2: 旅行記録アプリを使っているが、内容が薄いと感じている人

たびのしるし・経県値のようなアプリで「行った場所」は記録しているが、そこに何があったかは
写真フォルダに別で残っている状態の人。roadmap にある「旅タブ／場所タブ」（[roadmap.md](roadmap.md)）は
この層の「行った場所ごとに何を見たか振り返りたい」というニーズに対応する。

### ペルソナ3: プライバシー意識が高く、写真をクラウド AI に送りたくない人

母数は小さいが明確な差別化軸。「サーバーに送らない」を導入時に明示できるかが刺さるかどうかを分ける。
ただし Apple Intelligence 対応端末に限られるため、母数自体が当面小さいことは前提として持っておく
（[ADR-0002](adr/0002-on-device-ai-only.md) の制約と表裏）。

## ロードマップへの示唆

- 「外部 LLM API を選べるようにする」（[roadmap.md](roadmap.md)）は、解説の質だけでなく
  **Apple Intelligence 非対応端末でもアプリを使えるようにする** という配布面の理由が加わった。
  対応端末の少なさは今回の調査で見えた明確な制約なので、この項目の優先度メモとして残す
- 「旅タブ／場所タブ」はペルソナ2の裏付けが取れた。たびのしるし・経県値が地図×都道府県という
  可視化をしている点は、Meguri の「旅タブ」の見せ方を考えるときの参考になる
- 新規候補として「地図表示」を roadmap に追加した（下記）

## 参考文献

- [Artlas — 文化体験のためのAI搭載プラットフォーム](https://www.artlas.art/ja)
- [ArtScan vs Smartify: Museum Art Apps Compared](https://paintingrecognition.com/blog/artscan-vs-smartify-museum-app-comparison.html)
- [絵画鑑賞アプリ PINTOR -ピントル-](https://apps.apple.com/jp/app/id1482655341)
- [たびのしるし｜日本地図で行ったところを塗る・記録する旅行アプリ](https://tabinosirusi.click/)
- [世界で旅行系アプリの利用者数が拡大、日本は2年で3割増](https://www.travelvoice.jp/20180124-104493)
- [Apple doubles down on on-device AI in privacy and security masterstroke](https://macdailynews.com/2026/05/29/apple-doubles-down-on-on-device-ai-in-privacy-and-security-masterstroke-that-sets-it-apart-from-cloud-dependent-rivals/)
