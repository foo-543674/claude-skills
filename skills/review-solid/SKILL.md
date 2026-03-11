---
name: review-solid
description: コードレビューでSOLID原則の観点から設計を評価する。単一責任、開放閉鎖、リスコフ置換、インターフェース分離、依存逆転の各原則をチェックするときに使う。
---

# SOLID 原則レビュー

コードレビュー時に SOLID 原則の観点で指摘すべきポイントを定義する。

## Why: なぜSOLID原則が重要か

SOLID原則は、変更に強く、理解しやすく、再利用可能なオブジェクト指向設計の基本原則である。

**根本的な理由**:
1. **変更の局所化**: ソフトウェアは必ず変更される。SOLID原則に従った設計は、変更の影響を最小限に抑え、修正箇所を限定する。SOLID違反は、一箇所の変更が広範囲に波及し、デグレードリスクを増大させる
2. **理解可能性の向上**: 各クラス・モジュールの責務が明確だと、コードの理解が容易になる。God Classのような責務が曖昧なクラスは、何が起きるか予測困難で、変更が怖くなる
3. **テスタビリティ**: 依存が抽象を介して注入される設計は、テストダブルへの置き換えが容易で、単体テストが書きやすい。具象への直接依存は、テストを困難にし、テストカバレッジの低下を招く
4. **再利用性**: 単一責任で抽象に依存するクラスは、異なる文脈で再利用しやすい。複数の責務を持つクラスは、一部だけ使いたくても全体を引きずり、再利用が困難になる
5. **拡張性**: 新しい要件への対応が、既存コードの修正ではなく、新規コードの追加で実現できる。開放閉鎖原則に従った設計は、既存動作を壊すリスクなしに拡張できる

**SOLID原則レビューの目的**:
- 変更に強い設計を作る
- コードの理解と保守を容易にする
- テストしやすい構造を保証する
- 長期的な技術的負債の蓄積を防ぐ

## 判断プロセス（決定ツリー）

SOLID原則のレビュー時は、以下の順序で判断する。影響範囲が大きく、修正コストが小さい問題から確認し、問題があれば指摘する。

### ステップ1: 単一責任の原則（SRP）- 最優先

**判断基準**:
クラス・モジュールは「変更の理由」が1つだけであるべき。複数の理由で変更されるクラスは、影響範囲が広く、変更の副作用リスクが高い。

**チェック項目**:
1. **「このクラスは何をするものか」を一文で説明できるか**
   - 説明に「〜と〜」が入る → 複数の責務の可能性
   - 説明に「〜を管理する」「〜を制御する」など曖昧な表現 → 責務不明確の可能性

2. **変更理由が複数ないか**
   - 以下のような異なる理由の変更が同じクラスに影響するか確認:
     - ビジネスルールの変更
     - データ永続化方法の変更
     - UI表示形式の変更
     - 外部API連携方法の変更
     - ログ出力形式の変更
   - 2つ以上の変更理由がある → **SRP違反**

3. **具体的な違反パターン**:
   ```typescript
   // ❌ SRP違反: ビジネスロジック + 永続化 + バリデーション
   class User {
     constructor(public name: string, public email: string) {}

     validate() { /* バリデーション */ }  // 変更理由1
     calculateDiscount() { /* ビジネスロジック */ }  // 変更理由2
     save() { /* DB保存 */ }  // 変更理由3
   }

   // ✅ SRP準拠: 責務を分離
   class User {
     constructor(public name: string, public email: string) {}
     calculateDiscount() { /* ビジネスロジック */ }
   }
   class UserValidator {
     validate(user: User) { /* バリデーション */ }
   }
   class UserRepository {
     save(user: User) { /* DB保存 */ }
   }
   ```

**判定フロー**:
```
クラスの責務を分析
  ↓
「何をするものか」を一文で説明
  ↓
説明に「と」が含まれる？
  ↓ Yes → [Important] 複数の責務の可能性（詳細確認）
  ↓ No
  ↓
変更理由を列挙
  ↓
2つ以上の変更理由がある？
  ↓ Yes → [Important] SRP違反、責務を分離すべき
```

**ただし過剰分割に注意**:
- 「1クラス1メソッド」のような過剰な細分化は避ける
- 責務が本当に独立しているか確認（常に一緒に変更されるなら同じ責務）

**判定**: 2つ以上の明確な変更理由がある場合は**必ず指摘**

### ステップ2: 開放閉鎖の原則（OCP）- 高優先度

**判断基準**:
新しいケースを追加するときに、既存コードの修正が不要であるべき。拡張はコードの追加で、修正は既存コードの変更を意味する。

**チェック項目**:
1. **分岐の連鎖が拡張ごとに膨らむパターン**
   ```typescript
   // ❌ OCP違反: 新しい通知方法を追加するたびに修正が必要
   function sendNotification(type: string, message: string) {
     if (type === "email") {
       // メール送信
     } else if (type === "sms") {
       // SMS送信
     } else if (type === "push") {
       // プッシュ通知
     }
     // 新しいタイプを追加するたびにこの関数を修正
   }

   // ✅ OCP準拠: 新しいタイプは実装の追加のみ
   interface NotificationSender {
     send(message: string): void;
   }
   class EmailSender implements NotificationSender {
     send(message: string) { /* メール送信 */ }
   }
   class SmsSender implements NotificationSender {
     send(message: string) { /* SMS送信 */ }
   }
   // 新しいタイプ追加時は新規クラスを追加するだけ
   ```

2. **型による分岐（Type Switch）**
   - `instanceof`、型判定での分岐が連なる → **OCP違反の可能性**
   - 新しい型を追加するたびに分岐を追加する必要があるか → **OCP違反**

3. **拡張ポイントの有無**
   - 抽象クラス、インターフェース、ストラテジーパターンで拡張ポイントがあるか

**判定フロー**:
```
if-else/switchの連鎖を発見
  ↓
新しいケース追加時にこの分岐を修正する必要があるか？
  ↓ Yes
  → 現時点で3つ以上の分岐があるか？
      ↓ Yes → [Important] OCP違反、抽象化すべき
      ↓ No (2つ以下)
      → 今後も追加の見込みがあるか？
          ↓ Yes → [Minor] 抽象化を検討すべき
          ↓ No → 許容（YAGNI: You Aren't Gonna Need It）
```

**過剰抽象化の回避**:
- 「将来の拡張に備えて」の過剰な抽象化は避ける
- 現時点で具象が2つ以上なければ抽象化は不要
- 拡張の見込みが明確な場合のみ抽象化を推奨

**判定**: 3つ以上の分岐があり、今後も追加見込みがある場合は**指摘**

### ステップ3: 依存逆転の原則（DIP）- 高優先度

**判断基準**:
上位モジュール（ビジネスロジック）は下位モジュール（技術的詳細）の具象に依存せず、抽象に依存すべき。

**チェック項目**:
1. **具象への直接依存**
   ```typescript
   // ❌ DIP違反: UseCaseが具象に直接依存
   class CreateOrderUseCase {
     private repository = new MySQLOrderRepository();  // 具象への依存

     execute(order: Order) {
       this.repository.save(order);
     }
   }

   // ✅ DIP準拠: 抽象への依存 + 依存注入
   interface OrderRepository {
     save(order: Order): void;
   }
   class CreateOrderUseCase {
     constructor(private repository: OrderRepository) {}  // 抽象への依存

     execute(order: Order) {
       this.repository.save(order);
     }
   }
   ```

2. **依存の方向**
   - ビジネスロジックがインフラ（DB、HTTP、ファイルIO）の具象を直接importしているか → **DIP違反**
   - 安定した層（ビジネスロジック）が不安定な層（技術的詳細）に依存しているか → **DIP違反**

3. **テストダブルへの置き換え可能性**
   - 単体テスト時に依存を置き換えられるか
   - 置き換えられない → **DIP違反**（テスタビリティの問題）

**判定フロー**:
```
クラスの依存を確認
  ↓
上位モジュール（ユースケース、ドメイン）か？
  ↓ Yes
  → 下位モジュール（DB、HTTP、ファイル）の具象をimportしているか？
      ↓ Yes → [Important] DIP違反、抽象を介すべき
      ↓ No → OK
  ↓ No（下位モジュール）
  → 問題なし（下位は上位に依存してよい）
```

**判定**: 上位モジュールが具象に直接依存している場合は**必ず指摘**

### ステップ4: リスコフの置換原則（LSP）- 中優先度

**判断基準**:
サブクラスは親クラスの契約（事前条件、事後条件、不変条件）を守るべき。サブクラスで親の期待を裏切ると、多態性が破綻する。

**チェック項目**:
1. **事前条件の強化（禁止）**
   ```typescript
   // ❌ LSP違反: サブクラスが事前条件を強化
   class FileReader {
     read(path: string): string {
       // 任意のパスを受け付ける
     }
   }
   class SecureFileReader extends FileReader {
     read(path: string): string {
       if (!path.startsWith("/secure/")) {
         throw new Error("Path must start with /secure/");  // 事前条件の強化
       }
       // ...
     }
   }
   ```

2. **事後条件の弱体化（禁止）**
   ```typescript
   // ❌ LSP違反: サブクラスが事後条件を弱体化
   class Calculator {
     divide(a: number, b: number): number {
       if (b === 0) throw new Error("Division by zero");
       return a / b;  // 必ず数値を返す
     }
   }
   class ApproximateCalculator extends Calculator {
     divide(a: number, b: number): number | null {
       if (b === 0) return null;  // 親と異なる戻り値（事後条件の弱体化）
       return Math.round(a / b);
     }
   }
   ```

3. **不変条件の違反**
   - 親が保証する不変条件をサブクラスが破る

4. **継承 vs 委譲**
   - 「is-a」関係が成り立つか（LSP違反の多くはis-a関係が不適切）
   - 委譲（コンポジション）のほうが適切ではないか

**判定フロー**:
```
継承関係を発見
  ↓
サブクラスがオーバーライドしているか？
  ↓ Yes
  → 親と異なる例外を投げるか？
  → 親と異なる戻り値の範囲か？
  → 親の事前条件を強化しているか？
      ↓ いずれかYes → [Important] LSP違反
```

**継承の適切性判断**:
- is-a関係が成り立たない → 継承ではなく委譲を推奨
- サブクラスが親のメソッドの大半を使わない → LSP/ISP違反の可能性

**判定**: 契約違反がある場合は**必ず指摘**

### ステップ5: インターフェース分離の原則（ISP）- 低優先度

**判断基準**:
クライアントは使わないメソッドに依存すべきでない。太いインターフェースは、利用者に不要な依存を強制する。

**チェック項目**:
1. **空実装・例外での埋め合わせ**
   ```typescript
   // ❌ ISP違反: 不要なメソッドを空実装
   interface Worker {
     work(): void;
     eat(): void;
     sleep(): void;
   }
   class Robot implements Worker {
     work() { /* 動作 */ }
     eat() { /* 空実装 */ }  // ロボットは食べない
     sleep() { /* 空実装 */ }  // ロボットは寝ない
   }

   // ✅ ISP準拠: インターフェースを分離
   interface Workable {
     work(): void;
   }
   interface Eatable {
     eat(): void;
   }
   interface Sleepable {
     sleep(): void;
   }
   class Robot implements Workable {
     work() { /* 動作 */ }
   }
   ```

2. **利用者が使わないメソッド**
   - インターフェースの利用者が、そのメソッドの一部しか使っていないか
   - 役割ごとに小さなインターフェースに分離できないか

**判定フロー**:
```
インターフェース実装を発見
  ↓
空実装・例外で埋めているメソッドがあるか？
  ↓ Yes → [Minor] ISP違反、インターフェースを分離すべき
  ↓ No
  ↓
利用者がインターフェースの一部のメソッドしか使っていないか？
  ↓ Yes → [Minor] インターフェース分離を検討すべき
```

**判定**: 空実装・例外埋めがある場合は**指摘**、利用率が低い場合は**検討を推奨**

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

### 1. 単一責任の原則（SRP）

- [ ] クラス・モジュールの責務を一文で説明できるか
- [ ] 説明に「〜と〜」「〜を管理する」など曖昧な表現がないか
- [ ] 2つ以上の変更理由（ビジネスロジック、永続化、UI、外部連携等）が存在しないか
- [ ] ビジネスロジックと永続化処理が同じクラスにないか
- [ ] バリデーションとビジネスロジックが混在していないか
- [ ] 過剰分割（1クラス1メソッド）になっていないか

### 2. 開放閉鎖の原則（OCP）

- [ ] 新しいケース追加時に既存コードの修正が必要な構造でないか
- [ ] if-else/switchの連鎖が3つ以上あり、今後も追加見込みがあるか
- [ ] 型による分岐（instanceof、type switch）が連なっていないか
- [ ] 拡張ポイント（抽象クラス、インターフェース、ストラテジ）があるか
- [ ] 2つ以下の分岐を過剰に抽象化していないか（YAGNI違反）

### 3. 依存逆転の原則（DIP）

- [ ] 上位モジュールが下位モジュールの具象に直接依存していないか
- [ ] ユースケース・ドメイン層がDB、HTTP、ファイルIOの具象をimportしていないか
- [ ] 抽象（インターフェース・トレイト）を介して依存しているか
- [ ] 依存は外部から注入されているか（DIコンテナまたは手動注入）
- [ ] テストダブルへの置き換えが可能か

### 4. リスコフの置換原則（LSP）

- [ ] サブクラスがオーバーライドしたメソッドで親と異なる例外を投げていないか
- [ ] サブクラスがオーバーライドしたメソッドで親と異なる戻り値の範囲になっていないか
- [ ] サブクラスが親の事前条件を強化していないか
- [ ] is-a関係が本当に成り立つか（継承 vs 委譲の判断）
- [ ] サブクラスが親のメソッドの大半を使っていないか（Refused Bequest）

### 5. インターフェース分離の原則（ISP）

- [ ] インターフェース実装で空実装・例外埋めをしていないか
- [ ] 利用者がインターフェースの一部のメソッドしか使っていないか
- [ ] 役割ごとに小さなインターフェースに分離できないか

## よくあるアンチパターン

### God Class（SRP違反）
何でもやる巨大クラス。責務が曖昧で、変更の影響範囲が予測不能。

### Switch on Type（OCP違反）
型による分岐の連鎖。新しい型を追加するたびに既存コードを修正。

### Refused Bequest（LSP/ISP違反）
継承したが大半のメソッドを使わない・上書きする。is-a関係が不適切。

### Service Locator（DIP違反の一種）
グローバルなレジストリから依存を取得する。依存が隠蔽され、テストが困難。

## 例外ルール

以下の場合は、SOLID原則の例外として許容する。

### SRPの例外: Facade/Adapter

```typescript
// 複雑な外部ライブラリを簡素化するFacadeは、複数の責務を持つことが許容される
class PaymentFacade {
  initializeSDK() { /* SDK初期化 */ }
  charge(amount: number) { /* 決済 */ }
  refund(transactionId: string) { /* 返金 */ }
  // 外部ライブラリの複雑さを隠蔽する目的で複数の責務を持つことは許容
}
```

### OCPの例外: 閉じた選択肢のセット

```typescript
// 有限で固定された選択肢（曜日、月、HTTPメソッド等）は、switchで分岐しても許容
function getWeekdayName(day: number): string {
  switch (day) {
    case 0: return "Sunday";
    case 1: return "Monday";
    // ... 7つの曜日（追加されることはない）
  }
}
```

### DIPの例外: フレームワークへの依存

```typescript
// フレームワークのコントローラーは、フレームワーク固有の型への依存が許容される
import { Request, Response } from "express";  // フレームワークへの依存は許容

class UserController {
  async getUser(req: Request, res: Response) {
    // Express固有の型に依存することは、この層では許容される
  }
}
```

## 指摘の出し方

### 指摘の構造

```
【問題点】このクラスは○○の観点でSOLID原則に反しています
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□にリファクタリングすると改善します
【トレードオフ】ただし、◇◇の考慮も必要です
```

### 指摘の例

#### SRP違反の指摘

```
【問題点】`OrderService`クラスは、注文処理と決済処理の2つの責務を持っています
【理由】注文ロジックの変更と決済方法の変更は、独立した変更理由です
【影響】決済ロジックの変更時に、注文処理に意図しない影響が出るリスクがあります
【提案】以下のように責務を分離することを推奨します
  - `OrderProcessor`: 注文ロジック
  - `PaymentService`: 決済処理
  各クラスが単一の変更理由を持つようになり、変更の影響範囲が限定されます
【トレードオフ】クラス数は増えますが、各クラスの理解と変更が容易になります
```

#### OCP違反の指摘

```
【問題点】通知方法が増えるたびに`sendNotification`関数のif-elseが増えています
【理由】現在3つの通知方法があり、今後もSlack、Webhook等の追加が見込まれます
【影響】新しい通知方法を追加するたびに、この関数を修正する必要があり、既存動作を壊すリスクがあります
【提案】以下のように抽象化することを推奨します
  - `NotificationSender`インターフェースを定義
  - 各通知方法を個別のクラスとして実装（`EmailSender`, `SmsSender`等）
  新しい通知方法は新規クラスの追加のみで対応でき、既存コードへの影響がゼロになります
【トレードオフ】初期の実装コストは上がりますが、長期的には拡張が安全かつ容易になります
```

#### DIP違反の指摘

```
【問題点】`CreateOrderUseCase`が`MySQLOrderRepository`の具象に直接依存しています
【理由】ビジネスロジック（UseCase）が技術的詳細（MySQL）に依存すると、DB変更時にUseCaseの修正が必要になります
【影響】単体テストでDBのモックへの置き換えが困難で、テストカバレッジが低下します
【提案】以下のようにリファクタリングすることを推奨します
  - `OrderRepository`インターフェースを定義
  - UseCaseはインターフェースに依存
  - 具象（MySQLOrderRepository）は外部から注入
  DBをPostgreSQLに変更してもUseCaseの修正が不要になり、テストも容易になります
【トレードオフ】インターフェース定義の手間はありますが、テスタビリティと変更容易性が大幅に向上します
```

### 指摘の優先度ラベル

- **[Important]**: SRP違反（複数の変更理由）、DIP違反（上位が具象に依存）、LSP違反（契約違反）
- **[Minor]**: OCP違反（3つ以上の分岐）、ISP違反（空実装）
- **[Nit]**: 軽微な改善提案、過剰設計の指摘

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: SRP違反（Important指摘）

**コード**:
```typescript
class UserService {
  validateEmail(email: string): boolean { /* バリデーション */ }
  hashPassword(password: string): string { /* パスワードハッシュ */ }
  saveToDatabase(user: User): void { /* DB保存 */ }
  sendWelcomeEmail(email: string): void { /* メール送信 */ }
}
```

**期待される指摘**:
- [Important] 4つの異なる変更理由（バリデーション、暗号化、永続化、メール送信）
- 責務を分離すべき

### Case 2: OCP違反（Minor指摘）

**コード**:
```typescript
function calculateShipping(type: string, weight: number): number {
  if (type === "standard") return weight * 5;
  else if (type === "express") return weight * 10;
  else if (type === "overnight") return weight * 20;
  // 新しい配送方法を追加するたびに修正
}
```

**期待される指摘**:
- [Minor] 3つの分岐があり、今後も追加見込み
- 抽象化（Strategy）を検討すべき

### Case 3: DIP違反（Important指摘）

**コード**:
```typescript
class OrderProcessor {
  private repository = new MySQLOrderRepository();  // 具象への依存

  process(order: Order) {
    this.repository.save(order);
  }
}
```

**期待される指摘**:
- [Important] 具象（MySQLOrderRepository）に直接依存
- インターフェースを介して依存注入すべき

### Case 4: LSP違反（Important指摘）

**コード**:
```typescript
class Bird {
  fly(): void { /* 飛ぶ */ }
}
class Penguin extends Bird {
  fly(): void { throw new Error("Penguins can't fly"); }  // 契約違反
}
```

**期待される指摘**:
- [Important] サブクラスが親の契約を破っている
- is-a関係が不適切、継承ではなく委譲を検討すべき

### Case 5: 許容されるケース（指摘なし）

**コード**:
```typescript
// 曜日という固定された選択肢のセット
function getDayName(day: number): string {
  switch (day) {
    case 0: return "Sunday";
    case 1: return "Monday";
    // ... 7つの曜日
  }
}
```

**期待される判断**:
- 閉じた選択肢のセット（曜日は追加されない）
- OCP違反の例外として許容
- 指摘なし
