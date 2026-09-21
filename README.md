# iOS Project Template

iOS アプリ開発のためのテンプレートプロジェクトです。XprojGen を使用してプロジェクトを生成し、コード品質管理やCI/CDが事前設定されています。

## 🚀 使用方法

### プロジェクト生成

```bash
# 通常のディレクトリ構造
mint run akidon0000/XprojGen xprojgen MyAwesomeApp

# フラットなディレクトリ構造
mint run akidon0000/XprojGen xprojgen MyAwesomeApp --flat
```

## ⚙️ 事前設定されている機能

### コード品質管理

- **SwiftLint**: コーディング規約の自動チェック
  - 設定ファイル: `.swiftlint.yml`
  - 130以上のルールが事前設定済み

- **Swift-format**: コードフォーマットの自動整形
  - 設定ファイル: `.swift-format`
  - インデント、行長、スペースなどを統一

### CI/CD ワークフロー

- **SwiftLint チェック**: プルリクエスト時の自動コード品質チェック
- **Swift-format チェック**: プルリクエスト時の自動コードフォーマット適用
- **Danger**: プルリクエストの自動レビュー

### GitHub テンプレート

- **プルリクエストテンプレート**: Issue番号、説明、スクリーンショット項目を含む
- **イシューテンプレート**: バグレポート用のテンプレート

## 📁 ディレクトリ構造

```
ios-project-template/
├── .github/
│   ├── workflows/           # GitHub Actions ワークフロー
│   ├── PULL_REQUEST_TEMPLATE/
│   └── ISSUE_TEMPLATE/
├── .swiftlint.yml          # SwiftLint 設定
├── .swift-format           # Swift-format 設定
├── .gitignore              # Git 除外設定
└── Dangerfile.swift        # Danger 設定
```

## 🔧 セットアップ要件

### 必要なツール

- **Mint**: Swift パッケージマネージャー
  ```bash
  brew install mint
  ```

### 自動化

- プルリクエスト作成時に自動でSwiftLintとSwift-formatがチェックされます
- Dangerが追加のプルリクエストレビューを実行します

## 📄 ライセンス

このテンプレートは自由にご利用いただけます。生成されたプロジェクトのライセンスは各プロジェクトでご設定ください。

