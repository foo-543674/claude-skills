---
name: commit-message
description: Analyze git diff, stage changes in optimal granularity, and generate commit messages following foo-543674's conventions. Use when committing changes, when asked to commit, when generating commit messages, or when staging and committing code.
---

# Commit Message Generation

## ワークフロー

1. `git status` と `git diff` で未コミットの変更を把握する
2. 変更内容を分析し、粒度ルールに基づいて意味のある単位にグルーピングする
3. グループごとに `git add` (必要なら `git add -p`) → コミットメッセージ生成 → `git commit` を繰り返す

確認なしでコミットを実行する。ユーザーがコミットを依頼した時点で意思決定は完了している。

## Format

```
[prefix] #ref message
```

- `prefix`: 変更の種類
- `#ref`: Issue / PR 番号。なければ省略
- `message`: 英語、1 行、絵文字禁止。**何をしたかではなく、なぜその変更が必要かにフォーカスする**

## Prefix

| prefix | 用途 |
|--------|------|
| feat | 新規機能の追加 |
| fix | バグ修正 |
| update | 既存機能の仕様変更・更新 |
| improve | 外部インターフェースの変更を伴う品質改善 |
| refactor | 外部インターフェースを変えない内部改善 |
| test | テストの追加・修正 |
| docs | ドキュメントの変更 |
| style | フォーマット等 (動作に影響しない) |
| chore | ビルド、CI、依存関係 (エンドユーザーに影響しない) |

### Prefix 判定

1. **既存か新規か**: 既存ファイル/機能の変更か、新規追加か
2. **エンドユーザーへの影響**: なし → `chore`。あり → 3 へ
3. **既存の変更**: 仕様が変わる → `update`。品質改善 → `improve` or `refactor`
4. **新規追加**: 機能 → `feat`、テスト → `test`、ドキュメント → `docs`
5. **混在**: コミットを分ける

**よくある誤判定**:
- .md でも挙動を定義するファイルなら `update` (拡張子で判断しない)
- バージョンバンプ・依存更新 → `chore` (`update` ではない)
- 既存スキルへの観点追加 → `update` (`feat` ではない)

### update / improve / refactor の境界

- **update**: 仕様変更あり。テストの期待値が変わる
- **improve**: 仕様は同じだが外部インターフェース (trait 等) が変わる
- **refactor**: シグネチャも外部インターフェースも変わらない

## 粒度ルール

以下を順に確認し、該当すれば分ける:

1. **prefix が異なる** → 分ける
2. **新規追加と既存変更が混在** → 分ける
3. **同じ prefix でも目的が異なる** → 分ける (`and` で繋ぎたくなったら複数目的のサイン)
4. **独立した機能/モジュールが混在** → 各機能ごとに分ける
5. **1 ファイル内に混在** → `git add -p` で部分ステージング
6. **依存関係がある** → 依存される側を先にコミット

### AI の判断原則

- コミット数が多くなっても粒度ルールを最優先する
- `git add -p` を手間と思わない。1 ファイル内の混在は必ず分割する
- 「同じファイルだから 1 コミット」は禁止。目的の数だけコミットがある
