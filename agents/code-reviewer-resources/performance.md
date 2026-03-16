# パフォーマンスレビュー

コードレビュー時にパフォーマンスの観点で指摘すべきポイントを定義する。

## Why: なぜパフォーマンスレビューが重要か

パフォーマンスの問題は、ユーザー体験とシステムコストに直接的な影響を与える。

**根本的な理由**:
1. **ユーザー体験の保護**: レスポンスが遅いシステムは、ユーザーの離脱率を増加させる。Amazon の調査によれば、100ms の遅延で売上が1%減少する。パフォーマンスはユーザー満足度の基盤である
2. **スケーラビリティの確保**: 非効率なコードは、データ量やユーザー数の増加とともに指数関数的に悪化する。初期は問題なくても、成長とともに致命的なボトルネックとなる
3. **コストの削減**: 非効率なコードは、必要以上のサーバーリソース、データベース負荷、ネットワーク帯域を消費し、インフラコストを増大させる
4. **技術的負債の防止**: パフォーマンスの問題は、後から修正しようとすると、アーキテクチャレベルの大規模な変更が必要になることが多い。早期発見・早期修正が不可欠
5. **競争力の維持**: モバイル環境、グローバル展開、大量データ処理など、現代のアプリケーションはパフォーマンスが競争優位性を左右する

**パフォーマンスレビューの目的**:
- ユーザー体験を保護する
- システムのスケーラビリティを確保する
- インフラコストを最適化する
- 技術的負債の蓄積を防ぐ
- 過剰な最適化（早すぎる最適化）を避ける

## 判断プロセス（決定ツリー）

パフォーマンスレビュー時は、以下の順序で判断する。影響が大きく、データ量増加で悪化する問題から確認し、問題があれば指摘する。

### ステップ1: N+1問題がないか（最優先）

**判断基準**:
N+1問題は、データ量に比例してクエリ数が増加し、システムを破綻させる最も一般的なパフォーマンス問題。

**チェック項目**:

1. **ループ内のDBクエリ**:
   ```typescript
   // ❌ N+1問題: ユーザー数に比例してクエリ数が増加
   const users = await db.getUsers();  // 1クエリ
   for (const user of users) {
     const orders = await db.getOrdersByUserId(user.id);  // N クエリ
     // 100ユーザーなら101クエリ、10000ユーザーなら10001クエリ
   }

   // ✅ 一括取得: 合計2クエリ
   const users = await db.getUsers();
   const userIds = users.map(u => u.id);
   const orders = await db.getOrdersByUserIds(userIds);  // IN句で一括取得
   const ordersByUserId = groupBy(orders, 'userId');
   ```

2. **ORMの遅延読み込み**:
   ```typescript
   // ❌ 遅延読み込みによるN+1
   const posts = await Post.find();  // 1クエリ
   for (const post of posts) {
     console.log(post.author.name);  // 各postでauthorをfetch（Nクエリ）
   }

   // ✅ Eager Loading
   const posts = await Post.find().populate('author');  // JOIN で1クエリ
   ```

3. **ループ内のAPI呼び出し**:
   - 外部APIをループ内で呼んでいないか
   - バッチAPI、GraphQLのDataLoaderパターンで一括取得できないか

**判定フロー**:
```
ループを発見
  ↓
ループ内にDB/API呼び出しがあるか？
  ↓ Yes
  → データ量が増える可能性があるか？
      ↓ Yes → [Critical] N+1問題、一括取得すべき
      ↓ No（固定数）→ 許容
```

**判定**: ループ内でDB/APIを呼び出している場合は**必ず指摘**（Critical）

### ステップ2: アルゴリズムの計算量が適切か（高優先度）

**判断基準**:
O(n²)以上の計算量は、データ量増加で急激にパフォーマンスが悪化する。

**チェック項目**:

1. **ネストループによるO(n²)**:
   ```typescript
   // ❌ O(n²): リスト探索の繰り返し
   for (const user of users) {
     for (const order of orders) {
       if (order.userId === user.id) {
         // マッチング処理
       }
     }
   }

   // ✅ O(n): Mapで O(1) ルックアップ
   const ordersByUserId = new Map();
   for (const order of orders) {
     if (!ordersByUserId.has(order.userId)) {
       ordersByUserId.set(order.userId, []);
     }
     ordersByUserId.get(order.userId).push(order);
   }
   for (const user of users) {
     const userOrders = ordersByUserId.get(user.id) || [];
   }
   ```

2. **配列のfind/filterの繰り返し**:
   ```typescript
   // ❌ O(n²): 配列検索の繰り返し
   for (const id of ids) {
     const item = items.find(i => i.id === id);  // O(n) × n回
   }

   // ✅ O(n): Map化してO(1)ルックアップ
   const itemMap = new Map(items.map(i => [i.id, i]));
   for (const id of ids) {
     const item = itemMap.get(id);  // O(1)
   }
   ```

3. **判定基準**:
   - データ量は10件未満で固定 → O(n²)も許容
   - データ量が100件以上、または今後増える可能性 → O(n²)は**指摘**

**判定**: データ量が増加する可能性があり、O(n²)以上の計算量がある場合は**指摘**（Important）

### ステップ3: 不要な計算・重複処理がないか（中優先度）

**判断基準**:
同じ計算を繰り返すと、CPUとメモリを無駄に消費する。

**チェック項目**:

1. **ループ不変式**:
   ```typescript
   // ❌ ループ内で毎回同じ計算
   for (const item of items) {
     const limit = config.getLimit() * 1.5;  // 毎回同じ計算
     if (item.value > limit) { /* ... */ }
   }

   // ✅ ループ外に移動
   const limit = config.getLimit() * 1.5;
   for (const item of items) {
     if (item.value > limit) { /* ... */ }
   }
   ```

2. **重複データフェッチ**:
   ```typescript
   // ❌ 同じデータを複数回フェッチ
   const user1 = await getUser(userId);
   // 処理
   const user2 = await getUser(userId);  // 同じユーザーを再取得
   ```

3. **メモ化が有効なケース**:
   - 同じ入力で同じ結果を返す純粋関数
   - 計算コストが高い
   - 同じ引数で複数回呼ばれる

**判定**: 明らかに重複している計算がある場合は**指摘**（Minor）

### ステップ4: メモリ効率が適切か（中優先度）

**判断基準**:
大量データを一度にメモリに載せると、メモリ不足やGCの頻発を引き起こす。

**チェック項目**:

1. **大量データの一括読み込み**:
   ```typescript
   // ❌ 全データをメモリに載せる
   const allOrders = await db.query("SELECT * FROM orders");  // 100万件
   for (const order of allOrders) {
     // 処理
   }

   // ✅ ストリーミング処理
   const stream = db.queryStream("SELECT * FROM orders");
   for await (const order of stream) {
     // 処理
   }
   ```

2. **ページネーション・カーソルベース処理**:
   - API応答で全データを返していないか
   - バッチ処理で適切なチャンクサイズを使っているか

3. **文字列の繰り返し結合**:
   ```typescript
   // ❌ 文字列結合で中間オブジェクト大量生成
   let result = "";
   for (const item of items) {
     result += item.toString();  // 毎回新しい文字列オブジェクト
   }

   // ✅ 配列にpushしてjoin
   const parts = [];
   for (const item of items) {
     parts.push(item.toString());
   }
   const result = parts.join("");
   ```

**判定**: 大量データ（10万件以上）を一度にメモリに載せている場合は**指摘**（Important）

### ステップ5: I/O・ネットワークが最適化されているか（低優先度）

**判断基準**:
I/O待機時間を最小化し、必要なデータのみを転送する。

**チェック項目**:

1. **逐次実行の並行化**:
   ```typescript
   // ❌ 逐次実行: 合計3秒
   const user = await fetchUser();  // 1秒
   const orders = await fetchOrders();  // 1秒
   const products = await fetchProducts();  // 1秒

   // ✅ 並行実行: 最大1秒
   const [user, orders, products] = await Promise.all([
     fetchUser(),
     fetchOrders(),
     fetchProducts()
   ]);
   ```

2. **不要なデータのフェッチ**:
   - `SELECT *` を使っていないか（必要なカラムのみ取得）
   - API応答に不要なフィールドが含まれていないか

**判定**: 明らかに並行化できる処理が逐次実行されている場合は**指摘**（Minor）

### ステップ6: 早すぎる最適化を避ける（常に考慮）

**判断基準**:
最適化は、計測に基づき、実際のボトルネックに対してのみ行う。

**チェック項目**:

1. **計測の根拠**:
   - パフォーマンスの問題が実際に発生しているか
   - プロファイリングでボトルネックを特定しているか
   - 最適化による効果を計測しているか

2. **可読性とのトレードオフ**:
   - 最適化により可読性が大きく損なわれていないか
   - ホットパス（頻繁に実行される部分）の最適化か

3. **判定基準**:
   - N+1問題、O(n²)は計測不要で指摘（データ量増加で確実に悪化）
   - 微小な最適化（数ms）で可読性を損なう → 過剰最適化として指摘

**判定**: 計測なしの過剰な最適化は**指摘**（Nit）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

### 1. N+1問題

- [ ] ループ内にDBクエリがないか
- [ ] ループ内に外部API呼び出しがないか
- [ ] ORMの遅延読み込みが意図せずN+1を引き起こしていないか
- [ ] 一括取得（IN句、JOIN、バッチAPI）で解決できないか
- [ ] データ量が増える可能性があるか

### 2. アルゴリズムと計算量

- [ ] ネストループによるO(n²)がないか
- [ ] データ量が100件以上、または今後増える可能性があるか
- [ ] 配列のfind/filterを繰り返していないか（Map/Setで O(1) にできないか）
- [ ] ソートや検索で適切なアルゴリズムを使っているか

### 3. 不要な計算・重複処理

- [ ] ループ内で毎回同じ計算をしていないか
- [ ] 同じデータを複数回フェッチしていないか
- [ ] メモ化が有効な純粋関数を繰り返し呼んでいないか

### 4. メモリ効率

- [ ] 大量データ（10万件以上）を一度にメモリに載せていないか
- [ ] ストリーミング/ページネーションで処理可能か
- [ ] 文字列の繰り返し結合で中間オブジェクトが大量生成されていないか

### 5. I/O・ネットワーク

- [ ] 逐次実行している独立したI/O操作を並行実行できないか
- [ ] SELECT * や不要なフィールドをフェッチしていないか
- [ ] レスポンスサイズが大きすぎないか（ページネーション、フィールド絞り込み）

### 6. 早すぎる最適化

- [ ] 最適化が計測に基づいているか
- [ ] 可読性を大きく損なう最適化をしていないか
- [ ] ホットパス（頻繁に実行される部分）の最適化か

## 指摘の出し方

### 指摘の構造

```
【問題点】このコードは○○のパフォーマンス問題があります
【理由】△△だからです
【影響】データ量が××になると、パフォーマンスが□□になります
【提案】◇◇に変更すると改善します
【トレードオフ】ただし、☆☆の考慮も必要です
```

### 指摘の例

#### N+1問題の指摘

```
【問題点】ループ内でユーザーごとに注文をフェッチしており、N+1問題が発生しています
【理由】ユーザー数に比例してDBクエリ数が増加します
【影響】ユーザーが100人なら101クエリ、1万人なら10001クエリが発行され、DBが過負荷になります
【提案】以下のように一括取得を推奨します
  ```typescript
  // Before: N+1
  for (const user of users) {
    const orders = await db.getOrdersByUserId(user.id);
  }

  // After: 2クエリ
  const userIds = users.map(u => u.id);
  const orders = await db.getOrdersByUserIds(userIds);  // IN句
  const ordersByUserId = groupBy(orders, 'userId');
  ```
【トレードオフ】一括取得の実装コストはありますが、スケーラビリティが大幅に向上します
```

#### アルゴリズム計算量の指摘

```
【問題点】ネストループでユーザーと注文をマッチングしており、O(n²)の計算量です
【理由】ユーザー数×注文数だけループが回ります
【影響】ユーザー1000人、注文10000件なら、1000万回のループになり、レスポンスが数秒かかります
【提案】Map化してO(n)に改善を推奨します
  ```typescript
  // Before: O(n²)
  for (const user of users) {
    for (const order of orders) {
      if (order.userId === user.id) { /* ... */ }
    }
  }

  // After: O(n)
  const ordersByUserId = groupBy(orders, 'userId');
  for (const user of users) {
    const userOrders = ordersByUserId[user.id] || [];
  }
  ```
【トレードオフ】Map作成のメモリコストはありますが、計算時間が劇的に改善します
```

#### 早すぎる最適化の指摘

```
【問題点】可読性を大きく損なう最適化がされていますが、計測の根拠がありません
【理由】このパスは1リクエストあたり1回しか実行されず、最適化の効果は数msです
【影響】保守性が低下し、バグの温床になります
【提案】可読性を優先し、実際にボトルネックになった時点で最適化することを推奨します
【トレードオフ】「早すぎる最適化は諸悪の根源」の原則を尊重します
```

### 指摘の優先度ラベル

- **[Critical]**: N+1問題（データ量増加で確実に悪化）
- **[Important]**: O(n²)問題、大量データのメモリ一括読み込み
- **[Minor]**: 不要な計算、I/O並行化、過剰な最適化
- **[Nit]**: 微小な最適化提案

### トレードオフの明示

- 実際にボトルネックになりうるかを判断する
- データ量の想定を確認する（10件と1万件では判断が異なる）
- 可読性とのバランスを考慮する
- 「早すぎる最適化」を避ける

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: N+1問題（Critical指摘）

**コード**:
```typescript
const users = await db.getUsers();  // 100ユーザー
for (const user of users) {
  const orders = await db.getOrdersByUserId(user.id);  // 100クエリ
  console.log(`${user.name}: ${orders.length} orders`);
}
// 合計101クエリ
```

**期待される指摘**:
- [Critical] N+1問題が発生している
- ユーザー数に比例してクエリ数が増加
- 一括取得で2クエリに削減すべき

### Case 2: O(n²)問題（Important指摘）

**コード**:
```typescript
// users: 1000人、orders: 10000件
for (const user of users) {
  for (const order of orders) {
    if (order.userId === user.id) {
      // マッチング処理
    }
  }
}
// 1000 × 10000 = 1000万回ループ
```

**期待される指摘**:
- [Important] O(n²)の計算量
- データ量増加で急激に悪化
- Map化してO(n)に改善すべき

### Case 3: 大量データの一括読み込み（Important指摘）

**コード**:
```typescript
const allOrders = await db.query("SELECT * FROM orders");  // 100万件
for (const order of allOrders) {
  // 処理
}
```

**期待される指摘**:
- [Important] 100万件を一度にメモリに載せている
- メモリ不足のリスク
- ストリーミング処理またはページネーションを使うべき

### Case 4: 許容されるケース（指摘なし）

**コード**:
```typescript
// 固定5件のカテゴリーに対するループ
const categories = await db.getCategories();  // 常に5件
for (const category of categories) {
  const count = await db.getProductCount(category.id);
  // 合計6クエリだが、固定数なのでN+1問題とは言えない
}
```

**期待される判断**:
- データ量が固定（5件）で増加しない
- N+1問題にはならない
- 指摘なし（ただし、一括取得できるならその方が望ましいとコメント可）
