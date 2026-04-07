# 決定項目チェックリスト

setup-plan のインタビューで「漏れなく」聞くための、技術スタック別チェックリスト集。
各項目は **二択 + その他** または **狭い選択肢** の形式で1つずつ確認する。漠然とした「方針は？」という聞き方は禁止。

## 使い方

1. ユーザーから技術スタックを聞き出す（質問 1〜2）
2. 該当するカテゴリのチェックリストを抽出
3. 関係ないカテゴリ（例: フロントエンドが無いプロジェクトでは [フロントエンド] を除外）は削る
4. カテゴリごとに項目を順番に確認
5. 各項目には「デフォルト推奨」を提示し、ユーザーが選びやすくする

---

## [共通]

| 項目 | 選択肢 | 補足 |
|---|---|---|
| パッケージマネージャ | 言語標準 / 代替ツール | 例: Node なら npm/pnpm/yarn/bun, Python なら pip/poetry/uv/rye, Rust なら cargo |
| ランタイムバージョン管理 | mise / asdf / volta / 言語標準 / なし | devcontainer 内で固定するなら不要な場合も |
| エディタ統合 | VS Code 拡張一式 / なし | linter, formatter, 型チェッカーの拡張 |

---

## [フロントエンド]（Web UI がある場合）

| 項目 | 選択肢 | デフォルト推奨の例 |
|---|---|---|
| ビルドツール | Vite / Next.js / Remix / Astro / その他 | スタックによる |
| 単体テスト | Vitest / Jest / その他 | Vite なら Vitest |
| コンポーネントテスト | Testing Library / その他 | 上記と組み合わせ |
| E2E テスト | Playwright / Cypress / なし | Playwright |
| **ビジュアルリグレッション (VRT) の有無** | あり / なし | 製品開発ならあり |
| VRT ツール（あり時） | Chromatic（外部SaaS） / reg-suit（セルフホスト） / Playwright snapshot / Lost Pixel | 規模・予算で選択 |
| UI カタログ | Storybook / Ladle / なし | 製品開発なら Storybook |
| Storybook デプロイ先 | Chromatic / GitHub Pages / Vercel / なし | VRT に Chromatic 使うなら同じ |
| API 型生成 | OpenAPI から自動 / 手書き / GraphQL Codegen | バックエンドのAPI定義方針に依存 |
| Lint | ESLint / Biome | Biome は format も兼ねる |
| Format | Prettier / Biome / dprint | |
| バンドルサイズ監視 | size-limit / bundlesize / なし | 製品開発なら推奨 |
| 国際化 (i18n) | あり / なし | あり時はライブラリも決める |
| アクセシビリティテスト | axe / なし | |

---

## [バックエンド]（API サーバー等がある場合）

| 項目 | 選択肢 | 補足 |
|---|---|---|
| 単体テスト | 言語標準 / 代替ツール | Rust なら cargo test / nextest, Python なら pytest / unittest, Go なら go test / testify |
| 統合テスト | 言語内（testcontainers 等） / 言語非依存（Postman+Newman, Hurl, k6） / なし | |
| **API スキーマの管理方針** | スキーマファースト（OpenAPI 手書き → 実装） / コードファースト（コードから自動生成） / なし | |
| API ドキュメント公開 | Swagger UI / Redoc / Scalar / なし | |
| マイグレーションツール | sqlx-cli / sea-orm-cli / refinery / diesel / Alembic / Flyway / Liquibase / Prisma migrate | 言語・ORM による |
| マイグレーション実行タイミング | アプリ起動時 / CI で実行 / 手動 | |
| ロギング | tracing / log / structlog / zap / その他 | |
| エラー型 | 言語慣習に従う | Rust なら thiserror/anyhow |
| Lint | clippy / ruff / golangci-lint / その他 | |
| Format | rustfmt / black or ruff format / gofmt / その他 | |
| 認証・認可 | 自前 / Auth0 / Clerk / Supabase Auth / なし | |

---

## [データストア・インフラ]

| 項目 | 選択肢 | 補足 |
|---|---|---|
| RDBMS | PostgreSQL / MySQL / SQLite / なし | 具体バージョンも確認 |
| ORM / クエリビルダ | sqlx / sea-orm / diesel / Prisma / SQLAlchemy / 生 SQL / その他 | |
| **テスト用 DB** | 本番と同インスタンス / tmpfs で別インスタンス / SQLite で代替 | tmpfs は高速 |
| キャッシュ層 | Redis / Valkey / Memcached / なし | |
| メッセージキュー | RabbitMQ / NATS / Kafka / SQS / なし | |
| メール送信 | あり / なし | あり時のローカルは MailHog / Mailpit |
| オブジェクトストレージ | S3 / MinIO / なし | ローカルは MinIO |
| 検索エンジン | Elasticsearch / Meilisearch / Typesense / なし | |
| マイグレーション初期データ | seed スクリプトあり / なし | |

---

## [CI/CD]

| 項目 | 選択肢 | 補足 |
|---|---|---|
| CI サービス | GitHub Actions / GitLab CI / CircleCI / その他 | |
| **PR で実行するジョブ**（個別に確認） | lint / format check / 型チェック / 単体テスト / 統合テスト / E2E / VRT / build / マイグレーション dry-run / セキュリティスキャン | 1個ずつ「これは PR で回しますか？」と確認 |
| main マージ時の追加ジョブ | Storybook デプロイ / API ドキュメント公開 / イメージ push / リリースタグ / なし | |
| マトリクスビルド | OS 別 / バージョン別 / なし | |
| キャッシュ戦略 | actions/cache 利用箇所を個別に | node_modules, cargo registry, target, etc |
| パイプライン実行時間計測 | あり / なし | |
| シークレット管理 | GitHub Secrets / OIDC / Vault / その他 | |

---

## [ドキュメント・Claude 設定]

| 項目 | 選択肢 |
|---|---|
| README に書く項目 | プロジェクト概要 / セットアップ手順 / 開発フロー / 主要コマンド |
| `.contexts/` に置くドキュメント | アーキテクチャ / ドメイン用語 / setup-plan.md / その他 |
| `CLAUDE.md` の有無と粒度 | プロジェクト全体 / サブディレクトリ別 |
| `.claude/settings.json` の permissions | 必要な bash コマンド許可リスト |
| `enabledPlugins` | 技術スタックから導出（例: rust なら rust-lsp, MySQL なら mysql MCP） |
| 必要な MCP サーバー | Context7 / DB MCP / その他 |

---

## チェックリスト適用例

### 例: 個人開発の React + axum + PostgreSQL プロジェクト

導出するカテゴリ: 共通 / フロントエンド / バックエンド / データストア / CI / ドキュメント

省略するカテゴリ: なし

「個人開発で勉強目的」と判明したら、各項目のデフォルト推奨は **学習コスト低 + モダン** 寄りに振る（例: VRT は「なし」をデフォルトに）。

### 例: 仕事のバックエンド単体プロジェクト（CLI + API）

導出するカテゴリ: 共通 / バックエンド / データストア / CI / ドキュメント

省略するカテゴリ: フロントエンド

「製品開発」と判明したら、デフォルト推奨は **品質担保重視** に振る（VRT, セキュリティスキャン, マトリクスビルドを「あり」寄りに）。

---

## 方針キーワード → 派生ライブラリ表

ユーザーがインタビューで「TDD で」「プロパティベース」「BDD」「Snapshot」「モック使う」「契約テスト」等の **抽象的な方針キーワード** を口にしたら、以下の表に従って **そのスタックで必要になる具体的なライブラリ** を即座に依存追加候補に積む。チェックリスト項目に登場しないキーワードでも、派生ライブラリは必ず拾う。

判定基準: **「明日その環境でユーザーがそのスタイルでコードを書こうとしたとき、追加で `cargo add` / `npm install` / `pip install` する必要があるか？」必要なら未完。**

| 方針キーワード | Rust | Python | TypeScript | Go |
|---|---|---|---|---|
| TDD | （派生なし、姿勢） | 同左 | 同左 | 同左 |
| プロパティベーステスト | `proptest` / `quickcheck` | `hypothesis` | `fast-check` | `gopter` / `rapid` |
| BDD | `cucumber` | `behave` / `pytest-bdd` | `@cucumber/cucumber` | `godog` |
| Snapshot テスト | `insta` (+ `cargo-insta`) | `syrupy` | Vitest 標準 / `jest-snapshot` | `cupaloy` |
| パラメタライズドテスト | `rstest` | `pytest.mark.parametrize` (標準) | `it.each` (Vitest 標準) | `t.Run` (標準) |
| モック | `mockall` / `mockito`(HTTP) | `pytest-mock` / `responses` | `vitest` mock / `msw` | `gomock` / `testify/mock` |
| 時刻モック | （手書き trait 抽象） | `freezegun` | `vi.useFakeTimers` (標準) | （interface 抽象） |
| HTTP モック | `mockito` / `wiremock` | `responses` / `httpx mock` | `msw` | `httptest` (標準) |
| カバレッジ計測 | `cargo-llvm-cov` / `cargo-tarpaulin` | `coverage` / `pytest-cov` | `vitest --coverage` (c8) | `go test -cover` (標準) |
| ベンチマーク | `criterion` | `pytest-benchmark` | `vitest bench` / `tinybench` | `testing.B` (標準) |
| 並行性テスト | `loom` | （限定的） | （限定的） | `go test -race` (標準) |
| 契約テスト | `pact-rust` | `pact-python` | `pact-js` | `pact-go` |
| 構造化ログ | `tracing` + `tracing-subscriber` | `structlog` | `pino` / `winston` | `slog` (標準) / `zap` |
| エラー型整理 | `thiserror` (lib) + `anyhow` (bin) | （標準 Exception + 型ヒント） | `neverthrow` / 自前 Result | `errors` + `errors.Is` |
| DI / IoC | `shaku` / 手書き trait DI | `dependency-injector` / 手書き | `tsyringe` / `inversify` | （手書き interface） |
| 依存性注入で疎結合 | 上記 | 上記 | 上記 | 上記 |
| 非同期ランタイム | `tokio` (features 明示) / `async-std` | `asyncio` (標準) / `trio` | （標準） | （標準） |
| OpenAPI からコード生成 | `utoipa` / `openapi-generator` | `datamodel-code-generator` | `openapi-typescript` / `orval` | `oapi-codegen` |
| マイグレーション | `sqlx-cli` / `sea-orm-cli` / `refinery` / `diesel_migrations` | `alembic` / `yoyo-migrations` | `prisma migrate` / `drizzle-kit` / `knex` | `golang-migrate` / `goose` |
| ファジング | `cargo-fuzz` / `afl` | `atheris` | `fast-check` | `go test -fuzz` (標準) |

**運用ルール**:

- 表にあるキーワードを聞いたら、対応するライブラリを **必ず** 依存追加候補に積む
- 表にないキーワードでも、同じ判定基準（追加 install が必要か）で派生ライブラリを推論する
- 複数の選択肢がある場合は、Phase C のチェックリストに「**X を実現するなら `Y` / `Z` どちらにしますか？**」という二択質問として組み込む
- 派生ライブラリも「ツール別セットアップ表」の①〜⑥をすべて埋める対象とする（依存追加だけで終わらせない）
