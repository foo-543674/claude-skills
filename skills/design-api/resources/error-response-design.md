# エラーレスポンスの設計

エラーレスポンスは **常に複数エラーを表現できる構造** にする。単一エラー形式で設計すると、バリデーション時に fail-fast になり、ユーザー体験が劣化する。

## Why: 複数エラー返却が必須である理由

単一エラー形式 (`{ "error": "code", "message": "..." }`) で設計すると、バリデーションが fail-fast を強制され、以下のような drip-feed UX を招く。

**例**: `name` が「長さ 10 文字以内」かつ「記号はハイフンとアンダーバーのみ」という制約のとき、`foo(testname)` という入力:

1. ユーザーが `foo(testname)` を送信
2. サーバーが **長さ違反だけ** 返す
3. ユーザーが長さを直して再送
4. 今度は **文字種違反** が返る
5. ユーザーが何回も submit することになる

これは単に不便なだけでなく、ユーザーが「このフォームは全部直したはずなのにまた弾かれた」と感じる不信感を生む。

## 設計ルール

### ルール 1: エラー構造は常に配列ベース

```json
// ❌ NG: 単一エラー形式
{
  "error": {
    "code": "too_long",
    "message": "name must be at most 10 characters"
  }
}

// ✅ OK: 配列ベース。主語は `field` にあり、`code` は制約種別だけを表す
{
  "errors": [
    {
      "code": "too_long",
      "field": "name",
      "message": "name must be at most 10 characters"
    },
    {
      "code": "invalid_charset",
      "field": "name",
      "message": "name must only contain letters, digits, '-', '_'"
    }
  ]
}
```

エラーが 1 件のときも `errors: [...]` 配列で返す。配列にしておけば将来複数エラーを返したくなっても破壊的変更にならない。

### ルール 2: バリデーションは fail-fast しない

- 1 つのフィールドの複数制約違反はすべて 1 レスポンスで返す
- 複数フィールドの同時違反もすべて 1 レスポンスで返す
- バックエンド側の `Validator` は `Result<T, Vec<Error>>` のような **収集型** を返すようにアーキテクチャレベルで契約を定める (単数 `Result<T, Error>` だと fail-fast を強制してしまう)

### ルール 3: 1 フィールドの複数制約は個別エラーコードに分解する

```
✅ too_long       (制約種別)
✅ invalid_charset
❌ invalid        (何が悪いか分からない)
```

フロントが各制約を個別にハイライト表示できるよう、エラーコードは **制約の種別ごとに** 分ける。

### ルール 3 の補足: `code` にフィールド名を埋めない

- ❌ `name_too_long`, `description_too_long` (フィールド名を code に埋める)
- ✅ `too_long` + `field: "name"` / `field: "description"`

**理由**: エラーの主語は `field` 属性にある。`code` にフィールド名を埋め込むと:

1. **情報重複**: `field: "name"` と `code: "name_too_long"` で同じ情報を 2 回持つ
2. **クライアント側の分岐爆発**: クライアントが制約種別ごとにメッセージを出したいだけなのに、`name_too_long` / `description_too_long` / `title_too_long` … を個別に分岐する羽目になる。`code === "too_long"` で一箇所にまとめられるべき
3. **フィールド追加時の破壊的変更**: 新しいフィールドが増えるたびに新しいエラーコードが増え、クライアントのコード体系が肥大化する

`code` は **何の制約に違反したか** だけを表現し、**どのフィールドで違反したか** は `field` に任せる。

### ルール 4: エラー構造の統一

- プロジェクト全体で同じ構造 (`errors: [{ code, field?, message, details? }]`)
- エンドポイントごとに形を変えない
- クライアントがプログラム的に判別可能なコード体系

### ルール 5: 内部実装の漏出防止

- スタックトレース、SQL エラー、ORM のエラーコード (Prisma の `P2002` 等) を `message` や `code` に出さない
- エラーコードは API 独自の語彙で定義する

  - ❌ `{ "code": "P2002", "message": "Unique constraint failed" }`
  - ✅ `{ "code": "email_already_exists", "message": "..." }`

## バックエンド実装との契約

`Validator` が単一の `Result<T, Error>` を返す設計だと、呼び出し側が fail-fast にならざるを得ない。エラー収集を API 契約として守るには、アーキテクチャ層で以下のいずれかを強制する:

- `Validator::validate(input) -> Result<T, Vec<Error>>` (Rust 的)
- `Validator.validate(input): ValidationResult<T>` (成功/複数エラーを表現する専用型)
- Applicative-style validation (`zip`/`combine` で複数エラーを収集)

この契約は `design-architecture` で決め、`design-api` ではレスポンス形状としての配列化を必須にする。

## HTTP ステータスとの関係

複数エラーを 1 レスポンスで返す場合でも、HTTP ステータスは 1 つしか返せない。原則として:

- すべてのエラーがドメインバリデーション → `400 Bad Request`
- 認証と認可のエラーが混ざることは通常ない (401 は認証段階で単独で返る)

ステータスコードの詳細は `http-status-semantics.md` を参照。
