# foo-skills プラグイン

プロジェクトに AI が自走するためのコンテキスト基盤を生成するプラグイン。

## このプラグインの性格

このプラグインは「直接使う AI ツール」ではなく「プロジェクトに AI 自走基盤を生成するジェネレータ」。生成後はプラグインがなくても、Claude Code / GitHub Copilot / Cursor / Gemini CLI / OpenAI Codex CLI 等どの AI ツールでもプロジェクトのコンテキストが機能する。

```
プラグインの中 (原料 + エンジン)
  philosophy/    私の価値観・判断基準
  perspectives/  品質レンズ (設計にもレビューにも使う)
  bootstrap      プロジェクトに AI 自走基盤を生成するスキル

プロジェクトの中 (生成物)
  AGENTS.md (原典), CLAUDE.md / GEMINI.md (@AGENTS.md import)
  .github/copilot-instructions.md, .cursorrules (AGENTS.md から派生生成)
  code-reviewer エージェント
  アーキテクチャテスト
  コミット規約、開発コマンド
```

## 構成

### philosophy/ — 横断的な価値観

| ファイル | 内容 |
|---|---|
| `core-principles.md` | 語彙定義義務、逃げの禁止、捨てやすさ |
| `technology-choices.md` | 静的型付け優先、関数型寄り、技術選定の判断基準 |
| `quality-standards.md` | 製品品質 vs 技術品質、三層防御 |
| `development-values.md` | バーチカルスライス、テストファースト、0→0.1 / 99.9→100 |

### perspectives/ — 品質レンズ (20 観点)

設計時にもレビュー時にも使える二重用途の品質基準。各ファイルに「判断基準」「アンチパターン」「品質チェックポイント」を含む。

architecture, api-design, data-modeling, component, disposability, testing, error-handling, security, performance, concurrency, naming, readability, comments, variables, solid, functional, type-design, state-design, dependency, documentation

### skills/bootstrap — AI 自走基盤の生成器

`/foo-skills:bootstrap` で起動。5 Phase でプロジェクトに AI コンテキストを生成する。

## 使い方

```
/foo-skills:bootstrap
```

新規プロジェクトまたは既存プロジェクトで実行すると、対話を通じて AI 自走基盤を生成する。
