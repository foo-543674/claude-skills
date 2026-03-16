# 状態設計レビュー

コードレビュー時に状態管理と状態遷移設計の観点で指摘すべきポイントを定義する。フロントエンドの UI 状態、バックエンドのドメイン状態の両方を対象とする。

このスキルには筆者の設計思想が含まれる。状態設計はアプリケーションの複雑さの主要因であり、明示的な設計を推奨する。ただし状態の数と遷移パターンが少ない場面では、過度な形式化はかえって複雑さを増す。

## Why: なぜ状態設計レビューが重要か

状態設計の品質は、バグの発生頻度とデバッグの困難さを決定する。不適切な状態設計は、再現困難なバグと保守困難なコードを生む。

**根本的な理由**:
1. **バグの温床**: 不正な状態の組み合わせ（`isLoading && isError`、`draft && published` 等）が型で防がれていないと、ロジックのあらゆる箇所で不正状態のチェックが必要になり、チェック漏れがバグになる。型レベルで不正状態を排除すれば、バグは構造的に発生しない
2. **デバッグの困難さ**: 暗黙的な状態遷移（フラグの直接代入、条件なしの状態変更）は、「どこで、なぜ状態が変わったか」の追跡を困難にする。明示的な状態遷移（State Machine、イベント駆動）なら、ログを見るだけで状態変更の因果関係が分かる
3. **派生状態の同期問題**: 派生状態（計算可能な値）を独立した状態として保持すると、同期が壊れてデータ不整合が発生する。Single Source of Truth を守れば、同期問題は構造的に発生しない
4. **競合と整合性**: 楽観的更新の失敗時ロールバック、悲観的ロックの選択、競合解決戦略が不明確だと、複数ユーザーの同時操作でデータ不整合・ロストアップデートが発生する。適切な戦略を設計段階で決めなければ、後から修正が極めて困難
5. **状態爆発**: 状態数と遷移パターンが増加すると、すべての組み合わせのテストが不可能になり、エッジケースでのバグが多発する。状態の正規化と明示的な遷移で、管理可能な複雑さに抑える必要がある

**状態設計レビューの目的**:
- 不正な状態を型レベルで排除し、バグを構造的に防ぐ
- 明示的な状態遷移でデバッグを容易にする
- 派生状態を排除し、データ不整合を防ぐ
- 競合・整合性戦略を設計段階で決定する
- 状態爆発を防ぎ、管理可能な複雑さに保つ

## 判断プロセス（決定ツリー）

状態設計のレビュー時は、以下の順序で判断する。バグと整合性に直結する問題から確認し、問題があれば指摘する。

### ステップ1: 不可能な状態の型レベル排除（最優先）

**判断基準**:
不正な状態の組み合わせが型で防がれていないと、ロジック全体でチェックが必要になりバグの温床となる。

**チェック項目**:

1. **Boolean Explosion の回避**:
   ```typescript
   // ❌ フラグの組み合わせで状態を管理（不正な組み合わせを許容）
   type State = {
     isLoading: boolean;
     isError: boolean;
     isSuccess: boolean;
     data: User | null;
     error: Error | null;
   };
   // 不正な組み合わせ: isLoading && isError、isSuccess && isError 等

   // ✅ 判別共用体で不正な状態を排除
   type State =
     | { status: 'loading' }
     | { status: 'error'; error: Error }
     | { status: 'success'; data: User };
   // 型で不正な組み合わせが不可能
   ```

2. **状態ごとの異なるデータ構造**:
   ```typescript
   // ❌ 状態に関係なく同じ構造（null チェックが必要）
   type Order = {
     status: 'draft' | 'submitted' | 'approved';
     submittedAt: Date | null;  // submitted 以降で必須
     approvedBy: string | null;  // approved で必須
   };

   // ✅ 判別共用体で状態ごとに構造を分離
   type Order =
     | { status: 'draft' }
     | { status: 'submitted'; submittedAt: Date }
     | { status: 'approved'; submittedAt: Date; approvedBy: string };
   // 型で必須フィールドを保証
   ```

3. **遷移条件の型レベル表現**:
   ```typescript
   // ❌ 遷移条件が型で表現されていない
   function approve(order: Order): Order {
     order.status = 'approved';  // draft からも遷移可能（不正）
   }

   // ✅ 遷移可能な状態を型で限定
   function approve(order: Extract<Order, { status: 'submitted' }>): Order {
     return { status: 'approved', submittedAt: order.submittedAt, approvedBy: 'admin' };
   }
   // submitted 以外からは呼び出せない
   ```

**判定フロー**:
```
状態の型定義を確認
  ↓
複数のブールフラグで状態を管理しているか？
  ↓ Yes → [Important] 判別共用体に変更すべき
  ↓ No
  ↓
状態ごとに異なるデータを持つのに同じ構造か？
  ↓ Yes → [Important] 判別共用体で分離すべき
```

**判定**: Boolean Explosion、状態ごとの構造不一致は**必ず指摘**（Important）

### ステップ2: 状態遷移の明示性（高優先度）

**判断基準**:
暗黙的な状態遷移は、バリデーション漏れとデバッグ困難を招く。

**チェック項目**:

1. **直接代入の禁止**:
   ```typescript
   // ❌ 状態の直接代入（遷移条件チェックなし）
   order.status = 'approved';  // 遷移条件が不明

   // ✅ 明示的な遷移関数
   function approve(order: Order): Order {
     if (order.status !== 'submitted') {
       throw new Error('Cannot approve non-submitted order');
     }
     return { ...order, status: 'approved', approvedBy: 'admin' };
   }
   ```

2. **State Machine パターン**（複雑な遷移の場合）:
   ```typescript
   // ✅ 遷移表で許可された遷移を定義
   const transitions = {
     draft: ['submitted'],
     submitted: ['approved', 'rejected'],
     approved: [],
     rejected: ['draft'],
   };

   function transition(order: Order, to: OrderStatus): Order {
     if (!transitions[order.status].includes(to)) {
       throw new Error(`Cannot transition from ${order.status} to ${to}`);
     }
     return { ...order, status: to };
   }
   ```

**判定フロー**:
```
状態変更を確認
  ↓
状態を直接代入しているか？
  ↓ Yes → [Important] 明示的な遷移関数に変更すべき
  ↓ No
  ↓
遷移パターンが複雑（4状態以上、条件付き遷移）か？
  ↓ Yes → [Minor] State Machine パターンを検討すべき
```

**判定**: 状態の直接代入は**必ず指摘**（Important）

### ステップ3: 状態の正規化（高優先度）

**判断基準**:
派生状態を独立した状態として保持すると、同期が壊れてデータ不整合が発生する。

**チェック項目**:

1. **派生状態の排除**:
   ```typescript
   // ❌ 派生状態を保持（同期が壊れる）
   type State = {
     items: Item[];
     totalCount: number;  // items.length で計算可能
     isEmpty: boolean;    // items.length === 0 で計算可能
   };

   // ✅ 派生状態を計算
   type State = {
     items: Item[];
   };

   const totalCount = state.items.length;
   const isEmpty = state.items.length === 0;
   ```

2. **Single Source of Truth**:
   ```typescript
   // ❌ 同じデータが複数箇所に重複
   type State = {
     users: User[];
     userMap: Map<string, User>;  // users と重複
   };

   // ✅ 正規化（ID で管理）
   type State = {
     users: Map<string, User>;  // ID → User
   };

   const userList = Array.from(state.users.values());
   ```

**判定フロー**:
```
状態を確認
  ↓
他の状態から計算可能な値を保持しているか？
  ↓ Yes → [Important] 派生状態を削除し計算すべき
  ↓ No
  ↓
同じデータが複数箇所に重複しているか？
  ↓ Yes → [Important] 正規化すべき
```

**判定**: 派生状態の保持、重複は**必ず指摘**（Important）

### ステップ4: 楽観的更新と悲観的更新の選択（中優先度）

**判断基準**:
ユーザー体験と整合性のトレードオフを適切に判断する。

**チェック項目**:

1. **楽観的更新の適用**:
   ```typescript
   // ❌ すべての操作で悲観的更新（UX 悪い）
   async function like(postId: string) {
     await api.likePost(postId);  // 完了まで待つ
     refetch();  // データ再取得
   }

   // ✅ 楽観的更新（即座にUI更新）
   async function like(postId: string) {
     setState(prev => ({ ...prev, liked: true, likes: prev.likes + 1 }));

     try {
       await api.likePost(postId);
     } catch (error) {
       // ロールバック
       setState(prev => ({ ...prev, liked: false, likes: prev.likes - 1 }));
       showError('Failed to like');
     }
   }
   ```

2. **悲観的更新の適用**（整合性重視）:
   ```typescript
   // ✅ 決済は悲観的更新（整合性最重要）
   async function processPayment(orderId: string) {
     setLoading(true);
     try {
       const result = await api.processPayment(orderId);
       setState({ status: 'paid', ...result });
     } catch (error) {
       showError('Payment failed');
     } finally {
       setLoading(false);
     }
   }
   ```

**判定**: 不適切な選択は**指摘**（Minor）

### ステップ5: イベント駆動 vs 状態駆動の選択（低優先度）

**判断基準**:
リアルタイム性と複雑さのトレードオフを適切に判断する。

**チェック項目**:

1. **イベント駆動の適用**（リアルタイム性重要）:
   ```typescript
   // ✅ WebSocket でリアルタイム通知
   socket.on('order:updated', (order) => {
     updateOrder(order);
   });
   ```

2. **状態駆動の適用**（シンプル）:
   ```typescript
   // ✅ ポーリングで定期更新（シンプル）
   setInterval(() => {
     fetchOrders();
   }, 5000);
   ```

**判定**: 過度なイベント駆動は**指摘**（Nit）

### ステップ6: 状態遷移のテスタビリティ（低優先度）

**判断基準**:
状態遷移のテストが容易で、すべての遷移パターンを検証できる設計になっているか。

**チェック項目**:

1. **遷移関数の純粋性**:
   ```typescript
   // ❌ グローバル状態に依存（テストが困難）
   let currentOrder: Order = { status: 'draft' };
   function submit() {
     currentOrder.status = 'submitted';
   }

   // ✅ 純粋関数で遷移（テストが容易）
   function submit(order: Order): Order {
     if (order.status !== 'draft') {
       throw new Error('Cannot submit non-draft order');
     }
     return { ...order, status: 'submitted', submittedAt: new Date() };
   }
   ```

2. **遷移パターンの網羅的テスト**:
   ```typescript
   // ✅ すべての遷移パターンをテスト可能
   describe('Order state transitions', () => {
     test('draft -> submitted', () => {
       const draft: Order = { status: 'draft' };
       const submitted = submit(draft);
       expect(submitted.status).toBe('submitted');
     });

     test('submitted -> approved', () => {
       const submitted: Order = { status: 'submitted', submittedAt: new Date() };
       const approved = approve(submitted);
       expect(approved.status).toBe('approved');
     });

     test('invalid transition throws error', () => {
       const draft: Order = { status: 'draft' };
       expect(() => approve(draft)).toThrow();
     });
   });
   ```

**判定フロー**:
```
状態遷移のテスト容易性を確認
  ↓
遷移関数が純粋関数として実装されているか？
  ↓ No → [Minor] 副作用を分離すべき
  ↓ Yes
  ↓
すべての遷移パターンをテスト可能か？
  ↓ No → [Minor] テスタブルな設計に変更すべき
  ↓ Yes → OK
```

**判定**: テスト困難な設計は**指摘**（Minor）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

### 1. 不可能な状態の型レベル排除

- [ ] 不正な状態の組み合わせが型で防がれているか
- [ ] 複数のブールフラグの組み合わせで状態を表現していないか（Boolean Explosion の回避）
- [ ] 状態ごとに異なるデータ構造を持つ場合、判別共用体で表現されているか
- [ ] 遷移可能な状態が型で限定されているか（Extract 等を使用）
- [ ] 動的な状態遷移（ワークフローエンジン等）の場合、ランタイムの遷移表で管理されているか

### 2. 状態遷移の明示性

- [ ] 状態遷移が暗黙的（フラグの組み合わせ）ではなく、明示的に定義されているか
- [ ] 状態を直接代入せず、明示的な遷移関数を使用しているか
- [ ] 遷移時のバリデーション（遷移条件）がどこに実装されているか明確か
- [ ] 許可された遷移と禁止された遷移が明確か（`draft → published` は可、`published → draft` は不可、等）
- [ ] 複雑な遷移（4状態以上、条件付き遷移）の場合、State Machine パターンを検討しているか
- [ ] 状態が2〜3種類で遷移パターンが単純な場合、過度な形式化を避けているか

### 3. 状態の正規化

- [ ] 派生状態（他の状態から計算可能な状態）を独立した状態として保持していないか
- [ ] 同じデータが複数箇所に重複して保持されていないか（Single Source of Truth）
- [ ] キャッシュとしての重複保持の場合、同期戦略が明確か
- [ ] 計算コストが高い派生状態の場合、メモ化等の最適化を検討しているか

### 4. 楽観的更新と悲観的更新

- [ ] ユーザー体験のために楽観的更新が有効な場面で採用されているか
- [ ] 楽観的更新の失敗時のロールバック戦略があるか
- [ ] 競合が発生しうる操作で適切な競合解決戦略があるか（Last Write Wins, Merge, User Resolution）
- [ ] 決済や在庫管理など整合性が最重要の場面では悲観的ロック / 更新を採用しているか
- [ ] 楽観的更新による複雑さの増加を適切に評価しているか

### 5. イベント駆動 vs 状態駆動

- [ ] 状態変更の通知方法が設計されているか（Observer, Pub/Sub, Event Bus）
- [ ] イベントによる副作用の連鎖が追跡可能か
- [ ] 状態駆動（ポーリング）とイベント駆動（プッシュ）の選択が適切か
- [ ] イベント駆動の採用によるデバッグの困難さを評価しているか
- [ ] 状態遷移の因果関係が追跡できない場合、状態駆動を検討しているか

### 6. 状態遷移のテスタビリティ

- [ ] 遷移関数が純粋関数として実装されているか
- [ ] すべての遷移パターンをテスト可能な設計になっているか
- [ ] 不正な遷移のテストが実装されているか
- [ ] モックやスタブが不要な設計になっているか

## よくあるアンチパターン

- **Boolean Explosion**: `isLoading`, `isError`, `isSuccess`, `isRetrying` のフラグ組み合わせで状態を管理
- **Derived State as Source**: 計算可能な値を独立した状態として保持し、同期が壊れる
- **Implicit Transition**: `status = "approved"` の直接代入で遷移条件のチェックが行われない
- **Event Storm**: イベントの連鎖が制御不能になり、状態変更の因果関係が追えない

## 指摘の出し方

### 指摘の構造

```
【問題点】この状態設計は○○の問題があります
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□に変更すると改善します
【メリット】◇◇が実現できます
```

### 指摘の例

#### Boolean Explosion の指摘

```
【問題点】この状態管理は複数のブールフラグの組み合わせで状態を表現しています
【理由】`isLoading`, `isError`, `isSuccess` の組み合わせで状態を管理しており、不正な組み合わせ（`isLoading && isError`、`isSuccess && isError` 等）が型で防がれていません
【影響】以下のリスクが発生します:
  - ロジックのあらゆる箇所で不正状態のチェックが必要
  - チェック漏れがバグの温床となる
  - すべての組み合わせのテストが困難
【提案】以下のように判別共用体に変更してください
  ```typescript
  // Before: Boolean Explosion
  type State = {
    isLoading: boolean;
    isError: boolean;
    isSuccess: boolean;
    data: User | null;
    error: Error | null;
  };

  // After: 判別共用体で不正な状態を排除
  type State =
    | { status: 'loading' }
    | { status: 'error'; error: Error }
    | { status: 'success'; data: User };
  ```
【メリット】型レベルで不正な状態の組み合わせが構造的に不可能になり、バグが根本的に防がれます
```

#### 暗黙的な状態遷移の指摘

```
【問題点】この状態遷移は直接代入で実現されており、遷移条件のチェックがありません
【理由】`order.status = 'approved'` の直接代入により、どの状態からでも `approved` に遷移可能となっています
【影響】以下のリスクが発生します:
  - 不正な遷移（`draft` から直接 `approved` へ等）が発生しうる
  - 遷移時のバリデーションが実行されない
  - 状態変更の追跡が困難（ログを見ても因果関係が不明）
【提案】以下のように明示的な遷移関数に変更してください
  ```typescript
  // Before: 暗黙的な遷移
  order.status = 'approved';

  // After: 明示的な遷移関数
  function approve(order: Order): Order {
    if (order.status !== 'submitted') {
      throw new Error('Cannot approve non-submitted order');
    }
    return { ...order, status: 'approved', approvedBy: 'admin' };
  }
  ```
【メリット】遷移条件が明確になり、不正な遷移が型レベル・ランタイム双方で防がれます
```

#### 派生状態の保持の指摘

```
【問題点】この状態には派生状態（他の状態から計算可能な値）が含まれています
【理由】`totalCount` と `isEmpty` は `items.length` から計算可能ですが、独立した状態として保持されています
【影響】以下のリスクが発生します:
  - 同期が壊れてデータ不整合が発生（`items` を更新したが `totalCount` を更新し忘れる等）
  - 状態の更新箇所が増え、保守性が低下
  - Single Source of Truth が守られていない
【提案】以下のように派生状態を削除し、必要時に計算してください
  ```typescript
  // Before: 派生状態を保持
  type State = {
    items: Item[];
    totalCount: number;
    isEmpty: boolean;
  };

  // After: 派生状態を計算
  type State = {
    items: Item[];
  };

  const totalCount = state.items.length;
  const isEmpty = state.items.length === 0;
  ```
【メリット】同期問題が構造的に発生しなくなり、データ整合性が保証されます
```

#### 楽観的更新のロールバック戦略欠如の指摘

```
【問題点】この楽観的更新には失敗時のロールバック戦略がありません
【理由】UI を即座に更新していますが、API 呼び出しが失敗した場合の状態復旧処理が実装されていません
【影響】以下のリスクが発生します:
  - API 失敗時に UI 表示とサーバー状態が不整合になる
  - ユーザーが不正な状態を見続ける
  - データの信頼性が損なわれる
【提案】以下のようにロールバック戦略を実装してください
  ```typescript
  // Before: ロールバックなし
  async function like(postId: string) {
    setState(prev => ({ ...prev, liked: true, likes: prev.likes + 1 }));
    await api.likePost(postId);
  }

  // After: ロールバック実装
  async function like(postId: string) {
    // 楽観的更新
    setState(prev => ({ ...prev, liked: true, likes: prev.likes + 1 }));

    try {
      await api.likePost(postId);
    } catch (error) {
      // ロールバック
      setState(prev => ({ ...prev, liked: false, likes: prev.likes - 1 }));
      showError('Failed to like');
    }
  }
  ```
【メリット】API 失敗時も UI とサーバー状態の整合性が保たれ、ユーザー体験が向上します
```

### 指摘の優先度ラベル

- **[Important]**: Boolean Explosion、暗黙的な状態遷移、派生状態の保持、状態構造の不一致（バグと整合性に直結）
- **[Minor]**: State Machine パターンの欠如（複雑な遷移の場合）、楽観的更新のロールバック戦略欠如、テスト困難な設計
- **[Nit]**: 過度なイベント駆動、状態管理の粒度の不統一

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: Boolean Explosion（Important指摘）

**コード**:
```typescript
type State = {
  isLoading: boolean;
  isError: boolean;
  isSuccess: boolean;
  data: User | null;
  error: Error | null;
};

function loadUser(userId: string): void {
  state.isLoading = true;

  api.getUser(userId)
    .then(user => {
      state.isLoading = false;
      state.isSuccess = true;
      state.data = user;
    })
    .catch(error => {
      state.isLoading = false;
      state.isError = true;
      state.error = error;
    });
}
```

**期待される指摘**:
- [Important] 複数のブールフラグで状態を管理
- 不正な組み合わせ（`isLoading && isError` 等）が型で防がれていない
- 判別共用体に変更すべき

### Case 2: 暗黙的な状態遷移（Important指摘）

**コード**:
```typescript
type Order = {
  status: 'draft' | 'submitted' | 'approved';
  submittedAt?: Date;
  approvedBy?: string;
};

function processOrder(order: Order): void {
  // 遷移条件チェックなし
  order.status = 'approved';
  order.approvedBy = 'admin';
}
```

**期待される指摘**:
- [Important] 状態を直接代入している
- 遷移条件のチェックがなく、不正な遷移が発生しうる
- 明示的な遷移関数に変更すべき

### Case 3: 派生状態の保持（Important指摘）

**コード**:
```typescript
type State = {
  items: Item[];
  totalCount: number;  // items.length で計算可能
  isEmpty: boolean;    // items.length === 0 で計算可能
};

function addItem(state: State, item: Item): State {
  return {
    ...state,
    items: [...state.items, item],
    totalCount: state.items.length + 1,
    isEmpty: false,
  };
}
```

**期待される指摘**:
- [Important] 派生状態を独立した状態として保持
- 同期が壊れてデータ不整合が発生するリスク
- 派生状態を削除し、必要時に計算すべき

### Case 4: 楽観的更新のロールバック戦略欠如（Minor指摘）

**コード**:
```typescript
async function like(postId: string) {
  // 楽観的更新
  setState(prev => ({ ...prev, liked: true, likes: prev.likes + 1 }));

  // ロールバック処理なし
  await api.likePost(postId);
}
```

**期待される指摘**:
- [Minor] 楽観的更新の失敗時ロールバック戦略がない
- API 失敗時に UI とサーバー状態が不整合になる
- try-catch でロールバック処理を実装すべき

### Case 5: State Machine の不足（Minor指摘）

**コード**:
```typescript
type Order = {
  status: 'draft' | 'submitted' | 'approved' | 'rejected' | 'cancelled';
};

// 5状態あるが遷移ルールが不明確
function changeStatus(order: Order, to: OrderStatus): Order {
  if (to === 'approved' && order.status !== 'submitted') {
    throw new Error('Invalid transition');
  }
  return { ...order, status: to };
}
```

**期待される指摘**:
- [Minor] 5状態の複雑な遷移だが State Machine パターンが未使用
- 許可された遷移が明確でない
- 遷移表を導入して遷移ルールを明示化すべき

### Case 6: 許容されるケース（指摘なし）

**コード**:
```typescript
// 判別共用体で不正な状態を排除
type State =
  | { status: 'loading' }
  | { status: 'error'; error: Error }
  | { status: 'success'; data: User };

// 明示的な遷移関数
function approve(order: Extract<Order, { status: 'submitted' }>): Order {
  return {
    status: 'approved',
    submittedAt: order.submittedAt,
    approvedBy: 'admin'
  };
}

// 派生状態を計算
const totalCount = state.items.length;
const isEmpty = state.items.length === 0;

// 楽観的更新のロールバック実装
async function like(postId: string) {
  setState(prev => ({ ...prev, liked: true, likes: prev.likes + 1 }));

  try {
    await api.likePost(postId);
  } catch (error) {
    setState(prev => ({ ...prev, liked: false, likes: prev.likes - 1 }));
    showError('Failed to like');
  }
}
```

**期待される判断**:
- 判別共用体で不正な状態が型レベルで排除されている
- 明示的な遷移関数で遷移条件が保証されている
- 派生状態を計算で取得している
- 楽観的更新のロールバック戦略が実装されている
- 指摘なし
