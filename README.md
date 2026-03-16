# claude-skills

自分の設計思想・コードレビュー観点・実装方針を [Claude Code プラグイン](https://docs.anthropic.com/en/docs/claude-code/plugins) として管理するリポジトリ。

## セットアップ

```bash
claude plugin install github:foo-543674/claude-skills
```

アンインストール:

```bash
claude plugin uninstall claude-skills
```

## スキル一覧

### 要件定義

| スキル | 説明 |
|-------|------|
| requirements-elicitation | 曖昧な要求から具体的な要件を引き出し整理する |
| requirements-specification | 要件を受け入れ基準・境界条件・非機能要件として仕様化する |

### 設計

| スキル | 説明 |
|-------|------|
| design-architecture | アーキテクチャ設計（レイヤー構成、技術選定、境界定義、CQRS 適用判断） |
| design-data-model | データモデル設計（エンティティ識別、リレーション、正規化、マイグレーション） |
| design-api | API 設計（エンドポイント、リクエスト・レスポンス、エラー、バージョニング） |
| design-component | コンポーネント設計（責務分割、インターフェース、依存関係） |

### 環境構築

| スキル | 説明 |
|-------|------|
| setup-devcontainer | コンテナベースの開発環境構築（devcontainer） |
| setup-ci | CI/CD パイプライン構築（GitHub Actions ベース、既存ツール優先） |
| setup-local-infra | ローカル開発用インフラのコンテナ構築（DB、キャッシュ等） |

### 実装

| スキル | 説明 |
|-------|------|
| implement-feature | テストファーストで機能を実装する（Red-Green-Refactor） |
| implement-testing | テスト戦略の策定とテストの実装 |
| implement-refactor | 既存コードの安全なリファクタリング |

### その他

| スキル | 説明 |
|-------|------|
| commit-message | コミットメッセージの生成・コミット粒度の判断 |
| development-report | 各フェーズの成果物を統合した開発レポート生成 |

## エージェント

| エージェント | 説明 |
|-------------|------|
| code-reviewer | 変更コードに対して 17 観点から関連するものを自動選択し、統合レビューレポートを生成する |

### code-reviewer のレビュー観点（17 観点）

**技術品質**（優先）: Architecture, Security, Testing, Error Handling, Performance, Concurrency, Type Design, Data Modeling, Dependency

**製品品質**: Naming, Comments, Variables, Readability, SOLID, Functional, Component, API Design, State Design

## 参考

- [Claude Code Plugins ドキュメント](https://docs.anthropic.com/en/docs/claude-code/plugins)
