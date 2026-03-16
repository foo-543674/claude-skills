# セキュリティレビュー

コードレビュー時にセキュリティの観点で指摘すべきポイントを定義する。

## Why: なぜセキュリティレビューが重要か

セキュリティの脆弱性は、ユーザーデータの漏洩、システムの破壊、組織の信頼失墜を引き起こす。

**根本的な理由**:
1. **ユーザーデータの保護**: 個人情報、認証情報、決済情報などの漏洩は、ユーザーに直接的な被害を与え、法的責任と賠償リスクを生む。GDPR、個人情報保護法などの法規制違反となる
2. **組織の信頼とブランド**: セキュリティ侵害は組織の信頼を失墜させ、回復に長期間を要する。一度の侵害でビジネスが致命的なダメージを受けることもある
3. **修正コストの増大**: セキュリティの問題は、発見が遅れるほど修正コストが指数関数的に増大する。開発時に発見すれば数時間、本番侵害後の対応は数百万円〜数億円のコストとなる
4. **攻撃者の進化**: 攻撃手法は日々進化しており、既知の脆弱性を狙った自動化攻撃ツールが広く利用されている。一つでも脆弱性があれば、それが攻撃の入り口となる
5. **コンプライアンスと法的要件**: 業界標準（PCI DSS、HIPAA等）、法規制（GDPR、個人情報保護法等）への準拠は法的義務であり、違反は罰則の対象となる

**セキュリティレビューの目的**:
- ユーザーデータと資産を保護する
- 組織の信頼とブランドを守る
- 侵害による修正コストを最小化する
- 法的リスクとコンプライアンス違反を防ぐ
- セキュリティ意識をチーム全体に浸透させる

## 判断プロセス（決定ツリー）

セキュリティレビュー時は、以下の順序で判断する。影響範囲が大きく、悪用が容易な脆弱性から確認し、問題があれば指摘する。

### ステップ1: インジェクション脆弱性がないか（最優先）

**判断基準**:
インジェクション（SQLi、XSS、コマンドインジェクション等）は、OWASP Top 10で常に上位であり、データ漏洩やシステム侵害に直結する。

**チェック項目**:

1. **SQLインジェクション**:
   ```typescript
   // ❌ 文字列結合でSQLを構築
   const query = `SELECT * FROM users WHERE id = ${userId}`;
   // userId = "1 OR 1=1" でデータ全件取得可能

   // ✅ パラメータ化クエリ
   const query = `SELECT * FROM users WHERE id = ?`;
   db.execute(query, [userId]);
   ```

2. **XSS (Cross-Site Scripting)**:
   ```typescript
   // ❌ ユーザー入力を直接HTML出力
   const html = `<div>${userInput}</div>`;
   // userInput = "<script>alert(document.cookie)</script>" で攻撃可能

   // ✅ エスケープ処理
   const html = `<div>${escapeHtml(userInput)}</div>`;
   ```

3. **コマンドインジェクション**:
   ```typescript
   // ❌ ユーザー入力をコマンドに直接渡す
   exec(`convert ${filename} output.png`);
   // filename = "file.jpg; rm -rf /" で任意コマンド実行

   // ✅ シェル経由せず直接実行、または引数を適切にエスケープ
   execFile('convert', [filename, 'output.png']);
   ```

4. **その他のインジェクション**:
   - NoSQLインジェクション（MongoDB等）
   - LDAPインジェクション
   - XMLインジェクション
   - SSTI (Server-Side Template Injection)

**判定フロー**:
```
ユーザー入力を使用している箇所を発見
  ↓
入力がクエリ・コマンド・HTML等に埋め込まれているか？
  ↓ Yes
  → サニタイズ・エスケープ・パラメータ化されているか？
      ↓ No → [Critical] インジェクション脆弱性
      ↓ Yes → OK
```

**判定**: インジェクションの可能性がある場合は**必ず指摘**（Critical）

### ステップ2: 認証・認可が適切か（最優先）

**判断基準**:
認証・認可の欠陥は、不正アクセス、権限昇格、他人のデータアクセス（IDOR）を許す。

**チェック項目**:

1. **認証チェックの漏れ**:
   ```typescript
   // ❌ 認証チェックなしでエンドポイント公開
   app.get('/api/admin/users', (req, res) => {
     // 誰でもアクセス可能
   });

   // ✅ 認証ミドルウェア
   app.get('/api/admin/users', requireAuth, requireRole('admin'), (req, res) => {
     // 認証・認可済みのみアクセス可能
   });
   ```

2. **IDOR (Insecure Direct Object Reference)**:
   ```typescript
   // ❌ リソースの所有権チェックなし
   app.get('/api/orders/:id', async (req, res) => {
     const order = await db.getOrder(req.params.id);
     // 他人の注文も取得可能
     return order;
   });

   // ✅ 所有権チェック
   app.get('/api/orders/:id', async (req, res) => {
     const order = await db.getOrder(req.params.id);
     if (order.userId !== req.user.id) {
       return res.status(403).send('Forbidden');
     }
     return order;
   });
   ```

3. **権限昇格**:
   - ロールチェックが適切に実装されているか
   - 権限変更のエンドポイントが保護されているか

4. **セッション管理**:
   - トークンの有効期限が適切か
   - ログアウト時にトークンが無効化されるか
   - トークンがセキュアに保存されているか（httpOnly、Secure フラグ）

**判定**: 認証・認可の欠陥がある場合は**必ず指摘**（Critical）

### ステップ3: 機密データが保護されているか（高優先度）

**判断基準**:
パスワード、トークン、個人情報などの機密データが漏洩すると、直接的な被害につながる。

**チェック項目**:

1. **ハードコードされた認証情報**:
   ```typescript
   // ❌ ソースコードに認証情報
   const API_KEY = "sk_live_abcd1234";
   const DB_PASSWORD = "password123";

   // ✅ 環境変数
   const API_KEY = process.env.API_KEY;
   const DB_PASSWORD = process.env.DB_PASSWORD;
   ```

2. **ログへの機密情報出力**:
   ```typescript
   // ❌ パスワードやトークンをログ出力
   console.log('User login:', { email, password });
   console.log('API request:', { token: req.headers.authorization });

   // ✅ 機密情報をマスク
   console.log('User login:', { email, password: '[REDACTED]' });
   ```

3. **パスワードのハッシュ化**:
   ```typescript
   // ❌ 平文保存またはMD5/SHA1等の脆弱なハッシュ
   const hash = md5(password);

   // ✅ bcrypt、argon2等の適切なアルゴリズム
   const hash = await bcrypt.hash(password, 10);
   ```

4. **不要な個人情報の露出**:
   - API応答に不要な個人情報が含まれていないか
   - 最小限の情報のみ返しているか

**判定**: 機密データの不適切な扱いは**必ず指摘**（Critical/High）

### ステップ4: 入力検証が適切か（高優先度）

**判断基準**:
すべての外部入力（リクエスト、ファイル、外部API）は信頼できないものとして検証する。

**チェック項目**:

1. **ホワイトリスト検証**:
   ```typescript
   // ❌ ブラックリスト（漏れやすい）
   if (input.includes('<script>') || input.includes('onclick')) {
     throw new Error('Invalid input');
   }

   // ✅ ホワイトリスト
   if (!/^[a-zA-Z0-9_-]+$/.test(input)) {
     throw new Error('Invalid input');
   }
   ```

2. **ファイルアップロード**:
   - 拡張子、MIMEタイプ、サイズを検証しているか
   - ファイル内容の検証（マジックバイトチェック）をしているか
   - アップロードファイルを実行可能な場所に保存していないか

3. **オープンリダイレクト**:
   ```typescript
   // ❌ 検証なしのリダイレクト
   res.redirect(req.query.redirect_url);
   // redirect_url=https://evil.com でフィッシングサイトへ誘導

   // ✅ ホワイトリスト検証
   const allowedDomains = ['example.com'];
   if (!isAllowedDomain(redirect_url, allowedDomains)) {
     throw new Error('Invalid redirect');
   }
   ```

**判定**: 入力検証の欠如は**必ず指摘**（High）

### ステップ5: エラー処理で情報漏洩していないか（中優先度）

**判断基準**:
エラーメッセージやスタックトレースから内部情報が漏洩すると、攻撃の糸口となる。

**チェック項目**:

1. **スタックトレースの露出**:
   ```typescript
   // ❌ 本番環境でスタックトレースを返す
   app.use((err, req, res, next) => {
     res.status(500).json({ error: err.stack });
   });

   // ✅ 一般的なエラーメッセージ
   app.use((err, req, res, next) => {
     logger.error(err);  // サーバー側でログ
     res.status(500).json({ error: 'Internal Server Error' });
   });
   ```

2. **ユーザー列挙攻撃**:
   ```typescript
   // ❌ ユーザーの存在が推測可能
   if (!user) return res.status(404).send('User not found');
   if (!user.checkPassword(password)) return res.status(401).send('Wrong password');

   // ✅ 同じエラーメッセージ
   if (!user || !user.checkPassword(password)) {
     return res.status(401).send('Invalid credentials');
   }
   ```

3. **デバッグ機能の無効化**:
   - 本番環境でデバッグエンドポイントが有効になっていないか

**判定**: 情報漏洩の可能性がある場合は**指摘**（Medium）

### ステップ6: その他のセキュリティベストプラクティス（低優先度）

**チェック項目**:

1. **CSRF対策**:
   - 状態変更を伴うリクエストにCSRFトークンがあるか

2. **CORS設定**:
   - `Access-Control-Allow-Origin: *` を使っていないか

3. **セキュリティヘッダ**:
   - CSP、X-Frame-Options、HSTS等が設定されているか

4. **依存関係の脆弱性**:
   - 既知の脆弱性があるライブラリを使っていないか

**判定**: ベストプラクティス違反は**指摘**（Low〜Medium）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

### 1. インジェクション

- [ ] SQL クエリにユーザー入力を文字列結合で埋め込んでいないか（パラメータ化クエリを使う）
- [ ] HTML 出力でユーザー入力をエスケープしているか（XSS 対策）
- [ ] OS コマンド実行にユーザー入力を渡していないか（コマンドインジェクション）
- [ ] LDAP、XPath、NoSQL 等のクエリでも同様の注意を払っているか
- [ ] テンプレートエンジンでユーザー入力が式として評価されないか（SSTI）

### 2. 認証・認可

- [ ] 認証チェックが漏れているエンドポイントはないか
- [ ] 認可チェックがリソース単位で行われているか（IDOR: 他人のリソースにアクセスできないか）
- [ ] 権限昇格の抜け道がないか（ロールチェックの漏れ）
- [ ] セッション管理は安全か（トークンの有効期限、ローテーション、無効化）

### 3. データ保護

- [ ] パスワード、トークン、API キーがソースコードやログにハードコードされていないか
- [ ] 機密データがログに出力されていないか
- [ ] 個人情報が不必要にレスポンスに含まれていないか（最小限の情報のみ返す）
- [ ] 暗号化が必要なデータが平文で保存・通信されていないか
- [ ] パスワードのハッシュ化に安全なアルゴリズム（bcrypt, argon2 等）を使っているか

### 4. 入力の検証とサニタイズ

- [ ] すべての外部入力（リクエストパラメータ、ヘッダ、ファイルアップロード等）が検証されているか
- [ ] ホワイトリスト方式で検証しているか（ブラックリストは漏れやすい）
- [ ] ファイルアップロードで拡張子・MIME タイプ・サイズを検証しているか
- [ ] リダイレクト先 URL がオープンリダイレクトにならないか

### 5. エラー処理と情報漏洩

- [ ] エラーレスポンスにスタックトレースや内部情報が含まれていないか
- [ ] デバッグ用のエンドポイントや機能が本番で無効化されているか
- [ ] エラーメッセージから認証情報の有無が推測できないか（ユーザー列挙攻撃）

### 6. 依存関係

- [ ] 既知の脆弱性がある依存ライブラリを使っていないか
- [ ] 依存ライブラリのバージョンが古すぎないか
- [ ] 不必要に広い権限を持つライブラリを使っていないか

### 7. CSRF / CORS / セキュリティヘッダ

- [ ] 状態変更を伴うリクエストに CSRF トークンが含まれているか
- [ ] CORS の設定が必要以上に緩くないか（`Access-Control-Allow-Origin: *`）
- [ ] セキュリティ関連のレスポンスヘッダが設定されているか

## 指摘の出し方

### 指摘の構造

```
【問題点】このコードは○○のセキュリティ脆弱性があります
【理由】△△だからです
【影響】この脆弱性により××の攻撃が可能になります
【提案】□□に修正すると安全になります
【トレードオフ】ただし、◇◇の考慮も必要です
```

### 指摘の例

#### SQLインジェクションの指摘

```
【問題点】ユーザー入力を文字列結合でSQLクエリに埋め込んでいます
【理由】`userId`パラメータが直接SQL文字列に結合されています
【影響】攻撃者が`userId`に`"1 OR 1=1"`のような値を送ると、全ユーザーのデータを取得できます
【提案】以下のようにパラメータ化クエリを使用してください
  ```typescript
  // Before: SQLインジェクション脆弱性
  const query = `SELECT * FROM users WHERE id = ${userId}`;

  // After: パラメータ化クエリ
  const query = `SELECT * FROM users WHERE id = ?`;
  db.execute(query, [userId]);
  ```
【トレードオフ】なし。パラメータ化クエリは必須のセキュリティ対策です
```

#### IDOR（所有権チェック漏れ）の指摘

```
【問題点】他人のリソースへのアクセスを防ぐ所有権チェックがありません
【理由】リクエストされた注文IDの注文をそのまま返しており、認証済みユーザーのIDとの照合がありません
【影響】攻撃者が注文IDを順に試すことで、他のユーザーの注文情報を閲覧できます
【提案】以下のように所有権チェックを追加してください
  ```typescript
  // Before: IDOR脆弱性
  app.get('/api/orders/:id', async (req, res) => {
    const order = await db.getOrder(req.params.id);
    return order;
  });

  // After: 所有権チェック
  app.get('/api/orders/:id', async (req, res) => {
    const order = await db.getOrder(req.params.id);
    if (order.userId !== req.user.id) {
      return res.status(403).send('Forbidden');
    }
    return order;
  });
  ```
【トレードオフ】管理者権限での閲覧が必要な場合は、ロールチェックを別途実装してください
```

#### 機密情報のログ出力の指摘

```
【問題点】ログにパスワードやトークンが平文で出力されています
【理由】ログイン処理でユーザー情報をそのままログ出力しています
【影響】ログを閲覧できる攻撃者（内部犯、ログ管理システムへの侵入者等）がユーザーの認証情報を取得できます
【提案】以下のように機密情報をマスクしてください
  ```typescript
  // Before: 機密情報の平文ログ出力
  console.log('User login:', { email, password });

  // After: 機密情報をマスク
  console.log('User login:', { email, password: '[REDACTED]' });
  ```
【トレードオフ】デバッグが必要な場合は、開発環境のみでマスクを解除する設定を検討してください
```

#### XSS脆弱性の指摘

```
【問題点】ユーザー入力をエスケープせずにHTML出力しています
【理由】`userInput`が直接テンプレート文字列に埋め込まれています
【影響】攻撃者が`<script>alert(document.cookie)</script>`のようなスクリプトを入力すると、他のユーザーのブラウザで実行され、セッショントークン等が盗まれます
【提案】以下のようにエスケープ処理を追加してください
  ```typescript
  // Before: XSS脆弱性
  const html = `<div>${userInput}</div>`;

  // After: エスケープ処理
  const html = `<div>${escapeHtml(userInput)}</div>`;

  // または、React等のフレームワークの自動エスケープを利用
  return <div>{userInput}</div>;
  ```
【トレードオフ】意図的にHTMLを受け入れる必要がある場合は、DOMPurify等のサニタイザーライブラリを使用してください
```

### 指摘の優先度ラベル

- **[Critical]**: インジェクション、認証認可の欠陥、機密データ漏洩（必ず修正すべき）
- **[High]**: 入力検証の欠如、セッション管理の不備（修正を強く推奨）
- **[Medium]**: エラー処理での情報漏洩、CSRF対策の欠如（修正を推奨）
- **[Low]**: セキュリティヘッダの未設定、古い依存ライブラリ（修正を推奨）

### トレードオフの明示

- 修正による影響範囲を明示する
- パフォーマンス、UX、実装コストとのバランスを考慮する
- ただし、セキュリティの問題は nit ではなく、修正必須として扱う

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: SQLインジェクション（Critical指摘）

**コード**:
```typescript
const userId = req.params.id;
const query = `SELECT * FROM users WHERE id = ${userId}`;
const user = await db.execute(query);
```

**期待される指摘**:
- [Critical] SQLインジェクション脆弱性
- ユーザー入力を文字列結合でSQLに埋め込んでいる
- パラメータ化クエリを使うべき

### Case 2: IDOR（Critical指摘）

**コード**:
```typescript
app.get('/api/orders/:id', async (req, res) => {
  const order = await db.getOrder(req.params.id);
  return order;
});
```

**期待される指摘**:
- [Critical] IDOR脆弱性、所有権チェックがない
- 他人の注文情報を閲覧可能
- `order.userId !== req.user.id`チェックを追加すべき

### Case 3: ハードコードされた認証情報（Critical指摘）

**コード**:
```typescript
const API_KEY = "sk_live_abcd1234";
const DB_PASSWORD = "password123";
```

**期待される指摘**:
- [Critical] 機密情報がハードコードされている
- ソースコードに認証情報が平文で記載
- 環境変数（`process.env.API_KEY`等）を使うべき

### Case 4: XSS脆弱性（Critical指摘）

**コード**:
```typescript
const userInput = req.query.name;
const html = `<div>Hello, ${userInput}!</div>`;
res.send(html);
```

**期待される指摘**:
- [Critical] XSS脆弱性
- ユーザー入力を直接HTML出力
- エスケープ処理（`escapeHtml(userInput)`）を追加すべき

### Case 5: 情報漏洩（Medium指摘）

**コード**:
```typescript
app.use((err, req, res, next) => {
  res.status(500).json({ error: err.stack });
});
```

**期待される指摘**:
- [Medium] スタックトレースを本番環境で公開している
- 内部情報が攻撃の糸口となる
- 一般的なエラーメッセージに変更すべき

### Case 6: 許容されるケース（指摘なし）

**コード**:
```typescript
const query = `SELECT * FROM users WHERE id = ?`;
const user = await db.execute(query, [userId]);
```

**期待される判断**:
- パラメータ化クエリを使用している
- SQLインジェクション対策が適切
- 指摘なし
