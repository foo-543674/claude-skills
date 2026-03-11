---
name: setup-devcontainer
description: コンテナベースの開発環境を構築する。新規リポジトリの devcontainer 設定、既存リポジトリの開発環境改善を行うときに使う。
---

# 開発環境構築（devcontainer）

コンテナベースの開発環境を構築し、開発者が clone 後すぐに開発を始められる状態を作る。

技術品質の基盤。製品コードを書く前に整備する。

## Why: なぜ開発環境構築が重要か

開発環境の品質は、チームの生産性・新メンバーのオンボーディング速度・環境起因のバグの発生率を根本的に決定する。「動作する環境」の再現性がないと、開発効率が著しく低下し、バグの原因特定が困難になる。

**根本的な理由**:
1. **環境差異の排除**: 「自分のマシンでは動く」が開発の最大の障害。OS・ランタイムバージョン・インストール済みツール・設定の差異により、ある開発者のマシンでは動くが別の開発者のマシンでは動かない。環境差異の原因特定には膨大な時間がかかる。devcontainer により、全開発者が同一の環境で作業し、環境差異が構造的に排除される
2. **セットアップコストの削減**: 手動セットアップでは、新メンバーのオンボーディングに数日かかり、手順書の更新漏れ・手順ミスが頻発する。セットアップの複雑さは新メンバーの参入障壁となり、チームの拡張性を阻害する。devcontainer により、clone 後コンテナ起動で開発可能になり、オンボーディングが数分に短縮される
3. **ツールチェーンの統一**: linter・formatter・型チェッカーのバージョン差異により、ローカルでは検出されないが CI では失敗する問題が頻発する。手動セットアップでは、各開発者がツールのバージョン・設定を独自に管理し、統一が困難。devcontainer により、ツールチェーンがコンテナに含まれ、全員が同一バージョン・同一設定で作業する
4. **レビュー効率の向上**: 環境差異がなければ、レビュアーがレビュイーのコードをチェックアウトして即座に動作確認できる。環境差異があると、レビュアーがセットアップに時間を費やし、レビュー効率が低下する。devcontainer により、レビューアーも同一環境で即座に確認でき、レビュー品質が向上する
5. **CI/CD との一貫性**: ローカル環境と CI 環境の差異により、ローカルでは通るが CI では失敗する問題が頻発する。devcontainer で CI と同じコンテナイメージを使えば、ローカルと CI の環境差異が最小化され、CI 失敗の原因特定が容易になる

**開発環境構築の目的**:
- 環境差異を構造的に排除し、「自分のマシンでは動く」を根絶する
- セットアップコストを削減し、新メンバーのオンボーディングを加速する
- ツールチェーンを統一し、ローカル・CI の不一致を防ぐ
- レビュー効率を向上し、即座の動作確認を可能にする
- CI/CD との一貫性を確保し、環境起因のバグを防ぐ

## プロセス

### 1. 現状の確認

**既存リポジトリの場合**:
- `.devcontainer/` の有無
- `Dockerfile` / `docker-compose.yml` の有無
- 既存の開発環境セットアップ手順（README、Makefile 等）
- 使用言語・フレームワーク・ツールチェーン

**新規リポジトリの場合**:
- 使用予定の言語・フレームワーク
- 必要な外部ツール（linter, formatter, CLI 等）
- チームの IDE（VS Code 前提か、他 IDE も考慮するか）

### 2. devcontainer 設定の作成

#### 2.1 ベースイメージの選定

プロジェクトの技術スタックに合ったベースイメージを選ぶ。

**選定基準**:
- Microsoft 公式の devcontainer イメージがあればそれを優先する
- 複数言語が必要な場合は汎用イメージ + feature で追加する
- イメージサイズと起動速度のバランスを考慮する

#### 2.2 devcontainer.json の構成

```jsonc
// .devcontainer/devcontainer.json
{
  "name": "プロジェクト名",
  "image": "or dockerComposeFile + service",
  "features": {},
  "customizations": {
    "vscode": {
      "extensions": [],
      "settings": {}
    }
  },
  "forwardPorts": [],
  "postCreateCommand": "",
  "postStartCommand": ""
}
```

**必須検討項目**:
- `features`: 言語ランタイム、CLI ツール、共通ユーティリティ
- `extensions`: linter, formatter, 言語サポート、テストランナー
- `settings`: formatter on save, lint on save, 言語固有設定
- `forwardPorts`: アプリケーション、DB、管理画面等のポート
- `postCreateCommand`: 依存パッケージのインストール、初期セットアップ
- `postStartCommand`: 起動時に毎回必要な処理

#### 2.3 Dockerfile が必要な場合

ベースイメージ + features では足りない場合に Dockerfile を作成する。

**Dockerfile を作る基準**:
- システムパッケージの追加インストールが必要
- 特定バージョンのツールを固定したい
- マルチステージビルドで開発用ツールを含めたい

```
.devcontainer/
├── devcontainer.json
├── Dockerfile          # 必要な場合のみ
└── docker-compose.yml  # ローカルインフラが必要な場合
```

### 3. 開発ツールチェーンの統一

devcontainer 内で以下が統一されていることを確認する。

**必須ツール**:
- linter: コードスタイルの統一（ESLint, Ruff, clippy 等）
- formatter: フォーマットの統一（Prettier, Black, rustfmt 等）
- 型チェッカー: 型安全性の担保（tsc, mypy, cargo check 等）

**設定の配置**:
- linter / formatter の設定ファイルはリポジトリルートに置く
- devcontainer の settings で IDE が設定ファイルを自動認識するようにする
- 保存時の自動フォーマット・自動 lint を有効にする

### 4. 動作確認

devcontainer の構築後、以下を確認する。

- [ ] devcontainer がエラーなくビルド・起動できる
- [ ] 依存パッケージがインストール済みである
- [ ] linter / formatter が IDE 上で動作する
- [ ] テストが実行できる
- [ ] アプリケーションが起動できる（該当する場合）
- [ ] ポートフォワーディングが機能する（該当する場合）

## docker-compose との連携

ローカルインフラ（DB 等）が必要な場合は setup-local-infra スキルと連携する。devcontainer.json の `dockerComposeFile` で setup-local-infra が作成した `docker-compose.yml` を参照する構成にできる。

## よくあるアンチパターン

- **Fat Container**: 不要なツールを大量にインストールし、ビルドが遅い
- **Snowflake Environment**: devcontainer に入っていないツールを各開発者がローカルに追加し、環境差異が生まれる
- **Missing Formatter Config**: formatter が入っているが設定ファイルがなく、デフォルト設定で動作する（プロジェクトのスタイルと不一致）
- **No Post-Create Setup**: clone 後に手動で `npm install` 等が必要で、すぐに開発を始められない
