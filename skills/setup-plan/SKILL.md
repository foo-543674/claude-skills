---
name: setup-plan
description: 空のリポジトリから何を構築すべきかをインタビュー形式で整理し、開発環境・ローカルインフラ・CIの構築計画書を出力する。新規プロジェクトの環境構築を始めるとき、環境を一から整えたいときに使う。
---

# 環境構築計画

新規プロジェクトの環境構築に必要なものを、インタビューで漏れなく洗い出し、AI が実行可能な計画書として `.contexts/` に出力する。

## Why: なぜ計画書が必要か

環境構築の「忘れてた」は、個別の設定漏れではなく **構築すべきもの自体の洗い出し漏れ** から起きる。フロントエンドの開発環境を作ったが Storybook のデプロイパイプラインを忘れた、API サーバーを構築したが統合テスト環境や API ドキュメント生成を考慮していなかった、といった問題。

事前にドキュメントを書いても、技術スタックごとに必要なものが異なるため網羅しきれない。インタビューで方針を引き出し、技術スタックのベストプラクティスと掛け合わせることで、漏れを構造的に防ぐ。

## スコープ

**含む**: devcontainer、ローカルインフラ、CI パイプライン、ドキュメント戦略
**含まない**: CD パイプライン（デプロイ先によって大きく変わるため別スキルで扱う）

## プロセス

### 0. リポジトリ現状調査

**インタビューの前に、現在のリポジトリの状態を調査する。**

以下を確認し、結果をユーザーに共有してからインタビューに進む:

1. **できているもの**: 既に存在する設定・構成ファイル（devcontainer、docker-compose、CI、CLAUDE.md 等）
2. **できていないもの**: 技術スタックから推測して欠けているもの
3. **できているが不適切なもの**: 存在するが改善が必要なもの（非推奨な設定、philosophy.md の思想に反する構成等）

調査対象:
- プロジェクトルートのファイル構成（package.json, Cargo.toml, go.mod 等から技術スタックを把握）
- `.devcontainer/` の有無と内容
- `docker-compose*.yml` の有無と内容
- `.github/workflows/` の有無と内容
- `.claude/` の有無と内容（settings.json, CLAUDE.md）
- linter / formatter / テストの設定ファイル
- マイグレーション関連の構成

調査結果は以下の形式で共有する:

```
【リポジトリ現状】
✅ できているもの: [一覧]
❌ できていないもの: [一覧]
⚠️ 改善が必要なもの: [一覧と理由]
```

この結果を踏まえて、インタビューでは不足部分や改善部分に焦点を当てる。既にできている部分について冗長な質問はしない。

### 1. インタビュー

**1ターン1質問。オープン形式で方針を引き出す。**

以下の順序でインタビューを進める。各質問は1つずつ投げ、回答を受けてから次に進む。

#### 質問 1: プロジェクトの目的

何を作るか、その背景・目的を聞く。合わせてプロジェクトの性質（仕事/個人、製品開発/勉強目的）も把握する。これにより技術選定の判断基準が変わる。

#### 質問 2: 技術スタック

言語・フレームワークを聞く。決まっていれば確認、未定なら目的・制約から一緒に考える。

#### 質問 3: テストの方針

テストについてどう考えているかをオープンに聞く。回答から単体・統合・E2E・ビジュアルリグレッション等の方針を把握する。

#### 質問 4: API・ドキュメントの方針

API 設計のアプローチ（スキーマファースト等）やドキュメントの方針を聞く。

#### 質問 5: CI の方針

CI ツール、自動化したいこと、重視することを聞く。

#### 質問 6: ローカルインフラ

開発・テストに必要な外部サービス（DB、キャッシュ、メール等）を聞く。

#### 質問 7: 抜け漏れ確認

ここまでの回答を簡潔に要約し、他に考慮すべきことがないか確認する。

### 2. 計画書の導出

インタビュー結果をもとに、計画書を導出する。

**導出の原則**:

1. **ユーザーが明示した方針を最優先で反映する**
2. **技術スタックのベストプラクティスから必要な具体物を推論し、暗黙的に含める**: 「この言語・FW ならこれは必要」というものはユーザーが言及しなくても入れる
3. **`resources/philosophy.md` の思想を判断の指針にする**: テスト戦略、レビュー体験、ドキュメント方針等
4. **`resources/derivation-guide.md` を参照し、プロジェクト種別に応じた考慮事項を網羅する**
5. **「ツールを選定する」ではなく「動く環境を作る」**: 各ツールについて、それが実際に「コマンド一発で動く」状態まで必要な構成要素をすべて洗い出す（後述）

**「動く環境」の定義**:

ツールを選定したら、そのツールが **明日その環境を触る開発者が `<起動コマンド>` を実行するだけで使い始められる** 状態まで揃えることをセットアップのゴールとする。具体的には以下のすべてが揃って初めて完了:

| 要素 | 内容 |
|---|---|
| ① 依存追加 | マニフェスト（package.json, Cargo.toml 等）に依存・バージョンを記載 |
| ② 設定ファイル | ツール固有の設定ファイル（`.storybook/main.ts`, `vitest.config.ts`, `eslint.config.js`, `sqlx-data.json`, `migrations/` 等）を生成 |
| ③ 初期スキャフォールド | ツールが動くために必要な最小の入力（サンプルストーリー、サンプルテスト、初期マイグレーション、エントリポイント等） |
| ④ 起動・実行スクリプト | `package.json` scripts や `justfile`/`Makefile`/`cargo` エイリアス等の実行入口 |
| ⑤ devcontainer / CI への組み込み | ローカルでもCIでも同じコマンドで動くこと（必要なシステム依存・サービスも含めて） |
| ⑥ 動作確認手順 | 「このコマンドを実行してこの結果が出れば OK」という検証ステップ |

**①〜⑥のうち1つでも欠けたら「セットアップ未完」と判定する。** 「Storybook を package.json に書いた」だけは①しか満たしておらず、Storybook はまだ起動しない。

**AI が補完する例**:

| ユーザーの回答 | 「動く環境」として導出する具体物 |
|---|---|
| 「Storybook を使う」 | ① `storybook`, `@storybook/react-vite` 等を devDependencies に追加 / ② `.storybook/main.ts`, `.storybook/preview.ts` を生成 / ③ `src/components/Button.stories.tsx` 等の最小サンプルストーリー / ④ `npm run storybook`, `npm run build-storybook` を scripts に追加 / ⑤ devcontainer のポートフォワード、CI で `build-storybook` を実行 / ⑥ `npm run storybook` で 6006 番にアクセスしてサンプルが表示される |
| 「Vitest でユニットテスト」 | ① `vitest`, `@vitest/ui`, `jsdom` 等 / ② `vitest.config.ts`（環境・カバレッジ設定） / ③ `src/__tests__/sample.test.ts` / ④ `test`, `test:watch`, `test:coverage` scripts / ⑤ CI の test ジョブ / ⑥ `npm test` でサンプルがグリーン |
| 「sqlx-cli でマイグレーション」 | ① `Cargo.toml` に `sqlx` 依存と features（`postgres`, `runtime-tokio`, `macros` 等）追加 / ② `sqlx-cli` を devcontainer features か `cargo install sqlx-cli` で導入、`.env` に `DATABASE_URL` / ③ `migrations/` ディレクトリと初回マイグレーションファイル / ④ `cargo sqlx migrate run`, `cargo sqlx migrate add <name>` の実行手順、`justfile` 等に登録 / ⑤ docker-compose で PostgreSQL を起動、CI でマイグレーション実行ジョブ / ⑥ `sqlx migrate run` が成功し、`sqlx migrate info` で適用済みと表示 |
| 「ESLint + Prettier」 | ① 依存追加 / ② `eslint.config.js`, `.prettierrc`, `.prettierignore` / ③ ルール設定（既存の philosophy に沿った推奨セット） / ④ `lint`, `lint:fix`, `format` scripts / ⑤ CI の lint ジョブ、editor 設定（`.vscode/settings.json`） / ⑥ `npm run lint` がパスする |

**重要**: 計画書を導出するとき、選定した各ツールについて上記①〜⑥の表を頭の中で必ず埋める。埋まらない要素があれば「未完」として計画書に明記し、構築タスクに含める。

### 3. 計画書の出力

`.contexts/setup-plan.md` に計画書を出力する。`.contexts/` ディレクトリが存在しない場合は作成する。

## 計画書テンプレート

```markdown
# 環境構築計画: [プロジェクト名]

## プロジェクト概要

- 目的: [何を作るか]
- 性質: [仕事/個人、製品開発/勉強目的]
- 技術スタック: [言語、FW、主要ライブラリ]

## 方針サマリ

[インタビューで引き出した方針の要約。テスト戦略、API 方針、CI 方針等]

## devcontainer

### ベースイメージ
[選定理由付きで記載]

### features
[必要な features のリスト。各 feature の目的を記載]

### VS Code 拡張
[言語サポート、linter、formatter、テストランナー等]

### ツールチェーン
[linter、formatter、型チェッカーの構成と設定方針]

### ポートフォワーディング
[アプリケーション、DB、管理画面等のポート]

## ツール環境のセットアップ

**「ツールを選んだ」で終わらせない。各ツールについて、開発者が `<起動コマンド>` を実行するだけで動く状態まで構築する。**

選定した各ツール（lint/format/test/Storybook/マイグレーション/型生成/バンドル/ドキュメント生成 等）について、以下の①〜⑥をすべて埋める:

### ツール別セットアップ表

| ツール | ① 依存（マニフェスト） | ② 設定ファイル | ③ 初期スキャフォールド | ④ 実行スクリプト | ⑤ devcontainer/CI 統合 | ⑥ 動作確認コマンドと期待結果 |
|---|---|---|---|---|---|---|
| [ツール名] | [追加する依存とバージョン] | [生成する設定ファイルパス] | [サンプルファイル] | [scripts/タスク名] | [必要なシステム依存・ジョブ] | [コマンド + 期待結果] |

**埋められないマスがあれば「未完」と明記し、構築タスクに残す。**

### マニフェストファイル

対象（技術スタックから導出）: `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Gemfile`, `composer.json` 等

各マニフェストに記載するもの:

- **依存関係**: 上記表①の総和
- **スクリプト/タスク**: 上記表④の総和（`package.json` scripts, `cargo` エイリアス, `justfile`, `Makefile` 等）
- **メタデータ**: name, version, license, repository
- **言語・ランタイムバージョン制約**: `engines`, `rust-version`, `requires-python` 等

### 設定ファイル・スキャフォールド一覧

上記表②③で挙げた成果物のパスを一覧化する。例:

- `.storybook/main.ts`, `.storybook/preview.ts`
- `vitest.config.ts`, `src/__tests__/sample.test.ts`
- `eslint.config.js`, `.prettierrc`
- `migrations/0001_init.sql`
- `openapi.yaml`, `scripts/generate-types.sh`

## ローカルインフラ

### サービス構成
[必要なサービスのリスト。各サービスのイメージ・バージョン・ポート・用途]

### テスト用インフラ
[テスト専用のサービス構成。tmpfs 等の高速化設定]

### 初期データ・マイグレーション
[初期化スクリプト、シードデータの方針]

### 操作コマンド
[起動・停止・リセット・ログのコマンド体系]

## CI パイプライン

### トリガー
[PR 時、main マージ時等]

### ジョブ構成
[各ジョブの目的、実行内容、依存関係、並列化戦略]

### 成果物のデプロイ
[Storybook、テストレポート、API ドキュメント等のデプロイ先と方法]

### 実行速度の計測
[パイプライン実行時間のトラッキング方法]

## ドキュメント

### 人間用
[README の構成、API ドキュメントの形式と公開方法]

### AI 用
[.contexts/ に配置するドキュメントの一覧と目的]

### ツール化ドキュメント
[OpenAPI、Protocol Buffers 等、コード生成やバリデーションに活用する形式]

## Claude 設定

### .claude/settings.json
[許可コマンド（permissions.allow / deny）、環境変数、フック等。技術スタックに応じて必要な bash コマンドを許可]

### enabledPlugins（リポジトリで開発する人全員に必要なプラグイン）
[このリポジトリの技術スタックから導出し、開発者全員が使うべきプラグインを列挙する。
例: Rust → rust-lsp プラグイン、MySQL → mysql MCP、Terraform → terraform MCP 等。

導出手順:
1. 技術スタックからプラグイン候補を列挙
2. ローカルのマーケットプレイスカタログ（`~/.claude/plugins/cache/**/plugin.json`、および `~/.claude/settings.json` の `extraKnownMarketplaces` から辿れる各 `marketplace.json`）を Read で走査して実在確認
3. 見つかれば `<plugin>@<marketplace>` 形式で記載、無ければプレースホルダ + 注記

`.claude/settings.json` の `enabledPlugins` に固定してリポジトリにコミットする]

### CLAUDE.md
[プロジェクト固有のコンテキスト。アーキテクチャ概要、開発フロー、主要コマンド]

## .gitignore

[技術スタックから導出される ignore パターン。言語固有（node_modules, target, __pycache__, vendor 等）、エディタ・OS（.DS_Store, .idea, .vscode の例外）、ビルド成果物、ローカル環境ファイル（.env.local 等）、テスト成果物（coverage, .nyc_output 等）を網羅する]

## 構築タスク

以下の順序で構築する。各タスクは対応する setup-* スキルに委譲する。
リポジトリ現状調査で「できている」と判定されたタスクはスキップする。

1. [ ] devcontainer の構築 → `setup-devcontainer` スキル
2. [ ] ローカルインフラの構築 → `setup-local-infra` スキル
3. [ ] **ツール環境のセットアップ**: 「ツール別セットアップ表」の各行について①〜⑥をすべて完了
   - [ ] ① マニフェスト（package.json, Cargo.toml 等）に依存・スクリプト追加
   - [ ] ② 各ツールの設定ファイル生成（`.storybook/`, `vitest.config.ts`, `eslint.config.js`, `migrations/` 等）
   - [ ] ③ 初期スキャフォールド（サンプルストーリー、サンプルテスト、初回マイグレーション等）
   - [ ] ④ 起動・実行スクリプトの登録
   - [ ] ⑥ 各ツールの起動コマンドを実行し、表⑥の期待結果と一致することを確認
4. [ ] CI パイプラインの構築 → `setup-ci` スキル（上記④のスクリプトをそのまま呼ぶ）
5. [ ] .gitignore の作成
6. [ ] Claude 設定の構築（.claude/settings.json の permissions と enabledPlugins、CLAUDE.md）
7. [ ] ドキュメントの初期構成
8. [ ] エンドツーエンド動作確認: devcontainer 再ビルド → インフラ起動 → 依存インストール → 各ツールの起動コマンドを順に実行 → CI 実行 → すべてグリーン
```

## 計画書出力後のフロー

計画書を出力したら、ユーザーに以下を伝える:

1. 計画書のパス（`.contexts/setup-plan.md`）
2. 計画書の内容を確認・調整してから、Claude に @ で渡して構築を依頼できること
3. 構築は計画書の「構築タスク」セクションの順序で進めること
