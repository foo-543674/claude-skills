# claude-skills

自分の設計思想・コードレビュー観点・実装方針を [Claude Skills](https://claude.com/blog/skills) として管理するリポジトリ。

## セットアップ

```bash
# スキルを ~/.claude/skills/ にコピー
./deploy.sh
```

スキルを更新した場合は再度 `deploy.sh` を実行してください。

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

### 開発レポート

| スキル | 説明 |
|-------|------|
| development-report | 各フェーズの成果物を統合した開発レポート生成 |

### コードレビュー

| スキル | 説明 |
|-------|------|
| review-naming | 命名規則・一貫性のレビュー |
| review-comments | コメントの書き方（Why vs What、過不足）のレビュー |
| review-variables | 変数・定数の取り扱い（マジックナンバー、スコープ）のレビュー |
| review-readability | コード構造の可読性（関数の長さ、ネスト、早期リターン）のレビュー |
| review-solid | SOLID 原則（単一責任、依存逆転、開放閉鎖等）のレビュー |
| review-component | コンポーネント指向設計（分割粒度、Props 設計、状態の局所化）のレビュー |
| review-functional | 関数型指向（純粋関数、イミュータビリティ、副作用の分離）のレビュー |
| review-error-handling | エラーハンドリング・異常系設計のレビュー |
| review-performance | パフォーマンス（N+1、不要な計算、メモリ）のレビュー |
| review-security | セキュリティ（インジェクション、認証認可）のレビュー |
| review-testing | テスト設計・テストの質のレビュー |
| review-architecture | アーキテクチャ設計（レイヤー分離、依存方向、CQRS）のレビュー |
| review-api-design | API設計（エンドポイント命名、リクエスト・レスポンス構造、冪等性）のレビュー |
| review-type-design | 型設計（不正状態の排除、判別共用体、Branded Type）のレビュー |
| review-data-modeling | データモデリング（正規化、リレーション、マイグレーション、履歴管理）のレビュー |
| review-state-design | 状態設計（ステートマシン、状態正規化、楽観的更新）のレビュー |
| review-dependency | 依存関係設計（ライブラリ選定、循環依存、抽象化、バージョン管理）のレビュー |
| review-concurrency | 並行処理設計（レースコンディション、トランザクション境界、リトライ戦略）のレビュー |
| review-report | 各レビュー観点の結果を統合したレポート生成 |

### その他

| スキル | 説明 |
|-------|------|
| commit-message | コミットメッセージの生成・コミット粒度の判断 |

## 参考

- [Claude Skills 公式ブログ](https://claude.com/blog/skills)
- [Claude Code Skills ドキュメント](https://code.claude.com/docs/en/skills)
