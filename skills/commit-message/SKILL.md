---
name: commit-message
description: Analyze git diff, stage changes in optimal granularity, and generate commit messages following foo-543674's conventions. Use when committing changes.
---

# Commit Message Generation

## ワークフロー

このスキルが呼び出されたら、以下の手順で自動的にコミットを作成する。

1. `git status` と `git diff` で未コミットの変更を把握する
2. 変更内容を分析し、コミット粒度ルールに基づいて意味のある単位にグルーピングする
3. グループごとに以下を繰り返す（順序は変更の依存関係に基づいて判断する）
   a. 対象ファイルを `git add` でステージングする（ファイル内で粒度を分ける必要があれば `git add -p` を使う）
   b. コミットメッセージを生成する
   c. ユーザーにステージング内容とメッセージを提示し、確認を取る
   d. 承認されたら `git commit` を実行する

### 注意事項

- 必ずユーザーの確認を取ってからコミットする
- グルーピングの判断に迷う場合はユーザーに相談する
- 既にステージング済みの変更がある場合は、その意図をユーザーに確認してから進める

## Format

```
[prefix] #ref message
```

- `prefix`: 変更の種類を示す（後述）
- `#ref`: Issue や PR 番号。なければ省略
- `message`: 英語、1 行、絵文字禁止

## Prefix 一覧

| prefix | 用途 |
|--------|------|
| feat | 新規機能の追加 |
| fix | バグ修正 |
| update | 既存機能の仕様変更・更新 |
| docs | ドキュメントの変更 |
| style | コードスタイル・フォーマットの変更（動作に影響しない） |
| improve | 外部インターフェース（trait 等の言語が提供する抽象）に変更が及ぶ既存コードの改善 |
| refactor | 外部インターフェースを変えない内部構造の変更。シグネチャ変更がモジュール内部に閉じている場合も含む |
| test | テストの追加・修正 |
| chore | ビルド、CI、依存関係など開発補助の変更 |

### update と improve の境界

判断基準は **仕様が変わるかどうか**。

- **update**: 仕様の変更を伴う。原則としてテストの変更や追加が発生するはず
- **improve**: 仕様は変えずに、品質・パフォーマンス等を改善する。外部インターフェースの変更は伴うが、既存テストの期待値は変わらない

### improve と refactor の境界

判断基準は **外部レイヤーが触るインターフェースに変更が及ぶかどうか**。

- **refactor**: 関数の効率化、無駄なリソース排除などでシグネチャが一切変わらない場合。シグネチャが変わっても、その変更がモジュール内部に閉じていて、外部に公開された抽象（trait など）が変化しない場合も refactor
- **improve**: 外部インターフェースの変更を伴う改善

## メッセージの書き方

- **何をしたかではなく、なぜその変更が必要なのかにフォーカスする**
- 1 行に収まる長さにする
- 絵文字は使わない

### 良い例

```
[fix] #123 prevent race condition on concurrent session creation
[improve] reduce N+1 queries in order listing for faster page load
[refactor] extract auth logic to prepare for OAuth provider support
```

### 悪い例

```
[fix] fixed bug          ← なぜ直したのかわからない
[feat] add function      ← 何の機能かわからない
[feat] 🚀 add feature   ← 絵文字禁止
```

## コミット粒度

- 意味のある単位ごとに小さくコミットする
- 複数の意味や目的を含むビッグバンコミットを作らない。同じ prefix でも目的が異なれば分ける
  - 例: 新機能のために既存コードをリファクタした場合、`[refactor]` と `[feat]` は別コミットにする
  - 例: 独立した2つの機能追加は、それぞれ別の `[feat]` コミットにする
- 「小さく」とはクラス単位ではなく、**使用者の視点で一つの塊として扱える機能・モジュール単位**
  - 使用者はエンドユーザーの場合も、開発者の場合もある（例: チーム開発でドメイン層とインフラ層の担当が分かれている場合、ドメイン側が実装したモジュールの使用者はインフラ側の実装者になる）
