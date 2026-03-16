# アーキテクチャ設計レビュー

コードレビュー時にアーキテクチャ設計の観点で指摘すべきポイントを定義する。

Clean Architecture の依存ルールと CQRS の Command/Query 分離を基本原則とする。

## Why: なぜアーキテクチャレビューが重要か

アーキテクチャは、システムの長期的な保守性、拡張性、テスタビリティを決定する最も重要な設計判断である。

**根本的な理由**:
1. **変更の局所化**: 適切なアーキテクチャは、変更の影響を限定されたレイヤー・モジュールに閉じ込める。アーキテクチャが破綻すると、一箇所の変更が広範囲に波及し、変更コストが指数関数的に増大する
2. **技術的負債の防止**: アーキテクチャの問題は、初期には小さな不便として現れるが、時間とともに蓄積し、最終的にはシステム全体のリライトが必要になるほどの負債となる。早期発見・早期修正が不可欠
3. **テスタビリティの保証**: 依存が適切に注入される設計は、ユニットテストが容易で、テストカバレッジの向上とバグの早期発見につながる。アーキテクチャの問題はテストを困難にし、品質低下を招く
4. **チームの生産性**: 明確なレイヤー分離と責務の境界は、チームメンバーが独立して作業できる基盤となる。アーキテクチャが曖昧だと、コード変更時の調整コストが増大し、チームがスケールしない
5. **技術選択の柔軟性**: インフラへの依存が抽象を介している設計は、DB、フレームワーク、外部サービスの変更を容易にする。具象への直接依存は、技術選択を長期間固定し、技術的陳腐化のリスクを高める

**アーキテクチャレビューの目的**:
- 変更に強い設計を保証する
- 技術的負債の蓄積を防ぐ
- テスタビリティを確保する
- チームの生産性を最大化する
- 長期的な技術選択の柔軟性を維持する

## 判断プロセス（決定ツリー）

アーキテクチャレビュー時は、以下の順序で判断する。影響範囲が大きく、修正コストが時間とともに増大する問題から確認し、問題があれば指摘する。

### ステップ1: 依存の方向が適切か（最優先）

**判断基準**:
依存の方向が間違っていると、変更の影響が予測不能になり、アーキテクチャの根本が破綻する。

**チェック項目**:

1. **依存方向の原則**:
   - **安定した層に向かって依存する**: 変更頻度が低い層に向かって依存
   - **ビジネスロジックが技術的詳細に依存しない**: ドメイン層がインフラ層の具象を直接importしない

2. **具体的な違反パターン**:
   ```typescript
   // ❌ 依存方向違反: ドメイン層がインフラ層の具象に依存
   // domain/Order.ts
   import { MySQLOrderRepository } from "../infrastructure/MySQLOrderRepository";

   class Order {
     save() {
       const repo = new MySQLOrderRepository();  // 具象への依存
       repo.save(this);
     }
   }

   // ✅ 依存方向正しい: ドメイン層は抽象に依存、具象は外部から注入
   // domain/Order.ts
   interface OrderRepository {
     save(order: Order): void;
   }
   // ドメイン層は抽象のみを知る

   // infrastructure/MySQLOrderRepository.ts
   import { OrderRepository } from "../domain/OrderRepository";
   class MySQLOrderRepository implements OrderRepository {
     save(order: Order) { /* DB保存 */ }
   }
   ```

3. **判定フロー**:
   ```
   クラスのimport文を確認
     ↓
   上位モジュール（ドメイン、アプリケーション）か？
     ↓ Yes
     → 下位モジュール（インフラ）の具象をimportしているか？
         ↓ Yes → [Critical] 依存方向違反、抽象を介すべき
         ↓ No → OK
   ```

**判定**: 上位モジュールが下位の具象に依存している場合は**必ず指摘**（Critical）

### ステップ2: レイヤーの責務が明確か（高優先度）

**判断基準**:
各レイヤーの責務が明確でないと、どこに何を書くべきか判断できず、責務の混在が進む。

**チェック項目**:

1. **プロジェクトのレイヤー構成を把握**:
   - ディレクトリ構造・モジュール分割を確認
   - プロジェクトが採用しているレイヤー名を特定（名前はプロジェクトごとに異なる）

2. **各レイヤーの責務の本質的な定義**:

   **ドメイン層（名前の例: domain, core, model）**:
   - **定義**: そのアプリケーションがなくても存在しているルール・ロジック
   - ビジネスそのものの本質的なルール（注文の計算ロジック、在庫の制約等）
   - アプリケーション化する前から存在する概念
   - 外部依存（DB、HTTP、UI）を持たない
   - フレームワーク固有の依存を持たない
   - 例: 「10個以上購入で10%割引」というルールは、システムがなくても業務として存在する → ドメイン層

   **アプリケーション層（名前の例: usecase, application, service）**:
   - **定義**: 対象業務をアプリケーションで自動化しようとした時に初めて出てくるロジック
   - 永続化・IO（データベース保存、API呼び出し、メール送信等）
   - それらのオーケストレーション（手順の記述、依存の組み立て）
   - ロジックはドメイン層に委譲
   - 複雑な条件分岐・データ変換はドメイン層に移すべき
   - 例: 「注文をDBに保存してからメールを送る」という手順は、システム化して初めて必要になる → アプリケーション層

   **インフラ層（名前の例: infrastructure, adapter, gateway）**:
   - 技術的詳細（DB、HTTP、ファイルIO）
   - ドメイン概念を技術詳細に変換
   - ビジネスロジックを含まない

3. **責務違反パターン**:
   ```typescript
   // ❌ ユースケースにビジネスロジック
   class CreateOrderUseCase {
     execute(items: Item[]) {
       // ビジネスロジックがユースケースに埋まっている
       let total = 0;
       for (const item of items) {
         if (item.quantity > 10) {
           total += item.price * 0.9;  // 割引ロジック
         } else {
           total += item.price;
         }
       }
       // ...
     }
   }

   // ✅ ビジネスロジックはドメイン層
   class Order {
     calculateTotal(): number {
       return this.items.reduce((sum, item) =>
         sum + item.calculatePrice(), 0
       );
     }
   }
   class Item {
     calculatePrice(): number {
       return this.quantity > 10
         ? this.price * 0.9
         : this.price;
     }
   }
   class CreateOrderUseCase {
     execute(items: Item[]) {
       const order = new Order(items);
       const total = order.calculateTotal();  // ドメイン層に委譲
       // ...
     }
   }
   ```

**判定**: 責務の混在がある場合は**必ず指摘**（Important）

### ステップ3: ユースケースの設計が適切か（高優先度）

**判断基準**:
ユースケースは「依存の組み立てと手順の記述」に徹すべき。ロジックがあるなら、それはドメイン層に属する。

**チェック項目**:

1. **1ユースケース1クラス（または1関数）か**:
   - 複数のビジネス操作を1つのクラスにまとめていないか

2. **ユースケース名がビジネス操作を表しているか**:
   - ✅ `CreateOrder`, `ApproveRequest`, `CancelSubscription`
   - ❌ `OrderService.process()`, `UserManager.handle()`

3. **ユースケース内に複雑なロジックがないか**:
   ```typescript
   // ❌ ユースケースに複雑なロジック
   class CreateOrderUseCase {
     execute(data: OrderData) {
       if (data.items.length === 0) { /* バリデーション */ }
       let total = 0;
       for (const item of data.items) { /* 計算ロジック */ }
       if (total > 1000) { /* 割引ロジック */ }
       // ロジックだらけ
     }
   }

   // ✅ ユースケースは手順のみ、ロジックはドメイン層
   class CreateOrderUseCase {
     constructor(
       private orderRepository: OrderRepository,
       private paymentService: PaymentService
     ) {}

     async execute(data: OrderData): Promise<OrderResult> {
       const order = Order.create(data);  // ドメイン層
       await this.orderRepository.save(order);
       await this.paymentService.charge(order.total);
       return { orderId: order.id };
     }
   }
   ```

**判定**: ユースケースに複雑なロジックがある場合は**指摘**（Important）

### ステップ4: CQRS適用判断が適切か（中優先度）

**判断基準**:
Command（書き込み）とQuery（読み取り）で要件が明確に異なる場合のみCQRSを適用すべき。

**チェック項目**:

1. **CQRS適用の必要性**:
   - 書き込みと読み取りでデータモデルが大きく異なるか
   - パフォーマンス要件が異なるか
   - 複雑なビジネスルールと多様な検索条件が共存するか

2. **CQRS適用時のCommand側チェック**:
   - クリーンアーキテクチャ等の適切なレイヤー分離があるか
   - 正規化されたモデルを使っているか

3. **CQRS適用時のQuery側チェック**:
   - 過度な抽象化（Repository等）をしていないか
   - ストレージの能力を活かす薄い構造になっているか
   - 動的クエリ組み立てが必要な場合、Repositoryで抽象化すると逆に保守性が下がる

4. **不適切なCQRS適用**:
   ```typescript
   // ❌ 単純なCRUDにCQRSを過剰適用
   // Command側とQuery側で同じモデルを使っている
   class UserCommandModel { /* 同じフィールド */ }
   class UserQueryModel { /* 同じフィールド */ }
   ```

**判定**:
- CQRS不要なのに適用している → **過剰設計を指摘**（Minor）
- CQRS必要なのにCommand/Query混在 → **分離を推奨**（Important）

### ステップ5: 境界が明確に定義されているか（中優先度）

**判断基準**:
コンテキスト境界と外部システムとの接点が明確に定義され、防腐層が適切に配置されているか。

**チェック項目**:

1. **コンテキスト境界**:
   - 異なるドメインコンテキスト間で同じモデルを共有していないか
   - 境界ごとに独立したモデルを持っているか

2. **防腐層（Anti-Corruption Layer）**:
   ```typescript
   // ❌ 外部APIの型がドメイン層まで漏れる
   import { ExternalUserDTO } from "external-api";
   class Order {
     constructor(public user: ExternalUserDTO) {}  // 外部型への依存
   }

   // ✅ 防腐層で変換
   // adapter/ExternalUserAdapter.ts
   class ExternalUserAdapter {
     toDomain(externalUser: ExternalUserDTO): User {
       return new User(externalUser.name, externalUser.email);
     }
   }
   ```

3. **境界をまたぐデータ変換**:
   - 変換処理が一箇所にまとまっているか
   - 散在していないか

**判定**: 境界が曖昧、防腐層がない場合は**指摘**（Important）

### ステップ6: 複数集約をまたぐ操作の設計（低優先度）

**判断基準**:
複数集約をまたぐ操作を安易に`Service`にせず、ドメインの概念として設計しているか。

**チェック項目**:

1. **汎用的な`Service`の使用**:
   ```typescript
   // ❌ 汎用的なServiceに押し込む
   class OrderService {
     processOrder(order: Order, payment: Payment, inventory: Inventory) {
       // 複雑なロジック
     }
   }

   // ✅ 操作自体をドメインの概念として設計
   class OrderFulfillmentProcess {  // ドメイン層のWorkflow/Process
     execute(order: Order, payment: Payment, inventory: Inventory) {
       // Workflowとして明示的に設計
     }
   }
   ```

2. **判断基準**:
   - その操作にビジネス上の名前があるか → Workflow/Process/Sagaとして設計
   - 単純な委譲の連鎖か → ユースケース内で直接記述も許容

**判定**: 汎用`Service`に複雑な操作が押し込まれている場合は**指摘**（Minor）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

### 1. 依存の方向

- [ ] 上位モジュール（ドメイン、アプリケーション）が下位モジュール（インフラ）の具象をimportしていないか
- [ ] 依存の方向が一方通行になっているか（双方向依存・循環依存がないか）
- [ ] 抽象（インターフェース）を介して依存しているか
- [ ] 依存は外部から注入されているか（DI）

### 2. レイヤーの責務

- [ ] ドメイン層に「アプリケーション化して初めて必要になるロジック」（永続化、IO等）が混入していないか
- [ ] ドメイン層に外部依存（DB、HTTP、UI）がないか
- [ ] ドメイン層にフレームワーク固有の依存がないか
- [ ] アプリケーション層に「アプリケーションがなくても存在するビジネスルール」が埋まっていないか
- [ ] アプリケーション層に複雑なロジック（条件分岐、データ変換）が埋まっていないか（ドメイン層に移すべき）
- [ ] インフラ層にビジネスロジックが混入していないか

### 3. ユースケース設計

- [ ] 1ユースケース1クラス（または1関数）になっているか
- [ ] ユースケース名がビジネス操作を表しているか
- [ ] ユースケースが「依存の組み立てと手順」に徹しているか
- [ ] ユースケース内に複雑なロジックがないか
- [ ] ユースケース間の呼び出しが発生していないか

### 4. CQRS

- [ ] CQRS適用の必要性があるか（書き込みと読み取りの要件が明確に異なるか）
- [ ] Command側が適切なレイヤー分離・正規化されたモデルを持っているか
- [ ] Query側が過度な抽象化をしていないか
- [ ] 単純なCRUDに過剰なCQRSを適用していないか

### 5. 境界の定義

- [ ] コンテキスト境界が明確か
- [ ] 異なるコンテキスト間で同じモデルを共有していないか
- [ ] 外部APIとの接点に防腐層（Adapter/ACL）があるか
- [ ] 外部サービスの型・エラーがドメイン層まで漏れていないか
- [ ] 境界をまたぐデータ変換が一箇所にまとまっているか

### 6. 複数集約をまたぐ操作

- [ ] 複数集約操作が汎用的な`Service`に押し込まれていないか
- [ ] その操作にビジネス上の名前があるか（Workflow/Process/Saga）
- [ ] 単純な委譲の連鎖を過剰に抽象化していないか

### 7. エラーと例外の境界設計

- [ ] ドメイン層のエラーがドメインの言葉で表現されているか（`OrderNotFound`等、HTTPステータスコードではない）
- [ ] Infrastructure層の例外（DB接続エラー等）がドメイン層まで漏れていないか
- [ ] レイヤー境界でのエラー変換が行われているか
- [ ] ユースケースが返すエラーの種類が明確に定義されているか

## よくあるアンチパターン

- **Leaky Abstraction**: Repository インターフェースに SQL や ORM 固有の概念が漏れている
- **Anemic Domain Model**: Entity がデータの入れ物に過ぎず、ビジネスロジックがすべてユースケースにある
- **God Use Case**: 1つのユースケースが複数のビジネス操作をまとめて実行している
- **God Service**: 複数集約をまたぐ操作が `XxxService` に集約され、ドメインロジックの置き場所が曖昧になっている
- **Shared Kernel の肥大化**: 境界間の共有モデルが増え続け、実質的に境界がなくなっている
- **Query in Command**: Command の処理中に別の画面表示用データを組み立てている
- **Framework Coupling**: ドメイン層やアプリケーション層にフレームワークのモジュール・アノテーション・デコレータが入り込んでいる。これらの層はピュアな言語仕様だけで実装されているのが理想。言語自体の機能が弱い場合に Result 型等の汎用ユーティリティライブラリを使うのは許容されるが、フレームワーク固有の依存は持ち込まない

## 指摘の出し方

### 指摘の構造

```
【問題点】このコードは○○の観点でアーキテクチャ原則に反しています
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□にリファクタリングすると改善します
【トレードオフ】ただし、◇◇の考慮も必要です
```

### 指摘の例

#### 依存方向違反の指摘

```
【問題点】ドメイン層の`Order`クラスが、インフラ層の`MySQLOrderRepository`を直接importして使用しています
【理由】ドメイン層が技術的詳細（MySQL）に依存すると、DB変更時にビジネスロジックの修正が必要になります
【影響】
  - DB変更（PostgreSQL、DynamoDBへの移行等）の際にドメイン層を修正する必要がある
  - 単体テストでDBのモックに置き換えるのが困難
  - ドメインロジックと技術的詳細が強く結合し、変更の影響範囲が予測不能になる
【提案】以下のようにリファクタリングを推奨します
  1. `OrderRepository`インターフェースをドメイン層に定義
  2. ドメイン層はインターフェースのみに依存
  3. `MySQLOrderRepository`は外部から依存注入
  これにより、DB変更時はインフラ層のみの修正で済み、ドメイン層は一切変更不要になります
【トレードオフ】インターフェース定義の初期コストはありますが、長期的には変更容易性が大幅に向上します
```

### 指摘の優先度ラベル

- **[Critical]**: 依存方向違反（上位が下位の具象に依存）
- **[Important]**: 責務の混在、ユースケース設計の問題、境界の欠如
- **[Minor]**: CQRS適用判断、複数集約操作の設計、過剰設計
- **[Nit]**: 命名の改善、軽微なリファクタリング

### トレードオフの明示

- 過剰な分離を推奨しない。単純なCRUDにClean Architectureのフルレイヤーを強制しない
- 「この規模・複雑さならこの程度の分離で十分」という判断も示す
- CQRSの厳密な分離は、読み書きの要件が明確に異なる場合にのみ推奨する
- プロジェクトの既存アーキテクチャを尊重し、段階的な改善を提案する

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: 依存方向違反（Critical指摘）

**コード**:
```typescript
// domain/Order.ts
import { MySQLOrderRepository } from "../infrastructure/MySQLOrderRepository";

class Order {
  constructor(public items: Item[]) {}

  save() {
    const repository = new MySQLOrderRepository();  // 具象への直接依存
    repository.save(this);
  }
}
```

**期待される指摘**:
- [Critical] ドメイン層がインフラ層の具象に依存している
- 依存方向違反、抽象を介して依存を注入すべき

### Case 2: ユースケースにビジネスロジック（Important指摘）

**コード**:
```typescript
class CreateOrderUseCase {
  execute(items: Item[]) {
    // ユースケースに割引計算ロジック
    let total = 0;
    for (const item of items) {
      if (item.quantity > 10) {
        total += item.price * 0.9;  // 10%割引
      } else {
        total += item.price;
      }
    }
    // ...
  }
}
```

**期待される指摘**:
- [Important] ユースケースにビジネスロジックが埋まっている
- ドメイン層（Order, Item）に移動すべき

### Case 3: 許容されるケース（指摘なし）

**コード**:
```typescript
// 単純なCRUD、適度なレイヤー分離
class UserController {
  constructor(private userService: UserService) {}

  async getUser(id: string) {
    return await this.userService.findById(id);
  }
}
```

**期待される判断**:
- シンプルなCRUDには過剰な分離を強制しない
- この規模なら適切な分離レベル
- 指摘なし
