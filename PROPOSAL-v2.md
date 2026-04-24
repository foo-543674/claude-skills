# foo-skills v2 企画書: 「私の複製」から「自走する開発パートナー」へ

## 1. 背景: 現在のアプローチの限界

### 1.1 何が起きているか

現在の foo-skills は **16 のスキル + 1 エージェント(20観点)** で構成され、ソフトウェア開発の各フェーズを手順として体系化している。

```
requirements-* → design-* → setup-* → implement-* → code-reviewer
```

このアプローチには 3 つの構造的な限界がある。

#### 限界 1: 進化性の欠如

スキルは「今の私の思考プロセス」のスナップショットであり、技術の進歩やプロジェクトの文脈に応じて変化しない。新しいフレームワークが登場しても、スキルが記述する手順は古いまま残る。**思想は進化が遅いが、手順は陳腐化が速い。** 両者を混在させているため、思想の更新に手順の書き直しが伴い、手順の更新が思想を歪めるリスクがある。

#### 限界 2: 取り回しの悪さ (ツールロックイン)

16 のスキルはウォーターフォール的なフェーズに紐づいている。小さなスクリプトを書くときも、大規模システムを設計するときも、同じ粒度のスキルセットを前提とする。**プロジェクトの規模・性質に応じたスコープ調整の仕組みがない。**

さらに根本的な問題として、**スキルがプラグインの中にある限り、このプラグインをインストールできる環境でしか機能しない**。commit-message のルール、コードレビューの観点、設計の原則 — これらは「Claude Code + このプラグイン」という特定の組み合わせに閉じ込められている。GitHub Copilot、ブラウザ上の Claude、Cursor、その他の AI ツールでは一切使えない。**プラグインへの依存がツールロックインを生んでいる。**

#### 限界 3: ループの起点が常に「私」

```
┌─────────────────────────────────┐
│  私が判断 → スキルを呼ぶ → AI が実行  │
│  私が判断 → スキルを呼ぶ → AI が実行  │
│  私が判断 → スキルを呼ぶ → AI が実行  │
└─────────────────────────────────┘
```

スキルがどれだけ精緻でも、「次に何をするか」を決めるのは常に人間。AI は「優秀な手」だが「頭」がない。結果として、新しいプロジェクトを始めるたびに、AI が動き続けるための仕組み（CLAUDE.md、エージェント、フック）を人間がゼロから構築しなければならない。

### 1.2 根本原因

**スキルが「How (手順)」をエンコードしている。** しかし How は AI が元から持っている知識領域 (ウォードリーマッピング、イベントストーミング、ADR、DDD、テストピラミッド等)。現在のスキルは AI の知識を制約して「私のやり方」に閉じ込めているだけで、AI の強み (知識量、語彙力、構造化能力) を活かせていない。

---

## 2. 核心的な洞察: 3 つのパラダイムシフト

### 2.1 エンコードすべきもの/すべきでないもの

```
エンコードすべきもの (AI が持っていない):
  ✅ 価値観・判断基準     何を良しとするか (What)
  ✅ 適用条件・判断傾向    どういう状況でどちらを選ぶか (When/Why)
  ✅ 美意識・テイスト      私にとっての「良いコード」
  ✅ 介入ポイント          どこで私に聞くべきか

エンコードすべきでないもの (AI が既に知っている):
  ❌ 開発手法の手順        DDD の実践方法、テストの書き方
  ❌ フレームワークの使い方  React のセットアップ、CI の構築
  ❌ 設計パターンの適用方法  リポジトリパターン、CQRS の実装
```

### 2.2 役割分担: 0→0.1 と 99.9→100

```
0 ──→ 0.1            0.1 ──────────→ 99.9           99.9 ──→ 100
 私の領域                AI の領域                      私の領域

 課題・アイデア       知識 (フレームワーク, 手法)         最終判断
 こだわり            語彙 (言語化・構造化)              テイスト
 違和感              実装 (設計・コーディング)           承認
```

- **0→0.1**: 私が粗いアイデアや課題を出す。AI はそれを受け取り、構造化し、言語化を助ける
- **0.1→99.9**: AI が知識と語彙を駆使して形にする。手法の選択も AI が行う。ただし私の価値観・判断基準に従う
- **99.9→100**: 私が最終判断を下す。テイストに合うか、方向性が正しいか

### 2.3 インフラの再定義: AI-first

```
現在の「最初にやること」:
  devcontainer → docker-compose → CI → CLAUDE.md (おまけ)

あるべき「最初にやること」:
  CLAUDE.md → agents → hooks → rules → devcontainer → CI
  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  AI がそのプロジェクトで自走するためのコンテキスト基盤
```

**「AI のインフラ」が「人間のインフラ」より先。** AI がプロジェクトの文脈を理解し、自律的に判断できる状態を先に作る。技術的なインフラ (CI、コンテナ) の構築は、その文脈の中で AI 自身が遂行する。

---

## 3. 新しいアーキテクチャ

### 3.1 プラグインの性格: 「使うもの」から「生成するもの」へ

v2 の最も根本的な転換は、**プラグインの成果物はプラグイン自体ではなく、プロジェクトに生成されたコンテキストである** ということ。

```
v1: plugin = 直接使う AI ツール
  commit-message スキルを呼ぶ → AI がコミットメッセージを作る
  design-api スキルを呼ぶ → AI が API を設計する
  → このプラグインがないと何もできない (ツールロックイン)

v2: plugin = プロジェクト固有の AI 自走基盤を生成するジェネレータ
  bootstrap を呼ぶ → プロジェクトに CLAUDE.md, skills, agents, hooks を生成
  → 生成後はプラグインがなくても、プロジェクト自体が AI 自走コンテキストを持つ
  → Claude Code でも Copilot でも Cursor でも動く
```

**プラグインは「種」であり、プロジェクトに「実」をつける。実がつけば種は不要になる。**

### 3.2 構造概要

```
foo-skills/
├── philosophy/                       # 原料: 思想 (横断的・静的)
│   ├── core-principles.md            #   語彙定義義務, 逃げの禁止, 説明責任
│   ├── technology-choices.md         #   技術選定の判断基準と傾向
│   ├── quality-standards.md          #   製品品質 vs 技術品質の定義
│   └── development-values.md         #   バーチカルスライス, フィードバック駆動, テストファースト
│
├── perspectives/                     # 原料: 品質レンズ (設計にもレビューにも使う)
│   ├── architecture.md               #   営みの起源, レイヤー定義, 捨てやすさ
│   ├── api-design.md                 #   契約の明確性, ステータスセマンティクス
│   ├── data-modeling.md              #   ストレージ非依存, 正規化判断
│   ├── component.md                  #   4 Tier, シグネチャ境界
│   ├── testing.md                    #   テスト価値マトリクス
│   ├── error-handling.md
│   ├── security.md
│   ├── performance.md
│   ├── naming.md
│   ├── readability.md
│   ├── ... (他の観点)
│   └── disposability.md              #   影響範囲のコントロール可能性
│
├── skills/
│   └── bootstrap/                    # エンジン: AI 自走基盤の生成器
│       ├── SKILL.md
│       └── resources/
│           ├── context-template.md   #   生成する CLAUDE.md のテンプレート
│           ├── checklist.md          #   AI インフラのチェックリスト
│           └── catalog.md            #   生成可能な skills/agents/hooks のカタログ
│
└── .claude-plugin/
    └── plugin.json
```

**注目すべき点**: `skills/` 配下に bootstrap しかない。commit-message も code-reviewer もない。それらは bootstrap がプロジェクトに**生成する**もの。

### 3.3 生成物の例: bootstrap がプロジェクトに何を作るか

```
target-project/                       # bootstrap の生成先
├── .claude/
│   ├── CLAUDE.md                     # プロジェクト固有のコンテキスト
│   │                                 # (philosophy/ + perspectives/ から関連部分を選定・適用)
│   ├── settings.json                 # 許可コマンド、フック設定
│   └── agents/                       # プロジェクト固有のエージェント (必要なら)
│       └── code-reviewer.md
│
├── .github/
│   └── copilot-instructions.md       # Copilot 用 (CLAUDE.md から変換)
│
├── .cursorrules                      # Cursor 用 (CLAUDE.md から変換)
│
├── .contexts/                        # 設計判断・プロジェクト文脈
│   └── ...
│
├── tests/arch/ (or equivalent)       # アーキテクチャテスト (AI の秩序を自動検証)
│   ├── dependency-rules.test.ts      #   「domain が infrastructure を import してはならない」等
│   └── structure-rules.test.ts       #   「この型はこのディレクトリにしか置けない」等
│
└── (devcontainer, CI, etc.)          # 技術インフラは AI が自走して構築
```

**ポイント**: 生成されたプロジェクトは **ツール非依存**。Claude Code でも Copilot でも Cursor でも、そのプロジェクトで AI が自走できるコンテキストが整っている。

### 3.4 アーキテクチャテスト: AI の自走に対する自動ガードレール

AI に開発の大部分を任せる以上、「AI の判断を信頼する」のではなく「AI の判断を自動検証する」仕組みが不可欠。人間が開発するときは設計レビューで「この import おかしくない？」と気づける。AI が開発するときは **CI が壊れて止まる** ことでそれを実現する。

#### なぜ CLAUDE.md のルールだけでは不十分か

```
CLAUDE.md に「domain は infrastructure を import してはならない」と書く
  → AI はたいてい従う
  → でも複雑な実装の中で、無意識に違反することがある
  → レビューで人間が気づくか？ 気づかないこともある
  → 違反がマージされ、蓄積し、気づいたときには手遅れ

アーキテクチャテストに同じルールを書く
  → AI が違反した瞬間に CI が壊れる
  → AI 自身が「CI が壊れた → 原因は architecture test → 直す」のループを回せる
  → 人間のレビュー負荷が下がり、構造の秩序が自動的に保たれる
```

**CLAUDE.md はガイダンス (破れる)、アーキテクチャテストはガードレール (破れない)**。両方必要だが、AI に自走させるなら後者が決定的に重要。

#### bootstrap が生成するアーキテクチャテストの例

perspectives/ に記述された品質基準を、テストとして実行可能な形に変換する。

**依存方向ルール** (perspectives/architecture の「営みの起源」を検証):
```
domain → infrastructure を import していないか
domain → interfaces を import していないか
application → interfaces を import していないか
```

**型の配置ルール** (perspectives/disposability の「シグネチャ漏出防止」を検証):
```
ORM の型 (Prisma, TypeORM 等) が domain/ や application/ に出現しないか
外部 SDK の型が domain/ の public シグネチャに出現しないか
```

**構造ルール** (perspectives/architecture の「語彙定義義務」を検証):
```
Service, Manager, Helper, Utility を含むファイル名やクラス名がないか
```

#### 技術スタックごとの実現手段

| スタック | ツール | できること |
|---|---|---|
| TypeScript | `dependency-cruiser`, `eslint-plugin-boundaries` | import グラフの制約、ディレクトリ間の依存ルール |
| Rust | `cargo-deny`, カスタムテストモジュール | クレート依存の制約、`use` パスの検証 |
| Python | `import-linter` | パッケージ間の import ルール |
| Java/Kotlin | `ArchUnit` | クラス/パッケージ間の依存・命名・配置ルール |
| 言語非依存 | カスタムスクリプト (grep/ast ベース) | ファイル名、ディレクトリ構造、import パターン |

bootstrap はプロジェクトの技術スタックに応じて適切なツールを選定し、perspectives/ のルールをテストとして実装する。

#### philosophy/ との関係

この考え方は `philosophy/quality-standards.md` の「技術品質は暗黙に必須」と直結する。アーキテクチャの秩序は誰も口に出さないが、壊れると致命的。だからこそテストで自動保証する。

**AI 自走の三層防御**:
```
Layer 1: CLAUDE.md (ガイダンス)     → AI が従うべきルールを言語で伝える
Layer 2: Architecture Tests (検証)  → ルール違反を CI で自動検出する
Layer 3: Code Review Agent (評価)   → テストでは捉えきれない設計品質を評価する
```

### 3.2 各レイヤーの役割

#### Layer 1: philosophy/ — 横断的な思想

**役割**: すべての判断に適用される、私の価値観と判断基準。技術選定、設計判断、コード品質のあらゆる場面で AI が参照する「行動原則」。

**特徴**:
- **スキルとして呼ばれない**。CLAUDE.md や bootstrap で参照される背景知識
- **手順を含まない**。「何を良しとするか」「どういう時にどちらを選ぶか」のみ
- **進化が遅い**。技術トレンドではなく、私自身の思想の変化に連動する

**4 ファイルの分担**:

| ファイル | 内容 | 例 |
|---|---|---|
| `core-principles.md` | 全設計判断に適用する基礎原則 | 語彙定義義務、逃げの禁止と説明責任、Rule of Three |
| `technology-choices.md` | 技術選定における私の判断基準と傾向 | 静的型付け優先、関数型寄り、スクリプト言語を避ける理由 |
| `quality-standards.md` | 品質の定義と優先順位 | 製品品質 vs 技術品質、技術品質は暗黙に必須 |
| `development-values.md` | 開発プロセスにおける価値観 | フィードバックループ駆動、バーチカルスライス、テストファースト、end-to-end 貫通 |

#### Layer 2: perspectives/ — 品質レンズ

**役割**: 特定のドメイン (アーキテクチャ、API、データモデリング等) における私の品質基準と判断軸。**設計時にも、レビュー時にも使う二重用途の品質レンズ**。

**v1 との最大の違い**:

```
v1: 設計スキル (手順入り)  ──→  レビュー観点 (別物)
    design-architecture          code-reviewer-resources/architecture

v2: perspectives/architecture (一つのレンズ)
    ├── 設計時: このレンズに照らして設計判断する
    └── レビュー時: このレンズに照らして品質を評価する
```

設計スキルとレビュー観点が「同じ思想の表裏」であることを構造で表現する。

**各 perspective に含めるもの**:

```markdown
# [観点名]

## 判断基準 (What/When/Why)
- 私がこの領域で何を重視するか
- どういう状況でどちらを選ぶか
- なぜその判断をするか

## アンチパターン
- 私が「逃げ」と見なすパターン
- 典型的な品質問題

## 品質チェックポイント
- 設計時: この観点で確認すべきこと
- レビュー時: この観点で指摘すべきこと
```

**含めないもの**: 手順、テンプレート、ステップ1-N の実行フロー。

#### bootstrap/ — AI 自走基盤の構築スキル

**役割**: 新しいプロジェクトで「AI が自走できる状態」を構築する。**これが v2 の核心**。

**何をするか**:

1. **プロジェクトの本質を引き出す** (0→0.1 の支援)
   - ユーザーの粗いアイデア・課題を受け取る
   - AI の知識と語彙で構造化・言語化を助ける
   - ユーザーに最終判断を仰ぐ (99.9→100)

2. **AI コンテキスト基盤をプロジェクトに生成する**
   - プロジェクト固有の `CLAUDE.md` (philosophy/ と perspectives/ から関連部分を選定・適用)
   - プロジェクト固有のエージェント (`.claude/agents/code-reviewer.md` 等)
   - プロジェクト固有のフック・ルール
   - ツール横断のコンテキスト (`.github/copilot-instructions.md`, `.cursorrules` 等)
   - `.contexts/` に設計判断やプロジェクト文脈のドキュメント

3. **生成物はプラグイン非依存**
   - 生成されたプロジェクトは、このプラグインがなくても AI が自走できる
   - CLAUDE.md → Claude Code、copilot-instructions.md → Copilot、.cursorrules → Cursor
   - プラグインは「種」であり、生成されたプロジェクトが「実」

4. **技術インフラへの橋渡し**
   - AI コンテキストが整ったら、技術インフラ (devcontainer, CI, docker-compose) の構築に進む
   - ここからは AI が自身の知識を使って自走する (How は AI の領域)
   - ただし生成された CLAUDE.md 内の philosophy/ の判断基準に従う

**v1 の setup-plan との違い**:

```
v1 setup-plan:
  インタビュー → 計画書 → setup-devcontainer → setup-ci → setup-local-infra
  (人間のインフラを手順通りに構築)

v2 bootstrap:
  対話 → CLAUDE.md + agents + hooks → AI が自走して技術インフラを構築
  (AI のインフラを先に構築し、AI が残りを自走)
```

#### code-reviewer, commit-message — プラグインから消え、プロジェクトに生成される

v1 ではこれらはプラグイン内のスキル/エージェントだった。v2 ではプラグインから消える。

代わりに、bootstrap がプロジェクトに生成する:

- **code-reviewer**: perspectives/ の品質レンズを元に、プロジェクト固有のレビューエージェントを `.claude/agents/code-reviewer.md` に生成。プロジェクトの技術スタックに合わせて、関連する perspectives だけを組み込む
- **commit-message**: 私のコミット規約を CLAUDE.md のルールセクションに埋め込む。Claude Code では CLAUDE.md として、Copilot では copilot-instructions.md として参照される

**なぜプラグインに残さないか**: これらがプラグインにある限り、「Claude Code + このプラグイン」でしか使えない。プロジェクト側にあれば、どの AI ツールでも機能する。

---

## 4. 既存資産の移行マップ

### 4.1 思想の抽出と再配置

現在のスキルから「思想」を抽出し、新しいレイヤーに再配置する。

| 現在のスキル | 思想 (残す) | 手順 (捨てる) | 移行先 |
|---|---|---|---|
| `design-architecture` | 営みの起源、語彙定義義務、逃げの禁止、捨てやすさ (隔離戦略 4 種)、ドメインロジック置き場所優先順位、Result/Either | ステップ 1-8、成果物テンプレート | `philosophy/core-principles` + `perspectives/architecture` |
| `design-api` | 契約の明確性、HTTP ステータスセマンティクス、エラー配列ベース、ORM 型漏出防止 | ステップ 1-9、プロセス節、成果物 | `perspectives/api-design` |
| `design-data-model` | ストレージ非依存モデル、正規化 vs 非正規化の判断軸、Command/Query 側の分離 | ステップ 1-6、テンプレート | `perspectives/data-modeling` |
| `design-component` | 4 Tier コンポーネント分割、シグネチャ境界、fully controlled 境界、Rule of Three | ステップ 1-8、テンプレート | `perspectives/component` |
| `implement-feature` | テストファースト (Red-Green-Refactor)、技術品質を先に作り込む | 実装手順、チェックリスト | `philosophy/development-values` |
| `implement-testing` | テスト価値マトリクス、テスト価値の最小化を見極める | テスト層別一覧、テンプレート | `perspectives/testing` |
| `implement-refactor` | 特性化テスト、リファクタリングパターン選択の判断軸 | 手順、チェックリスト | (perspectives に分散) |
| `requirements-elicitation` | 本質的な課題の特定、スコープ (In/Out/Future) | 5W1H 手順、テンプレート | `philosophy/development-values` (一部) |
| `requirements-specification` | INVEST 原則、境界条件思考、仕様レベルのセマンティクス | テンプレート、Given-When-Then | (perspectives に分散) |
| `plan-implementation` | バーチカルスライス、「確かめたいこと」必須、end-to-end 貫通、AC vs DoD | テンプレート、ステップ 0-5 | `philosophy/development-values` |
| `setup-plan` | 「今すぐコーディングに移って技術品質が保たれる状態」、方針→ライブラリ派生 | インタビュー手順、テンプレート | `skills/bootstrap/` (AI インフラ先行に再設計) |
| `setup-devcontainer` | (思想は薄い) | 全体 | 削除 (AI の知識で代替) |
| `setup-ci` | (思想は薄い) | 全体 | 削除 (AI の知識で代替) |
| `setup-local-infra` | (思想は薄い) | 全体 | 削除 (AI の知識で代替) |
| `commit-message` | prefix 体系、粒度の判断基準 | (手順は少ない) | bootstrap が生成するプロジェクトの CLAUDE.md に埋め込み |
| `development-report` | (思想は薄い) | テンプレート | 削除 (必要ならプロジェクト固有で生成) |
| `code-reviewer` | 技術品質 vs 製品品質、スコープ意識、既存コードへの敬意 | ステップ 1-6 | bootstrap が生成するプロジェクトの `.claude/agents/code-reviewer.md` |
| `code-reviewer-resources/*` | 20 観点の品質チェックポイント | (手順は少ない) | `perspectives/` に吸収。bootstrap がプロジェクトに必要な perspectives を選んで生成 |

### 4.2 ファイル数の変化

```
v1 (プラグイン内): 16 スキル + 1 エージェント + 20 リソース = 37+ ファイル
v2 (プラグイン内): 4 philosophy + ~20 perspectives + 1 スキル (bootstrap) = ~25 ファイル
v2 (生成先):       CLAUDE.md + agents + hooks + copilot-instructions + .cursorrules = プロジェクト依存
```

重要なのはファイル数ではなく、**プラグインの中と外の役割分離**:

- **プラグイン内** = 原料 (philosophy, perspectives) + エンジン (bootstrap)。私の思想のマスターデータ
- **プロジェクト側** = 生成されたコンテキスト。ツール非依存で AI が自走するための基盤。プラグインがなくても機能する

---

## 5. bootstrap スキルの詳細設計

v2 の核心である bootstrap スキルのコンセプトを示す。

### 5.1 トリガー

- 新規プロジェクトの立ち上げ
- 既存プロジェクトへの AI コンテキスト導入
- 「このプロジェクトで AI が自走できるようにして」

### 5.2 プロセス概要

```
Phase 1: Seed (0→0.1 の支援)
  ユーザーの粗いアイデア・課題を受け取る
  AI の知識と語彙で言語化を手伝う
  プロジェクトの本質を 1-2 文に凝縮する
       ↓
Phase 2: Context Design
  philosophy/ を読み込み、プロジェクトに適用すべき原則を選定
  perspectives/ から関連する品質レンズを選定
  プロジェクト固有の判断基準・例外を対話で確認
       ↓
Phase 3: Generate AI Infrastructure (ガイダンス層)
  CLAUDE.md を生成 (プロジェクト固有のコンテキスト + philosophy 参照)
  ツール横断コンテキストを生成 (copilot-instructions, .cursorrules)
  必要なエージェント・フック・ルールを生成
  .contexts/ に設計判断ドキュメントを生成
       ↓
Phase 4: Generate Architecture Tests (ガードレール層)
  perspectives/ のルールを実行可能なテストに変換
  技術スタックに応じたツールを選定 (dependency-cruiser, ArchUnit 等)
  依存方向・型配置・命名規則のテストを生成
  CI に組み込み (AI が違反したら CI が壊れる)
       ↓
Phase 5: Build Technical Infrastructure
  AI が自身の知識で技術インフラを構築 (devcontainer, CI, etc.)
  生成された CLAUDE.md + architecture tests の枠内で自走
  ユーザーは 99.9→100 で最終判断
```

### 5.3 生成する CLAUDE.md の構成イメージ

```markdown
# [Project Name]

## このプロジェクトについて
[プロジェクトの本質を 1-2 文で]

## 開発の原則
[philosophy/ から選定した原則。プロジェクト固有の適用方法を含む]

## 品質基準
[perspectives/ から選定した品質レンズ。プロジェクト固有の重み付け]

## 判断の委任範囲
[AI が自律判断してよい範囲と、ユーザーに確認すべきポイント]

## 技術スタック
[選定理由と、各技術の「捨てやすさ」戦略]

## 開発フロー
[AI がどう動くか: PR の出し方、コミットの粒度、テストの方針]
```

### 5.4 v1 の setup-plan との本質的な違い

| 観点 | v1 setup-plan | v2 bootstrap |
|---|---|---|
| 最初に作るもの | devcontainer, docker-compose | CLAUDE.md, agents, hooks, **architecture tests** |
| AI の役割 | 計画書通りに実行する手 | 自走する開発パートナー |
| How の扱い | スキルに手順が書いてある | AI が知識から導出 |
| 秩序の保証 | 人間がレビューで気づく | **CI が自動で壊れる** (architecture tests) |
| ユーザーの負荷 | チェックリスト全項目を確認 | 本質的な判断のみ (0→0.1, 99.9→100) |
| プロジェクト適応 | 同じスキルを毎回適用 | プロジェクト固有のコンテキストを毎回生成 |

---

## 6. perspectives の詳細設計

### 6.1 v1 からの統合方針

各 perspective は、**v1 の設計スキルの思想** + **v1 のレビュー観点のチェックポイント** を統合する。

例: `perspectives/architecture.md`

```
v1 の入力:
  ├── skills/design-architecture/SKILL.md (思想: 営みの起源, 捨てやすさ等)
  ├── skills/design-architecture/resources/principles.md (思想: 語彙定義義務, 逃げの禁止)
  ├── skills/design-architecture/resources/domain-modeling.md (思想: 置き場所優先順位等)
  └── agents/code-reviewer-resources/architecture.md (チェックポイント)

v2 の出力:
  └── perspectives/architecture.md
      ├── 判断基準: 営みの起源でレイヤーを分ける、語彙定義義務...
      ├── アンチパターン: 逃げ A-F, 貧血エンティティ, Cargo Cult...
      └── 品質チェックポイント: 設計時にもレビュー時にも使える統一リスト
```

### 6.2 perspective ファイルの構造

```markdown
# [観点名]

## この観点で重視すること (What/Why)
[私がこの領域で何を大事にし、なぜそうするか]

## 判断基準 (When)
[どういう状況でどう判断するか。判断フローではなく判断軸]

## アンチパターン
[私が「逃げ」「設計の怠慢」と見なすパターン]

## 品質チェックポイント
[設計でもレビューでも使える品質確認項目]
```

**ポイント: 手順 (ステップ 1-N) を含めない。** 判断の「軸」と「基準」だけ。その軸をどの順番で適用するかは AI がコンテキストに応じて決める。

---

## 7. 期待される効果

### 7.1 三つの限界の解消

| 限界 | v1 | v2 |
|---|---|---|
| **進化性** | 手順と思想が混在し、更新が困難 | 思想 (philosophy) と手順 (AI の知識) が分離。思想だけを独立して進化できる |
| **取り回し** | プラグイン内にスキルがあり、Claude Code でしか使えない (ツールロックイン) | bootstrap がプロジェクト側にコンテキストを生成。CLAUDE.md / copilot-instructions / .cursorrules で**どの AI ツールでも動く** |
| **スコープ調整** | スキルの粒度が固定 | bootstrap で生成する CLAUDE.md でプロジェクトごとに AI の自律範囲を調整 |

### 7.2 新しい開発フロー

```
Before (v1):
  私: 「ユーザー管理機能を作りたい」
  私: /requirements-elicitation → 対話 → 仕様書
  私: /design-architecture → 対話 → 設計書
  私: /design-api → 対話 → API 仕様
  私: /setup-plan → 対話 → 計画書
  私: /implement-feature → AI が実装
  私: code-reviewer → AI がレビュー
  (私がすべてのフェーズを起動し、AI は各フェーズの手を動かすだけ)

After (v2):
  私: 「ユーザー管理機能を作りたい。認証は JWT で。」  (0→0.1)
  AI: philosophy/ と perspectives/ に基づいて設計・実装を自走  (0.1→99.9)
      - 必要に応じて要件の深掘りを私に確認
      - 設計判断は perspectives/ の基準で自律的に実施
      - 判断に迷ったら私に確認  (99.9→100 のポイント)
  私: 「LGTM」または「ここはこう変えて」  (99.9→100)
```

### 7.3 プラグインの性格の変化

```
v1: 「開発プロセスの手順書」 (消費されるもの)
    → AI に「私のやり方」で作業させるツール
    → 私がいないと動けない
    → Claude Code + このプラグインでしか動かない

v2: 「AI 自走基盤のジェネレータ」 (生成するもの)
    → プロジェクトに AI 自走コンテキストを生成する
    → 生成後はプラグインなしでも動く (ツール非依存)
    → Claude Code でも Copilot でも Cursor でも動く
    → 私は起点 (0→0.1) と終点 (99.9→100) に集中
```

**比喩**: v1 は「毎回シェフを呼ぶ出張料理」、v2 は「レシピと味の基準を厨房に仕込んでおく」。仕込みが終われば、誰が (どの AI が) 厨房に立っても、同じ味の料理が出る。

---

## 8. リスクと対策

| リスク | 対策 |
|---|---|
| 思想の抽出時に重要な暗黙知が失われる | v1 のスキルを丁寧に分析し、思想部分を漏れなく移行。移行後に v1 と v2 で同じ判断が出るか検証する |
| perspectives が設計にもレビューにも使えるほど汎用的に書けるか | まず architecture と api-design の 2 つで試作し、二重用途が成立するか確認する |
| bootstrap が生成する CLAUDE.md の品質 | テンプレートと具体例を充実させ、生成品質を安定させる。最初は生成後に私がレビューする運用で始める |
| AI が自律判断する範囲が広すぎて暴走する | bootstrap で「判断の委任範囲」を明示的に設計。段階的に委任範囲を広げる |

---

## 9. 移行計画

### Phase 1: 思想の抽出と perspectives の試作

1. v1 の全スキルから思想 (What/When/Why) を抽出・整理
2. `philosophy/` の 4 ファイルを作成
3. `perspectives/architecture` と `perspectives/api-design` を試作し、二重用途の成立を検証

### Phase 2: bootstrap スキルの設計と試作

1. bootstrap スキルの詳細設計
2. 小規模プロジェクトで試行し、生成される CLAUDE.md の品質を検証
3. philosophy/ と perspectives/ の参照が適切に機能するか確認

### Phase 3: 残りの perspectives の整備と v1 スキルの廃止

1. 全 perspectives を整備
2. code-reviewer を perspectives/ 参照に移行
3. v1 の設計・実装・環境構築スキルを廃止
4. commit-message はそのまま維持

### Phase 4: 実践と改善

1. 実プロジェクトで v2 を使用し、フィードバックを収集
2. philosophy/ と perspectives/ を実践に基づいて改善
3. bootstrap の生成品質を継続的に向上
