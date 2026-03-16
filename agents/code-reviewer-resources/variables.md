# 変数・定数レビュー

コードレビュー時に変数・定数の取り扱いの観点で指摘すべきポイントを定義する。

## Why: なぜ変数・定数レビューが重要か

変数・定数の適切な扱いは、コードの可読性と保守性に直接的な影響を与える。

**根本的な理由**:
1. **意図の明示化**: マジックナンバーや不明瞭な変数名は、コードの意図を隠蔽する。`if (age > 18)` より `if (age > LEGAL_ADULT_AGE)` のほうが、なぜ18なのか、将来変わる可能性があるのかが明確になる
2. **変更の局所化**: 定数化されていない値は、変更時にコード全体を検索して修正する必要があり、修正漏れのリスクが高い。定数化すれば、一箇所の変更で済む
3. **認知負荷の削減**: 不要な変数や広すぎるスコープは、コード読解時に追跡すべき情報を増やし、認知負荷を増大させる。必要最小限の変数で、使用箇所の近くに宣言することが重要
4. **バグの防止**: 変数の再利用や不適切なミュータビリティは、意図しない値の上書きを引き起こし、追跡困難なバグを生む
5. **環境依存性の管理**: ハードコードされた環境依存の値（URL、タイムアウト等）は、環境ごとの変更が困難で、本番デプロイ時のミスの原因となる

**変数・定数レビューの目的**:
- コードの意図を明確にする
- 変更の影響範囲を限定する
- コード読解時の認知負荷を最小化する
- 意図しない変数の上書きを防ぐ
- 環境依存の値を適切に管理する

## 判断プロセス（決定ツリー）

変数・定数のレビュー時は、以下の順序で判断する。影響範囲が大きく、バグや保守性に直結する問題から確認し、問題があれば指摘する。

### ステップ1: マジックナンバー・マジックストリングがないか（最優先）

**判断基準**:
意味のある数値・文字列がリテラルのまま埋め込まれていると、意図が不明瞭で変更時の修正漏れリスクが高い。

**チェック項目**:

1. **定数化すべき値**:
   ```typescript
   // ❌ マジックナンバー
   if (user.age >= 18) {
     // 18は何を意味する？法律で変わる可能性は？
   }
   if (retryCount > 3) {
     // 3はどういう根拠？
   }

   // ✅ 定数化
   const LEGAL_ADULT_AGE = 18;
   const MAX_RETRY_COUNT = 3;

   if (user.age >= LEGAL_ADULT_AGE) {
     // 意図が明確
   }
   if (retryCount > MAX_RETRY_COUNT) {
     // リトライ上限であることが明確
   }
   ```

2. **定数化不要な値**（文脈上自明）:
   - `0`, `1`, `-1`: 配列インデックス、初期値、オフセット等
   - `""`, `null`, `undefined`: 空・無の表現
   - `100`: パーセンテージの文脈で自明
   - 物理定数（`Math.PI`等は言語標準に存在）

3. **複数箇所で使用される値**:
   ```typescript
   // ❌ 同じ値が複数箇所にハードコード
   fetch("https://api.example.com/users");
   fetch("https://api.example.com/orders");
   // URL変更時に複数箇所を修正する必要がある

   // ✅ 定数化
   const API_BASE_URL = "https://api.example.com";
   fetch(`${API_BASE_URL}/users`);
   fetch(`${API_BASE_URL}/orders`);
   ```

**判定フロー**:
```
数値・文字列リテラルを発見
  ↓
文脈上自明か（0, 1, "", 配列インデックス等）？
  ↓ Yes → OK
  ↓ No
  ↓
ビジネス上の意味を持つか？
  ↓ Yes → [Important] 定数化すべき
  ↓ No
  ↓
複数箇所で使用されているか？
  ↓ Yes → [Important] 定数化すべき
  ↓ No → [Minor] 定数化を検討
```

**判定**: ビジネス上の意味を持つ値、複数箇所で使用される値は**必ず指摘**

### ステップ2: 変数のスコープが適切か（高優先度）

**判断基準**:
変数のスコープが必要以上に広いと、意図しない参照や変更のリスクが高まり、認知負荷も増大する。

**チェック項目**:

1. **使用箇所との距離**:
   ```typescript
   // ❌ スコープが広すぎる
   function process() {
     const config = loadConfig();  // ここで宣言
     // 50行の処理
     applyConfig(config);  // ここで初めて使用
   }

   // ✅ 使用箇所の近くで宣言
   function process() {
     // 50行の処理
     const config = loadConfig();
     applyConfig(config);
   }
   ```

2. **ループ変数のスコープ**:
   ```typescript
   // ❌ ループの外で宣言
   let i;
   let item;
   for (i = 0; i < items.length; i++) {
     item = items[i];
     // ...
   }
   // i, item がループ外でも参照可能（意図しない参照のリスク）

   // ✅ ループ内でスコープを限定
   for (let i = 0; i < items.length; i++) {
     const item = items[i];
     // ...
   }
   ```

3. **クラスフィールド vs ローカル変数**:
   ```typescript
   // ❌ メソッド内でしか使わないのにフィールド
   class OrderProcessor {
     private tempResult: any;  // 1つのメソッドでしか使わない

     process() {
       this.tempResult = calculate();
       return this.tempResult;
     }
   }

   // ✅ ローカル変数で十分
   class OrderProcessor {
     process() {
       const result = calculate();
       return result;
     }
   }
   ```

**判定フロー**:
```
変数の宣言位置と使用位置を確認
  ↓
宣言から使用まで20行以上離れている？
  ↓ Yes → [Minor] 使用箇所の近くに移動すべき
  ↓ No
  ↓
ループ変数がループ外で宣言されている？
  ↓ Yes → [Minor] ループ内に移動すべき
  ↓ No
  ↓
クラスフィールドが1つのメソッドでしか使われていない？
  ↓ Yes → [Minor] ローカル変数にすべき
```

**判定**: スコープが不適切な場合は**指摘**

### ステップ3: ミュータビリティが適切か（高優先度）

**判断基準**:
再代入されない変数は `const` / `final` / `val` で宣言すべき。意図しない再代入を防ぐ。

**チェック項目**:

1. **再代入の有無**:
   ```typescript
   // ❌ 再代入されないのに let
   let user = getUser();
   processUser(user);
   // user は再代入されない

   // ✅ const で宣言
   const user = getUser();
   processUser(user);
   ```

2. **ミュータブル vs イミュータブルコレクション**:
   ```typescript
   // ❌ 変更しないのにミュータブル
   const items = [];
   items.push(...getItems());  // 変更している
   return items.map(transform);

   // ✅ イミュータブルで十分
   const items = getItems();
   return items.map(transform);
   ```

**判定フロー**:
```
変数宣言を確認
  ↓
再代入されているか？
  ↓ No
  → const/final/valで宣言されているか？
      ↓ No → [Minor] 不変宣言にすべき
      ↓ Yes → OK
```

**判定**: 再代入されない変数が可変宣言されている場合は**指摘**

### ステップ4: 不要な変数宣言がないか（中優先度）

**判断基準**:
変数名が式に意味的な情報を追加していなければ、冗長な中間変数である。

**チェック項目**:

1. **意味的な情報を追加しない変数**:
   ```typescript
   // ❌ 冗長な中間変数
   const result = user.getName();
   return result;
   // result は何の情報も追加していない

   // ✅ 直接返す
   return user.getName();
   ```

2. **意味的な情報を追加する変数**（残すべき）:
   ```typescript
   // ✅ 複雑な式を分解して意味を明示
   const isEligibleForDiscount =
     user.age >= 18 &&
     user.hasVerifiedEmail &&
     user.accountCreatedDaysAgo > 30;

   if (isEligibleForDiscount) {
     // 意味が明確
   }
   ```

**判定基準**:
- 変数名が式の意味を**明確化**している → 残すべき
- 変数名が単なるエイリアス → 不要

**判定**: 冗長な中間変数は**指摘**

### ステップ5: 変数の再利用・上書きがないか（中優先度）

**判断基準**:
一つの変数を異なる目的で使い回すと、追跡が困難になりバグの原因となる。

**チェック項目**:

1. **変数の意味の変化**:
   ```typescript
   // ❌ 変数の意味が途中で変わる
   let data = fetchUserData();
   // data は UserData 型
   data = transformData(data);
   // data は TransformedData 型に変化
   data = enrichData(data);
   // data は EnrichedData 型に変化

   // ✅ 各段階で別の変数
   const userData = fetchUserData();
   const transformedData = transformData(userData);
   const enrichedData = enrichData(transformedData);
   ```

2. **シャドウイングの混乱**:
   ```typescript
   // ❌ 同じ名前の変数が複数スコープに存在
   const config = globalConfig;
   if (condition) {
     const config = localConfig;  // シャドウイング
     // どのconfigか混乱
   }

   // ✅ 明確な命名
   const globalConfig = getGlobalConfig();
   if (condition) {
     const localConfig = getLocalConfig();
   }
   ```

**判定**: 変数の意味が変化する、シャドウイングで混乱する場合は**指摘**

### ステップ6: 定数の管理が適切か（低優先度）

**判断基準**:
定数の定義場所、環境依存の値の扱いが適切か。

**チェック項目**:

1. **定数の定義場所**:
   - 1つのファイルでのみ使用 → ファイル内で定義
   - 複数ファイルで使用 → 共通定数ファイルで定義

2. **環境依存の値**:
   ```typescript
   // ❌ ハードコード
   const API_URL = "https://api.example.com";
   const TIMEOUT = 30000;

   // ✅ 環境変数
   const API_URL = process.env.API_URL;
   const TIMEOUT = Number(process.env.TIMEOUT) || 30000;
   ```

**判定**: 環境依存の値がハードコードされている場合は**指摘**

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

## レビュー観点（詳細チェックリスト）

### 1. マジックナンバー・マジックストリング

- [ ] 意味のある数値・文字列がリテラルのまま埋め込まれていないか
- [ ] ビジネス上の意味を持つ値が定数化されているか
- [ ] 複数箇所で使用される値が定数として一元管理されているか
- [ ] 文脈上自明な値（0, 1, "", 配列インデックス等）を過剰に定数化していないか

### 2. スコープの適切さ

- [ ] 変数の宣言と使用が20行以上離れていないか
- [ ] ループ変数がループ外で宣言されていないか
- [ ] クラスフィールドが1つのメソッドでしか使われていないか
- [ ] 変数のスコープが必要最小限に限定されているか

### 3. ミュータビリティ

- [ ] 再代入されない変数に const / final / val を使っているか
- [ ] ミュータブルなコレクションが本当に必要か
- [ ] イミュータブルで済む場合にイミュータブルを優先しているか

### 4. 不要な変数宣言

- [ ] 一度しか使われない中間変数が冗長になっていないか
- [ ] 変数名が式に意味的な情報を追加しているか（追加していなければ不要）
- [ ] 複雑な式を分解して可読性を上げる中間変数を見逃していないか

### 5. 変数の再利用・上書き

- [ ] 一つの変数を異なる目的で使い回していないか
- [ ] 変数の意味が途中で変化していないか
- [ ] シャドウイングが読み手を混乱させていないか

### 6. 定数の管理

- [ ] 定数の定義場所は適切か（使用箇所の近く vs 共通定数ファイル）
- [ ] 環境依存の値（URL、タイムアウト値等）がハードコードされていないか
- [ ] 環境変数で設定可能になっているか

## 指摘の出し方

### 指摘の構造

```
【問題点】この変数は○○の問題があります
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□に変更すると改善します
```

### 指摘の例

#### マジックナンバーの指摘

```
【問題点】この `18` は意味が不明瞭です
【理由】ビジネス上の意味を持つ値がリテラルのまま埋め込まれています
【影響】この値が何を意味するか、将来変わる可能性があるかが不明瞭で、変更時の修正漏れリスクがあります
【提案】以下のように定数化してください
  ```typescript
  // Before: マジックナンバー
  if (user.age >= 18) {
    // ...
  }

  // After: 定数化
  const LEGAL_ADULT_AGE = 18;
  if (user.age >= LEGAL_ADULT_AGE) {
    // ...
  }
  ```
```

#### スコープの指摘

```
【問題点】この変数 `config` の宣言が使用箇所から50行離れています
【理由】宣言と使用が離れすぎると、コード読解時に変数の内容を記憶し続ける必要があります
【影響】認知負荷が増大し、意図しない参照のリスクも高まります
【提案】使用箇所の直前に宣言を移動してください
```

#### ミュータビリティの指摘

```
【問題点】この変数 `user` は再代入されていないのに `let` で宣言されています
【理由】再代入されない変数は `const` で宣言すべきです
【影響】意図しない再代入を防げず、バグの原因となります
【提案】以下のように `const` に変更してください
  ```typescript
  // Before: let
  let user = getUser();
  processUser(user);

  // After: const
  const user = getUser();
  processUser(user);
  ```
```

#### 不要な変数の指摘

```
【問題点】この変数 `result` は意味的な情報を追加していません
【理由】変数名が単なるエイリアスで、式の意味を明確化していません
【影響】冗長なコードとなり、可読性が低下します
【提案】中間変数を削除して直接返してください
  ```typescript
  // Before: 冗長な中間変数
  const result = user.getName();
  return result;

  // After: 直接返す
  return user.getName();
  ```
```

#### 変数の再利用の指摘

```
【問題点】この変数 `data` は途中で意味が変化しています
【理由】最初は `UserData` 型、変換後は `TransformedData` 型、最後は `EnrichedData` 型と、同じ変数が異なる意味で使われています
【影響】変数の追跡が困難になり、バグの原因となります
【提案】各段階で別の変数を使用してください
  ```typescript
  // Before: 変数の意味が変化
  let data = fetchUserData();
  data = transformData(data);
  data = enrichData(data);

  // After: 各段階で別の変数
  const userData = fetchUserData();
  const transformedData = transformData(userData);
  const enrichedData = enrichData(transformedData);
  ```
```

### 指摘の優先度ラベル

- **[Important]**: マジックナンバー（ビジネス上の意味を持つ）、環境依存の値のハードコード
- **[Minor]**: スコープの不適切さ、ミュータビリティ、不要な変数、変数の再利用
- **[Nit]**: 軽微な可読性改善

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: マジックナンバー（Important指摘）

**コード**:
```typescript
if (user.age >= 18 && retryCount < 3) {
  // 18と3は何を意味する？
}
```

**期待される指摘**:
- [Important] `18` と `3` がマジックナンバー
- `LEGAL_ADULT_AGE` と `MAX_RETRY_COUNT` のような定数にすべき

### Case 2: スコープが広すぎる（Minor指摘）

**コード**:
```typescript
function process() {
  const config = loadConfig();  // ここで宣言
  // 50行の処理
  applyConfig(config);  // ここで初めて使用
}
```

**期待される指摘**:
- [Minor] 宣言と使用が50行離れている
- 使用箇所の直前に移動すべき

### Case 3: 再代入されないのに let（Minor指摘）

**コード**:
```typescript
let user = getUser();
processUser(user);
// user は再代入されない
```

**期待される指摘**:
- [Minor] 再代入されないのに `let` を使用
- `const` に変更すべき

### Case 4: 不要な中間変数（Minor指摘）

**コード**:
```typescript
const result = user.getName();
return result;
```

**期待される指摘**:
- [Minor] 冗長な中間変数
- `return user.getName()` と直接返すべき

### Case 5: 変数の意味が変化（Minor指摘）

**コード**:
```typescript
let data = fetchUserData();
data = transformData(data);
data = enrichData(data);
```

**期待される指摘**:
- [Minor] 変数の意味が途中で変化
- 各段階で別の変数を使用すべき

### Case 6: 許容されるケース（指摘なし）

**コード**:
```typescript
// 配列インデックス、初期値等は定数化不要
for (let i = 0; i < items.length; i++) {
  if (items[i] !== null) {
    // 0, null は文脈上自明
  }
}

// 意味的な情報を追加する中間変数（残すべき）
const isEligibleForDiscount =
  user.age >= LEGAL_ADULT_AGE &&
  user.hasVerifiedEmail &&
  user.accountCreatedDaysAgo > 30;

if (isEligibleForDiscount) {
  // 複雑な条件式を分解して意味を明示
}
```

**期待される判断**:
- 文脈上自明な値は定数化不要
- 意味的な情報を追加する変数は適切
- 指摘なし
