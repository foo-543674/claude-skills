# 型設計レビュー

コードレビュー時に型システムを活かした設計の観点で指摘すべきポイントを定義する。TypeScript, Scala, Rust, Kotlin 等の型システムを持つ言語を対象とする。

このスキルには筆者の設計思想が含まれる。型による安全性の追求とコードの複雑さはトレードオフの関係にあり、プロジェクトの規模・チームの型システムへの習熟度に応じた判断が必要。

## Why: なぜ型設計レビューが重要か

型設計の品質は、コンパイル時に防げるバグの範囲とコードの保守性を決定する。不適切な型設計は、ランタイムエラーの温床となり、リファクタリングを困難にする。

**根本的な理由**:
1. **コンパイル時のバグ検出**: 型レベルで不正な状態・操作を排除すれば、実行せずにバグを発見できる。`string` で何でも表現すると、型チェッカーは無力化され、ランタイムエラーが多発する。型による保護が強いほど、テストやデバッグの負担が減る
2. **リファクタリングの安全性**: 型が明確なら、変更の影響範囲が型エラーで明示される。`any` や型アサーションの乱用は、変更が必要な箇所を隠蔽し、リファクタリング時に見落としが発生する。型を活かせば、大規模な変更も安全に実行できる
3. **ドメイン知識の表現**: 型はドメインのルール・制約を表現する手段。`UserId` と `ProductId` を別の型にすれば、誤用が型エラーになる。プリミティブ型の乱用は、ドメイン知識をコードに埋め込む機会を失わせ、暗黙知が増える
4. **API の自己文書化**: 型が明確なら、関数のシグネチャだけで使い方が分かる。戻り値が `any` や `unknown` では、実装を読むかドキュメントを探さないと使えない。型を活かせば、IDE の補完とコンパイラの支援で開発効率が向上する
5. **検証の責務の明確化**: 未検証の `string` と検証済みの `Email` を型で区別すれば、検証漏れが構造的に防がれる。型とランタイムバリデーションの責務が曖昧だと、検証の重複や漏れが発生し、セキュリティリスクが増大する

**型設計レビューの目的**:
- コンパイル時に検出できるバグの範囲を最大化する
- リファクタリングの安全性を確保し、変更容易性を高める
- ドメイン知識を型として表現し、暗黙知を減らす
- API の自己文書化により、開発効率を向上させる
- 検証の責務を明確にし、セキュリティリスクを削減する

## 判断プロセス（決定ツリー）

型設計のレビュー時は、以下の順序で判断する。コンパイル時のバグ検出に直結する問題から確認し、問題があれば指摘する。

### ステップ1: 不正な状態の型レベル排除（最優先）

**判断基準**:
不正な状態の組み合わせが型で防がれていないと、ランタイムエラーが多発し、テスト負担が増大する。

**チェック項目**:

1. **判別共用体による状態分離**:
   ```typescript
   // ❌ optional フィールドで矛盾する状態が生まれる
   type Article = {
     status: 'draft' | 'published';
     publishedAt?: Date;  // draft でも publishedAt が存在しうる（不正）
     author?: string;     // published でも author が null（不正）
   };

   // ✅ 判別共用体で状態ごとに構造を分離
   type Article =
     | { status: 'draft'; author: string }
     | { status: 'published'; author: string; publishedAt: Date };
   ```

2. **不変条件の型レベル表現**:
   ```typescript
   // ❌ 型で不変条件が表現されていない
   type Range = {
     min: number;
     max: number;  // min > max でも型エラーにならない
   };

   // ✅ Branded Type で不変条件を保証
   type Range = {
     readonly min: number;
     readonly max: number;
     readonly _brand: 'ValidRange';  // コンストラクタでのみ付与
   };

   function createRange(min: number, max: number): Range {
     if (min > max) {
       throw new Error('min must be <= max');
     }
     return { min, max, _brand: 'ValidRange' };
   }
   ```

**判定フロー**:
```
型定義を確認
  ↓
optional フィールドの組み合わせで矛盾する状態が生まれないか？
  ↓ Yes → [Important] 判別共用体で分離すべき
  ↓ No
  ↓
ドメインの不変条件が型で表現されているか？
  ↓ No → [Important] Branded Type 等で保証すべき
  ↓ Yes → OK
```

**判定**: 不正な状態を許容する型は**必ず指摘**（Important）

### ステップ2: プリミティブ型の過剰使用（高優先度）

**判断基準**:
`string` や `number` で何でも表現すると、誤用が型エラーにならず、バグの温床となる。

**チェック項目**:

1. **Branded Type の導入**:
   ```typescript
   // ❌ プリミティブ型で表現（誤用が防げない）
   function getUser(userId: string): User { ... }
   function getProduct(productId: string): Product { ... }

   getUser(productId);  // 型エラーにならない（バグ）

   // ✅ Branded Type で区別
   type UserId = string & { readonly _brand: 'UserId' };
   type ProductId = string & { readonly _brand: 'ProductId' };

   function getUser(userId: UserId): User { ... }
   function getProduct(productId: ProductId): Product { ... }

   getUser(productId);  // 型エラー（誤用を防ぐ）
   ```

2. **単位の異なる数値の区別**:
   ```typescript
   // ❌ 単位が異なる数値を同じ number で扱う
   function convertCurrency(amount: number, rate: number): number { ... }
   convertCurrency(100, 0.9);  // 100 が円なのかドルなのか不明

   // ✅ 単位ごとに型を分離
   type JPY = number & { readonly _unit: 'JPY' };
   type USD = number & { readonly _unit: 'USD' };

   function convertToUSD(amount: JPY, rate: number): USD { ... }
   ```

**判定フロー**:
```
プリミティブ型の使用を確認
  ↓
ドメイン固有の ID・値を string/number で表現しているか？
  ↓ Yes → [Important] Branded Type に変更すべき
  ↓ No
  ↓
単位の異なる数値を同じ number で扱っているか？
  ↓ Yes → [Important] 単位ごとに型を分離すべき
  ↓ No → OK
```

**判定**: プリミティブ型の過剰使用は**必ず指摘**（Important）

### ステップ3: 型の表現力（高優先度）

**判断基準**:
型が曖昧だと、IDE の補完が効かず、実装を読まないと使えない。

**チェック項目**:

1. **Union 型による列挙**:
   ```typescript
   // ❌ string で受ける（誤入力が防げない）
   function setStatus(status: string): void { ... }
   setStatus('activ');  // タイポが型エラーにならない

   // ✅ Union 型で列挙
   type Status = 'active' | 'inactive' | 'pending';
   function setStatus(status: Status): void { ... }
   setStatus('activ');  // 型エラー
   ```

2. **any / unknown の適切な使用**:
   ```typescript
   // ❌ 戻り値が any（使う側が困る）
   function parseJSON(json: string): any { ... }

   // ✅ ジェネリクスで型を明示
   function parseJSON<T>(json: string): T { ... }
   ```

3. **型アサーションの制限**:
   ```typescript
   // ❌ as で型安全性を破壊
   const user = data as User;  // data が User とは限らない

   // ✅ 型ガードで安全に変換
   function isUser(data: unknown): data is User {
     return typeof data === 'object' && data !== null && 'id' in data;
   }

   if (isUser(data)) {
     const user = data;  // 型が保証されている
   }
   ```

**判定フロー**:
```
型の明確さを確認
  ↓
列挙できる値を string で受けているか？
  ↓ Yes → [Important] Union 型に変更すべき
  ↓ No
  ↓
any/unknown を不適切に使用しているか？
  ↓ Yes → [Important] 具体的な型に変更すべき
  ↓ No
  ↓
as による型アサーションを乱用しているか？
  ↓ Yes → [Important] 型ガードに変更すべき
  ↓ No → OK
```

**判定**: 曖昧な型、型アサーションの乱用は**必ず指摘**（Important）

### ステップ4: ジェネリクスの適切な使用（中優先度）

**判断基準**:
ジェネリクスは再利用性を高めるが、過度な使用は可読性を損なう。

**チェック項目**:

1. **再利用性の向上**:
   ```typescript
   // ❌ 具象型をハードコード（再利用性がない）
   function getUserById(id: string): User { ... }
   function getProductById(id: string): Product { ... }
   // 同じパターンが繰り返される

   // ✅ ジェネリクスで抽象化
   function getById<T>(collection: T[], id: string): T | undefined { ... }
   ```

2. **過剰な抽象化の回避**:
   ```typescript
   // ❌ 1箇所でしか使わないのにジェネリクス
   function processUser<T extends User>(user: T): T { ... }
   // T は常に User なので不要

   // ✅ 具象型で十分
   function processUser(user: User): User { ... }
   ```

**判定**: 不適切なジェネリクスの使用は**指摘**（Minor）

### ステップ5: アサーションとバリデーションの責務分離（中優先度）

**判断基準**:
未検証の値と検証済みの値が型で区別されていないと、検証漏れが発生する。

**チェック項目**:

1. **検証済み型の導入**:
   ```typescript
   // ❌ 未検証の string と検証済みの Email が区別されない
   function sendEmail(email: string): void { ... }

   // ✅ 検証済み型を導入
   type Email = string & { readonly _brand: 'Email' };

   function createEmail(input: string): Email {
     if (!isValidEmail(input)) {
       throw new Error('Invalid email');
     }
     return input as Email;
   }

   function sendEmail(email: Email): void { ... }
   ```

2. **外部入力のランタイムバリデーション**:
   ```typescript
   // ❌ 型だけで安全を仮定（ランタイム検証なし）
   type User = { id: string; email: string };
   const user: User = JSON.parse(req.body);  // 型と実際の形が違うかも

   // ✅ ランタイムバリデーション
   function parseUser(data: unknown): User {
     if (!isValidUser(data)) {
       throw new Error('Invalid user data');
     }
     return data;
   }
   ```

**判定**: 検証済み型の欠如は**指摘**（Minor）

### ステップ6: 型の複雑さの管理（低優先度）

**判断基準**:
型が過度に複雑だと、可読性が低下し、エラーメッセージが理解困難になる。

**チェック項目**:

1. **型の分解**:
   ```typescript
   // ❌ 複雑な型定義
   type ComplexType = {
     a: { b: { c: string } } & { d: number };
     e: (x: number) => (y: string) => boolean;
   };

   // ✅ 型を分解して可読性向上
   type NestedB = { b: { c: string } };
   type WithD = NestedB & { d: number };
   type TransformFn = (x: number) => (y: string) => boolean;

   type ComplexType = {
     a: WithD;
     e: TransformFn;
   };
   ```

**判定**: 過度に複雑な型は**指摘**（Nit）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

### 1. 不正な状態の型レベル排除

- [ ] 不正な状態の組み合わせが型レベルで存在できてしまわないか
- [ ] optional フィールドの組み合わせで矛盾する状態が生まれないか
- [ ] 判別共用体（Discriminated Union）で状態ごとに持つべきフィールドを分離できないか
- [ ] ドメインの不変条件が型で表現されているか
- [ ] ドメインの複雑さに対して型が過度に複雑になっていないか（複雑な場合はランタイムバリデーションとの併用を検討）

### 2. プリミティブ型の過剰使用

- [ ] `string` や `number` を意味のある型に置き換えられないか（UserId, Email, Price 等）
- [ ] Branded Type / Opaque Type でプリミティブ型に意味を持たせているか
- [ ] 単位の異なる数値（円 vs ドル、px vs rem）を同じ `number` 型で扱っていないか
- [ ] ドメインレイヤーでプリミティブ型を直接取り回していないか
- [ ] ドメインレイヤー外（プレゼンテーション層、インフラ層等）で導入コストとのバランスを考慮しているか

### 3. 型の表現力

- [ ] Union 型で列挙できるものを `string` で受けていないか
- [ ] 戻り値の型が曖昧でないか（`any`, `unknown` の乱用）
- [ ] 型推論に頼りすぎて公開 API の型が不明確になっていないか
- [ ] `as` による型アサーションを安易に使っていないか
- [ ] 型ガードで安全に型を変換しているか

### 4. ジェネリクスの適切な使用

- [ ] ジェネリクスが必要な場面で具象型をハードコードしていないか
- [ ] 逆に、1箇所でしか使わない型にジェネリクスを導入していないか
- [ ] 型パラメータの制約（extends / bounds）が適切か（広すぎ・狭すぎ）
- [ ] ジェネリクスのネストが深すぎて可読性を損なっていないか
- [ ] 使われない型パラメータ（Phantom Generics）が存在しないか

### 5. アサーションとバリデーションの責務分離

- [ ] ドメインオブジェクトの生成箇所で、アサーション（プログラマのミス検出）とバリデーション（外部入力の検証）が混在していないか
- [ ] バリデーション済みの値を型で区別しているか（未検証の `string` と検証済みの `Email` の区別）
- [ ] 外部入力（API リクエスト、ユーザー入力）には型とは別にランタイムバリデーションがあるか
- [ ] ドメインの文脈で「未検証だが受け入れなければならない値」と「検証済みの値」を型で区別しているか
- [ ] システムによる自動バリデーション（形式・整合性）と、業務フローとしての承認・確認を混同していないか

### 6. 型の複雑さの管理

- [ ] 型定義が過度に複雑で可読性を損なっていないか
- [ ] 複雑な型を適切に分解しているか
- [ ] 型エラーメッセージが理解可能か
- [ ] チームの型システムへの習熟度に見合った型設計か

## よくあるアンチパターン

- **Stringly Typed**: あらゆる値が `string` で表現され、型による保護がない
- **God Interface**: 1つの巨大な型定義に全フィールドが optional で含まれている
- **Type Assertion Driven Development**: `as` で型エラーを握りつぶしている
- **Phantom Generics**: 使われない型パラメータが存在する

## 指摘の出し方

### 指摘の構造

```
【問題点】この型設計は○○の問題があります
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□に変更すると改善します
【トレードオフ】◇◇とのバランスを考慮する必要があります
```

### 指摘の例

#### 不正な状態を許容する型の指摘

```
【問題点】この型定義は optional フィールドの組み合わせで矛盾する状態を許容しています
【理由】`status` が `'draft'` でも `publishedAt` が存在しうる型定義になっており、不正な状態の組み合わせが型で防がれていません
【影響】以下のリスクが発生します:
  - ランタイムで不正な状態の組み合わせをチェックする必要がある
  - チェック漏れがバグになる
  - テストでのすべての組み合わせの検証が困難
【提案】以下のように判別共用体で状態ごとに構造を分離してください
  ```typescript
  // Before: optional フィールドで矛盾する状態が生まれる
  type Article = {
    status: 'draft' | 'published';
    publishedAt?: Date;
    author?: string;
  };

  // After: 判別共用体で状態ごとに構造を分離
  type Article =
    | { status: 'draft'; author: string }
    | { status: 'published'; author: string; publishedAt: Date };
  ```
【トレードオフ】型定義が複雑になりますが、コンパイル時に不正な状態の組み合わせが構造的に排除され、バグが根本的に防がれます
```

#### プリミティブ型の過剰使用の指摘

```
【問題点】この関数はドメイン固有の ID を `string` で受けています
【理由】`UserId` と `ProductId` が同じ `string` 型で表現されており、誤用が型エラーにならない設計になっています
【影響】以下のリスクが発生します:
  - `getUser(productId)` のような誤用がコンパイル時に検出されない
  - IDE の補完でも区別されず、開発効率が低下
  - リファクタリング時に誤用を見落とすリスク
【提案】以下のように Branded Type で ID を区別してください
  ```typescript
  // Before: プリミティブ型で表現
  function getUser(userId: string): User { ... }
  function getProduct(productId: string): Product { ... }

  getUser(productId);  // 型エラーにならない

  // After: Branded Type で区別
  type UserId = string & { readonly _brand: 'UserId' };
  type ProductId = string & { readonly _brand: 'ProductId' };

  function getUser(userId: UserId): User { ... }
  function getProduct(productId: ProductId): Product { ... }

  getUser(productId);  // 型エラー
  ```
【トレードオフ】型定義と変換関数が増えますが、コンパイル時に誤用が検出され、リファクタリングの安全性が大幅に向上します
```

#### 型アサーションの乱用の指摘

```
【問題点】この型変換は `as` による型アサーションで実現されています
【理由】`data as User` により、`data` が実際に `User` の形を持っているかの検証なしに型が強制されています
【影響】以下のリスクが発生します:
  - ランタイムで `data` が `User` でない場合にエラーが発生
  - 型安全性が破壊され、型チェッカーの保護が無効化される
  - リファクタリング時に誤りが検出されない
【提案】以下のように型ガードで安全に型を変換してください
  ```typescript
  // Before: 型アサーションで強制
  const user = data as User;

  // After: 型ガードで安全に変換
  function isUser(data: unknown): data is User {
    return (
      typeof data === 'object' &&
      data !== null &&
      'id' in data &&
      'name' in data
    );
  }

  if (isUser(data)) {
    const user = data;  // 型が保証されている
  } else {
    throw new Error('Invalid user data');
  }
  ```
【トレードオフ】型ガード関数の実装が必要ですが、ランタイムでの型の整合性が保証され、バグが根本的に防がれます
```

#### 検証済み型の欠如の指摘

```
【問題点】この関数は未検証の `string` と検証済みの `Email` が区別されていません
【理由】メール送信関数が `string` を受け取っており、形式チェック済みかどうかが型で保証されていません
【影響】以下のリスクが発生します:
  - メール形式の検証漏れが発生しうる
  - 検証の重複（複数箇所で同じ検証を実行）
  - セキュリティリスク（不正な形式のメールアドレスが渡される）
【提案】以下のように検証済み型を導入してください
  ```typescript
  // Before: 未検証の string
  function sendEmail(email: string): void { ... }

  // After: 検証済み型を導入
  type Email = string & { readonly _brand: 'Email' };

  function createEmail(input: string): Email {
    if (!isValidEmail(input)) {
      throw new Error('Invalid email');
    }
    return input as Email;
  }

  function sendEmail(email: Email): void { ... }

  // 使用側
  const email = createEmail(userInput);  // 検証
  sendEmail(email);  // 検証済みが保証されている
  ```
【トレードオフ】型定義とファクトリ関数が必要ですが、検証漏れが構造的に防がれ、セキュリティが向上します
```

### 指摘の優先度ラベル

- **[Important]**: 不正な状態を許容する型、プリミティブ型の過剰使用、型アサーションの乱用、Union 型の欠如（コンパイル時のバグ検出に直結）
- **[Minor]**: ジェネリクスの不適切な使用、検証済み型の欠如、any/unknown の乱用
- **[Nit]**: 型の複雑さ、型定義の分解不足

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: 不正な状態を許容する型（Important指摘）

**コード**:
```typescript
type Article = {
  status: 'draft' | 'published';
  publishedAt?: Date;  // draft でも publishedAt が存在しうる
  author?: string;     // published でも author が null
};

function publish(article: Article): Article {
  return {
    ...article,
    status: 'published',
    publishedAt: new Date(),
  };
}
```

**期待される指摘**:
- [Important] optional フィールドの組み合わせで矛盾する状態が生まれる
- `status: 'draft'` でも `publishedAt` が存在しうる（不正な状態）
- 判別共用体で状態ごとに構造を分離すべき

### Case 2: プリミティブ型の過剰使用（Important指摘）

**コード**:
```typescript
function getUser(userId: string): User { ... }
function getProduct(productId: string): Product { ... }

// 使用側
const productId: string = '123';
const user = getUser(productId);  // 型エラーにならない（バグ）
```

**期待される指摘**:
- [Important] ドメイン固有の ID を `string` で表現
- `UserId` と `ProductId` の誤用が型エラーにならない
- Branded Type で ID を区別すべき

### Case 3: 型アサーションの乱用（Important指摘）

**コード**:
```typescript
function parseUser(json: string): User {
  const data = JSON.parse(json);
  return data as User;  // 検証なしに型を強制
}
```

**期待される指摘**:
- [Important] `as` による型アサーションで型安全性を破壊
- `data` が実際に `User` の形を持っているか検証していない
- 型ガードで安全に変換すべき

### Case 4: Union 型の欠如（Important指摘）

**コード**:
```typescript
function setStatus(status: string): void {
  // status が 'active', 'inactive', 'pending' のいずれか
}

setStatus('activ');  // タイポが型エラーにならない
```

**期待される指摘**:
- [Important] 列挙できる値を `string` で受けている
- タイポが型エラーにならない
- Union 型で列挙すべき

### Case 5: ジェネリクスの不適切な使用（Minor指摘）

**コード**:
```typescript
// 1箇所でしか使わないのにジェネリクス
function processUser<T extends User>(user: T): T {
  console.log(user.name);
  return user;
}
```

**期待される指摘**:
- [Minor] 1箇所でしか使わないのにジェネリクスを導入
- `T` は常に `User` なので不要
- 具象型で十分

### Case 6: 検証済み型の欠如（Minor指摘）

**コード**:
```typescript
function sendEmail(email: string): void {
  // メール送信処理
}

// 使用側
const userInput = getUserInput();
sendEmail(userInput);  // 形式チェックなし
```

**期待される指摘**:
- [Minor] 未検証の `string` と検証済みの `Email` が区別されていない
- メール形式の検証漏れが発生しうる
- 検証済み型を導入すべき

### Case 7: 許容されるケース（指摘なし）

**コード**:
```typescript
// 判別共用体で不正な状態を排除
type Article =
  | { status: 'draft'; author: string }
  | { status: 'published'; author: string; publishedAt: Date };

// Branded Type で ID を区別
type UserId = string & { readonly _brand: 'UserId' };
type ProductId = string & { readonly _brand: 'ProductId' };

function getUser(userId: UserId): User { ... }
function getProduct(productId: ProductId): Product { ... }

// 型ガードで安全に変換
function isUser(data: unknown): data is User {
  return (
    typeof data === 'object' &&
    data !== null &&
    'id' in data &&
    'name' in data
  );
}

if (isUser(data)) {
  const user = data;  // 型が保証されている
}

// Union 型で列挙
type Status = 'active' | 'inactive' | 'pending';
function setStatus(status: Status): void { ... }

// 検証済み型
type Email = string & { readonly _brand: 'Email' };

function createEmail(input: string): Email {
  if (!isValidEmail(input)) {
    throw new Error('Invalid email');
  }
  return input as Email;
}

function sendEmail(email: Email): void { ... }
```

**期待される判断**:
- 判別共用体で不正な状態が型レベルで排除されている
- Branded Type で ID の誤用が防がれている
- 型ガードで安全に型を変換している
- Union 型で列挙可能な値を型で表現している
- 検証済み型で検証漏れを防いでいる
- 指摘なし
