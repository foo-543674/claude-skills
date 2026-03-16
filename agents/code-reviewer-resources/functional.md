# 関数型指向設計レビュー

コードレビュー時に関数型プログラミングの観点で指摘すべきポイントを定義する。純粋な関数型言語に限らず、マルチパラダイム言語で関数型のアプローチを取り入れる場面にも適用する。

## Why: なぜ関数型指向設計レビューが重要か

関数型指向の設計は、コードの予測可能性とテスタビリティを大幅に向上させる。不適切な手続き的実装は、保守性と品質を低下させる。

**根本的な理由**:
1. **テスタビリティの向上**: 純粋関数（同じ入力で常に同じ出力、副作用なし）は、モックやスタブが不要でテストが極めて簡単。副作用が混在した関数は、環境のセットアップ・外部依存のモック・状態の初期化が必要で、テストコストが数倍〜数十倍になる
2. **並行処理の安全性**: イミュータブルなデータは、レースコンディションやデータ競合が発生しない。ミュータブルな共有状態は、mutex やロックが必要で、デッドロックやパフォーマンス低下を招く。並行処理の複雑さが指数関数的に増大する
3. **可読性と予測可能性**: 純粋関数は、入力から出力が完全に予測可能で、関数名とシグネチャを見るだけで振る舞いが理解できる。副作用が混在すると、コード全体を読まないと挙動が分からず、認知負荷が増大する
4. **デバッグの容易性**: 純粋関数のバグは、入力と出力の関係を見れば原因が特定できる。副作用が混在すると、実行タイミング・グローバル状態・外部システムの状態に依存し、再現が困難で原因特定に膨大な時間を要する
5. **コードの再利用性**: 純粋関数は、外部依存がないため他の場所でも再利用できる。副作用が混在した関数は、特定の環境・状態に依存し、再利用が困難。同じロジックを何度も書く無駄が発生する

**関数型指向設計レビューの目的**:
- テストコストを最小化し、品質を向上させる
- 並行処理の複雑さを削減し、安全性を確保する
- コードの可読性と予測可能性を向上させる
- デバッグ時間を削減し、開発効率を上げる
- コードの再利用性を高め、重複を排除する

## 判断プロセス（決定ツリー）

関数型指向設計のレビュー時は、以下の順序で判断する。テスタビリティと保守性に直結する問題から確認し、問題があれば指摘する。

### ステップ1: 副作用の分離（最優先）

**判断基準**:
ビジネスロジックと副作用が混在すると、テストが困難になり、ロジックの再利用ができない。

**チェック項目**:

1. **純粋な計算と副作用の分離**:
   ```typescript
   // ❌ ビジネスロジックと副作用が混在
   function processOrder(orderId: string): void {
     const order = db.findById(orderId);  // 副作用: DB読み取り
     const total = order.items.reduce((sum, item) => sum + item.price, 0);  // 純粋な計算
     const tax = total * 0.1;  // 純粋な計算

     logger.info(`Processing order ${orderId}`);  // 副作用: ログ
     db.update(orderId, { total: total + tax });  // 副作用: DB書き込み
   }

   // ✅ 副作用を分離
   // 純粋な計算（ビジネスロジック）
   function calculateOrderTotal(items: OrderItem[]): number {
     const subtotal = items.reduce((sum, item) => sum + item.price, 0);
     const tax = subtotal * 0.1;
     return subtotal + tax;
   }

   // 副作用を含む実行層
   async function processOrder(orderId: string): Promise<void> {
     const order = await db.findById(orderId);  // 副作用
     const total = calculateOrderTotal(order.items);  // 純粋な計算

     logger.info(`Processing order ${orderId}`);  // 副作用
     await db.update(orderId, { total });  // 副作用
   }
   ```

2. **計算と実行のフェーズ分離**:
   ```typescript
   // ❌ 計算と実行が混在
   function applyDiscounts(userId: string): void {
     const user = getUser(userId);  // 実行
     const eligible = user.age >= 18;  // 計算
     if (eligible) {
       applyDiscount(userId, 0.1);  // 実行
     }
   }

   // ✅ 計算フェーズと実行フェーズを分離
   // 計算: 何をすべきかを決定（純粋）
   function determineDiscount(user: User): number | null {
     return user.age >= 18 ? 0.1 : null;
   }

   // 実行: 決定を実行（副作用）
   async function applyDiscounts(userId: string): Promise<void> {
     const user = await getUser(userId);
     const discount = determineDiscount(user);

     if (discount !== null) {
       await applyDiscount(userId, discount);
     }
   }
   ```

3. **副作用のシグネチャ明示**:
   ```typescript
   // ❌ シグネチャから副作用が読み取れない
   function processUser(user: User): User {
     sendEmail(user.email);  // 隠れた副作用
     return user;
   }

   // ✅ 副作用を Promise で明示
   async function processUser(user: User): Promise<User> {
     await sendEmail(user.email);  // Promise で副作用を明示
     return user;
   }

   // ✅ または副作用を関数名で明示
   function sendEmailAndReturnUser(user: User): Promise<User> {
     // ...
   }
   ```

**判定フロー**:
```
関数を確認
  ↓
副作用（I/O、ログ、DB、外部API等）が含まれているか？
  ↓ Yes
  ↓
純粋な計算と副作用が混在しているか？
  ↓ Yes → [Important] 純粋な計算を別関数に抽出すべき
  ↓ No
  ↓
副作用がシグネチャから読み取れるか？
  ↓ No → [Important] Promise または関数名で明示すべき
```

**判定**: 副作用と純粋な計算の混在は**必ず指摘**（Important）

### ステップ2: 純粋関数化（高優先度）

**判断基準**:
外部状態に依存する関数は、テストが困難で予測不能。純粋関数化できる場合は優先的に実施。

**チェック項目**:

1. **外部状態への依存排除**:
   ```typescript
   // ❌ グローバル変数に依存
   let discount = 0.1;
   function calculatePrice(price: number): number {
     return price * (1 - discount);  // グローバル変数に依存
   }

   // ✅ 外部状態への依存を排除
   function calculatePrice(price: number, discount: number): number {
     return price * (1 - discount);  // 引数から取得
   }
   ```

2. **同じ入力で常に同じ出力**:
   ```typescript
   // ❌ 実行時刻に依存（非決定的）
   function isBusinessHours(): boolean {
     const hour = new Date().getHours();
     return hour >= 9 && hour < 18;
   }

   // ✅ 時刻を引数で受け取る（決定的）
   function isBusinessHours(date: Date): boolean {
     const hour = date.getHours();
     return hour >= 9 && hour < 18;
   }
   ```

3. **不必要な副作用の除去**:
   ```typescript
   // ❌ 計算にログが混在
   function calculateTotal(items: Item[]): number {
     console.log('Calculating total...');  // 不要な副作用
     return items.reduce((sum, item) => sum + item.price, 0);
   }

   // ✅ 純粋な計算のみ
   function calculateTotal(items: Item[]): number {
     return items.reduce((sum, item) => sum + item.price, 0);
   }
   ```

**判定フロー**:
```
関数を確認
  ↓
外部状態（グローバル変数、現在時刻等）に依存しているか？
  ↓ Yes → [Important] 外部状態を引数で受け取るべき
  ↓ No
  ↓
同じ入力で常に同じ出力を返すか？
  ↓ No → [Important] 非決定的な要素を引数化すべき
```

**判定**: 外部状態依存、非決定性は**必ず指摘**（Important）

### ステップ3: イミュータビリティ（高優先度）

**判断基準**:
破壊的変更は、並行処理でバグを引き起こし、コードの追跡を困難にする。

**チェック項目**:

1. **破壊的変更の回避**:
   ```typescript
   // ❌ 破壊的変更
   function addItem(cart: Cart, item: Item): Cart {
     cart.items.push(item);  // 元のオブジェクトを変更
     return cart;
   }

   // ✅ 新しいオブジェクトを返す
   function addItem(cart: Cart, item: Item): Cart {
     return {
       ...cart,
       items: [...cart.items, item],
     };
   }
   ```

2. **コレクション操作の非破壊性**:
   ```typescript
   // ❌ 元の配列を変更
   function filterActiveUsers(users: User[]): User[] {
     return users.filter(u => u.isActive);  // filter は OK
     // しかし以下は NG
     // users.sort((a, b) => a.name.localeCompare(b.name));  // sort は破壊的
   }

   // ✅ 非破壊的な操作
   function sortUsersByName(users: User[]): User[] {
     return [...users].sort((a, b) => a.name.localeCompare(b.name));
   }
   ```

3. **共有状態のイミュータブル化**:
   ```typescript
   // ❌ ミュータブルな共有状態
   const config = { timeout: 1000 };
   function setTimeout(value: number) {
     config.timeout = value;  // 共有状態を変更
   }

   // ✅ イミュータブルな共有状態
   function createConfig(timeout: number): Config {
     return Object.freeze({ timeout });  // 変更不可
   }
   ```

**判定フロー**:
```
データ操作を確認
  ↓
元のデータを破壊的に変更しているか？
  ↓ Yes → [Important] 新しいデータを返すべき
  ↓ No
  ↓
sort/reverse 等の破壊的メソッドを使っているか？
  ↓ Yes → [Important] コピーしてから操作すべき
```

**判定**: 破壊的変更は**必ず指摘**（Important）

### ステップ4: データ変換パイプライン（中優先度）

**判断基準**:
命令的なループは可読性を下げる。宣言的な変換で意図を明確にする。

**チェック項目**:

1. **命令的ループから宣言的変換へ**:
   ```typescript
   // ❌ 命令的ループ
   function getActiveUserNames(users: User[]): string[] {
     const result: string[] = [];
     for (let i = 0; i < users.length; i++) {
       if (users[i].isActive) {
         result.push(users[i].name);
       }
     }
     return result;
   }

   // ✅ 宣言的な変換
   function getActiveUserNames(users: User[]): string[] {
     return users
       .filter(user => user.isActive)
       .map(user => user.name);
   }
   ```

2. **パイプラインの各ステップの明確化**:
   ```typescript
   // ❌ 複雑な1行
   const result = users.filter(u => u.age >= 18 && u.hasEmail).map(u => ({ ...u, discount: u.age >= 65 ? 0.2 : 0.1 }));

   // ✅ ステップを分解
   const adults = users.filter(user => user.age >= 18 && user.hasEmail);
   const withDiscounts = adults.map(user => ({
     ...user,
     discount: user.age >= 65 ? 0.2 : 0.1,
   }));
   ```

**判定**: 命令的ループは**指摘**（Minor）

### ステップ5: 高階関数の適切な使用（中優先度）

**判断基準**:
複雑なラムダは可読性を損なう。適度に名前付き関数に切り出す。

**チェック項目**:

1. **複雑なラムダの切り出し**:
   ```typescript
   // ❌ 複雑なラムダ
   users.filter(u => {
     const hasPermission = u.role === 'admin' || u.role === 'moderator';
     const isVerified = u.emailVerified && u.phoneVerified;
     return hasPermission && isVerified && u.isActive;
   });

   // ✅ 名前付き関数に切り出し
   function hasModeratorPermission(user: User): boolean {
     return user.role === 'admin' || user.role === 'moderator';
   }

   function isFullyVerified(user: User): boolean {
     return user.emailVerified && user.phoneVerified;
   }

   function canModerate(user: User): boolean {
     return hasModeratorPermission(user) && isFullyVerified(user) && user.isActive;
   }

   users.filter(canModerate);
   ```

**判定**: 複雑なラムダは**指摘**（Minor）

### ステップ6: null / 例外の代替（低優先度）

**判断基準**:
null チェックの連鎖や例外での制御フローは、可読性を下げる。

**チェック項目**:

1. **Optional 型での明示的な処理**:
   ```typescript
   // ❌ null チェックの連鎖
   function getUserEmail(userId: string): string | null {
     const user = findUser(userId);
     if (user === null) return null;

     const profile = user.profile;
     if (profile === null) return null;

     return profile.email;
   }

   // ✅ Optional 型（言語サポートがある場合）
   function getUserEmail(userId: string): Option<string> {
     return findUser(userId)
       .flatMap(user => user.profile)
       .map(profile => profile.email);
   }
   ```

2. **Result 型での明示的なエラー処理**:
   ```typescript
   // ❌ 例外で制御フロー
   function parseAge(input: string): number {
     const age = parseInt(input);
     if (isNaN(age)) {
       throw new Error('Invalid age');
     }
     if (age < 0 || age > 150) {
       throw new Error('Age out of range');
     }
     return age;
   }

   // ✅ Result 型で明示的なエラー
   function parseAge(input: string): Result<number, ParseError> {
     const age = parseInt(input);
     if (isNaN(age)) {
       return Err(new ParseError('Invalid age'));
     }
     if (age < 0 || age > 150) {
       return Err(new ParseError('Age out of range'));
     }
     return Ok(age);
   }
   ```

**判定**: null チェックの連鎖は**指摘**（Nit）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

### 1. 副作用の分離

- [ ] 純粋な計算と副作用（I/O、ログ、DB、外部API等）が混在していないか
- [ ] 「計算」と「実行」のフェーズが明確に分かれているか
- [ ] 副作用が関数のシグネチャ（Promise、関数名等）から読み取れるか
- [ ] ビジネスロジックが純粋な関数として抽出されているか

### 2. 純粋関数化

- [ ] 同じ入力に対して常に同じ出力を返すか
- [ ] 外部状態（グローバル変数、現在時刻等）に依存していないか
- [ ] 純粋にできる関数が不必要に副作用を持っていないか
- [ ] 非決定的な要素（乱数、時刻等）が引数化されているか

### 3. イミュータビリティ

- [ ] データの変更が破壊的（in-place mutation）になっていないか
- [ ] コレクション操作で元のデータを壊していないか
- [ ] sort/reverse 等の破壊的メソッドをコピー後に使用しているか
- [ ] 共有される状態がミュータブルになっていないか
- [ ] パフォーマンスが重要なホットパスでは局所的なミュータブル操作を許容しているか

### 4. データ変換パイプライン

- [ ] 命令的なループ（for + 手動 push）を宣言的な変換（map/filter/reduce）に置き換えられないか
- [ ] パイプラインの各ステップが明確な責務を持っているか
- [ ] メソッドチェーンが長すぎて可読性を損なっていないか
- [ ] 大量データの場合、遅延評価やイテレータを検討しているか

### 5. 高階関数の適切な使用

- [ ] コールバックやラムダが複雑すぎないか
- [ ] 長いラムダを名前付き関数に切り出しているか
- [ ] 高階関数の乱用で逆に読みにくくなっていないか
- [ ] 部分適用やカリー化が意味のある場面で使われているか

### 6. null / 例外の代替

- [ ] null チェックの連鎖を Optional/Maybe/Result 型で置き換えられないか
- [ ] 例外を制御フローに使っていないか
- [ ] Expected な失敗を戻り値の型で表現しているか
- [ ] 言語やフレームワークの慣習に沿っているか

## 指摘の出し方

### 指摘の構造

```
【問題点】この関数型指向設計は○○の問題があります
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□に変更すると改善します
【メリット】◇◇が実現できます
```

### 指摘の例

#### 副作用と純粋な計算の混在の指摘

```
【問題点】この関数はビジネスロジックと副作用が混在しています
【理由】DB読み取り・純粋な計算・ログ・DB書き込みが1つの関数に含まれています
【影響】以下のリスクが発生します:
  - テストが困難（DB のモックが必要）
  - ビジネスロジックの再利用ができない
  - 変更の影響範囲が広い
【提案】以下のように純粋な計算を別関数に抽出してください
  ```typescript
  // Before: 副作用と計算が混在
  function processOrder(orderId: string): void {
    const order = db.findById(orderId);  // 副作用
    const total = order.items.reduce((sum, item) => sum + item.price, 0);  // 計算
    const tax = total * 0.1;  // 計算

    logger.info(`Processing order ${orderId}`);  // 副作用
    db.update(orderId, { total: total + tax });  // 副作用
  }

  // After: 純粋な計算を抽出
  // 純粋な計算（ビジネスロジック）
  function calculateOrderTotal(items: OrderItem[]): number {
    const subtotal = items.reduce((sum, item) => sum + item.price, 0);
    const tax = subtotal * 0.1;
    return subtotal + tax;
  }

  // 副作用を含む実行層
  async function processOrder(orderId: string): Promise<void> {
    const order = await db.findById(orderId);
    const total = calculateOrderTotal(order.items);  // 純粋な計算

    logger.info(`Processing order ${orderId}`);
    await db.update(orderId, { total });
  }
  ```
【メリット】calculateOrderTotal が単独でテスト可能になり、他の場所でも再利用できます
```

#### 破壊的変更の指摘

```
【問題点】この関数は元の配列を破壊的に変更しています
【理由】sort() メソッドは元の配列を直接変更し、新しい配列を返しません
【影響】以下のリスクが発生します:
  - 呼び出し元の配列が予期せず変更される
  - 並行処理でレースコンディションが発生
  - デバッグが困難（どこで配列が変更されたか追跡不能）
【提案】以下のように非破壊的な操作に変更してください
  ```typescript
  // Before: 破壊的変更
  function sortUsersByName(users: User[]): User[] {
    return users.sort((a, b) => a.name.localeCompare(b.name));
    // 元の配列が変更される
  }

  // After: 非破壊的な操作
  function sortUsersByName(users: User[]): User[] {
    return [...users].sort((a, b) => a.name.localeCompare(b.name));
    // 新しい配列を返す
  }
  ```
【メリット】呼び出し元の配列が保護され、並行処理でも安全になります
```

#### 命令的ループから宣言的変換への指摘

```
【問題点】この命令的なループは宣言的な変換で置き換えられます
【理由】for ループと手動 push は、何をしているかが分かりにくく、バグが混入しやすい構造です
【影響】以下のリスクが発生します:
  - コードの意図が不明瞭
  - 変更時にバグが混入しやすい
  - 可読性が低く、レビューが困難
【提案】以下のように map + filter で宣言的に書いてください
  ```typescript
  // Before: 命令的ループ
  function getActiveUserNames(users: User[]): string[] {
    const result: string[] = [];
    for (let i = 0; i < users.length; i++) {
      if (users[i].isActive) {
        result.push(users[i].name);
      }
    }
    return result;
  }

  // After: 宣言的な変換
  function getActiveUserNames(users: User[]): string[] {
    return users
      .filter(user => user.isActive)
      .map(user => user.name);
  }
  ```
【メリット】何をしているか（アクティブなユーザーの名前を取得）が一目で分かります
```

### 指摘の優先度ラベル

- **[Important]**: 副作用と純粋な計算の混在、外部状態依存、破壊的変更（テスタビリティ・並行処理の安全性に直結）
- **[Minor]**: 命令的ループ、複雑なラムダ、高階関数の乱用
- **[Nit]**: null チェックの連鎖、例外での制御フロー

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: 副作用と純粋な計算の混在（Important指摘）

**コード**:
```typescript
function processOrder(orderId: string): void {
  const order = db.findById(orderId);  // 副作用
  const total = order.items.reduce((sum, item) => sum + item.price, 0);  // 計算

  logger.info(`Processing order ${orderId}`);  // 副作用
  db.update(orderId, { total });  // 副作用
}
```

**期待される指摘**:
- [Important] ビジネスロジック（計算）と副作用が混在
- 純粋な計算を別関数に抽出すべき
- テストが困難、再利用ができない

### Case 2: 破壊的変更（Important指摘）

**コード**:
```typescript
function sortUsersByName(users: User[]): User[] {
  return users.sort((a, b) => a.name.localeCompare(b.name));
  // 元の配列が変更される
}
```

**期待される指摘**:
- [Important] 元の配列を破壊的に変更
- 並行処理でレースコンディションのリスク
- コピーしてから sort すべき

### Case 3: 外部状態依存（Important指摘）

**コード**:
```typescript
let discount = 0.1;
function calculatePrice(price: number): number {
  return price * (1 - discount);  // グローバル変数に依存
}
```

**期待される指摘**:
- [Important] グローバル変数に依存
- テストが困難、予測不能
- discount を引数で受け取るべき

### Case 4: 命令的ループ（Minor指摘）

**コード**:
```typescript
function getActiveUserNames(users: User[]): string[] {
  const result: string[] = [];
  for (let i = 0; i < users.length; i++) {
    if (users[i].isActive) {
      result.push(users[i].name);
    }
  }
  return result;
}
```

**期待される指摘**:
- [Minor] 命令的なループ
- map + filter で宣言的に書ける
- 可読性と保守性が向上

### Case 5: 許容されるケース（指摘なし）

**コード**:
```typescript
// 純粋な計算を抽出
function calculateOrderTotal(items: OrderItem[]): number {
  const subtotal = items.reduce((sum, item) => sum + item.price, 0);
  const tax = subtotal * 0.1;
  return subtotal + tax;
}

// 非破壊的な操作
function sortUsersByName(users: User[]): User[] {
  return [...users].sort((a, b) => a.name.localeCompare(b.name));
}

// 宣言的な変換
function getActiveUserNames(users: User[]): string[] {
  return users
    .filter(user => user.isActive)
    .map(user => user.name);
}

// 副作用が明示されている
async function processOrder(orderId: string): Promise<void> {
  const order = await db.findById(orderId);
  const total = calculateOrderTotal(order.items);
  await db.update(orderId, { total });
}
```

**期待される判断**:
- 純粋な計算が分離されている
- 非破壊的な操作を使用
- 宣言的な変換で可読性が高い
- 副作用が Promise で明示されている
- 指摘なし
