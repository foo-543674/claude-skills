---
name: design-component
description: コンポーネント・モジュールの責務分割とインターフェースを設計する。クラス・関数・モジュールの分割粒度と依存関係を決めるときに使う。
---

# コンポーネント設計

要件とアーキテクチャをもとに、モジュール・クラス・関数の分割とインターフェースを設計する。

review-component、review-solid、review-functional の観点を設計時に先取りする。UI コンポーネントに限らず、バックエンドのモジュール分割にも適用する。

## このスキルのスコープ

**扱う** (このスキルで決めること):
- フロントエンドの UI コンポーネント 4 区分 (Page / Container / Domain Presentational / Generic Presentational) と依存方向
- フロントエンドのリアクティブ単位の分割 (queries / mutations / state) と命名
- フロントエンドのファイル・ディレクトリ構造 (`features/<f>/...`, `lib/infra/`, `routes/`, `components/` 等)
- フロントエンドの状態管理ポリシー (fully controlled, CSS 擬似クラス判断)
- フロントエンドのインフラ抽象 (`lib/infra/` + Page → Container Props 引き渡し)
- バックエンドのレイヤー内モジュール・クラスの責務分割
- モジュール・クラス間のインターフェース設計 (公開 API, 依存方向, ISP 適用)
- 共通化の判断 (Rule of Three)
- 循環依存の回避

**扱わない** (他のスキルに任せる):
- バックエンドのレイヤー定義そのもの (営みの起源, ポート配置, レイヤー間依存) → `design-architecture`
- 集約生成の 4 役割パイプライン (Input → Validator → Validated → Factory) の方針 → `design-architecture` (実装詳細はこのスキル)
- エンティティ属性・テーブル構造・正規化 → `design-data-model`
- HTTP エンドポイント形状・リクエスト/レスポンス DTO → `design-api`
- テスト戦略・テスト実装 → `implement-testing` (Storybook + VRT の方針言及にとどめる)

スコープ外の項目は **出力しない**。成果物テンプレートで該当する箇所にはプレースホルダ (`→ <スキル名> で決定`) を置き、低品質な内容を埋めるより空欄にする。低品質な出力は存在自体が害悪なので、書かない方がマシ。

## 基礎原則 (必読)

設計判断のすべてに以下 2 つの基礎原則を適用する。詳細は `../design-architecture/resources/principles.md` を必ず読むこと。

### 1. 語彙定義義務

構造的な語 (クラス名・モジュール名・コンポーネント区分名) は「動詞 + 目的語」で 1 文定義できなければならない。

**既定の禁止語**: サービス / マネージャ / ヘルパー / ユーティリティ / プロセッサ / ワーカー / エンジン。装飾語 (`UserService` の `User` のような) を付けても禁止語の曖昧さは解消しない。

### 2. 逃げの禁止と説明責任

「思いつかないからとりあえずこれ」「難しいから簡単な方に逃げる」を避ける。フロントで特に注意すべき逃げ:

- **逃げ A (曖昧な箱)**: コンポーネントを「View」「Component」のひと括りで分けず、4 区分に分ける
- **逃げ D (安易な抽象化)**: 1 回しか使わないのに汎用コンポーネントを作らない (Rule of Three)
- **逃げ E (テストでの設計問題吸収)**: 「コンポーネントテストで API モックが必要」になったら設計のサイン
- **コンポーネントが状態を持つ逃げ**: 「とりあえず `useState` で持っておく」と Storybook での Props 制御による全カタログ化が破綻する

逃げざるを得ない場合は判断記録に Why を 3 点 (なぜ / 代替検討 / 見直しトリガー) 残す。

## Why: なぜコンポーネント設計が重要か

コンポーネント設計の品質は、表示の変更容易性・ロジックの再利用性・フレームワーク移行の可能性を根本的に決定する。宣言的 UI (状態から表示を導く) の原則に基づき、表示と状態管理を明確に分離することが、フロントエンド開発の成否を分ける。

**根本的な理由**:
1. **表示と状態管理の分離 (宣言的 UI の実現)**: 表示は「状態をどう表示するか」のみを記述し、状態管理は「状態をどう管理するか」を記述する。混在するとデザイン変更のたびに状態管理を含む全体をテストし直す必要がある
2. **捨てやすさの確保**: 純粋な Presentational コンポーネント (Props を受け取り JSX を返すだけ) はいつでも捨てて作り直せる。State・副作用を持つと技術的負債が蓄積する
3. **状態管理の再利用**: 状態管理を `state/` に集約すれば、異なる表示で同じロジックを再利用できる
4. **フレームワーク移行の可能性**: 表示と状態管理を分離すれば、フレームワーク変更時に状態管理は変更不要で表示のみ書き直せばよい
5. **認知負荷の削減**: 「Container は橋渡し」「state は状態管理」「Presentational は状態の表示」と役割が明確になる

## 判断プロセス

### ステップ1: UI かバックエンドモジュールか

**判定**:
- UI コンポーネント → ステップ 2 (4 区分) へ
- バックエンドモジュール → ステップ 6 (責務の分解) へ

### ステップ2: UI コンポーネントの 4 区分

責務をぼかさないために、UI コンポーネントは以下の 4 区分に分けて配置・命名する。「Container と Presentational の 2 区分」では区分けが甘い。

| 区分 | 1 文定義 | 配置 |
|---|---|---|
| Page | URL に対応し、URL パラメータの受け取り・レイアウトの組み立て・必要な Container の配置と `InfraContext` から取得した抽象の Props 引き渡しを行う | `src/routes/` |
| Container | feature ごとのリアクティブ状態 (サーバー状態 + 画面状態) を組み立て、それらの値とコールバックを Domain Presentational に Props としてばらして渡す | `src/features/<f>/containers/` |
| Domain Presentational | feature 固有の意味のあるブロック (フォーム全体、リスト全体等) を、Props で受け取った値だけで描画する | `src/features/<f>/components/` |
| Generic Presentational | feature やドメイン語彙に依存しない汎用 UI 原子を、Props で受け取った値だけで描画する | `src/components/` |

**依存方向**: Page → Container → Domain Presentational → Generic Presentational の一方向のみ。

詳細は `resources/component-tiers.md` を必ず参照。

### ステップ3: コンポーネントは状態を持たない (fully controlled)

JavaScript で扱う状態はすべて `features/<f>/state/` のリアクティブ単位 (Hook / Signal / Composable / Store 等) に住まわせる。コンポーネントは Props と Props 経由のコールバックだけで動作する。

**禁止**:
- Domain Presentational / Generic Presentational が `useState` / `createSignal` 等を内部で呼ぶこと
- Container が `useState` / `createSignal` 等を内部で直接呼ぶこと (state 側に切り出す)
- Container が `useContext` を直接呼ぶこと (Page で取り出して Props で渡す)

**例外**: CSS の擬似クラスで表現できる視覚状態 (`:hover` / `:focus` / `:active` / `:disabled` / `:checked` 等) はリアクティブ単位に持ち上げず CSS で書く。理由は DevTools エミュレートと Storybook 擬似クラスアドオンの恩恵を捨てないため。

詳細・判断フロー・コード例は `resources/state-policy.md` を必ず参照。

### ステップ4: Presentational の純粋性

Presentational は `UI = f(state)` の関数として設計する。

**チェック項目**:
- 命令的な DOM 操作 (`element.style.display = 'none'` 等) をしない
- State を持っていない
- 副作用 (API 呼び出し、LocalStorage アクセス等) を持っていない
- 同じ Props なら同じ結果を返す
- ユーザー操作はコールバック Props で親へ通知する

### ステップ5: ファイル命名と 1 ファイル 1 リアクティブ単位

`features/<f>/` の中は `queries/` / `mutations/` / `state/` / `containers/` / `components/` に分割し、リアクティブ単位は 1 ファイル 1 つだけエクスポートする。

- ❌ `api.ts` 1 ファイルに全部入り (肥大化する)
- ✅ `queries/<noun>.ts`、`mutations/<verb>-<noun>.ts`、`state/<noun>.ts`

**命名規約はフレームワークの慣習に従う**:
- React: `useXxx` (Hooks)
- SolidJS: `createXxx` (Signal / Resource)
- Vue: `useXxx` (Composables)

### ステップ6: バックエンドモジュールの責務分解

1 モジュール 1 責務。「このモジュールは何をするか」を 1 文で説明できない場合は分割。

**チェック項目**:
- 変更理由が複数ある場合は分割する
- 「動詞 + 目的語」で責務を 1 文定義できるか (語彙定義義務)
- 例: ユーザー認証 + データ永続化 → `Authenticator` + `UserRepository` に分割

**分解の軸**:
- ビジネスロジック vs インフラストラクチャ
- 入力バリデーション vs データ変換 vs 永続化
- 共通処理 vs ドメイン固有処理

### ステップ7: 共通化の判断 (Rule of Three)

**判定フロー**:
```
同じパターンが何回出現するか?
  ↓ 1 回 → 具象のまま (抽象化しない)
  ↓ 2 回 → 様子見 (まだ抽象化しない)
  ↓ 3 回以上 → 共通化・抽象化を検討
```

過度な抽象化を避ける。1 回しか使わないのに汎用コンポーネントを作らない。フロントエンドには高機能な DI コンテナがないため、過度な抽象化は複雑さを増すだけ (逃げ D)。

### ステップ8: 循環依存の回避

A → B → A のような循環依存は必ず解消する。

**解消方法**:
- 共通部分を第三のモジュールに抽出
- イベント駆動で疎結合にする
- 依存方向を一方向に統一する

## 捨てやすさ: シグネチャの境界設計

> **「捨てる時の影響範囲がコントロールできる状態か」**

技術的負債は、外的要因の変化が自分たちのコードにどこまで影響するかをコントロールできなくなった時に爆発する。コンポーネント設計の文脈では、捨てやすさは **シグネチャ (公開インターフェース) に外部ライブラリ固有の型を露出させない** ことで実現する。

### なぜシグネチャ露出が致命的か

公開シグネチャに外部ライブラリ固有の型が出ていると、**それを使うものすべてが直接依存する** 構造になる。今この関数 / コンポーネントを呼ぶ箇所が 1 つしかなくても、**今後追加されるすべての呼び出し元が同じ依存を引き継ぐ**。1 箇所の依存ではなく、未来全体の依存爆発を抑え込むのが、シグネチャ独立性の価値。

### ステップ9: シグネチャ独立性の検証

各モジュール / クラス / コンポーネントの **public な引数型 / 戻り値型 / コールバック型 / Props 型** に外部ライブラリ固有の型が出ていないか確認する。

**チェック項目**:

1. **バックエンドモジュールの場合**:
   - public 関数 / メソッドの引数型に ORM の生成型 / フレームワークの Request / Response 型 / 外部 SDK の型が出ていないか
   - 戻り値型に同じものが出ていないか
   - エラー型 (Result/Either の Err 側) に外部ライブラリ固有の例外型が出ていないか
   - **NG 例**: `function createOrder(req: express.Request): Promise<PrismaOrder>` — Express と Prisma に縛られる
   - **OK 例**: `function createOrder(input: CreateOrderInput): Promise<Result<OrderId, CreateOrderError>>` — 自前定義型のみ

2. **UI コンポーネント (Generic Presentational) の場合**:
   - Props 型に UI ライブラリ固有の型 (MUI の `SxProps`、特定アイコンライブラリの型等) が露出していないか
   - 露出していると、その Generic Presentational を使う Domain Presentational すべてが UI ライブラリに直接依存する
   - **NG 例**: `Button` の Props で `sx?: SxProps<Theme>` を受ける → MUI 依存が呼び出し元全部に伝搬
   - **OK 例**: `Button` の Props は `variant: "primary" | "secondary"` 等の自前抽象のみ。内部で MUI に変換

3. **状態管理 / queries / mutations の場合**:
   - 公開する hook / signal / store の戻り値型に、ライブラリ固有の型 (axios の `AxiosResponse`、TanStack Query の `UseQueryResult` の生型等) が露出していないか
   - **TanStack Query 等は例外**: queries / mutations 自体がそのライブラリの型 (UseQueryResult 等) を返すのは一般的なパターン。ただし **その型に含まれる data / error は自前定義型** にすること

### ステップ10: ラッパー / Adapter のシグネチャ独立性

戦略 A (ラッパー / 抽象化) を採用したラッパー / Adapter を設計する時は、**ラッパー自身のシグネチャが内部で使っているライブラリに依存しない** ことを必須とする。

**チェック項目**:

1. **ラッパーの引数 / 戻り値が内部ライブラリに依存していないか**:
   ```typescript
   // ❌ 「ラッパー」と称しているが内部の axios 型が露出
   import { AxiosResponse, AxiosError } from "axios";
   export const httpGet = <T>(url: string): Promise<AxiosResponse<T>> => { /* ... */ };

   // ✅ シグネチャが axios から独立
   export type HttpResult<T> = Result<{ status: number; body: T }, HttpError>;
   export const httpGet = <T>(url: string): Promise<HttpResult<T>> => { /* ... */ };
   ```

2. **薄すぎる素通しラッパーは作らない**:
   - Adapter として「何も変換 / 制御していない」ラッパーは過剰設計
   - 内部ライブラリの API を引数も戻り値もそのまま素通しするだけのラッパーは、認知負荷を増やすだけで捨てやすさの実質的な効果がない
   - ラッパーには必ず **エラー型変換、戻り値の正規化、特定機能の制限、デフォルト値の付与** 等の Adapter 責務を持たせる

### ステップ11: import 制限の実装 (戦略 B)

UI コンポーネントライブラリ / 状態管理ライブラリのように、ラッパーで隠蔽するのが構造的に困難な対象には、**import 制限** で隔離する。

**設計時に決めること**:

1. **許可ディレクトリの定義**:
   - 「このライブラリを直接 import してよいのはこのディレクトリ配下のみ」というルールを明文化
   - 例: 「MUI は `src/components/ui/` 配下のみ直接 import 可」「Zustand は `src/features/<f>/state/` 配下のみ直接 import 可」

2. **lint による機械的強制**:
   - ESLint の `no-restricted-imports` / `eslint-plugin-import` の `import/no-restricted-paths`
   - Rust の `clippy::disallowed_methods`
   - 設計時に「lint で強制する」ことを必ずセットで決める。手動運用は破綻する

3. **許可ディレクトリ内でのシグネチャ独立性**:
   - 許可ディレクトリ内 (`src/components/ui/Button.tsx` 等) のコンポーネントの **Props 型は呼び出し元から見て独立** にする
   - 内部実装で MUI を使うのは OK だが、Props で `SxProps<Theme>` を受けない
   - これにより、許可ディレクトリ内部だけを書き換えれば呼び出し元への影響を抑えられる

### ステップ12: ライブラリ使用ガイドラインの存在義務

主要な外部ライブラリそれぞれに、使い方のガイドラインが明文化されている状態を保つ。

**含めるべき項目**:
- どの戦略 (A/B/C/D) を採用しているか
- 直接 import が許可されるディレクトリはどこか
- ラッパー / Adapter がある場合、その配置場所と使い方
- lint で強制されているルール
- 「明日このライブラリがなくなったら何を修正するか」の見積もり

配置場所: `.contexts/dependencies/<library>.md` 等、プロジェクトの慣習に従う。

### 過剰設計を避ける

- **言語標準** (`Array.prototype.map`, `JSON.parse`, `Math` 等) は素のまま使う
- **薄い素通しラッパー** を作らない
- **置換可能性が要件にないものへの抽象化** (YAGNI 違反) を避ける
- 重要なのは「コントロール下にあること」で、「完全に隔離されていること」ではない

### 関連する他の設計スキルとの分担

- 戦略選択 (4 種類のどれを採用するか) の方針 → `design-architecture`
- ストレージ非依存のドメインモデル → `design-data-model`
- API レスポンス DTO への内部型漏出防止 → `design-api`

## インフラ抽象 (フロント)

ブラウザ依存の機能 (現在時刻、LocalStorage、ナビゲーション等) は `lib/infra/` に抽象として定義し、エントリポイントで Provider に束ねる。Page で `useContext` から取り出し、Container には Props で渡す。Container 内で `useContext` を直接呼ばない。

詳細は `resources/component-tiers.md` の「インフラ抽象の引き渡し」を参照。

## 成果物テンプレート

```markdown
# コンポーネント設計: [機能名]

## 用語集 (Glossary)
[このリポジトリで使う構造的な語の 1 文定義]

## コンポーネント一覧 (UI の場合)

### Page
- [Page 名]: [URL] / [配置する Container の列挙] / [InfraContext から取り出して渡す抽象]

### Container
- [Container 名]:
  - 使うリアクティブ単位: [queries / mutations / state]
  - Props として受け取るインフラ抽象: [...]
  - 渡す Domain Presentational: [...]

### Domain Presentational (fully controlled)
- [コンポーネント名]:
  - Props (state): [...]
  - Props (callbacks): [...]
  - Storybook バリエーション: [...]

### Generic Presentational
- [コンポーネント名]:
  - Props: [...]

## リアクティブ単位一覧

### queries/
- [ファイル]: [1 文定義]

### mutations/
- [ファイル]: [1 文定義]

### state/
- [ファイル]: [1 文定義]

## 依存関係図
[コンポーネント間の依存関係 (テキスト表現)]

## ファイル配置
[フロントエンドのディレクトリ構造案 (features/<f>/queries|mutations|state|containers|components, lib/infra, routes, components 等)]
[バックエンドのレイヤー単位ディレクトリは → `design-architecture` で決定]
[テーブル・マイグレーション配置は → `design-data-model` で決定]
[OpenAPI / API 形状は → `design-api` で決定]

## 逃げの判断記録
[逃げざるを得なかった判断があれば: 何を / なぜ / 検討した代替案 / 見直しトリガー]
```

## ADR の作成基準

以下に該当する判断を行った場合、ADR を作成する:

- コンポーネント分割の粒度判断 (4 区分のどこに置くか境界が曖昧な場合)
- 状態管理方式の選択 (リアクティブ単位の粒度、永続化方式)
- DI コンテナの導入・不導入の判断
- 共通コンポーネントの抽出基準の決定
- デザインパターンの適用判断
- 「逃げ」を採用した判断
- 既定の禁止語 (サービス、マネージャ等) を構造的概念として使う判断

ADR のテンプレートと配置場所はプロジェクトの既存方針に従う。プロジェクトに ADR の慣習がない場合は `docs/adr/` に連番で配置し、MADR 形式を提案する。

## よくあるアンチパターン

- **God Component**: 1 つのコンポーネントに複数の責務が集中する
- **Prop Drilling**: 深いコンポーネントツリーを通じてデータを受け渡す
- **Premature Abstraction**: 1 回しか使わないのに汎用コンポーネントを作る
- **Tight Coupling**: コンポーネント間が具象クラスで直接結合している
- **Circular Dependency**: A → B → C → A のような循環依存
- **Stateful Presentational**: Presentational が `useState` / `createSignal` を持ち、Storybook での Props 制御による全カタログ化が破綻する
- **Container がロジックを持つ**: Container 内で計算・分岐・状態管理を行い、薄いグルーでなくなる
- **Container が `useContext` を直接呼ぶ**: テスト・Storybook で Provider セットアップが必要になる
- **「コンポーネントテストで API モック」**: Container と Presentational の区分けが甘いサイン (4 区分が守られていれば不要)
- **`api.ts` 全部入り**: feature の queries / mutations / state を 1 ファイルにまとめて肥大化させる
- **CSS 擬似クラスを JS に持ち上げる**: `:hover` などをリアクティブ単位で表現し、DevTools / Storybook アドオンの恩恵を捨てる
- **「ドメインサービス」「マネージャ」「ヘルパー」のひと括り**: 語彙定義義務違反

## 関連リソース

- `../design-architecture/resources/principles.md` — 語彙定義義務 / 逃げの禁止 (横断原則の正典)
- `resources/component-tiers.md` — 4 区分の責務 / 依存方向 / インフラ抽象引き渡し / ファイル命名
- `resources/state-policy.md` — fully controlled / CSS 擬似クラス判断フロー / Container と state の関係
