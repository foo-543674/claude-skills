# データモデリングレビュー

コードレビュー時にデータベース設計とエンティティモデリングの観点で指摘すべきポイントを定義する。RDB を主な対象とするが、原則はドキュメント DB 等にも応用できる。

このスキルはイミュータブルデータモデリングを基本思想とする。Nullable カラムの精査とテーブル分離により UPDATE を排除し、ほぼすべての操作を INSERT で表現するデータ構造を目指す。これによりスケーラビリティの向上と変更履歴の自然な保持が得られる。ただしこの思想はトレードオフを伴い、テーブル数の増加やクエリの複雑化を招く場合がある。プロジェクトの規模・要件に応じた判断が必要。

**UPDATE / DELETE に対する基本的な考え方**: 現実世界には UPDATE や DELETE に相当する事象は存在しない。システムの UPDATE は「最初からその状態だったことにする」という過去への遡及的な改変であり、DELETE も同様に「最初から存在しなかったことにする」操作である。正当なビジネスフローの中で UPDATE や DELETE が必要になっている場合、それはモデリングに問題がある兆候と捉える。ユーザーの入力ミス修正などイレギュラー対応として UPDATE が必要になるケースはあるが、それは例外的な運用操作であり、通常のビジネスフローとは区別して設計する。

## Why: なぜデータモデリングレビューが重要か

データモデリングの品質は、システムの長期的な保守性とスケーラビリティを決定する。不適切な設計は、後から修正が極めて困難な技術的負債となる。

**根本的な理由**:
1. **修正の困難さとコスト**: データモデルの変更は、マイグレーション・既存データの変換・アプリケーションコードの修正を伴い、コードのリファクタリングと比較して数十倍〜数百倍のコストがかかる。特に本番稼働後は、ダウンタイムやデータ損失のリスクを伴うため、修正が実質的に不可能な場合もある
2. **データ整合性への影響**: 不適切なモデリング（外部キー制約の欠如、Nullable の乱用、不正な状態の型レベル排除不足等）は、データ不整合を許容する構造となり、バグの温床となる。整合性が壊れたデータは、全体のデータ品質を低下させ、分析・レポート・ビジネス判断に影響する
3. **クエリパフォーマンスの決定**: テーブル構造・インデックス設計・正規化レベルは、クエリパフォーマンスを根本的に決定する。N+1 問題、不要な JOIN、フルスキャン等の性能問題は、モデル設計の段階で決まる。後からインデックス追加で解決できる範囲は限定的
4. **スケーラビリティの制約**: ロック競合を招く UPDATE 中心の設計、肥大化する単一テーブル、分散が困難な密結合なモデルは、スケールアウトの障壁となる。トラフィック増加時に対処不能な状況に陥る
5. **ビジネスロジックの複雑化**: 不適切なモデル（暗黙の状態遷移、Nullable による未確定状態の表現、ビジネス概念の不一致等）は、アプリケーション層のロジックを複雑にし、バグを誘発する。モデルが明確なら、ロジックはシンプルになる

**データモデリングレビューの目的**:
- 修正困難な技術的負債を初期段階で防ぐ
- データ整合性を型レベル・制約レベルで保証する
- クエリパフォーマンスとスケーラビリティを確保する
- ビジネス概念を正確に反映し、ロジックをシンプルにする
- 長期的な保守性と変更容易性を担保する

## 判断プロセス（決定ツリー）

データモデリングのレビュー時は、以下の順序で判断する。修正困難で影響範囲が大きい問題から確認し、問題があれば指摘する。

### ステップ1: エンティティ設計とビジネス概念の一致（最優先）

**判断基準**:
エンティティがビジネス概念を正しく反映していないと、全体のモデルが不整合となり、修正が極めて困難。

**チェック項目**:

1. **ビジネス概念の正確な反映**:
   ```sql
   -- ❌ ビジネス概念が不明瞭
   CREATE TABLE user_data (
     id INT PRIMARY KEY,
     name VARCHAR(255),
     status VARCHAR(50),  -- 何のステータス？
     date DATETIME,       -- 何の日付？
     type VARCHAR(50)     -- 何のタイプ？
   );

   -- ✅ ビジネス概念が明確
   CREATE TABLE employees (
     id INT PRIMARY KEY,
     full_name VARCHAR(255) NOT NULL,
     employment_status ENUM('active', 'on_leave', 'suspended') NOT NULL,
     hired_at DATE NOT NULL
   );

   CREATE TABLE retirements (
     id INT PRIMARY KEY,
     employee_id INT NOT NULL,
     retired_at DATE NOT NULL,
     reason VARCHAR(255),
     FOREIGN KEY (employee_id) REFERENCES employees(id)
   );
   ```

2. **God Table の回避**:
   ```sql
   -- ❌ 無関係な概念が混在
   CREATE TABLE records (
     id INT PRIMARY KEY,
     type VARCHAR(50),  -- 'order', 'invoice', 'shipment'
     data JSON  -- 型ごとに異なる構造
   );

   -- ✅ 概念ごとに分離
   CREATE TABLE orders (...);
   CREATE TABLE invoices (...);
   CREATE TABLE shipments (...);
   ```

3. **正規化の基本**:
   ```sql
   -- ❌ 繰り返しグループ（第1正規形違反）
   CREATE TABLE orders (
     id INT PRIMARY KEY,
     item1 VARCHAR(255),
     item2 VARCHAR(255),
     item3 VARCHAR(255)
   );

   -- ✅ 第1正規形
   CREATE TABLE orders (
     id INT PRIMARY KEY,
     customer_id INT
   );
   CREATE TABLE order_items (
     id INT PRIMARY KEY,
     order_id INT,
     product_id INT,
     quantity INT,
     FOREIGN KEY (order_id) REFERENCES orders(id)
   );
   ```

**判定フロー**:
```
エンティティ設計を確認
  ↓
ビジネス概念と一致しているか？
  ↓ No → [Important] エンティティを再設計すべき
  ↓ Yes
  ↓
無関係な概念が混在していないか（God Table）？
  ↓ Yes → [Important] テーブルを分離すべき
  ↓ No
  ↓
第1〜3正規形の違反がないか？
  ↓ Yes → [Important] 正規化すべき
  ↓ No → OK
```

**判定**: ビジネス概念の不一致、God Table は**必ず指摘**（Important）

### ステップ2: Nullable カラムの精査とテーブル分離（高優先度）

**判断基準**:
Nullable カラムの不適切な使用は、UPDATE 中心の設計を招き、スケーラビリティとデータ整合性を損なう。

**チェック項目**:

1. **Nullable の分類**:
   ```sql
   -- ❌ 「未確定」を Nullable で表現（UPDATE が発生）
   CREATE TABLE employees (
     id INT PRIMARY KEY,
     name VARCHAR(255) NOT NULL,
     retirement_date DATE NULL  -- 後から UPDATE で埋める
   );

   -- ✅ イベント発生時に INSERT
   CREATE TABLE employees (
     id INT PRIMARY KEY,
     name VARCHAR(255) NOT NULL
   );

   CREATE TABLE retirements (
     id INT PRIMARY KEY,
     employee_id INT NOT NULL,
     retired_at DATE NOT NULL,
     FOREIGN KEY (employee_id) REFERENCES employees(id)
   );
   ```

2. **本当に Optional な値の判定**:
   ```sql
   -- ✅ 本当に optional な値（ビジネス上任意）
   CREATE TABLE users (
     id INT PRIMARY KEY,
     email VARCHAR(255) NOT NULL,
     nickname VARCHAR(255) NULL  -- ニックネームは任意
   );

   -- ❌ ビジネス上必要なのに Nullable
   CREATE TABLE orders (
     id INT PRIMARY KEY,
     customer_id INT NULL  -- 注文に顧客は必須のはず
   );
   ```

3. **UPDATE 排除の徹底**:
   ```sql
   -- ❌ ステータス更新を UPDATE で実現
   CREATE TABLE orders (
     id INT PRIMARY KEY,
     status ENUM('pending', 'paid', 'shipped') NOT NULL
   );
   -- UPDATE orders SET status = 'paid' WHERE id = ?

   -- ✅ イベントテーブルで状態遷移を INSERT
   CREATE TABLE orders (
     id INT PRIMARY KEY,
     created_at DATETIME NOT NULL
   );

   CREATE TABLE order_payments (
     id INT PRIMARY KEY,
     order_id INT NOT NULL,
     paid_at DATETIME NOT NULL,
     FOREIGN KEY (order_id) REFERENCES orders(id)
   );

   CREATE TABLE order_shipments (
     id INT PRIMARY KEY,
     order_id INT NOT NULL,
     shipped_at DATETIME NOT NULL,
     FOREIGN KEY (order_id) REFERENCES orders(id)
   );
   ```

**判定フロー**:
```
Nullable カラムを発見
  ↓
本当に optional な値か？
  ↓ No（ビジネス上必要）
  → 「未確定」なだけか？
    ↓ Yes → [Important] イベントテーブルに分離すべき
    ↓ No → [Important] NOT NULL にすべき
  ↓ Yes（任意）→ OK
```

**判定**: 「未確定」を Nullable で表現している場合は**必ず指摘**（Important）

### ステップ3: リレーション設計と外部キー制約（高優先度）

**判断基準**:
不適切なリレーション設計は、データ整合性を損ない、クエリを複雑にする。

**チェック項目**:

1. **外部キー制約の有無**:
   ```sql
   -- ❌ 外部キー制約なし（孤立レコードが発生）
   CREATE TABLE order_items (
     id INT PRIMARY KEY,
     order_id INT NOT NULL,
     product_id INT NOT NULL
   );

   -- ✅ 外部キー制約で整合性保証
   CREATE TABLE order_items (
     id INT PRIMARY KEY,
     order_id INT NOT NULL,
     product_id INT NOT NULL,
     FOREIGN KEY (order_id) REFERENCES orders(id),
     FOREIGN KEY (product_id) REFERENCES products(id)
   );
   ```

2. **N:M の中間テーブル設計**:
   ```sql
   -- ❌ 単純なリンクテーブルに不要な属性
   CREATE TABLE enrollments (
     student_id INT,
     course_id INT,
     enrollment_date DATE,  -- これは必要？
     grade VARCHAR(2),      -- これは中間テーブルの責務？
     PRIMARY KEY (student_id, course_id)
   );

   -- ✅ 中間テーブルは最小限
   CREATE TABLE enrollments (
     student_id INT,
     course_id INT,
     enrolled_at DATE NOT NULL,
     PRIMARY KEY (student_id, course_id),
     FOREIGN KEY (student_id) REFERENCES students(id),
     FOREIGN KEY (course_id) REFERENCES courses(id)
   );

   -- 成績は別テーブル（イベント）
   CREATE TABLE grades (
     id INT PRIMARY KEY,
     student_id INT NOT NULL,
     course_id INT NOT NULL,
     grade VARCHAR(2) NOT NULL,
     graded_at DATE NOT NULL,
     FOREIGN KEY (student_id, course_id) REFERENCES enrollments(student_id, course_id)
   );
   ```

3. **Polymorphic Association の回避**:
   ```sql
   -- ❌ 1つの外部キーが複数テーブルを参照（型安全性喪失）
   CREATE TABLE comments (
     id INT PRIMARY KEY,
     commentable_type VARCHAR(50),  -- 'Post' or 'Photo'
     commentable_id INT,
     content TEXT
   );

   -- ✅ テーブルごとにコメントテーブル分離
   CREATE TABLE post_comments (
     id INT PRIMARY KEY,
     post_id INT NOT NULL,
     content TEXT NOT NULL,
     FOREIGN KEY (post_id) REFERENCES posts(id)
   );

   CREATE TABLE photo_comments (
     id INT PRIMARY KEY,
     photo_id INT NOT NULL,
     content TEXT NOT NULL,
     FOREIGN KEY (photo_id) REFERENCES photos(id)
   );
   ```

**判定フロー**:
```
リレーションを確認
  ↓
外部キー制約があるか？
  ↓ No → [Important] 外部キー制約を追加すべき
  ↓ Yes
  ↓
Polymorphic Association になっていないか？
  ↓ Yes → [Important] テーブルを分離すべき
  ↓ No → OK
```

**判定**: 外部キー制約の欠如、Polymorphic Association は**必ず指摘**（Important）

### ステップ4: 削除の設計（中優先度）

**判断基準**:
「削除」と呼ばれている操作の本質を分析し、適切な実装方法を選択する。

**チェック項目**:

1. **削除 vs 状態遷移の判定**:
   ```sql
   -- ❌ 「退会」を論理削除で実現
   CREATE TABLE users (
     id INT PRIMARY KEY,
     email VARCHAR(255) NOT NULL,
     deleted_at DATETIME NULL
   );

   -- ✅ 「退会」は状態遷移（イベント）
   CREATE TABLE users (
     id INT PRIMARY KEY,
     email VARCHAR(255) NOT NULL
   );

   CREATE TABLE user_withdrawals (
     id INT PRIMARY KEY,
     user_id INT NOT NULL,
     withdrawn_at DATETIME NOT NULL,
     reason VARCHAR(255),
     FOREIGN KEY (user_id) REFERENCES users(id)
   );
   ```

2. **物理削除 vs アーカイブ**:
   ```sql
   -- ✅ 本当に削除（復旧不要）
   DELETE FROM session_tokens WHERE expires_at < NOW();

   -- ✅ 復旧要件がある場合はアーカイブ
   -- 1. アーカイブテーブルに移動
   INSERT INTO archived_orders SELECT * FROM orders WHERE id = ?;
   -- 2. 元テーブルから削除
   DELETE FROM orders WHERE id = ?;
   ```

3. **論理削除の問題**:
   ```sql
   -- ❌ 論理削除（全クエリに条件追加必要）
   CREATE TABLE products (
     id INT PRIMARY KEY,
     name VARCHAR(255) NOT NULL,
     deleted_at DATETIME NULL
   );
   -- SELECT * FROM products WHERE deleted_at IS NULL;
   -- ↑ 全クエリに条件追加が必要、漏れるとバグ

   -- ❌ ユニーク制約との干渉
   CREATE TABLE users (
     id INT PRIMARY KEY,
     email VARCHAR(255) NOT NULL UNIQUE,
     deleted_at DATETIME NULL
   );
   -- 同じメールで再登録できない（ユニーク制約が残る）
   ```

**判定**: 論理削除を使っている場合は**指摘**（Minor）

### ステップ5: インデックス設計（中優先度）

**判断基準**:
不適切なインデックス設計は、クエリパフォーマンスを著しく低下させる。

**チェック項目**:

1. **WHERE 句のカラム**:
   ```sql
   -- ❌ 頻繁に検索されるカラムにインデックスなし
   SELECT * FROM orders WHERE customer_id = ?;
   -- customer_id にインデックスがない

   -- ✅ インデックス追加
   CREATE INDEX idx_orders_customer_id ON orders(customer_id);
   ```

2. **複合インデックスのカラム順序**:
   ```sql
   -- ❌ カラム順序が不適切
   CREATE INDEX idx_orders_date_customer ON orders(created_at, customer_id);
   -- SELECT * FROM orders WHERE customer_id = ? AND created_at > ?;
   -- ↑ customer_id が先に来るクエリなのにインデックスが使えない

   -- ✅ クエリパターンに合わせた順序
   CREATE INDEX idx_orders_customer_date ON orders(customer_id, created_at);
   ```

3. **不要なインデックス**:
   ```sql
   -- ❌ 使われないインデックス（書き込み性能低下）
   CREATE INDEX idx_users_created_at ON users(created_at);
   -- created_at で検索することがない
   ```

**判定**: 明らかなインデックス不足は**指摘**（Minor）

### ステップ6: マイグレーション戦略（低優先度）

**判断基準**:
安全でロールバック可能なマイグレーション設計が必要。

**チェック項目**:

1. **NOT NULL カラムの追加**:
   ```sql
   -- ❌ NOT NULL カラムをデフォルト値なしで追加
   ALTER TABLE users ADD COLUMN phone VARCHAR(20) NOT NULL;
   -- 既存レコードでエラー

   -- ✅ デフォルト値付き
   ALTER TABLE users ADD COLUMN phone VARCHAR(20) NOT NULL DEFAULT '';
   ```

2. **Expand-Contract Pattern**:
   ```sql
   -- ❌ カラム名を直接変更（ダウンタイムが発生）
   ALTER TABLE users RENAME COLUMN name TO full_name;

   -- ✅ Expand-Contract
   -- 1. Expand: 新カラム追加
   ALTER TABLE users ADD COLUMN full_name VARCHAR(255);
   -- 2. 並行期間（両方に書き込み）
   UPDATE users SET full_name = name WHERE full_name IS NULL;
   -- 3. Contract: 旧カラム削除
   ALTER TABLE users DROP COLUMN name;
   ```

**判定**: 破壊的マイグレーションは**指摘**（Nit）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

### 1. エンティティ設計とビジネス概念の一致

- [ ] エンティティがビジネス概念を正しく反映しているか
- [ ] 無関係な概念が1つのテーブルに混在していないか（God Table の回避）
- [ ] 第1〜3正規形の違反がないか
- [ ] 非正規化する場合、理由（パフォーマンス、読み取りパターン）が明確か
- [ ] CQRS の Read Model で非正規化を検討しているか

### 2. Nullable カラムの精査とテーブル分離

- [ ] Nullable カラムが「本当に optional な値」か「未確定なだけでビジネス上必要な値」か区別されているか
- [ ] 「未確定」を Nullable で表現していないか
- [ ] イベント発生時に INSERT する設計になっているか
- [ ] UPDATE を排除し、ほぼすべての操作が INSERT で表現されているか
- [ ] テーブル分離による JOIN 増加を CQRS の Read Model で対策しているか

### 3. リレーション設計と外部キー制約

- [ ] 1:N, N:M のリレーションが正しくモデル化されているか
- [ ] 外部キー制約が適切に設定されているか
- [ ] N:M の中間テーブルに不要な属性が含まれていないか
- [ ] Polymorphic Association になっていないか
- [ ] カスケード削除の影響範囲を把握しているか
- [ ] マイクロサービス間では結果整合性の設計が別途あるか

### 4. 削除の設計

- [ ] 「削除」と呼ばれている操作が本当に削除か、状態遷移かを分析しているか
- [ ] 状態遷移の場合、イベントテーブルへの INSERT で表現しているか
- [ ] 本当に削除の場合、物理削除を選択しているか
- [ ] 復旧要件がある場合、アーカイブテーブルへの移動を検討しているか
- [ ] 論理削除（deleted_at）を使っていないか

### 5. インデックス設計

- [ ] WHERE / JOIN / ORDER BY で使われるカラムにインデックスがあるか
- [ ] 複合インデックスのカラム順序が検索パターンに合っているか
- [ ] 不要なインデックスが残っていないか
- [ ] 実際のクエリパターンと計測に基づいて設計しているか

### 6. マイグレーション戦略

- [ ] NOT NULL カラムの追加にデフォルト値があるか
- [ ] カラム名変更・型変更を expand-contract pattern で安全に行っているか
- [ ] ロールバック可能なマイグレーションになっているか
- [ ] 大量データのテーブルに対するマイグレーションのロック影響を考慮しているか

### 7. 時系列データと履歴管理

- [ ] 変更履歴が必要なデータにイベントソーシングまたは履歴テーブルが設計されているか
- [ ] 「現在の状態」と「履歴」のクエリパターンが分離されているか
- [ ] 有効期間（valid_from / valid_to）を持つデータの重複・ギャップ防止策があるか
- [ ] 監査ログ（誰が・いつ・何を変更したか）の要件が満たされているか

## よくあるアンチパターン

- **EAV（Entity-Attribute-Value）の安易な採用**: ユーザー定義属性やプラグインシステム等、スキーマの動的拡張が本質的に必要な場面では有効な選択肢だが、固定的なビジネス要件を EAV で表現するとクエリの複雑化・型安全性の喪失・データ整合性の担保困難を招く
- **Polymorphic Association**: 1つの外部キーカラムが複数テーブルを参照する（型安全性の喪失）
- **God Table**: 無関係な概念が1つのテーブルに詰め込まれている
- **Nullable as Pending**: ビジネス上必要な値を Nullable カラムで「未確定」として同一テーブルに持たせ、後から UPDATE する設計
- **Soft Delete as Default**: 分析なしに論理削除をデフォルト採用し、実際には「状態遷移」であるものを削除フラグで表現している
- **Implicit State Machine**: 状態遷移がカラムの値の組み合わせで暗黙的に表現されている

## 指摘の出し方

### 指摘の構造

```
【問題点】このデータモデルは○○の問題があります
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□に変更すると改善します
【トレードオフ】◇◇とのバランスを考慮する必要があります
```

### 指摘の例

#### Nullable カラムの不適切な使用の指摘

```
【問題点】この退職日カラムが Nullable で、後から UPDATE で埋める設計になっています
【理由】退職日は「未確定」なのではなく「退職というイベントがまだ発生していない」状態です
【影響】この設計により以下のリスクが発生します:
  - UPDATE によるロック競合が発生し、スケーラビリティが低下
  - 変更履歴が自然に残らず、監査要件を満たせない
  - 「退職していない従業員」を取得するクエリが `WHERE retirement_date IS NULL` となり、インデックスが効かない
【提案】以下のように退職イベントを別テーブルに分離してください
  ```sql
  -- Before: Nullable で UPDATE
  CREATE TABLE employees (
    id INT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    retirement_date DATE NULL  -- 後から UPDATE
  );

  -- After: イベントテーブルに分離して INSERT
  CREATE TABLE employees (
    id INT PRIMARY KEY,
    name VARCHAR(255) NOT NULL
  );

  CREATE TABLE retirements (
    id INT PRIMARY KEY,
    employee_id INT NOT NULL,
    retired_at DATE NOT NULL,
    reason VARCHAR(255),
    FOREIGN KEY (employee_id) REFERENCES employees(id)
  );
  ```
【トレードオフ】テーブル分離により JOIN が増加しますが、CQRS の Read Model で非正規化した View を用意することで対策できます
```

#### 論理削除の指摘

```
【問題点】このテーブルで論理削除（deleted_at）を使用しています
【理由】論理削除は以下の問題を引き起こします:
  - 全クエリに `WHERE deleted_at IS NULL` の付与が必要で、漏れるとバグ
  - ユニーク制約との干渉（同じメールで再登録できない）
  - テーブル肥大化とインデックス効率の低下
【影響】クエリの複雑化、バグの増加、パフォーマンス低下のリスクがあります
【提案】以下のいずれかのアプローチに変更してください
  ```sql
  -- Approach 1: 「退会」は状態遷移（イベント）として扱う
  CREATE TABLE user_withdrawals (
    id INT PRIMARY KEY,
    user_id INT NOT NULL,
    withdrawn_at DATETIME NOT NULL,
    reason VARCHAR(255),
    FOREIGN KEY (user_id) REFERENCES users(id)
  );

  -- Approach 2: 本当に削除なら物理削除
  DELETE FROM users WHERE id = ?;

  -- Approach 3: 復旧要件がある場合はアーカイブ
  INSERT INTO archived_users SELECT * FROM users WHERE id = ?;
  DELETE FROM users WHERE id = ?;
  ```
【トレードオフ】テーブル分離や物理削除により、復旧の難易度が上がる場合がありますが、アーカイブテーブルで対応できます
```

#### 外部キー制約欠如の指摘

```
【問題点】この中間テーブルに外部キー制約がありません
【理由】外部キー制約がないと、参照先が削除されても中間テーブルのレコードが残り、孤立レコードが発生します
【影響】データ整合性が失われ、JOIN 時に存在しないレコードを参照してバグの原因となります
【提案】以下のように外部キー制約を追加してください
  ```sql
  -- Before: 制約なし
  CREATE TABLE order_items (
    id INT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL
  );

  -- After: 外部キー制約追加
  CREATE TABLE order_items (
    id INT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id)
  );
  ```
【トレードオフ】外部キー制約により書き込み性能が若干低下しますが、データ整合性の保証のメリットが大きく上回ります
```

### 指摘の優先度ラベル

- **[Important]**: ビジネス概念の不一致、God Table、Nullable の不適切な使用、外部キー制約の欠如、Polymorphic Association（データ整合性・スケーラビリティに直結）
- **[Minor]**: 論理削除の使用、インデックス不足、正規化不足
- **[Nit]**: マイグレーション戦略の不備、軽微な最適化

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: Nullable の不適切な使用（Important指摘）

**コード**:
```sql
CREATE TABLE employees (
  id INT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  retirement_date DATE NULL  -- 後から UPDATE で埋める
);
```

**期待される指摘**:
- [Important] 退職日が Nullable で後から UPDATE する設計
- 「未確定」ではなく「イベント未発生」なので別テーブルに分離すべき
- retirements テーブルを作成し、退職時に INSERT すべき

### Case 2: 外部キー制約の欠如（Important指摘）

**コード**:
```sql
CREATE TABLE order_items (
  id INT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL
);
```

**期待される指摘**:
- [Important] 外部キー制約がない
- 孤立レコードが発生し、データ整合性が失われる
- FOREIGN KEY 制約を追加すべき

### Case 3: 論理削除の使用（Minor指摘）

**コード**:
```sql
CREATE TABLE users (
  id INT PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  deleted_at DATETIME NULL
);
```

**期待される指摘**:
- [Minor] 論理削除（deleted_at）を使用
- 全クエリに WHERE 条件追加が必要、ユニーク制約との干渉
- 状態遷移として扱う、物理削除、またはアーカイブに変更すべき

### Case 4: Polymorphic Association（Important指摘）

**コード**:
```sql
CREATE TABLE comments (
  id INT PRIMARY KEY,
  commentable_type VARCHAR(50),  -- 'Post' or 'Photo'
  commentable_id INT,
  content TEXT
);
```

**期待される指摘**:
- [Important] Polymorphic Association で型安全性が失われている
- 外部キー制約が設定できず、整合性が保証されない
- post_comments と photo_comments テーブルに分離すべき

### Case 5: 許容されるケース（指摘なし）

**コード**:
```sql
-- イミュータブルデータモデリング
CREATE TABLE employees (
  id INT PRIMARY KEY,
  name VARCHAR(255) NOT NULL
);

CREATE TABLE retirements (
  id INT PRIMARY KEY,
  employee_id INT NOT NULL,
  retired_at DATE NOT NULL,
  FOREIGN KEY (employee_id) REFERENCES employees(id)
);

-- 本当に optional な値
CREATE TABLE users (
  id INT PRIMARY KEY,
  email VARCHAR(255) NOT NULL,
  nickname VARCHAR(255) NULL  -- ニックネームは任意
);

-- 外部キー制約
CREATE TABLE order_items (
  id INT PRIMARY KEY,
  order_id INT NOT NULL,
  product_id INT NOT NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id),
  FOREIGN KEY (product_id) REFERENCES products(id)
);
```

**期待される判断**:
- イベントテーブルに分離され、UPDATE が排除されている
- 本当に optional な値のみ Nullable
- 外部キー制約で整合性が保証されている
- 指摘なし
