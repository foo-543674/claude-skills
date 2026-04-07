# 捨てやすさ（Disposability）レビュー

コードレビュー時に「捨てやすさ」の観点で指摘すべきポイントを定義する。

## 核心原則

> **「捨てる時の影響範囲がコントロールできる状態か」**

技術的負債は、外的要因による変化が自分たちのコードにどこまで影響するかを **コントロールできなくなった時に爆発する**。設計の根幹は、外的要因の変化に対する **影響範囲のコントロール可能性** を確保することにある。

完全に隔離されている必要はない。重要なのは「明日この技術がなくなったら何箇所修正が必要か」が **予測可能** であり、**限定された場所** に閉じ込められていることである。

## Why: なぜ捨てやすさが重要か

ほとんどの技術的負債は、自分たちが書いた時点で問題なのではなく、**外的要因（ライブラリの廃止、ミドルウェアの変更、フレームワークの陳腐化、ベンダーロックイン、ライセンス変更等）が発生した時** に、その変化を吸収できる構造になっていなかったために爆発する。

**根本的な理由**:

1. **影響範囲の予測可能性**: 「明日 MySQL がなくなったらどうする？」と問うた時に、「Repository を作り直して既存の Repository を消すだけ」と即答できる構造は、変更コストが見積もり可能で、判断を先送りにせずに済む。逆に「全コードを grep して置換」が必要な構造は、変更を提案すること自体が組織的に不可能になる
2. **置換の選択肢を残す**: 捨てやすい設計は、技術選択を「永続的なロックイン」ではなく「現時点のベストチョイス」として扱える。後から優れた選択肢が出てきた時に乗り換える余地が残る
3. **将来の依存者を巻き込まない**: シグネチャに外部型が露出していると、その関数を呼ぶ **これから書かれるコード** すべてが間接的に外部型に依存する。今の自分が書く 1 箇所の依存ではなく、未来全体の依存爆発を抑え込むのが捨てやすさの価値である
4. **設計原則の根底にある共通価値観**: クリーンアーキテクチャの依存逆転、ヘキサゴナルアーキテクチャのポート/アダプタ、防腐層、SOLID の DIP、関心の分離 — これらほぼすべての設計原則は「影響範囲のコントロール可能性」という同じゴールを別の角度から表現している

**捨てやすさレビューの目的**:
- 外的要因の変化が局所化される構造を保証する
- シグネチャ露出による影響範囲の指数的拡大を防ぐ
- ガイドライン不在 / 違反による直接 import の散逸を検出する
- 対象の性質に応じた適切な隔離戦略の適用を促す

## 隔離戦略の 4 種類

「捨てやすさ」の手段はラッパーだけではない。対象の性質に応じて最適な戦略を選ぶ。

| 戦略 | 適する対象 | 例 |
|---|---|---|
| **A. ラッパー / 抽象化** | 内部詳細が露出しやすい技術基盤系。テスト Spy が困難 | DB クライアント・ORM、HTTP クライアント、ロガー、日付ライブラリ |
| **B. import 制限** | 中身が前面に出る・テスタブル・ラッパー化が困難 | UI コンポーネントライブラリ、状態管理ライブラリ |
| **C. レイヤー分離による結果的隔離** | そもそも IO / インフラに該当する | `fs`、ファイル IO、外部 API |
| **D. 並存可能な構造** | 一気に置換不可能な大型依存 | フレームワーク（React/Solid 混在、段階的移行可能） |

戦略 A だけが「捨てやすい設計」ではない。B〜D も同じく「影響範囲のコントロール」を実現する正当な手段である。対象の性質に対して **戦略がミスマッチ** になっていることが指摘対象。

## 判断プロセス（決定ツリー）

捨てやすさレビュー時は、以下の順序で判断する。**影響範囲が将来の依存者を巻き込むレベルの問題から確認する**。

### ステップ1: シグネチャ露出の検出（最優先）

**判断基準**:
外部ライブラリ / フレームワーク固有の型が public な関数 / メソッドのシグネチャに出ていると、**それを使うものすべてが直接依存する** ことになる。今の 1 箇所の依存ではなく、**未来の依存者を含めて影響範囲が肥大化していく** 構造的問題である。

**チェック項目**:

1. **public 関数 / メソッドのシグネチャ確認**:
   - 引数の型に外部ライブラリ / フレームワーク固有の型が出ていないか
   - 戻り値の型に外部ライブラリ / フレームワーク固有の型が出ていないか
   - 例外型 / エラー型が外部ライブラリ固有のものになっていないか

2. **典型的な違反パターン**:
   ```typescript
   // ❌ Express の Request 型が public なシグネチャに露出
   // application/CreateOrder.ts
   import { Request } from "express";
   export function createOrder(req: Request) {
     // この関数を呼ぶすべてのコードが Express に依存する
     // → 将来 Fastify や Hono に乗り換える時、全呼び出し元を書き換える必要がある
   }

   // ✅ 自分で定義した型を使う
   // application/CreateOrder.ts
   export type CreateOrderInput = {
     items: OrderItemInput[];
     userId: UserId;
   };
   export function createOrder(input: CreateOrderInput) {
     // Express への依存は interfaces 層で吸収済み
   }
   ```

   ```typescript
   // ❌ Prisma の生成型がドメイン層 / アプリケーション層に露出
   import { User as PrismaUser } from "@prisma/client";
   export function getActiveUser(): Promise<PrismaUser> { /* ... */ }

   // ✅ ドメイン型に変換する
   export function getActiveUser(): Promise<User> { /* ... */ }
   ```

   ```typescript
   // ❌ axios のエラー型がアプリケーション層まで漏れる
   import { AxiosError } from "axios";
   export async function fetchUser(id: string): Promise<Result<User, AxiosError>> { /* ... */ }

   // ✅ ドメインの言葉で表現したエラー型に変換
   type FetchUserError =
     | { kind: "not-found" }
     | { kind: "network-failure" }
     | { kind: "unauthorized" };
   export async function fetchUser(id: string): Promise<Result<User, FetchUserError>> { /* ... */ }
   ```

3. **判定フロー**:
   ```
   public な関数 / メソッドのシグネチャを確認
     ↓
   引数 / 戻り値 / エラー型に外部ライブラリ固有の型が含まれているか?
     ↓ Yes
       → その関数 / メソッドはどのレイヤーにあるか?
           ↓ ドメイン層 / アプリケーション層
               → [Critical] シグネチャ露出、外部型を漏らさない
           ↓ infrastructure / interfaces 層の境界より外側
               → 境界自体の設計ミス、Critical
           ↓ 境界層の内部 (adapter 内部)
               → OK
     ↓ No → OK
   ```

**判定**: ドメイン層 / アプリケーション層の public な関数 / メソッドのシグネチャに外部ライブラリ固有の型が露出している場合は **必ず指摘**（Critical）

### ステップ2: 使用ガイドラインの存在と遵守（高優先度）

**判断基準**:
そのライブラリ / フレームワークの使い方が **明文化されていない** か、**明文化されていても守られていない** 場合、外的要因の変化に対する影響範囲のコントロールが失われる。

**チェック項目**:

1. **ガイドラインの存在確認**:
   - 対象ライブラリの使用ルール（どこから import 可、ラッパー経由必須か、import 制限ディレクトリは何か）が `.contexts/` / ADR / README / コード規約等に明文化されているか
   - lint ルール（ESLint の `no-restricted-imports`、Rust の `clippy::disallowed_methods`、依存関係 lint 等）で機械的に強制されているか

2. **ガイドライン違反の検出**:
   - ガイドラインがある場合、それに違反した直接 import がないか
   - ラッパー / Adapter が定義されているのに、それを迂回して直接 import している箇所はないか
   - ガイドラインで「特定ディレクトリ配下のみ直接 import 可」とされているのに、ディレクトリ外から import している箇所はないか

3. **典型的な違反パターン**:
   ```typescript
   // ガイドライン: dayjs は lib/date/ 内のラッパー経由でのみ使用
   // ✅ ガイドライン遵守
   import { formatDate } from "@/lib/date";
   const display = formatDate(order.createdAt);

   // ❌ ガイドライン違反: 直接 import
   import dayjs from "dayjs";
   const display = dayjs(order.createdAt).format("YYYY-MM-DD");
   ```

   ```typescript
   // ガイドライン: MUI コンポーネントは src/components/ui/ 配下からのみ直接 import 可
   // ✅ ガイドライン遵守
   // src/features/order/components/OrderForm.tsx
   import { Button } from "@/components/ui/Button";

   // ❌ ガイドライン違反: features 配下から MUI を直接 import
   // src/features/order/components/OrderForm.tsx
   import { Button } from "@mui/material";
   ```

4. **検出方法**:
   ```bash
   # ライブラリの直接 import が散らばっていないかを実測
   grep -rn "from ['\"]dayjs['\"]" src/ | grep -v "src/lib/date/"
   grep -rn "from ['\"]@mui/material" src/ | grep -v "src/components/ui/"
   ```

**判定**:
- ガイドラインが存在しない場合 → **指摘**（Important）。対象ライブラリの性質に応じた戦略策定を提案
- ガイドラインがあり違反している場合 → **指摘**（Important）。違反箇所を具体的に列挙
- lint で強制されていない場合 → **指摘**（Minor）。lint ルール導入を提案

### ステップ3: 隔離戦略の妥当性（高優先度）

**判断基準**:
対象ライブラリの性質に対して採られている隔離戦略（4 種類のいずれか）が適切か。戦略がない、または性質と戦略がミスマッチな場合、捨てる時の影響範囲がコントロールできない。

**チェック項目**:

1. **対象ライブラリの性質を判定し、適切な戦略が採られているか確認**:

   | 対象の性質 | 推奨戦略 | 例 |
   |---|---|---|
   | 内部詳細が露出しやすい技術基盤、テスト Spy が困難 | **A. ラッパー / 抽象化** | DB クライアント、HTTP クライアント、ロガー、日付ライブラリ、メール送信、決済 SDK |
   | 中身が前面に出る、テスタブル、ラッパー化が困難 | **B. import 制限** | UI コンポーネントライブラリ、状態管理ライブラリ |
   | IO / インフラに該当する | **C. レイヤー分離による結果的隔離** | `fs`、ファイル IO、外部 API |
   | 一気に置換不可能な大型依存 | **D. 並存可能な構造** | フレームワーク（React/Solid 混在、段階的移行可能） |

2. **戦略ミスマッチの典型パターン**:
   - **DB クライアントを生で使用** (戦略 A が適用されていない): Repository / Adapter を介さず、ドメイン層やアプリケーション層から直接 ORM の query API を呼んでいる
   - **HTTP クライアントを生で使用** (戦略 A が適用されていない): axios / fetch / reqwest を直接呼ぶコードがプロジェクト全体に散らばっている
   - **UI ライブラリを無理にラッパー化** (戦略 B が適切なのに A を採用): MUI の Button を独自 Button でラップしているが、Props がほぼ素通しでラッパーが Adapter になっていない (Premature Disposability)
   - **`fs` をアプリケーション層から直接呼ぶ** (戦略 C が適用されていない): infrastructure 層に閉じ込めず、ユースケース内で `fs.readFile` を呼んでいる
   - **フレームワーク非依存な構造になっていない** (戦略 D の前提が崩れている): ドメイン層やアプリケーション層がフレームワークの基底クラス / デコレータ / DI コンテナに依存しており、フレームワーク変更時にビジネスロジックも書き換えが必要

3. **判定フロー**:
   ```
   対象ライブラリを特定
     ↓
   性質を判定 (技術基盤系? UI 系? IO? フレームワーク?)
     ↓
   推奨戦略 (A/B/C/D) を特定
     ↓
   現状の戦略と一致しているか?
     ↓ Yes → OK
     ↓ No
       → 戦略がない (生で散らばっている) → 戦略策定を Important で指摘
       → 戦略がミスマッチ (例: UI を無理にラッパー) → 戦略変更を Important で指摘
       → 戦略は正しいが部分的にしか適用されていない → ガイドライン違反として指摘
   ```

**判定**: 戦略がない / ミスマッチな場合は **指摘**（Important）

### ステップ4: 影響範囲の実測（中優先度）

**判断基準**:
「明日この技術がなくなったら何箇所修正が必要か」を実測し、影響範囲が予測可能でコントロール下にあるかを確認する。

**チェック項目**:

1. **直接 import の散らばり実測**:
   ```bash
   # 対象ライブラリの直接 import 箇所をカウント
   grep -rn "from ['\"]<library>" src/ | wc -l
   grep -rn "from ['\"]<library>" src/ | awk -F: '{print $1}' | sort -u | wc -l
   ```

2. **判定基準**:
   - 1〜数箇所（特定ディレクトリに集中）→ コントロール下にある（OK）
   - プロジェクト全体に散らばっている → コントロール下にない（要対応）
   - 判定の基準は対象の性質次第。技術基盤系（戦略 A 対象）はラッパー 1 箇所が理想、UI 系（戦略 B 対象）は許可ディレクトリ配下に集中していれば OK

3. **型参照の伝搬確認**:
   - 対象ライブラリの型が public シグネチャに出ている関数が、何箇所から呼ばれているかも確認
   - 露出が深く伝搬しているほど、剥がすコストが指数的に増大する

**判定**: 散らばりが大きい場合は **指摘**（Minor）。ガイドライン策定 + 段階的隔離を提案

### ステップ5: 過剰設計の警告（Minor）

**判断基準**:
すべてを捨てやすくする必要はない。隔離コストが将来の置換コストを上回るケースでは、シンプルな直接利用が正解。

**チェック項目**:

1. **言語標準ライブラリへの安易なラッパー化**:
   - `Math`, `Array.prototype.map`, `JSON.parse` 等の言語標準を独自ラッパーで包んでいないか
   - 言語標準は「明日なくなる」ことが事実上ない。ラッパーは認知負荷を増やすだけ

2. **薄すぎるラッパー**:
   - ラッパー関数が外部ライブラリの API をそのまま素通ししているだけになっていないか
   - その場合、ラッパーの意味はない。Adapter として何かを変換 / 制御していないラッパーは過剰設計

3. **置換可能性が要件にないものへの抽象化**:
   - 「将来差し替えるかもしれない」という根拠なき不安だけで抽象化していないか
   - YAGNI（You Aren't Gonna Need It）の原則を適用すべきケース

**判定**: 過剰設計が見られる場合は **指摘**（Minor / Nit）。シンプルな直接利用への置き換えを推奨

## レビュー観点（詳細チェックリスト）

### 1. シグネチャ露出（最重要）

- [ ] ドメイン層 / アプリケーション層の public 関数 / メソッドの引数型に外部ライブラリ固有の型が出ていないか
- [ ] ドメイン層 / アプリケーション層の public 関数 / メソッドの戻り値型に外部ライブラリ固有の型が出ていないか
- [ ] ドメイン層 / アプリケーション層が返すエラー型に外部ライブラリ固有の例外 / エラーが含まれていないか
- [ ] フレームワークの Request / Response / Context 型がアプリケーション層以下に漏れていないか
- [ ] ORM の生成型 (Prisma の `User`, TypeORM の Entity 等) がドメイン層に漏れていないか

### 2. ガイドラインの存在と遵守

- [ ] 主要な外部ライブラリそれぞれに、使い方ガイドライン (どこから import 可、ラッパー経由必須か等) が明文化されているか
- [ ] ガイドラインがあるなら、違反する直接 import がプロジェクト内にないか
- [ ] ラッパー / Adapter が定義されているのに迂回している箇所はないか
- [ ] ガイドラインが lint ルール (`no-restricted-imports` 等) で機械的に強制されているか

### 3. 隔離戦略の妥当性

- [ ] DB クライアント / ORM が Repository / Adapter で隔離されているか (戦略 A)
- [ ] HTTP クライアントが Client ラッパーで隔離されているか (戦略 A)
- [ ] ロガーがラッパー経由で使われているか (戦略 A)
- [ ] 日付ライブラリがラッパー経由で使われているか (戦略 A)
- [ ] UI コンポーネントライブラリが許可ディレクトリ配下からのみ直接 import されているか (戦略 B)
- [ ] 状態管理ライブラリが許可ディレクトリ配下からのみ直接 import されているか (戦略 B)
- [ ] `fs` 等の IO がインフラ層に閉じ込められているか (戦略 C)
- [ ] フレームワークがドメイン層 / アプリケーション層から完全に排除されているか (戦略 D の前提)
- [ ] フロントフレームワークの場合、複数フレームワーク混在が技術的に可能な構造になっているか (戦略 D)

### 4. 影響範囲の実測

- [ ] 主要な外部ライブラリの直接 import が、許可されたディレクトリ以外に散らばっていないか
- [ ] 「明日このライブラリがなくなったら何箇所修正が必要か」が見積もり可能か
- [ ] 修正が必要な箇所が特定のディレクトリ / モジュールに局所化されているか

### 5. 過剰設計の警告

- [ ] 言語標準ライブラリへの不要なラッパー化がないか
- [ ] 薄すぎる素通しラッパーがないか
- [ ] 置換可能性が要件にないものへの抽象化がないか

## よくあるアンチパターン

- **Signature Leak**: ドメイン層 / アプリケーション層の public シグネチャに外部ライブラリ固有の型 (Express の `Request`, Prisma の生成型, AxiosError 等) が露出している。**今の 1 箇所だけでなく、その関数の将来の呼び出し元すべてを巻き込んで影響範囲が肥大化する**
- **Scattered Direct Import**: ガイドライン無しで、特定の外部ライブラリへの直接 import がプロジェクト全体に散らばっている。剥がす時の影響範囲が予測不能
- **Bypassed Wrapper**: ラッパー / Adapter が定義されているのに、楽だからと直接 import で迂回している箇所がある。ラッパーの存在意義が無効化される
- **Ungoverned Library**: 主要な外部ライブラリの使い方ガイドライン (どこから import 可、ラッパー必須か等) がそもそも存在しない
- **Strategy Mismatch**: 対象ライブラリの性質に対して隔離戦略がミスマッチ。例: UI コンポーネントライブラリを独自ラッパーで包もうとして破綻、DB クライアントに対して import 制限だけで Repository を作っていない
- **Framework-Coupled Domain**: ドメイン層 / アプリケーション層がフレームワークの基底クラス / デコレータ / DI コンテナに依存しており、フレームワーク変更時にビジネスロジックの書き換えも必要になる
- **Shallow Wrapper**: ラッパー関数が外部ライブラリの API を素通ししているだけで、Adapter として何かを変換 / 制御していない (過剰設計)
- **Premature Disposability**: 言語標準や極めて安定した依存に対して不要な抽象化を入れる (過剰設計)
- **Unenforced Guideline**: ガイドラインは存在するが lint で強制されておらず、新規コードがガイドラインを破り続けている

## 指摘の出し方

### 指摘の構造

```
【問題点】このコードは捨てやすさの観点で問題があります
【理由】△△だからです
【影響】「明日 ◯◯ がなくなったら / 差し替えたくなったら」に対して××のコストが発生します
【提案】□□にリファクタリングすると、影響範囲を [具体的な範囲] に閉じ込められます
【トレードオフ】ただし、◇◇の考慮も必要です
```

### 指摘の例

#### Critical: シグネチャ露出

```
【問題点】`application/CreateOrderUseCase.ts:15` の `execute` メソッドの引数型 `req: express.Request` に Express 固有の型が露出しています
【理由】この型が public なシグネチャに出ていることで、`CreateOrderUseCase.execute` を呼ぶすべてのコードが Express に間接的に依存します。今この関数を呼ぶ箇所が 1 箇所しかなくても、今後追加されるすべての呼び出し元が同じ依存を引き継ぎます
【影響】
  - 将来 Fastify や Hono に乗り換える時、`CreateOrderUseCase` 自体と全呼び出し元の書き換えが必要
  - `CreateOrderUseCase` を CLI / バッチ / テストから呼ぶ時にも Express の Request を組み立てる必要が出る
  - 「明日 Express がなくなったら何箇所修正が必要か」が grep するまで分からない状態
【提案】interfaces 層 (HTTP ハンドラ) で Express の Request からアプリケーション層の入力 DTO に変換し、`CreateOrderUseCase.execute` は自前定義の `CreateOrderInput` 型を受け取るようにしてください
  ```typescript
  // application/CreateOrderUseCase.ts
  export type CreateOrderInput = {
    userId: UserId;
    items: OrderItemInput[];
  };
  export class CreateOrderUseCase {
    execute(input: CreateOrderInput): Promise<Result<OrderId, CreateOrderError>> { /* ... */ }
  }

  // interfaces/http/createOrderHandler.ts
  export const createOrderHandler = (req: express.Request, res: express.Response) => {
    const input: CreateOrderInput = {
      userId: req.user.id,
      items: req.body.items,
    };
    return useCase.execute(input).then(/* ... */);
  };
  ```
  これにより、Express への依存は `interfaces/http/` 配下のみに閉じ込められ、フレームワーク変更時はそこだけを書き換えれば済みます
【トレードオフ】DTO 変換コードの分だけ記述量は増えますが、将来の変更コストと比べれば極めて小さいコストです
```

#### Important: ガイドライン不在

```
【問題点】`dayjs` がプロジェクト全体で直接 import されており、使い方ガイドラインがありません
【理由】`grep -rn "from ['\"]dayjs['\"]" src/` の結果、47 ファイルで直接 import されています。ガイドライン (どこから import 可、ラッパー必須か) も明文化されていません
【影響】
  - 将来 `dayjs` を別のライブラリ (date-fns, luxon, Temporal API 等) に乗り換える時、47 ファイルを全部書き換える必要がある
  - 各箇所で異なるフォーマット文字列・タイムゾーン処理が混在し、バグの温床になる
  - 「明日 dayjs がメンテ停止したらどうする？」に答えられない状態
【提案】
  1. `src/lib/date/` に日付操作ラッパーを作成 (`formatDate`, `parseDate`, `addDays` 等)
  2. ガイドラインを `.contexts/dependencies/dayjs.md` に明文化: 「dayjs は `lib/date/` 内のみ直接 import 可。他のディレクトリからは `lib/date/` のラッパー経由で使う」
  3. ESLint の `no-restricted-imports` で `lib/date/` 以外からの dayjs import を禁止
  4. 既存の 47 箇所はラッパー経由に段階的に置き換え
  これにより、将来 dayjs を剥がす時は `lib/date/` 内部のみの修正で済みます
【トレードオフ】ラッパー設計と段階的移行の初期コストはありますが、47 箇所への波及を防ぐ効果は大きいです
```

#### Important: 戦略ミスマッチ

```
【問題点】MUI の `Button` を独自 `Button` コンポーネントでラップしていますが、Props がほぼ素通しで Adapter になっていません
【理由】UI コンポーネントライブラリは中身 (children, sx, slot props 等) が前面に出るため、ラッパーで隠蔽するのは構造的に困難です。素通しラッパーは認知負荷を増やすだけで、捨てやすさの実質的な効果がありません
【影響】
  - ラッパーの存在意義が薄く、メンテナンスコストだけが残る
  - 「いつか差し替えやすくするため」という名目で過剰設計になっている
【提案】UI ライブラリには戦略 B (import 制限) が適しています
  1. `src/components/ui/` 配下を「MUI 直接 import 許可ゾーン」とする
  2. それ以外のディレクトリ (`src/features/...`) からは MUI を直接 import 禁止 (`no-restricted-imports` で強制)
  3. `src/components/ui/` 配下では MUI を素直に使う
  これにより、将来 MUI を剥がす時の影響範囲は `src/components/ui/` に限定されます
【トレードオフ】完全な「シグネチャ独立」ではありませんが、UI ライブラリの性質上これが現実的な落とし所です
```

#### Minor: 過剰設計

```
【問題点】`src/lib/json.ts` で `JSON.parse` / `JSON.stringify` を独自関数でラップしていますが、Adapter として何もしていません
【理由】JSON は ECMAScript 標準仕様で、明日なくなることはありません。ラッパーは認知負荷を増やすだけです
【影響】コードを読む人が「なぜラッパーがあるのか」を考える時間が無駄になる
【提案】`JSON.parse` / `JSON.stringify` を直接使ってください。ラッパーが必要になるのは、特定の挙動 (Date 復元、BigInt 対応、Reviver の標準化等) を Adapter として加えたい時だけです
【トレードオフ】なし
```

### 指摘の優先度ラベル

- **[Critical]**: シグネチャ露出（ドメイン層 / アプリケーション層の public シグネチャに外部ライブラリ固有型が露出）
- **[Important]**: ガイドライン不在 / ガイドライン違反 / 隔離戦略のミスマッチ / 戦略の不適用
- **[Minor]**: 影響範囲の散らばり実測指摘 / 過剰設計（薄い素通しラッパー、不要な抽象化）/ lint 強制不足
- **[Nit]**: 命名の改善、軽微なリファクタリング提案

### トレードオフの明示

- **すべてを捨てやすくする必要はない**。隔離コストが将来の置換コストを上回るケースでは指摘しない
- **言語標準・極めて安定した依存** (ECMAScript 標準、Rust 標準ライブラリ、Go 標準ライブラリ等) は素のまま使ってよい
- 重要なのは「捨てる時の影響範囲が **予測可能** であること」。完全に隔離されている必要はなく、**コントロール下にある** ことが本質
- 既存プロジェクトで散らばっている直接 import を一気に全置換することは推奨せず、段階的隔離を提案する
- 過剰なラッパーを増やすことが目的化しないように、各指摘で「Why」を必ず添える

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: シグネチャ露出（Critical 指摘）

**コード**:
```typescript
// application/CreateOrderUseCase.ts
import { Request } from "express";
import { PrismaClient, Order } from "@prisma/client";

export class CreateOrderUseCase {
  constructor(private prisma: PrismaClient) {}

  async execute(req: Request): Promise<Order> {
    return this.prisma.order.create({ data: req.body });
  }
}
```

**期待される指摘**:
- [Critical] アプリケーション層の `execute` メソッドの引数型に Express の `Request` が露出している
- [Critical] アプリケーション層の `execute` メソッドの戻り値型に Prisma の `Order` (生成型) が露出している
- [Important] `PrismaClient` が直接コンストラクタ注入されており、Repository / Adapter による隔離がない（戦略 A 不適用）

### Case 2: ガイドライン違反（Important 指摘）

**状況**:
- `.contexts/dependencies/dayjs.md` に「dayjs は `src/lib/date/` 内でのみ直接 import 可」と明記されている
- ラッパー `src/lib/date/format.ts` が定義されている
- `src/features/order/components/OrderList.tsx` で `import dayjs from "dayjs"` している

**期待される指摘**:
- [Important] ガイドライン違反: `OrderList.tsx` で dayjs を直接 import している。`src/lib/date/` 経由に変更すべき
- [Minor] lint で強制されていないため、`no-restricted-imports` の追加を提案

### Case 3: 戦略ミスマッチ（Important 指摘）

**コード**:
```typescript
// src/features/order/components/SubmitButton.tsx
import { Button as MuiButton } from "@mui/material";

export const SubmitButton = (props: ButtonProps) => {
  return <MuiButton {...props} variant="contained" />;
};
```

**かつ**: `src/components/ui/Button.tsx` という独自ラッパーが既にあり、それも MuiButton をほぼ素通ししているだけ

**期待される指摘**:
- [Important] UI コンポーネントライブラリには戦略 B (import 制限) が適切。素通しラッパーは過剰設計
- [Important] `src/features/order/components/` から MUI を直接 import している（戦略 B が定まっていれば違反）
- 提案: `src/components/ui/` 配下を許可ゾーンとし、`src/features/...` からの直接 import を `no-restricted-imports` で禁止

### Case 4: 適切なケース（指摘なし）

**コード**:
```typescript
// src/lib/http/client.ts
// HTTP クライアントのラッパー (戦略 A)
import axios from "axios";

export type HttpClient = {
  get<T>(url: string): Promise<Result<T, HttpError>>;
  post<T>(url: string, body: unknown): Promise<Result<T, HttpError>>;
};

export const createHttpClient = (baseURL: string): HttpClient => {
  const instance = axios.create({ baseURL });
  return {
    get: async (url) => { /* axios エラーを HttpError に変換 */ },
    post: async (url, body) => { /* axios エラーを HttpError に変換 */ },
  };
};

// application/FetchUserUseCase.ts
import { HttpClient } from "@/lib/http/client";

export class FetchUserUseCase {
  constructor(private http: HttpClient) {}
  async execute(id: UserId): Promise<Result<User, FetchUserError>> {
    // axios への依存はゼロ。HttpClient 抽象のみに依存
  }
}
```

**期待される判断**:
- 戦略 A (ラッパー / 抽象化) が適切に適用されている
- シグネチャ露出なし
- 指摘なし

### Case 5: 過剰設計（Minor 指摘）

**コード**:
```typescript
// src/lib/array.ts
export function map<T, U>(arr: T[], fn: (x: T) => U): U[] {
  return arr.map(fn);
}

export function filter<T>(arr: T[], fn: (x: T) => boolean): T[] {
  return arr.filter(fn);
}
```

**期待される指摘**:
- [Minor] 言語標準 `Array.prototype.map` / `Array.prototype.filter` への不要なラッパー。Adapter として何も追加しておらず素通し。標準 API を直接使うべき
