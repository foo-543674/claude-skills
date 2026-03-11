---
name: review-concurrency
description: コードレビューで並行処理設計を評価する。レースコンディション、デッドロック、非同期処理パターン、トランザクション境界、ロック粒度、リトライ・タイムアウト戦略をチェックするときに使う。
---

# 並行処理設計レビュー

コードレビュー時に並行処理・非同期処理の設計の観点で指摘すべきポイントを定義する。マルチスレッド、async/await、メッセージパッシング等、パラダイムを問わない共通原則を扱う。

このスキルには筆者の設計思想が含まれる。並行処理のバグは再現困難で発見が遅れやすいため、防御的な設計を推奨する。ただし過度なロックや同期は並行性のメリットを殺すため、リスクに見合った対策が必要。

## Why: なぜ並行処理設計レビューが重要か

並行処理設計の品質は、システムの信頼性とスケーラビリティを決定する。不適切な設計は、デバッグ困難なバグと本番障害を引き起こす。

**根本的な理由**:
1. **バグの検出困難性**: 並行処理のバグ（レースコンディション、デッドロック等）はタイミング依存で再現が非常に困難。開発・テスト環境では発生せず、本番環境の高負荷時に初めて顕在化することが多い。発生後の再現も難しく、原因特定に膨大な時間を要する
2. **影響範囲の広さ**: データ競合やデッドロックは、単一機能の障害に留まらず、システム全体の停止やデータ破損を引き起こす。1つの不適切なロック設計が、全ユーザーに影響する障害の原因となる
3. **デバッグコストの膨大さ**: 再現困難なため、ログ分析・タイミング解析・仮説検証を繰り返す必要があり、通常のバグの数倍〜数十倍の調査時間がかかる。本番環境でのみ発生する場合、調査自体が困難になる
4. **パフォーマンスとの両立難度**: 過度なロックや同期は、並行処理のメリット（スループット向上、レイテンシ削減）を完全に殺す。適切なバランス（データ一貫性 vs 並行性）を取る設計判断が極めて難しく、経験と知識が必要
5. **スケーラビリティへの影響**: 並行処理設計の良し悪しが、スケール時のボトルネックを決定する。不適切な設計は、負荷増加時に指数関数的にパフォーマンスが劣化し、スケールアウトしても改善しない

**並行処理設計レビューの目的**:
- タイミング依存のバグを設計段階で防ぐ
- システム全体の停止・データ破損を回避する
- デバッグ困難な本番障害を予防する
- データ一貫性と並行性のバランスを最適化する
- スケーラビリティを確保する

## 判断プロセス（決定ツリー）

並行処理設計のレビュー時は、以下の順序で判断する。データ一貫性とシステム停止リスクに直結する問題から確認し、問題があれば指摘する。

### ステップ1: レースコンディションとデータ競合がないか（最優先）

**判断基準**:
共有データへの同時アクセスが保護されていないと、データ破損や不整合が発生する。

**チェック項目**:

1. **共有データの保護**:
   ```typescript
   // ❌ 共有データが保護されていない
   let counter = 0;
   async function increment() {
     const current = counter;  // Read
     await delay(1);           // 他のスレッドがcounterを変更する可能性
     counter = current + 1;    // Write（上書きで他の変更が失われる）
   }

   // ✅ アトミック操作で保護
   import { Mutex } from 'async-mutex';
   let counter = 0;
   const mutex = new Mutex();
   async function increment() {
     const release = await mutex.acquire();
     try {
       counter++;
     } finally {
       release();
     }
   }
   ```

2. **Read-Modify-Write パターンの TOCTOU 問題**:
   ```typescript
   // ❌ Check と Use の間に競合
   if (stock > 0) {              // Check
     await delay(100);           // 他のリクエストが在庫を減らす可能性
     stock--;                    // Use（在庫がマイナスになる）
   }

   // ✅ アトミックな操作
   const result = await db.execute(
     'UPDATE products SET stock = stock - 1 WHERE id = ? AND stock > 0',
     [productId]
   );
   if (result.affectedRows === 0) {
     throw new Error('Out of stock');
   }
   ```

3. **DB のロック戦略**:
   ```typescript
   // ❌ 楽観的ロックなし（後勝ちで上書き）
   const user = await db.findById(userId);
   user.balance += 100;
   await db.save(user);  // 他のトランザクションの変更が失われる

   // ✅ 楽観的ロック（version カラム）
   const user = await db.findById(userId);
   user.balance += 100;
   user.version++;
   const result = await db.execute(
     'UPDATE users SET balance = ?, version = ? WHERE id = ? AND version = ?',
     [user.balance, user.version, userId, user.version - 1]
   );
   if (result.affectedRows === 0) {
     throw new Error('Conflict: retry');
   }

   // ✅ 悲観的ロック（SELECT FOR UPDATE）
   await db.transaction(async (trx) => {
     const user = await trx.raw('SELECT * FROM users WHERE id = ? FOR UPDATE', [userId]);
     user.balance += 100;
     await trx.save(user);
   });
   ```

**判定フロー**:
```
共有データへのアクセスを発見
  ↓
複数のスレッド/非同期処理から同時アクセスされる可能性があるか？
  ↓ Yes
  ↓
Read-Modify-Write パターンか？
  ↓ Yes → [Important] アトミック操作またはロックで保護すべき
  ↓ No
  ↓
DB の更新操作か？
  ↓ Yes → [Important] 楽観的ロックまたは悲観的ロックを使用すべき
  ↓ No → [Important] mutex/lock で保護すべき
```

**判定**: 共有データが保護されていない場合は**必ず指摘**（Important）

### ステップ2: デッドロックリスクがないか（高優先度）

**判断基準**:
複数のリソースをロックする場合、取得順序が統一されていないとデッドロックが発生する。

**チェック項目**:

1. **ロック取得順序の統一**:
   ```typescript
   // ❌ ロック取得順序が不統一（デッドロック発生）
   // Transaction 1: A → B の順でロック
   await lockA.acquire();
   await lockB.acquire();

   // Transaction 2: B → A の順でロック
   await lockB.acquire();
   await lockA.acquire();
   // → T1 が A を保持して B を待ち、T2 が B を保持して A を待つ

   // ✅ ロック取得順序を統一
   // 常に ID の昇順でロック
   const locks = [lockA, lockB].sort((a, b) => a.id - b.id);
   for (const lock of locks) {
     await lock.acquire();
   }
   ```

2. **ロック保持時間の最小化**:
   ```typescript
   // ❌ ロック内で I/O（保持時間が長い）
   await mutex.acquire();
   try {
     const data = await fetchFromExternalAPI();  // I/O
     await processData(data);                    // 処理
     await saveToDatabase(data);                 // I/O
   } finally {
     mutex.release();
   }

   // ✅ ロック外で I/O
   const data = await fetchFromExternalAPI();  // I/O（ロック外）
   await mutex.acquire();
   try {
     await processData(data);  // 最小限の処理のみロック内
   } finally {
     mutex.release();
   }
   await saveToDatabase(data);  // I/O（ロック外）
   ```

3. **タイムアウト付きロック**:
   ```typescript
   // ❌ 無限待ち（デッドロック時に永遠に待つ）
   await mutex.acquire();

   // ✅ タイムアウト付き
   const release = await mutex.acquire({ timeout: 5000 });
   if (!release) {
     throw new Error('Lock acquisition timeout');
   }
   ```

**判定フロー**:
```
複数のリソースをロックしているか？
  ↓ Yes
  ↓
ロック取得順序が全ての箇所で統一されているか？
  ↓ No → [Important] ロック取得順序を統一すべき（デッドロックリスク）
  ↓ Yes
  ↓
ロック内で I/O や長時間処理をしているか？
  ↓ Yes → [Important] ロック外に移動すべき（競合増大・デッドロックリスク）
  ↓ No
  ↓
タイムアウトが設定されているか？
  ↓ No → [Minor] タイムアウトを設定すべき（無限待ち防止）
```

**判定**: デッドロックリスクがある場合は**必ず指摘**（Important）

### ステップ3: 非同期処理パターンが適切か（高優先度）

**判断基準**:
非同期処理のエラーハンドリング漏れや不適切な並列化は、バグや性能問題を引き起こす。

**チェック項目**:

1. **非同期エラーハンドリング**:
   ```typescript
   // ❌ 未処理の Promise rejection
   async function process() {
     fetchData();  // await を忘れている
     // エラーが発生してもキャッチされない
   }

   // ❌ try-catch 漏れ
   async function process() {
     const data = await fetchData();  // エラーが上位に伝播
     return data;
   }

   // ✅ 適切なエラーハンドリング
   async function process() {
     try {
       const data = await fetchData();
       return data;
     } catch (error) {
       logger.error('Failed to fetch data', error);
       throw new ProcessError('Data fetch failed', { cause: error });
     }
   }
   ```

2. **並列化の適切性**:
   ```typescript
   // ❌ 並列化可能なのに逐次実行（遅い）
   const user = await fetchUser(userId);
   const orders = await fetchOrders(userId);
   const products = await fetchProducts(userId);

   // ✅ 並列化
   const [user, orders, products] = await Promise.all([
     fetchUser(userId),
     fetchOrders(userId),
     fetchProducts(userId),
   ]);

   // ❌ 順序依存なのに並列化（バグ）
   await Promise.all([
     createUser(userData),
     createOrder(userData.id),  // userData.id がまだ存在しない
   ]);

   // ✅ 順序依存を尊重
   const user = await createUser(userData);
   const order = await createOrder(user.id);
   ```

3. **バックプレッシャー対策**:
   ```typescript
   // ❌ 無制限の並列実行（メモリ枯渇・外部サービス過負荷）
   await Promise.all(
     items.map(item => processItem(item))  // 1万件を同時に処理
   );

   // ✅ 並列度を制限
   import pLimit from 'p-limit';
   const limit = pLimit(10);  // 最大10並列
   await Promise.all(
     items.map(item => limit(() => processItem(item)))
   );
   ```

**判定フロー**:
```
非同期処理を発見
  ↓
await が適切に使われているか？
  ↓ No → [Important] await 漏れ、エラーハンドリング漏れ
  ↓ Yes
  ↓
並列化可能な処理を逐次実行していないか？
  ↓ Yes → [Minor] Promise.all で並列化すべき（性能改善）
  ↓ No
  ↓
順序依存の処理を並列化していないか？
  ↓ Yes → [Important] 逐次実行に修正すべき（バグ）
  ↓ No
  ↓
バックプレッシャー対策があるか？
  ↓ No → [Minor] 並列度制限を追加すべき（リソース枯渇防止）
```

**判定**: エラーハンドリング漏れ、順序制御ミスは**必ず指摘**（Important）

### ステップ4: トランザクション境界が適切か（中優先度）

**判断基準**:
トランザクションの範囲が広すぎるとロック競合が増大し、狭すぎるとデータ不整合が発生する。

**チェック項目**:

1. **トランザクション範囲**:
   ```typescript
   // ❌ 範囲が広すぎる（ロック競合増大）
   await db.transaction(async (trx) => {
     await fetchExternalAPI();      // 外部 API 呼び出し
     await trx.insert(data);        // DB 操作
     await sendEmail(user);         // メール送信
   });

   // ✅ 最小限の範囲
   const apiData = await fetchExternalAPI();  // トランザクション外
   await db.transaction(async (trx) => {
     await trx.insert(apiData);  // DB 操作のみ
   });
   await sendEmail(user);  // トランザクション外

   // ❌ 範囲が狭すぎる（データ不整合）
   await db.insert('orders', order);
   await db.insert('order_items', items);  // 失敗したら order だけ残る

   // ✅ 適切な範囲（整合性確保）
   await db.transaction(async (trx) => {
     await trx.insert('orders', order);
     await trx.insert('order_items', items);
   });
   ```

2. **分散トランザクション**:
   ```typescript
   // ❌ 分散トランザクションが必要なのに考慮なし
   await orderDB.insert(order);
   await inventoryDB.decrementStock(productId);  // 失敗したら不整合

   // ✅ Saga パターン（補償トランザクション）
   try {
     const order = await orderDB.insert(order);
     await inventoryDB.decrementStock(productId);
   } catch (error) {
     await orderDB.delete(order.id);  // 補償トランザクション
     throw error;
   }
   ```

**判定**: トランザクション範囲が不適切な場合は**指摘**（Minor）

### ステップ5: リトライ・タイムアウト戦略が適切か（中優先度）

**判断基準**:
リトライは冪等性を前提とし、指数バックオフとタイムアウトが必要。

**チェック項目**:

1. **リトライの冪等性**:
   ```typescript
   // ❌ 非冪等な操作をリトライ（二重実行）
   async function sendEmail(user) {
     await retry(() => emailService.send(user.email));
     // メールが複数回送信される
   }

   // ✅ 冪等性キーで保護
   async function sendEmail(user, idempotencyKey) {
     await retry(() => emailService.send({
       to: user.email,
       idempotencyKey,  // 同じキーなら1回のみ送信
     }));
   }
   ```

2. **指数バックオフとジッター**:
   ```typescript
   // ❌ 固定間隔リトライ（thundering herd）
   await retry(() => operation(), {
     retries: 3,
     delay: 1000,  // 全リクエストが同時にリトライ
   });

   // ✅ 指数バックオフ + ジッター
   await retry(() => operation(), {
     retries: 3,
     delay: (attempt) => Math.min(1000 * 2 ** attempt + Math.random() * 1000, 10000),
   });
   ```

3. **タイムアウト階層**:
   ```typescript
   // ❌ タイムアウトの階層が逆
   // 上流: 5秒、下流: 10秒 → 上流が先にタイムアウトしても下流が動き続ける

   // ✅ 上流 > 下流
   // 上流: 10秒、下流: 5秒 → 下流が先にタイムアウトし、上流が制御可能
   ```

**判定**: リトライ戦略が不適切な場合は**指摘**（Minor）

### ステップ6: 並行性のメリットが最大化されているか（低優先度）

**判断基準**:
過度なロックや同期で並行性のメリットが失われていないか。

**チェック項目**:

1. **ロック粒度**:
   ```typescript
   // ❌ 粒度が粗い（並行性低下）
   const globalMutex = new Mutex();
   async function updateUser(userId, data) {
     await globalMutex.acquire();  // 全ユーザーの更新を直列化
     // ...
   }

   // ✅ 粒度を細かく
   const userMutexes = new Map<string, Mutex>();
   async function updateUser(userId, data) {
     const mutex = userMutexes.get(userId) || new Mutex();
     await mutex.acquire();  // ユーザーごとにロック
     // ...
   }
   ```

**判定**: 並行性が過度に制限されている場合は**指摘**（Nit）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

### 1. レースコンディションとデータ競合

- [ ] 共有データへの同時アクセスが mutex/lock/atomic で保護されているか
- [ ] Read-Modify-Write パターンで TOCTOU 問題がないか
- [ ] DB 更新で楽観的ロック（version カラム）または悲観的ロック（SELECT FOR UPDATE）が使われているか
- [ ] await の前後で共有データの状態が変わる可能性を考慮しているか
- [ ] アトミック操作（DB の UPDATE ... WHERE 条件、Compare-And-Swap 等）が適切に使われているか

### 2. デッドロックと順序制御

- [ ] 複数のリソースをロックする場合、取得順序が全箇所で統一されているか
- [ ] ロック内で I/O（外部 API、DB クエリ、ファイル操作等）を実行していないか
- [ ] ロックの保持時間が最小限に抑えられているか
- [ ] タイムアウト付きロックを使用しているか（無限待ちの防止）
- [ ] ロック取得失敗時の処理が定義されているか

### 3. 非同期処理パターンの適切性

- [ ] 全ての Promise に await が付いているか（Fire and Forget の防止）
- [ ] 非同期処理のエラーハンドリングが漏れていないか
- [ ] 並行実行可能な処理を Promise.all で並列化しているか
- [ ] 順序依存のある処理を不適切に並列化していないか
- [ ] バックプレッシャー対策（並列度制限、キューサイズ上限）があるか
- [ ] 外部サービスのレート制限を考慮しているか

### 4. トランザクション境界設計

- [ ] トランザクションの範囲が適切か（整合性確保とロック競合のバランス）
- [ ] トランザクション内で外部 API 呼び出しをしていないか
- [ ] 分散トランザクションが必要な場面で Saga パターンや補償トランザクションが実装されているか
- [ ] ネストされたトランザクションの振る舞いが意図通りか
- [ ] トランザクション分離レベルが適切に設定されているか

### 5. リトライ・タイムアウト・バックオフ

- [ ] リトライ対象が冪等な操作に限定されているか
- [ ] 指数バックオフとジッターが実装されているか
- [ ] リトライ回数の上限が設定されているか
- [ ] タイムアウトが適切に設定されているか（上流 > 下流）
- [ ] Circuit Breaker が必要な場面で導入されているか

### 6. 並行性のメリット最大化

- [ ] ロック粒度が適切か（過度に粗くないか）
- [ ] Read-Write Lock を使って読み取り並行性を向上できないか
- [ ] 不必要な同期処理がないか

## よくあるアンチパターン

- **Fire and Forget**: 非同期処理の結果もエラーも確認しない
- **Lock Everything**: 過度なロックで並行性のメリットを完全に殺す
- **Async/Sync Mixing**: 同期処理の中で非同期処理を無理やり待機する（ブロッキング）
- **Unbounded Queue**: 上限のないキューがメモリを食い尽くす
- **TOCTOU Vulnerability**: Check と Use の間に状態が変わる
- **Thundering Herd**: 全リクエストが同時にリトライして負荷が集中

## 指摘の出し方

### 指摘の構造

```
【問題点】この並行処理設計は○○の問題があります
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□に変更すると改善します
【トレードオフ】◇◇とのバランスを考慮する必要があります
```

### 指摘の例

#### レースコンディションの指摘

```
【問題点】この在庫チェックと減算処理にレースコンディションがあります
【理由】Check（在庫確認）と Use（在庫減算）の間に await があり、他のリクエストが在庫を変更する可能性があります
【影響】複数リクエストが同時に実行されると、在庫がマイナスになる（過剰販売）リスクがあります
【提案】以下のようにアトミックな DB 操作に変更してください
  ```typescript
  // Before: Check と Use が分離
  const product = await db.findById(productId);
  if (product.stock > 0) {        // Check
    await delay(100);             // 他のリクエストが在庫を減らす
    product.stock--;              // Use（在庫がマイナスになる）
    await db.save(product);
  }

  // After: アトミック操作
  const result = await db.execute(
    'UPDATE products SET stock = stock - 1 WHERE id = ? AND stock > 0',
    [productId]
  );
  if (result.affectedRows === 0) {
    throw new Error('Out of stock');
  }
  ```
【トレードオフ】アトミック操作により安全性は向上しますが、悲観的ロックに比べてリトライが必要になる場合があります
```

#### デッドロックリスクの指摘

```
【問題点】この処理は複数のリソースを異なる順序でロックしており、デッドロックのリスクがあります
【理由】Transaction A は User → Order の順、Transaction B は Order → User の順でロックを取得しています
【影響】負荷が高い状況で、A が User を保持して Order を待ち、B が Order を保持して User を待つデッドロックが発生し、システム全体が停止します
【提案】以下のようにロック取得順序を統一してください
  ```typescript
  // Before: 順序不統一
  // Transaction A
  await userLock.acquire();
  await orderLock.acquire();

  // Transaction B
  await orderLock.acquire();
  await userLock.acquire();

  // After: 順序統一（常に ID 昇順）
  const locks = [userLock, orderLock].sort((a, b) => a.id - b.id);
  for (const lock of locks) {
    await lock.acquire();
  }
  ```
【トレードオフ】ロック順序の統一により安全性は向上しますが、コードの複雑性が若干増加します
```

#### 非同期エラーハンドリング漏れの指摘

```
【問題点】この非同期処理のエラーハンドリングが漏れています
【理由】await なしで Promise を実行しているため、エラーが発生しても呼び出し元でキャッチできません
【影響】エラーが未処理の Promise rejection となり、Node.js では警告、将来的にはプロセス終了の原因となります
【提案】以下のように await を付けてエラーハンドリングを追加してください
  ```typescript
  // Before: await 漏れ
  async function process() {
    fetchData();  // await がない
    // エラーが発生してもキャッチされない
  }

  // After: 適切なエラーハンドリング
  async function process() {
    try {
      const data = await fetchData();
      return data;
    } catch (error) {
      logger.error('Failed to fetch data', error);
      throw new ProcessError('Data fetch failed', { cause: error });
    }
  }
  ```
【トレードオフ】エラーハンドリングの追加によりコード量は増えますが、安全性と保守性が大幅に向上します
```

### 指摘の優先度ラベル

- **[Important]**: レースコンディション、デッドロックリスク、非同期エラーハンドリング漏れ、順序制御ミス（データ破損・システム停止リスク）
- **[Minor]**: トランザクション範囲の不適切さ、リトライ戦略の不備、バックプレッシャー対策不足
- **[Nit]**: ロック粒度の最適化、並行性のメリット最大化

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: レースコンディション（Important指摘）

**コード**:
```typescript
let counter = 0;
async function increment() {
  const current = counter;  // Read
  await delay(1);           // 他のスレッドが counter を変更
  counter = current + 1;    // Write（上書き）
}
```

**期待される指摘**:
- [Important] Read-Modify-Write パターンにレースコンディションあり
- 複数の increment() が同時実行されると、カウントが失われる
- mutex または atomic 操作で保護すべき

### Case 2: デッドロックリスク（Important指摘）

**コード**:
```typescript
// Transaction A
await userLock.acquire();
await orderLock.acquire();

// Transaction B
await orderLock.acquire();
await userLock.acquire();
```

**期待される指摘**:
- [Important] ロック取得順序が不統一でデッドロックリスクあり
- A が User を保持して Order を待ち、B が Order を保持して User を待つ
- ロック取得順序を統一（常に ID 昇順等）すべき

### Case 3: 非同期エラーハンドリング漏れ（Important指摘）

**コード**:
```typescript
async function process() {
  fetchData();  // await を忘れている
  return 'done';
}
```

**期待される指摘**:
- [Important] await 漏れで未処理の Promise rejection が発生
- fetchData() のエラーがキャッチされない
- await を追加し、try-catch でエラーハンドリングすべき

### Case 4: トランザクション範囲（Minor指摘）

**コード**:
```typescript
await db.transaction(async (trx) => {
  await fetchExternalAPI();  // 外部 API 呼び出し
  await trx.insert(data);
  await sendEmail(user);     // メール送信
});
```

**期待される指摘**:
- [Minor] トランザクション範囲が広すぎる
- 外部 API・メール送信がトランザクション内にある（ロック競合増大）
- DB 操作のみトランザクション内に限定すべき

### Case 5: 許容されるケース（指摘なし）

**コード**:
```typescript
// Mutex で保護
const mutex = new Mutex();
async function increment() {
  const release = await mutex.acquire();
  try {
    counter++;
  } finally {
    release();
  }
}

// 並列化
const [user, orders] = await Promise.all([
  fetchUser(userId),
  fetchOrders(userId),
]);

// アトミック DB 操作
const result = await db.execute(
  'UPDATE products SET stock = stock - 1 WHERE id = ? AND stock > 0',
  [productId]
);
```

**期待される判断**:
- 共有データが mutex で適切に保護されている
- 並列化可能な処理を Promise.all で並列化している
- DB 操作がアトミックで TOCTOU 問題がない
- 指摘なし
