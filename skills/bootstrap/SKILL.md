---
name: bootstrap
description: プロジェクトに AI が自走するためのコンテキスト基盤を構築する。新規プロジェクトの立ち上げ時、既存プロジェクトに AI コンテキストを導入するとき、「AI が自走できるようにして」と言われたときに使う。
---

# Bootstrap — AI 自走基盤の構築

プロジェクトに AI が自律的に開発を継続できるコンテキスト基盤を生成する。

このスキルの成果物は **プラグインの中ではなくプロジェクトの中** に生成される。生成後はプラグインがなくても、Claude Code / GitHub Copilot / Cursor / Gemini CLI / OpenAI Codex CLI 等どの AI ツールでもプロジェクトのコンテキストが機能する。

## Why

新しいプロジェクトを始めるとき、AI が開発を自走するための仕組み (CLAUDE.md、エージェント、フック、ルール) を人間がゼロから構築している。これは毎回繰り返される手作業であり、プロジェクトごとに品質がばらつく。

このスキルは、私の思想 (philosophy/) と品質基準 (perspectives/) を原料に、プロジェクト固有の AI 自走基盤を生成する。**AI のインフラを人間のインフラより先に整備する。**

## 生成物

```
target-project/
├── AGENTS.md                         # プロジェクト指示の単一原典 (Codex CLI / その他 AGENTS.md 対応ツール)
├── CLAUDE.md                         # Claude Code 用 (`@AGENTS.md` で AGENTS.md を import)
├── GEMINI.md                         # Gemini CLI 用 (`@AGENTS.md` で AGENTS.md を import)
├── .claude/
│   ├── settings.json                 # 許可コマンド、フック設定
│   └── agents/                       # プロジェクト固有エージェント (必要なら)
│       └── code-reviewer.md
│
├── .github/
│   └── copilot-instructions.md       # Copilot 用 (AGENTS.md からの派生生成 — import 構文がないため)
│
├── .cursorrules                      # Cursor 用 (AGENTS.md からの派生生成 — import 構文がないため)
│
├── tests/arch/ (or equivalent)       # アーキテクチャテスト
│   └── (技術スタックに応じたツールで生成)
│
└── .contexts/                        # 設計判断・プロジェクト文脈
    └── bootstrap-decisions.md        # bootstrap 中に行った判断の記録
```

**単一原典化方針**: `AGENTS.md` をプロジェクト指示の原典とする。`CLAUDE.md` と `GEMINI.md` は `@AGENTS.md` 1 行 + 各ツール固有の追記のみで、本文は AGENTS.md を import して同期する。`.cursorrules` と `.github/copilot-instructions.md` は import 構文を持たないため、bootstrap 時に AGENTS.md から派生生成する (再 bootstrap で再同期)。これにより編集時の乖離を構造的に防ぐ。Claude Code 公式 docs が「AGENTS.md がある場合は CLAUDE.md でそれを import せよ」と明記しているため、この方針は公式に支持されている。

## プロセス

### Phase 1: Seed — プロジェクトの本質を引き出す (0→0.1 の支援)

ユーザーの粗いアイデア・課題を受け取り、AI の知識と語彙で構造化・言語化を助ける。

**やること**:
1. ユーザーの入力 (課題、アイデア、こだわり) を受け取る
2. 以下を 1 問ずつ対話で確認する:
   - **何を作るか** — プロジェクトの目的を 1-2 文に凝縮する
   - **技術スタック** — 言語・フレームワーク・ランタイム。未定なら一緒に決める (philosophy/technology-choices.md を参照)
   - **プロジェクトの規模感** — 個人/チーム、短期/長期
3. 既存プロジェクトの場合は現状を調査する (ディレクトリ構造、既存設定、AGENTS.md / CLAUDE.md / GEMINI.md / `.cursorrules` / `.github/copilot-instructions.md` の有無)

**出力**: プロジェクトの本質を 1-2 文で表現した要約と、技術スタック。

### Phase 2: Context Design — 適用すべき原則の選定

philosophy/ と perspectives/ を読み込み、このプロジェクトに何を適用するかを選定する。

**やること**:
1. `${CLAUDE_PLUGIN_ROOT}/philosophy/` を全て読み込む
2. `${CLAUDE_PLUGIN_ROOT}/perspectives/` から技術スタックとプロジェクト性質に関連するものを選定する
3. プロジェクト固有の判断基準・例外を対話で確認する (1 問ずつ、最小限):
   - philosophy の原則のうち、このプロジェクトでは適用しないものはあるか
   - perspectives の基準のうち、このプロジェクトでの重み付けを変えるものはあるか

**選定の判断基準**:

| プロジェクトの性質 | 適用する perspectives |
|---|---|
| バックエンド API | architecture, api-design, data-modeling, error-handling, security, testing, disposability |
| フロントエンド SPA | component, state-design, naming, readability, testing, disposability |
| CLI ツール | error-handling, testing, naming |
| フルスタック | 上記の組み合わせ |

**出力**: 適用する philosophy/perspectives の選定結果と、プロジェクト固有の調整事項。

### Phase 3: Generate AI Context — ガイダンス層の生成

選定した原則と基準をプロジェクト固有のコンテキストファイルに変換する。

**やること**:
1. **AGENTS.md (原典) を生成する** — `resources/context-template.md` を参考に、プロジェクト固有の内容で生成する。これがプロジェクト指示の単一原典となる (Codex CLI 公式 + Claude Code 公式が連携を推奨している共通フォーマット)
2. **import 系ツール用ファイルを生成する** (本文は AGENTS.md を参照させる):
   - `CLAUDE.md` — 先頭に `@AGENTS.md` 1 行。Claude Code 固有の指示があれば下に追記
   - `GEMINI.md` — 先頭に `@AGENTS.md` 1 行。Gemini CLI 固有の指示があれば下に追記
3. **派生生成系ツール用ファイルを生成する** (import 構文がないため AGENTS.md から本文を派生):
   - `.github/copilot-instructions.md` — AGENTS.md の核心部分を Copilot 形式に変換
   - `.cursorrules` — AGENTS.md の核心部分を Cursor 形式に変換
   - 派生元 (AGENTS.md) を冒頭にコメントで明記し、再 bootstrap 時に再生成すべきことを示す
4. **code-reviewer エージェントを生成する** (必要な場合):
   - 選定した perspectives をレビュー観点として組み込んだプロジェクト固有の code-reviewer
   - `.claude/agents/code-reviewer.md` に配置
   - 生成する code-reviewer.md には以下の動作原則を必ず明記する:
     - **設定ファイル・ベンダー固有 DSL・スキーマに踏み込むレビューは、必ず該当する公式ドキュメントまたはスキーマを参照してから指摘する**。推測でモノを言わない (対象例: Claude Code permission DSL, OpenAPI スキーマ, Cargo.toml, package.json, terraform プロバイダ DSL 等)
     - レビュー間で指摘内容が矛盾する場合、その原因はほぼ常に「最初に仕様を確認していない」ことなので、確認を経てから指摘する
     - 仕様を確認せず推測で述べる場合は「未確認だが」と明示する
5. **自然言語の使用範囲を AGENTS.md に埋め込む**:
   - ドキュメント / ローカライズファイルはプロジェクトの公用語可、ソースコード・コメント・識別子・コミットメッセージは英語のみ、という境界を明文化する
   - bootstrap 時にプロジェクトの公用語を確認し、`resources/context-template.md` をもとに生成する **AGENTS.md の表** をプロジェクトに合わせて調整する (テンプレート自体は変更しない)
   - 対話言語 (issue / PR description) と成果物言語の混同を構造的に防ぐための節
6. **コミット規約を AGENTS.md に埋め込む**:
   - prefix 体系 ([feat], [fix], [update], [improve], [refactor], [chore], [docs], [test], [style])
   - 粒度の判断基準 (目的単位でステージング、ファイル単位ではなく変更の意図単位)
   - 言語: subject / body / trailer すべて英語のみ
7. **.contexts/ に判断記録を残す**:
   - bootstrap 中に行った判断 (適用した perspectives、除外した原則とその理由) を記録

**AGENTS.md (原典) に含める内容** (resources/context-template.md 参照):
- プロジェクトの概要 (Phase 1 の要約)
- 開発の原則 (philosophy/ から選定)
- 品質基準 (perspectives/ から選定)
- AI の判断委任範囲 (何を自律判断してよいか、何を確認すべきか)
- 技術スタックと捨てやすさ戦略
- 自然言語の使用範囲 (対話言語と成果物言語の境界)
- コミット規約
- 開発コマンド一覧 (Phase 5 で埋める)

### Phase 4: Generate Architecture Tests — ガードレール層の生成

perspectives/ のルールを実行可能なテストに変換し、CI で自動検証する仕組みを構築する。

**やること**:
1. 技術スタックに応じたアーキテクチャテストツールを選定する:

   | スタック | ツール |
   |---|---|
   | TypeScript | dependency-cruiser, eslint-plugin-boundaries |
   | Rust | cargo-deny, カスタムテストモジュール |
   | Kotlin/Java | ArchUnit |
   | Python | import-linter |
   | 言語非依存 | カスタムスクリプト (grep/ast ベース) |

2. 選定した perspectives から、テスト化可能なルールを抽出する:

   | perspective | テスト化するルール |
   |---|---|
   | architecture | 依存方向 (domain → infrastructure の import 禁止) |
   | architecture | フレームワーク型の domain/application 層への侵入禁止 |
   | disposability | ORM 型のドメイン層への漏出禁止 |
   | disposability | import 制限ガイドラインの遵守 |
   | core-principles | 禁止語 (Service, Manager 等) のクラス名使用禁止 |

3. テストを生成し、CI に組み込む

**重要**: すべてのルールをテスト化する必要はない。テスト化が容易で、違反時の影響が大きいものから始める。テストでは捉えきれない品質は code-reviewer エージェント (Layer 3) がカバーする。

**出力**: アーキテクチャテストファイルと CI 設定への追加。

### Phase 5: Bridge to Technical Infrastructure — 技術インフラへの橋渡し

AI コンテキスト基盤が整ったら、技術インフラの構築に進む。**ここからは AI が自身の知識を使って自走する。** philosophy/ の判断基準には従うが、How は AI が決める。

`${CLAUDE_PLUGIN_ROOT}/skills/bootstrap/resources/known-pitfalls.md` に既知の落とし穴が登録されている。技術インフラ構築時に該当する技術 (Copilot Coding Agent 連携、claude-code-action 等) を扱う場合は該当エントリを参照する。

**やること**:
1. 技術インフラの構築 (必要なものだけ):
   - devcontainer (開発環境のコンテナ化)
   - docker-compose (ローカルインフラ)
   - CI パイプライン (lint, test, format, type check, architecture tests)
   - linter/formatter/型チェッカーの設定
   - テストフレームワークの設定とサンプルテスト
2. AGENTS.md の「開発コマンド一覧」を実際のコマンドで埋める (CLAUDE.md / GEMINI.md は `@AGENTS.md` で import しているため自動的に反映される)
3. `.claude/settings.json` の許可コマンドを設定する
4. 動作確認: すべてのコマンドが成功することを確認

**受け入れ基準**: 「今すぐコーディングに移って技術品質が保たれる状態になっているか」

この基準を満たさない場合は未完とする:
1. **書ける**: 追加 install なしにコードが書き始められる
2. **走る**: テスト・lint・format・型チェック・ビルドが成功する
3. **止まる**: 規約違反・型エラー・テスト失敗が検知されて止まる
4. **再現する**: 別マシン・別開発者でも同じ結果になる
5. **見える**: ログ・エラー・テストレポートが読める

## 対話の原則

- **1 ターン 1 質問**。複数質問を並べない
- **二択 + その他** の形式で聞く。漠然とした開放質問は禁止
- **推奨を提示する**。「どうしますか？」ではなく「X を推奨しますが、Y もあります。どちらにしますか？」
- **「おまかせ」を受け入れる**。ユーザーが「おまかせ」と言ったら推奨を適用して先に進む
- Phase 1-2 で本質的な判断だけ聞き、Phase 3-5 は可能な限り自走する
