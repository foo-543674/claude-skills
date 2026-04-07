# 技術スタック別の導出ガイド

インタビュー結果から計画書の具体物を導出する際の参考。ここに書かれていないものでも、技術スタックのベストプラクティスとして必要なものは積極的に計画書に含める。

## 導出の原則

1. **ユーザーが明示した方針** → 最優先で反映
2. **技術スタックのベストプラクティス** → 暗黙的に含める（ユーザーが計画書上で削除・調整可能）
3. **philosophy.md の思想** → 判断に迷ったときの指針
4. **ツールは適材適所** → 1つのツールに複数責務を担わせない。特にマイグレーションは SQL ベースツールを優先（philosophy.md 参照）

## プロジェクト種別ごとの考慮事項

### フロントエンド（React, Vue, Svelte 等）

**devcontainer**:
- Node.js ランタイム（features で追加）
- パッケージマネージャー（npm / pnpm / yarn）
- VS Code 拡張: 言語サポート、linter、formatter、テストランナー

**ローカルインフラ**:
- API モックサーバー（バックエンドが別チームの場合）
- Storybook 用のビルド環境

**CI**:
- lint + 型チェック + ユニットテスト
- Storybook ビルド + デプロイ（Chromatic 等）
- ビジュアルリグレッションテスト
- E2E テスト（ユーザーストーリーベース、最小限）
- バンドルサイズチェック
- Lighthouse CI（パフォーマンス監視）

**ドキュメント**:
- Storybook（コンポーネントカタログ兼ドキュメント）
- README（セットアップ手順）

### バックエンド API（Express, FastAPI, Go 等）

**devcontainer**:
- 言語ランタイム（features で追加）
- DB クライアント CLI（psql, mysql 等）
- API テストツール

**ローカルインフラ**:
- DB（PostgreSQL, MySQL 等）
- キャッシュ（Redis 等、必要に応じて）
- メールサーバー（mailpit 等、メール機能がある場合）
- オブジェクトストレージ（MinIO 等、ファイルアップロードがある場合）

**CI**:
- lint + 型チェック + ユニットテスト
- 統合テスト（言語非依存: Postman/Newman）
- API スキーマのバリデーション（OpenAPI lint 等）
- セキュリティスキャン（依存パッケージ脆弱性）
- API ドキュメント生成 + デプロイ

**ドキュメント**:
- OpenAPI / Protocol Buffers（スキーマファースト）
- API ドキュメント（Swagger UI / Redoc 等、ブラウザで確認可能にデプロイ）
- README（セットアップ手順、API 概要）

### フルスタック（Next.js, Nuxt, SvelteKit 等）

上記フロントエンド + バックエンドの両方を含む。加えて:

**CI**:
- フロントエンド・バックエンド両方の lint + テスト
- E2E テスト（フルスタックとして統合的に）
- SSR / SSG のビルドチェック

### CLI ツール / ライブラリ

**devcontainer**:
- 言語ランタイム
- 配布用ビルドツール

**CI**:
- lint + 型チェック + ユニットテスト
- マトリクステスト（複数バージョン対応の場合）
- パッケージビルド + ドライラン公開
- CHANGELOG 生成

**ドキュメント**:
- README（使い方、API リファレンス）
- 必要に応じて静的サイト（VitePress, Docusaurus 等）

### GAS（Google Apps Script）

**devcontainer**:
- Node.js ランタイム
- clasp CLI
- TypeScript 環境

**CI**:
- lint + 型チェック
- ユニットテスト（ビジネスロジック部分）
- clasp push（CD として）

## 共通で常に含めるもの

以下は技術スタックに関係なく、全プロジェクトで計画書に含める:

**devcontainer**:
- `docker-outside-of-docker` feature（必須）
- `.gitattributes`（改行コード統一: `* text=auto eol=lf`）
- 保存時自動フォーマット設定

**Claude 設定**:
- `.claude/settings.json`:
  - `permissions.allow` / `deny`: 技術スタックで頻用する bash コマンドを許可
  - `enabledPlugins`: **このリポジトリで開発する人全員に必要なプラグインを固定する**。現在の Claude Code セッションにインストール済みのプラグインを問うのではなく、技術スタックから導出して提案する
- `CLAUDE.md`: プロジェクト固有のコンテキスト（アーキテクチャ概要、開発フロー、コマンド一覧等）

**enabledPlugins の導出例**（技術スタックから導出する。インストール済みプラグインは聞かない）:

| 技術スタック要素 | 導出されるプラグイン例 |
|---|---|
| Rust | `rust-lsp` プラグイン |
| Go | `go-lsp` 系プラグイン |
| TypeScript / Node.js | `typescript-lsp` 系プラグイン |
| MySQL を使用 | `mysql` MCP プラグイン |
| PostgreSQL を使用 | `postgres` MCP プラグイン |
| Terraform を使用 | `terraform` MCP プラグイン |
| AWS を使用 | `aws-docs` MCP プラグイン |
| GitHub Actions / PR レビュー多用 | `github` MCP プラグイン |

**正式名称の照合手順**（プレースホルダで終わらせず、可能な限り実名を埋める）:

1. 上表で技術スタックに該当する候補を列挙
2. ローカルのマーケットプレイスカタログを Read / Glob で走査して実在確認:
   - `~/.claude/plugins/cache/**/plugin.json`
   - `~/.claude/settings.json` の `extraKnownMarketplaces` から辿れる各 `marketplace.json`
3. 見つかれば `<plugin-name>@<marketplace-name>` 形式で計画書に記載
4. 見つからなければプレースホルダ + 注記（「既知マーケットプレイスに存在しないため別途検索が必要」）

**CI**:
- テスト実行速度の計測（CI の実行時間をトラッキング）
- テストレポートのブラウザ公開

**ドキュメント**:
- README（セットアップ手順、開発フロー）
- `.contexts/` に計画書自体と判断背景を配置
