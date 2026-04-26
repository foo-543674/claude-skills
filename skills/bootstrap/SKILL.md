---
name: bootstrap
description: プロジェクトに AI が自走するためのコンテキスト基盤を構築する。新規プロジェクトの立ち上げ時、既存プロジェクトに AI コンテキストを導入するとき、「AI が自走できるようにして」と言われたときに使う。
---

# Bootstrap — AI 自走基盤の構築

プロジェクトに AI が自律的に開発を継続できるコンテキスト基盤を生成する。

このスキルの成果物は **プラグインの中ではなくプロジェクトの中** に生成される。生成後はプラグインがなくても、Claude Code / Copilot / Cursor 等どの AI ツールでもプロジェクトのコンテキストが機能する。

## Why

新しいプロジェクトを始めるとき、AI が開発を自走するための仕組み (CLAUDE.md、エージェント、フック、ルール) を人間がゼロから構築している。これは毎回繰り返される手作業であり、プロジェクトごとに品質がばらつく。

このスキルは、私の思想 (philosophy/) と品質基準 (perspectives/) を原料に、プロジェクト固有の AI 自走基盤を生成する。**AI のインフラを人間のインフラより先に整備する。**

## 生成物

```
target-project/
├── CLAUDE.md                         # プロジェクト固有のコンテキスト
├── .claude/
│   ├── settings.json                 # 許可コマンド、フック設定
│   └── agents/                       # プロジェクト固有エージェント (必要なら)
│       └── code-reviewer.md
│
├── .github/
│   └── copilot-instructions.md       # Copilot 用 (CLAUDE.md の要点を変換)
│
├── .cursorrules                      # Cursor 用 (CLAUDE.md の要点を変換)
│
├── tests/arch/ (or equivalent)       # アーキテクチャテスト
│   └── (技術スタックに応じたツールで生成)
│
└── .contexts/                        # 設計判断・プロジェクト文脈
    └── bootstrap-decisions.md        # bootstrap 中に行った判断の記録
```

## プロセス

### Phase 1: Seed — プロジェクトの本質を引き出す (0→0.1 の支援)

ユーザーの粗いアイデア・課題を受け取り、AI の知識と語彙で構造化・言語化を助ける。

**やること**:
1. ユーザーの入力 (課題、アイデア、こだわり) を受け取る
2. 以下を 1 問ずつ対話で確認する:
   - **何を作るか** — プロジェクトの目的を 1-2 文に凝縮する
   - **技術スタック** — 言語・フレームワーク・ランタイム。未定なら一緒に決める (philosophy/technology-choices.md を参照)
   - **プロジェクトの規模感** — 個人/チーム、短期/長期
3. 既存プロジェクトの場合は現状を調査する (ディレクトリ構造、既存設定、CLAUDE.md の有無)

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
1. **CLAUDE.md を生成する** — `resources/context-template.md` を参考に、プロジェクト固有の内容で生成する
2. **ツール横断コンテキストを生成する**:
   - `.github/copilot-instructions.md` — CLAUDE.md の核心部分を Copilot 形式に変換
   - `.cursorrules` — CLAUDE.md の核心部分を Cursor 形式に変換
3. **code-reviewer エージェントを生成する** (必要な場合):
   - 選定した perspectives をレビュー観点として組み込んだプロジェクト固有の code-reviewer
   - `.claude/agents/code-reviewer.md` に配置
   - 生成する code-reviewer.md には以下の動作原則を必ず明記する:
     - **設定ファイル・ベンダー固有 DSL・スキーマに踏み込むレビューは、必ず該当する公式ドキュメントまたはスキーマを参照してから指摘する**。推測でモノを言わない (対象例: Claude Code permission DSL, OpenAPI スキーマ, Cargo.toml, package.json, terraform プロバイダ DSL 等)
     - レビュー間で指摘内容が矛盾する場合、その原因はほぼ常に「最初に仕様を確認していない」ことなので、確認を経てから指摘する
     - 仕様を確認せず推測で述べる場合は「未確認だが」と明示する
4. **コミット規約を CLAUDE.md に埋め込む**:
   - prefix 体系 ([feat], [fix], [update], [improve], [refactor], [chore], [docs], [test], [style])
   - 粒度の判断基準 (目的単位でステージング、ファイル単位ではなく変更の意図単位)
5. **.contexts/ に判断記録を残す**:
   - bootstrap 中に行った判断 (適用した perspectives、除外した原則とその理由) を記録

**CLAUDE.md に含める内容** (resources/context-template.md 参照):
- プロジェクトの概要 (Phase 1 の要約)
- 開発の原則 (philosophy/ から選定)
- 品質基準 (perspectives/ から選定)
- AI の判断委任範囲 (何を自律判断してよいか、何を確認すべきか)
- 技術スタックと捨てやすさ戦略
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

**やること**:
1. 技術インフラの構築 (必要なものだけ):
   - devcontainer (開発環境のコンテナ化)
   - docker-compose (ローカルインフラ)
   - CI パイプライン (lint, test, format, type check, architecture tests)
   - linter/formatter/型チェッカーの設定
   - テストフレームワークの設定とサンプルテスト
2. CLAUDE.md の「開発コマンド一覧」を実際のコマンドで埋める
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
