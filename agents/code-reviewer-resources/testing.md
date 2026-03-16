# テストレビュー

コードレビュー時にテスト設計・テストの質の観点で指摘すべきポイントを定義する。

## Why: なぜテストレビューが重要か

テストはソフトウェア品質の最後の砦であり、コードの信頼性と長期的な保守性を決定する。

**根本的な理由**:
1. **品質保証の最後の砦**: テストが不十分だと、バグが本番環境で発見され、ユーザーに直接被害を与える。開発時にバグを発見できれば、修正コストは数分〜数時間。本番で発見されれば、数日〜数週間の調査・修正・影響確認が必要になる
2. **リファクタリングの安全網**: テストがなければ、コード変更時に既存機能を壊していないか確認できず、変更が怖くなる。テストがあれば、自信を持ってリファクタリングでき、技術的負債の返済が可能になる
3. **仕様のドキュメント化**: コードは「何ができるか」を示すが、「どう振る舞うべきか」は示さない。テスト名と構造が実行可能な仕様ドキュメントとなり、新メンバーの理解を助ける
4. **デバッグ時間の削減**: バグ発生時、テストがあればどの部分が壊れたか即座に特定できる。テストがなければ、手動デバッグに膨大な時間を費やす
5. **回帰バグの防止**: 過去に修正したバグが再発することを防ぐ。テストがなければ、同じバグを何度も修正する無駄が発生する

**テストレビューの目的**:
- 本番環境へのバグ流出を防ぐ
- リファクタリング・変更を安全に行えるようにする
- テストを実行可能な仕様ドキュメントとして機能させる
- デバッグ・障害対応時間を最小化する
- 長期的なソフトウェアの信頼性を担保する

## 判断プロセス（決定ツリー）

テストレビュー時は、以下の順序で判断する。影響範囲が大きく、品質に直結する問題から確認し、問題があれば指摘する。

### ステップ1: テスト名が仕様を表現しているか（最優先）

**判断基準**:
テスト名は実行可能な仕様ドキュメント。「何をテストするか」ではなく「どう振る舞うべきか」を表現すべき。

**チェック項目**:

1. **具体的なユースケースが読み取れるか**:
   ```typescript
   // ❌ 何をテストするか不明
   test('should return error when email format is invalid')
   // どういう format が invalid なのかわからない

   // ✅ 具体的な仕様が明確
   test('should reject registration when email has no at sign')
   test('should reject registration when email has no domain part')
   ```

2. **実装の詳細ではなく振る舞いを表現しているか**:
   ```typescript
   // ❌ 戻り値の型の説明でしかない
   test('should return true')
   test('should return error object')

   // ✅ ビジネス上の振る舞いを表現
   test('should allow user to login with valid credentials')
   test('should prevent login after 3 failed attempts')
   ```

3. **`should` / `must` prefix の適切性**:
   - フレームワークが自動付与する場合（ScalaTest の `should` メソッド等）は不要
   - 手動でテスト名を書く場合は、仕様文として読めるように `should` を使う

**判定フロー**:
```
テスト名を確認
  ↓
具体的な入力・条件・期待結果が読み取れるか？
  ↓ No → [Important] テスト名が曖昧、具体的な仕様を表現すべき
  ↓ Yes
  ↓
実装詳細（戻り値の型等）ではなく振る舞いを表現しているか？
  ↓ No → [Important] 振る舞いベースの命名に変更すべき
  ↓ Yes → OK
```

**判定**: テスト名から仕様が読み取れない場合は**必ず指摘**（Important）

### ステップ2: テストケースの網羅性が十分か（高優先度）

**判断基準**:
正常系だけでなく、異常系・境界値・エラーケースを網羅しているか。

**チェック項目**:

1. **境界値テスト**:
   - 0、1、空文字列、null、最大値、最小値
   - 境界の前後（N-1, N, N+1）
   ```typescript
   // ❌ 正常系のみ
   test('should calculate discount for 10 items')

   // ✅ 境界値も網羅
   test('should apply no discount for 9 items')
   test('should apply 10% discount for 10 items')  // 境界
   test('should apply 10% discount for 11 items')
   ```

2. **異常系テスト**:
   - エラー発生時の振る舞い
   - 不正入力時の拒否
   - タイムアウト、ネットワークエラー等
   ```typescript
   // ❌ 正常系のみ
   test('should fetch user data')

   // ✅ 異常系も網羅
   test('should fetch user data when API responds')
   test('should throw error when API returns 404')
   test('should throw error when API times out')
   ```

3. **条件分岐のカバレッジ**:
   - すべての if 文の true/false パス
   - switch 文のすべての case
   - 早期リターンのすべてのパス

**判定フロー**:
```
テストケースを確認
  ↓
正常系のテストがあるか？
  ↓ No → [Critical] 正常系テストがない
  ↓ Yes
  ↓
異常系のテストがあるか？
  ↓ No → [Important] 異常系テストがない
  ↓ Yes
  ↓
境界値のテストがあるか？
  ↓ No → [Important] 境界値テストがない
  ↓ Yes → OK
```

**判定**: 異常系・境界値テストがない場合は**必ず指摘**（Important）

### ステップ3: テストの独立性が保たれているか（高優先度）

**判断基準**:
テスト間に実行順序の依存や共有状態の干渉がないか。

**チェック項目**:

1. **実行順序依存の有無**:
   ```typescript
   // ❌ 前のテストの結果に依存
   test('should create user', () => {
     user = createUser('test@example.com');
   });
   test('should update user', () => {
     updateUser(user.id);  // 前のテストの user に依存
   });

   // ✅ 各テストが独立
   test('should create user', () => {
     const user = createUser('test@example.com');
   });
   test('should update user', () => {
     const user = createUser('test@example.com');  // 自分でセットアップ
     updateUser(user.id);
   });
   ```

2. **共有状態の干渉**:
   - グローバル変数への依存
   - データベースの状態が残る
   - ファイルシステムの状態が残る
   ```typescript
   // ❌ 共有状態に依存
   let counter = 0;
   test('should increment', () => {
     counter++;
     expect(counter).toBe(1);
   });
   test('should increment', () => {
     counter++;
     expect(counter).toBe(1);  // 前のテストの影響で失敗
   });

   // ✅ 各テストが独立した状態を持つ
   test('should increment', () => {
     let counter = 0;
     counter++;
     expect(counter).toBe(1);
   });
   ```

3. **クリーンアップの確実性**:
   - teardown / afterEach でのクリーンアップ
   - try-finally での確実なリソース解放

**判定**: 実行順序依存・共有状態の干渉がある場合は**必ず指摘**（Important）

### ステップ4: テストダブルの使用が適切か（中優先度）

**判断基準**:
モック・スタブは外部依存の置き換えに限定し、実装の詳細を検証しない。

**チェック項目**:

1. **モックの使いすぎ**:
   ```typescript
   // ❌ モックだらけのテスト（設計の問題を示唆）
   test('should process order', () => {
     const mockValidator = mock(Validator);
     const mockCalculator = mock(Calculator);
     const mockRepository = mock(Repository);
     const mockLogger = mock(Logger);
     const mockMailer = mock(Mailer);
     // ...モックが多すぎる
   });

   // ✅ 外部依存のみモック
   test('should process order', () => {
     const mockRepository = mock(Repository);  // DB: 外部依存
     const mockMailer = mock(Mailer);  // メール送信: 外部依存
     // Validator, Calculator は実物を使う（Pure functionなら）
   });
   ```

2. **実装の詳細の検証**:
   ```typescript
   // ❌ 内部メソッドの呼び出し順序を検証
   test('should process order', () => {
     const spy = jest.spyOn(service, 'internalMethod');
     service.processOrder(order);
     expect(spy).toHaveBeenCalledTimes(1);  // 実装詳細
   });

   // ✅ 振る舞いを検証
   test('should process order', () => {
     service.processOrder(order);
     expect(order.status).toBe('processed');  // 振る舞い
   });
   ```

3. **テストダブルの振る舞いの正確性**:
   - モックの振る舞いが実際の依存先と乖離していないか
   - Contract Test で整合性を担保しているか

**判定**: モックが多すぎる、実装詳細を検証している場合は**指摘**（Minor）

### ステップ5: テストの保守性が確保されているか（中優先度）

**判断基準**:
実装変更時にテストが過度に壊れず、テスト自体も理解・修正しやすいか。

**チェック項目**:

1. **実装詳細への依存度**:
   ```typescript
   // ❌ 実装詳細に依存
   test('should process order', () => {
     // 内部実装の具体的な手順に依存
     expect(service['validateOrder']).toHaveBeenCalled();
     expect(service['calculateTotal']).toHaveBeenCalled();
     expect(service['saveOrder']).toHaveBeenCalled();
   });

   // ✅ 振る舞いをテスト
   test('should process order', () => {
     const result = service.processOrder(order);
     expect(result.status).toBe('success');
   });
   ```

2. **テストヘルパーの適切性**:
   - 重複するセットアップはヘルパーに抽出
   - ただし過度な抽象化でテストが読みにくくならないように
   ```typescript
   // ❌ 重複だらけ
   test('test1', () => {
     const user = { id: 1, name: 'Alice', email: 'alice@example.com' };
     // ...
   });
   test('test2', () => {
     const user = { id: 1, name: 'Alice', email: 'alice@example.com' };
     // ...
   });

   // ✅ ヘルパーで重複削減
   function createTestUser() {
     return { id: 1, name: 'Alice', email: 'alice@example.com' };
   }
   ```

3. **マジックナンバーの排除**:
   - テスト内の意味不明な数値・文字列
   - 意図が伝わる定数を使う

**判定**: 実装詳細への過度な依存がある場合は**指摘**（Minor）

### ステップ6: テストピラミッドに従っているか（低優先度）

**判断基準**:
ユニットテスト（多）、統合テスト（中）、E2Eテスト（少）のバランス。

**チェック項目**:

1. **適切な層へのテスト配置**:
   ```
   【ピラミッドの理想形】
          /\
         /E2\  ← 最少（主要なユーザーシナリオのみ）
        /----\
       /統合  \  ← 中程度（コンポーネント間の連携）
      /--------\
     /ユニット  \  ← 最多（ロジック網羅、境界値、エッジケース）
    /------------\
   ```

2. **重複の排除**:
   - ユニットテストで網羅済みのエッジケースを統合テストに重複して書かない
   - E2Eテストは主要なハッピーパスのみ

3. **障害特定の容易性**:
   - 上位層のテストが失敗したとき、下位層のテストで原因箇所を特定できるか

**判定**: ピラミッドの逆転（E2E過多、ユニットテスト不足）がある場合は**指摘**（Minor）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

## レビュー観点（詳細チェックリスト）

### 1. テスト名と仕様の明示性

- [ ] テスト名から具体的な仕様が読み取れるか（ユースケース的な説明）
- [ ] 実装詳細ではなく振る舞いを表現しているか
- [ ] `should` / `must` prefix が適切に使われているか（フレームワーク自動付与なら不要）
- [ ] テスト一覧を読むだけで対象モジュールの仕様が把握できるか
- [ ] テストが先に書かれ、実装がそのテストを満たす形で進められているか（テストファースト）

### 2. テストケースの網羅性

- [ ] 正常系だけでなく異常系・境界値がテストされているか
- [ ] 代表的な境界値（0、1、空、null、最大値、最小値、境界の前後）がテストされているか
- [ ] 条件分岐のすべてのパスを通るテストがあるか
- [ ] エラーケース（例外発生、タイムアウト、不正入力等）のテストがあるか
- [ ] 同じ構造で入力だけが異なるテストを、パラメータ化テストで1つにまとめているか
- [ ] Property-based testing が有効な場面（数学的性質、変換の可逆性、不変条件等）で活用されているか

### 3. テストの構造と可読性

- [ ] Arrange-Act-Assert（AAA）パターンで構造化されているか
- [ ] 1 テスト 1 アサーション（概念的に。1つの振る舞いを検証していればOK）になっているか
- [ ] テストの意図が読んですぐわかるか（変数名、セットアップの明確さ）

### 4. テストの独立性

- [ ] テスト間に実行順序の依存がないか
- [ ] 共有状態（グローバル変数、DB の状態等）がテスト間で干渉しないか
- [ ] 各テストが自分で必要な前提条件をセットアップしているか
- [ ] teardown / cleanup が確実に行われるか

### 5. テストダブルの適切な使用

- [ ] モック / スタブの使用が適切か（外部依存の置き換えに限定）
- [ ] 実装の詳細（内部メソッドの呼び出し順序等）をモックで検証していないか
- [ ] モックが多すぎないか（モックだらけのテストは設計の問題を示唆）
- [ ] テストダブルの振る舞いが実際の依存先と乖離していないか

### 6. テストの保守性

- [ ] テストが実装の変更に過度に敏感になっていないか（振る舞いをテストする）
- [ ] テストヘルパーやファクトリが適切に使われているか（セットアップの重複削減）
- [ ] テストヘルパーの抽象化が過度で、テスト自体が読みにくくなっていないか
- [ ] マジックナンバーがテスト内に埋まっていないか（意図が伝わる値を使う）

### 7. テストの信頼性

- [ ] フレイキーテスト（実行するたびに結果が変わる）の要因はないか
  - 時刻依存、乱数依存、外部サービス依存、並行処理のタイミング依存
- [ ] テストが本当に失敗すべきとき失敗するか（アサーションが甘すぎないか）
- [ ] テスト対象のコードを意図的に壊したとき、テストが検出できるか

### 8. テストピラミッド

- [ ] ユニットテスト（最多）でロジック網羅、境界値、エッジケースを担保しているか
- [ ] 統合テスト（中程度）でコンポーネント間の連携を確認しているか
- [ ] E2Eテスト（最少）は主要なユーザーシナリオのみに絞られているか
- [ ] ユニットテストで網羅済みのエッジケースを統合テストやE2Eに重複して書いていないか
- [ ] 各テストが適切な層に配置されているか
- [ ] 上位層のテストが失敗したとき、下位層のテストで原因箇所を特定できる構造か

## 指摘の出し方

### 指摘の構造

```
【問題点】このテストは○○の問題があります
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□に変更すると品質が向上します
【トレードオフ】ただし、◇◇の考慮も必要です
```

### 指摘の例

#### テスト名の曖昧さの指摘

```
【問題点】テスト名が曖昧で、具体的な仕様が読み取れません
【理由】`should return error when email format is invalid`では、どういう format が invalid なのか不明です
【影響】テスト一覧から仕様を把握できず、新メンバーの理解を妨げます
【提案】以下のように具体的な仕様を表現してください
  ```typescript
  // Before: 曖昧
  test('should return error when email format is invalid')

  // After: 具体的
  test('should reject registration when email has no at sign')
  test('should reject registration when email has no domain part')
  test('should reject registration when email domain is empty')
  ```
【トレードオフ】テスト名が長くなりますが、実行可能な仕様ドキュメントとして機能します
```

#### 境界値テスト不足の指摘

```
【問題点】境界値のテストがありません
【理由】割引適用の閾値（10個）のテストはありますが、9個と11個のテストがありません
【影響】境界付近で off-by-one エラーが発生する可能性があります
【提案】以下の境界値テストを追加してください
  ```typescript
  test('should apply no discount for 9 items')    // 境界の直前
  test('should apply 10% discount for 10 items')  // 境界
  test('should apply 10% discount for 11 items')  // 境界の直後
  ```
【トレードオフ】テスト数は増えますが、境界付近のバグを早期発見できます
```

#### テストの独立性欠如の指摘

```
【問題点】テスト間に実行順序の依存があります
【理由】2つ目のテストが1つ目のテストで作成した `user` 変数に依存しています
【影響】テストの実行順序が変わると失敗し、並行実行もできません
【提案】以下のように各テストが独立してセットアップを行ってください
  ```typescript
  // Before: 依存あり
  let user;
  test('should create user', () => {
    user = createUser('test@example.com');
  });
  test('should update user', () => {
    updateUser(user.id);  // 前のテストに依存
  });

  // After: 独立
  test('should create user', () => {
    const user = createUser('test@example.com');
  });
  test('should update user', () => {
    const user = createUser('test@example.com');  // 自分でセットアップ
    updateUser(user.id);
  });
  ```
【トレードオフ】セットアップの重複が増えますが、テストヘルパーで共通化できます
```

#### モック過多の指摘

```
【問題点】テスト内のモックが多すぎます（5つ以上）
【理由】Validator、Calculator、Repository、Logger、Mailer のすべてをモックしています
【影響】モックだらけのテストは、設計の問題（依存が多すぎる）を示唆しています
【提案】以下のように外部依存のみモックし、Pure functionは実物を使用してください
  ```typescript
  // Before: モックだらけ
  const mockValidator = mock(Validator);
  const mockCalculator = mock(Calculator);
  const mockRepository = mock(Repository);
  const mockLogger = mock(Logger);
  const mockMailer = mock(Mailer);

  // After: 外部依存のみモック
  const mockRepository = mock(Repository);  // DB: 外部依存
  const mockMailer = mock(Mailer);  // メール送信: 外部依存
  // Validator, Calculator は実物を使う（Pure functionなら）
  ```
【トレードオフ】設計のリファクタリング（依存の削減）も検討すべきです
```

### 指摘の優先度ラベル

- **[Important]**: テスト名の曖昧さ、異常系・境界値テスト不足、テストの独立性欠如（必ず修正すべき）
- **[Minor]**: モック過多、実装詳細への依存、テストヘルパーの過度な抽象化（修正を推奨）
- **[Nit]**: テストピラミッドの逆転、軽微な可読性改善（修正を推奨）

### トレードオフの明示

- テスト数増加とカバレッジ向上のバランス
- 可読性と保守性のバランス
- 具体的な改善提案と実装コストの明示

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: テスト名が曖昧（Important指摘）

**コード**:
```typescript
test('should return error when email format is invalid', () => {
  const result = validateEmail('invalidemail');
  expect(result.isValid).toBe(false);
});
```

**期待される指摘**:
- [Important] テスト名が曖昧、具体的な仕様が読み取れない
- どういう format が invalid なのか不明
- `should reject when email has no at sign` のような具体的な命名にすべき

### Case 2: 境界値テスト不足（Important指摘）

**コード**:
```typescript
test('should apply 10% discount for 10 items', () => {
  const price = calculateDiscount(10);
  expect(price).toBe(90);
});
```

**期待される指摘**:
- [Important] 境界値（9個、11個）のテストがない
- off-by-one エラーのリスク
- 境界の前後のテストを追加すべき

### Case 3: テストの独立性欠如（Important指摘）

**コード**:
```typescript
let user;
test('should create user', () => {
  user = createUser('test@example.com');
});
test('should update user', () => {
  updateUser(user.id);
});
```

**期待される指摘**:
- [Important] テスト間に実行順序の依存がある
- 2つ目のテストが1つ目の結果に依存
- 各テストが独立してセットアップを行うべき

### Case 4: モック過多（Minor指摘）

**コード**:
```typescript
test('should process order', () => {
  const mockValidator = mock(Validator);
  const mockCalculator = mock(Calculator);
  const mockRepository = mock(Repository);
  const mockLogger = mock(Logger);
  const mockMailer = mock(Mailer);
  // ...
});
```

**期待される指摘**:
- [Minor] モックが多すぎる（5つ以上）
- 設計の問題（依存が多すぎる）を示唆
- 外部依存のみモックし、Pure functionは実物を使うべき

### Case 5: 実装詳細への依存（Minor指摘）

**コード**:
```typescript
test('should process order', () => {
  const spy = jest.spyOn(service, 'internalMethod');
  service.processOrder(order);
  expect(spy).toHaveBeenCalledTimes(1);  // 内部メソッドの呼び出しを検証
});
```

**期待される指摘**:
- [Minor] 実装の詳細（内部メソッドの呼び出し）を検証している
- 振る舞いではなく実装をテストしている
- `order.status` 等の振る舞いを検証すべき

### Case 6: 許容されるケース（指摘なし）

**コード**:
```typescript
test('should reject registration when email has no at sign', () => {
  const result = validateEmail('invalidemail');
  expect(result.isValid).toBe(false);
  expect(result.error).toBe('Email must contain @');
});
```

**期待される判断**:
- テスト名が具体的で仕様を表現している
- 振る舞いをテストしている
- 指摘なし
