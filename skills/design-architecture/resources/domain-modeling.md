# ドメインモデリング: 営みの起源と責務の置き場所

ドメイン層 (domain) に何を置いて何を置かないかの判断、ドメインロジックの置き場所の優先順位、集約生成フロー、外部事実の渡し方を定義する。

前提として `principles.md` の語彙定義義務と逃げの禁止を必ず適用する。

## 1. 営みの起源によるレイヤーの定義

レイヤーを「Clean Architecture だから」「DDD だから」のような既成の枠組みで決めない。代わりに、各レイヤーが扱う関心事の **起源** で分ける。

### domain (ドメイン層)

**定義**: 「アプリケーションになる前から、現実でその営みをする上で必要だったロジック」を表現する場所。

例: 在庫管理アプリなら「在庫とは何か」「入庫・出庫とは何か」は紙の帳簿で管理していた頃から存在した概念。これらが domain に入る。永続化やログは domain に入らない (紙の帳簿には DB ドライバも構造化ログもない)。

### application (アプリケーション層)

**定義**: 「現実の営みをアプリケーションにしたときに初めて発生する文脈・ロジック」を引き受ける場所。

例: 永続化、トランザクション境界、構造化ログ、トレース、メトリクス、ユースケースレベルの認可、レート制限、入出力 DTO の詰め替え。いずれも紙の帳簿では存在しなかったが、ソフトウェアにしたから必要になった関心事。

詳細は `application-layer.md` を参照。

### infrastructure (インフラ層)

**定義**: domain と application が「外界に求める能力」(ポート) の具体実装を提供する場所。DB ドライバ、ハッシュアルゴリズムの実装、システムクロックなど。

### interfaces (インターフェース層)

**定義**: 外部プロトコル (HTTP, gRPC, CLI) との境界。リクエスト/レスポンスの DTO 変換と、認証・レート制限などのプロトコル固有のミドルウェア。

### この区分による帰結

#### 帰結 1: リポジトリは domain ではなく application に置く

「永続化」は紙の帳簿の時代には存在しなかった。アプリにしたから初めて必要になった営み。したがって永続化のためのポート (Repository インターフェース) は application 層に住む。domain は永続化を知らない。

「Clean Architecture の典型図ではリポジトリインターフェースは domain」と無批判に当てはめてはいけない。それは Clean Architecture の典型例を雑に持ち込んだ結果であり、レイヤーの起源で考えると整合しない。

#### 帰結 2: Clock や PasswordHasher のような「現実の概念のポート」は domain に置く

時刻 (Clock) は紙の帳簿の時代から存在した概念 (時計を見て記録した)。秘密の変換 (PasswordHasher) も「合言葉を記号に変換する」という現実の営みとして表現できる。

これらは「現実に存在する概念」なので domain にインターフェースを置く。実装は infrastructure (システム時刻を OS から取る、ハッシュ関数を呼ぶ) が提供する。

#### 帰結 3: infrastructure は domain にも依存する

Clock の実装をするなら domain の `Clock` インターフェースを実装する必要があるので、infrastructure は domain にも依存する。「インフラ層は domain を知らない」という典型図はここでも成立しない。

### ポート配置の原則

| ポートの性質 | 配置場所 | 例 |
|---|---|---|
| 現実に存在する概念 | domain | Clock, PasswordHasher, RandomNumberGenerator |
| アプリの営み (永続化、認可、ログ等) | application | Repository, SessionStore, AuditLogSink |

判断に迷ったら自問する: 「このポートが表す概念は、紙の帳簿の時代から存在したか?」

## 2. ドメインロジックの置き場所の優先順位

ドメイン層の中で、ロジックをどこに置くかを以下の優先順位で判断する。**上から検討し、上のレベルで表現できないときだけ下に降りる**。

### 優先度 1: 値オブジェクト

**置く対象**: 単一の値が満たすべき制約。

**構造**:
- `Type::tryNew(raw)` または `Type::parse(raw)` が「値オブジェクト or エラー」を返す (Result/Either 型)
- 一度作られた値オブジェクトは常に妥当 (型がそれを保証する)
- コンストラクタで例外を投げない (逃げ F: 例外による検証エラー表現の禁止)

**例**: ユーザー ID の文字種・予約語チェック、数量の範囲検証、メールアドレスの形式検証、日付の未来日禁止 (「今日」を引数で渡して純粋関数化)

### 優先度 2: 集約 / エンティティのメソッド

**置く対象**: 既存集約の状態に対する単純な操作。

**構造**:
- 集約のメソッドが Result/Either 型を返す
- 必要な外部事実 (別集約のスナップショット、bool フラグ等) は呼び出し側が事前ロードして引数で渡す
- メソッドは「与えられた事実を前提に自分を更新する/拒否する」ことに集中する

**例**: `Session::end(now)` で `started_at <= now` を検証して状態遷移する、`Note::edit(newText)` で文字数検証して更新する。

### 優先度 3: Input → Validator → Validated → Factory の型付きパイプライン

**置く対象**: 集約の生成、または複雑なミューテーション (多フィールド入力 + 外部事実が絡むもの)。

**構造**: 次節「集約生成の 4 役割」参照。

### 優先度 4: ドメインワークフロー

**置く対象**: 上記のいずれにも収まらず、本当に複数集約にまたがる不可分なドメイン判断が発生した場合のみ。

**条件**:
- `〜Workflow` という名前で **1 ワークフロー 1 目的** に閉じる
- ワークフロー名が「動詞 + 目的語」で 1 文定義できることを必須にする (語彙定義義務)
- それでも漠然と何でも入れたくなったら、それは複数の責務が混ざっている証拠なので分ける

**典型的な誤用**: 「思いつかないからワークフローに入れておく」(逃げ A)。優先度 1-3 で表現できないか徹底的に検討してから、最後の手段としてのみ使う。多くのプロジェクトではワークフローが必要なケースは存在しない。

### よくある誤りと対策

| 誤り | なぜ駄目か | 対策 |
|---|---|---|
| 「ドメインサービス」を最初に作る | 語彙定義義務違反。何でも吸い込む箱になる | 値オブジェクト・集約メソッド・Validator/Factory パイプラインで表現できないか先に検討する |
| 集約を貧血エンティティ (getter/setter のみ) にする | 不変条件を守る責務がどこにもなくなる | 不変条件の検証と状態遷移を集約メソッドに置く |
| インスタンス化時に例外を投げる | エラー処理が言語の例外機構に依存し、型レベルで「未検証」を表現できなくなる | コンストラクタは Result/Either を返す `tryNew` / `parse` 形式にする |

## 3. 集約生成の 4 役割 (型付きパイプライン)

集約の生成は、常に以下 4 つの役割を経由させる。役割を分けることで、未検証データから集約が作られる経路を型システムレベルで遮断する。

### 4 役割

1. **入力型 (Input)**
   - 素の外部データを表す構造体
   - フィールドは公開 (誰でも作れる)
   - 検証ロジックを持たない

2. **Validator**
   - 入力 + 必要な外部事実を受け取り、Result/Either 型 (`Result<Validated, DomainError>`) を返す
   - 値オブジェクトの構築、外部事実との整合性検証をここに集約する

3. **検証済み入力型 (Validated)**
   - 内部フィールドの可視性を絞り (パッケージ private / `internal` / `pub(crate)` 等)、Validator を通らないと作れない構造体
   - 「この型のインスタンスが存在する = 検証済み」を型レベルで保証する

4. **Factory**
   - 検証済み入力型を受け取り、集約を生成する **失敗しない** 関数
   - ID 採番・初期状態設定・タイムスタンプ付与など
   - Result/Either を返さない (型レベルで妥当性が保証されているため)

### 擬似コード (言語非依存)

```
// 1. 入力型: 素のデータ。誰でも作れる
struct CreateExerciseInput {
    name: String
    measurementKinds: List<RawKind>
    parentId: Optional<String>
}

// 2. Validator: 入力 + 外部事実 → 検証済み入力 or エラー
class CreateExerciseValidator {
    static validate(
        input: CreateExerciseInput,
        owner: UserId,
        nameTaken: Boolean,         // 外部事実: 同名種目の存在
        parent: Optional<Exercise>  // 外部事実: 親種目のスナップショット
    ): Result<ValidatedCreateExerciseInput, DomainError> {
        val name = ExerciseName.tryNew(input.name)?
        if (nameTaken) return Err(DomainError.NameConflict)
        val kinds = MeasurementKindSet.tryNew(input.measurementKinds)?
        // 親の妥当性検証など
        return Ok(ValidatedCreateExerciseInput(owner, name, kinds, parent?.id))
    }
}

// 3. 検証済み入力型: フィールドはパッケージ内のみ公開 (外からは作れない)
struct ValidatedCreateExerciseInput {
    package owner: UserId
    package name: ExerciseName
    package kinds: MeasurementKindSet
    package parentId: Optional<ExerciseId>
}

// 4. Factory: 検証済み入力 → 集約。失敗しない (Result/Either を返さない)
class ExerciseFactory {
    static create(
        validated: ValidatedCreateExerciseInput,
        id: ExerciseId,
        now: Timestamp
    ): Exercise {
        return Exercise(
            id = id,
            owner = validated.owner,
            name = validated.name,
            kinds = validated.kinds,
            parentId = validated.parentId,
            createdAt = now
        )
    }
}
```

### 既存集約のミューテーションへの適用

複雑なミューテーション (多フィールド入力 + 外部事実) も同じパターン:

- `ChangeXxxInput` → `ChangeXxxValidator.validate(input, externalFacts)` → `ValidatedChangeXxx` → `Aggregate.applyChangeXxx(validated)` (infallible)

集約側の `applyXxx` は型レベルで妥当性が保証された入力しか受け取らないので失敗せず、Result/Either を返さない。ロジックは「内部状態を更新する」だけ。これによって集約は貧血にならず、不変条件を守る責務を保ちつつ、入力検証ロジックは Validator に切り出される。

### Validator/Factory が不要な単純ケース

単一値ミューテーション (例: `Note::edit(newText)`) は、値オブジェクト 1 つで十分なので Validator/Factory は要らない。集約メソッドが直接 Result/Either を返す。

**判断基準**: 「外部事実が必要か」「複数フィールドの整合が必要か」のいずれかが Yes なら Validator/Factory パイプラインを使う。

## 4. 外部事実の渡し方 (3 形式)

Validator は domain の住人なので、リポジトリやデータベースを知らない。必要な外部事実は **application 層から引数で受け取る**。形は以下の 3 つから選ぶ。

「常にプレーンな値で渡す」を既定にしない — データ量が増えたときに全件ロードを強制してしまうため (逃げ B / D に近い退化が発生する)。

### 形 A: プレーンな値 (事前に集約された結論)

application が DB に「結論だけを問い合わせるクエリ」を投げて、その結果を Boolean / Integer / 小さな構造体として渡す。

**使うべき条件**: 結論の集約コストが O(1) 〜 O(log n) で済み、その値を取るために大量のレコードを読まない場合。

| 例 | application 側のクエリ | Validator の引数 |
|---|---|---|
| 名前の重複 | `SELECT EXISTS(... WHERE owner=? AND name=?)` | `nameTaken: Boolean` |
| 子要素の数 | `SELECT COUNT(*) WHERE parent_id=?` | `childCount: Integer` |
| 親エンティティ | `SELECT * WHERE id=? AND owner=?` | `parent: Optional<Parent>` |

### 形 B: ドメインの語彙で表したコレクション抽象

「ある種類の集合に対して問い合わせる」こと自体がドメインの営みになってきたら、`Ledger` / `History` のような **現実の営みを表す言葉** で domain にインターフェースを切る。

**「リポジトリ」とは呼ばない** — リポジトリは application の語彙 (永続化のポート) であり、domain の語彙ではない。domain のコレクション抽象は現実の営みの言葉 (帳簿、履歴、台帳など) で命名する。命名が「動詞 + 目的語」で 1 文定義できることを必須にする (語彙定義義務)。

```
// domain: 「種目台帳」という現実の語彙で表現したコレクション抽象
// 定義: 「種目の親子関係を引いたり、ある種目に紐づく子種目の数を数えたりする」
interface ExerciseLedger {
    fun ancestorsOf(id: ExerciseId): List<Exercise>
    fun countChildrenOf(id: ExerciseId): Integer
}

class ReparentExerciseValidator {
    static validate(
        input: ReparentExerciseInput,
        ledger: ExerciseLedger
    ): Result<ValidatedReparent, DomainError> {
        // 必要なときだけ ledger を引いて検証する
    }
}
```

**使うべき条件**:
- Validator のロジックが「最大何件読むか」を事前に決められず、入力に応じて読む量が変わる
- 「コレクションに対する問い合わせ」自体がドメインの語彙として自然
- インターフェース名を「動詞 + 目的語」で 1 文定義できる

### 形 C: 高階関数 (取得関数)

最小単位の取得関数を関数型として引数に受け取る。コレクション抽象を切るほどではないが、Validator が **遅延的に / 条件付きで** データを読みたいときに使う。

```
class ReparentExerciseValidator {
    static validate(
        input: ReparentExerciseInput,
        loadParent: (ExerciseId) -> Optional<Exercise>
    ): Result<ValidatedReparent, DomainError> {
        // loadParent をたどって祖先列を構築し、循環・深さを検証する。
        // 循環が早期に検出できればその時点で打ち切れる
    }
}
```

**使うべき条件**:
- 形 A の事前集約だと「最悪ケースの全件ロード」を強制してしまう
- 形 B のコレクション抽象を切るほど概念として独立していない
- 取得が「必要な分だけ」「短絡評価したい」場合 (例: 循環検出は最初のヒットで終わる)

### 判断フロー

```
1. application 側で O(1)〜O(log n) のクエリで結論を出せるか?
     Yes → 形 A (プレーンな値)
     No  ↓

2. その「集合への問い合わせ」がドメインの語彙として独立しているか?
   (= 「動詞 + 目的語」で 1 文定義できる名前を付けられるか?)
     Yes → 形 B (ドメイン語彙のコレクション抽象)
     No  ↓

3. → 形 C (高階関数で取得関数を渡す)
```

domain は決して「データを取りに行くコード」を直接持たないが、**いつ何を取るか** はドメインのロジックに委ねられる、というのが形 B / C の意義。
