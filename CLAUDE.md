# foo-skills プラグイン

ソフトウェア開発の各フェーズ（要件定義・設計・実装・レビュー・環境構築）を支援するスキルとエージェント。

## 開発ライフサイクルとの対応

```
要件定義 ─→ 設計 ─→ 実装 ─→ レビュー
                              ↓
requirements-*   design-*   implement-*   code-reviewer (agent)
                                           ↑
環境構築（実装より先に整備する）           commit-message
setup-plan → setup-*                       development-report
```

### スキル一覧

**要件定義**: ユーザーとの対話を通じて要件を明確にする
- `requirements-elicitation`: 曖昧な要求から具体的な要件を引き出す
- `requirements-specification`: 引き出した要件を受け入れ基準・非機能要件として仕様化する

**設計**: 要件をもとに技術的な設計を行う。code-reviewer の観点を先取りして設計に組み込む
- `design-architecture`: レイヤー構成、技術選定、境界定義、CQRS 適用判断
- `design-data-model`: エンティティ識別、リレーション設計、正規化、マイグレーション
- `design-api`: エンドポイント設計、リクエスト・レスポンス構造、バージョニング
- `design-component`: モジュール・コンポーネントの責務分割とインターフェース設計

**環境構築**: 製品コードの実装より先に整備する技術基盤
- `setup-plan`: インタビューで構築すべきものを洗い出し、計画書を `.contexts/` に出力する（最初に使う）
- `setup-devcontainer`: コンテナベースの開発環境
- `setup-ci`: CI/CD パイプライン（GitHub Actions）
- `setup-local-infra`: ローカル開発用インフラ（DB、キャッシュ等を docker compose で構築）

**実装**: テストファーストで段階的に実装する
- `implement-feature`: Red-Green-Refactor サイクルでの機能実装
- `implement-testing`: テスト戦略の策定とテスト実装
- `implement-refactor`: 影響範囲の分析と安全なリファクタリング

**その他**
- `commit-message`: git diff を分析し、適切な粒度でステージング・コミットメッセージ生成
- `development-report`: 要件定義・設計・実装の成果物を統合した開発レポート生成

### エージェント

**コードレビュー**: `code-reviewer`
- 変更ファイルの種類に応じて 18 のレビュー観点から関連するものを自動選択し、統合レビューレポートを生成する
- 技術品質（Security, Testing, Error Handling 等）と製品品質（Naming, Readability, SOLID 等）の 2 カテゴリで評価し、技術品質を優先する
- コードレビューを依頼されたとき、自動的に起動される

## 使い方

- 各スキルは `/foo-skills:<skill-name>` で明示的に呼び出せる
- ユーザーの作業内容に応じて自動的に関連するスキルやエージェントが選択されることもある
- 設計スキルと code-reviewer の観点は対になっている（例: `design-architecture` ↔ architecture 観点）。設計時にレビュー観点を先取りし、レビューで指摘される問題を事前に回避する
