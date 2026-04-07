# フロントエンドコンポーネントの 4 区分

UI コンポーネントは責務を 4 区分に分けて配置・命名する。曖昧な「View」「Component」のひと括りで済ませない。

前提として `../../design-architecture/resources/principles.md` の語彙定義義務と逃げの禁止を適用する。

## 1. 4 区分の定義

各区分は「動詞 + 目的語」で 1 文定義できる責務を持つ。

### 1.1 Page Component

**1 文定義**: ルート (URL) に 1 対 1 対応し、URL パラメータの受け取り・レイアウトの組み立て・必要な Container の配置とインフラ抽象の引き渡しを行う。

- **持つもの**: URL パラメータ・クエリパラメータの受け取り、レイアウトの組み立て、Container の配置、`InfraContext` から取得した抽象の Props 引き渡し
- **持たないもの**: データ取得そのもの (Container に委ねる)、ドメインロジック、フォーム状態
- **配置**: `src/routes/`
- **テスト**: 書かない。実 HTTP 経路は API 統合テストで担保する

### 1.2 Container Component

**1 文定義**: feature ごとのリアクティブ状態 (サーバー状態 + 画面状態) を組み立て、それらの値とコールバックを Domain Presentational に Props としてばらして渡す。

- **持つもの**: サーバー状態リアクティブ単位 (queries / mutations) と画面状態リアクティブ単位 (state) の組み立て、mutation の `onSuccess` での `invalidateQueries` 等の繋ぎ込み
- **持たないもの**: 描画ロジック、ドメインルール、複雑な計算、**自分自身の状態** (フレームワークの状態管理プリミティブを Container 内で直接呼ばない。状態が要るなら `state/` に切り出す)、`useContext` の直接呼び出し (Page から Props で受け取る)
- **配置**: `src/features/<feature>/containers/`
- **テスト**: 書かない。ロジックがない薄いグルーなのでモック検証になるだけ。書きたくなったらロジックがある証拠なので `lib/` か state 側に切り出す

### 1.3 Domain Presentational Component

**1 文定義**: feature 固有の意味のあるブロック (フォーム全体、リスト全体、ツリー表示等) を、Props で受け取った値だけで描画する。

- **持つもの**: Props の受け取りと JSX の構築、複数の Generic Presentational の組み合わせ
- **持たないもの**: API 呼び出し、グローバル状態への直接アクセス、非同期処理、**JavaScript で扱うローカルな状態** (フレームワークの状態管理プリミティブを含む)。開閉・選択中・フォーム入力値のような構造的な画面状態はすべて Props で外から受け取る (fully controlled)
- **CSS 擬似クラスで表現できる視覚状態 (`:hover` / `:focus` / `:active` / `:disabled` / `:checked` 等) は CSS 側で書く** (詳細は `state-policy.md` 参照)
- **配置**: `src/features/<feature>/components/`
- **テスト**: Storybook でカタログ化 + VRT (Chromatic 等)。Props のバリエーション (空状態、ロード中、エラー、複数行データ等) を Story として並べ、視覚差分でレビューする

### 1.4 Generic Presentational Component

**1 文定義**: feature やドメイン語彙に依存しない汎用 UI 原子を、Props で受け取った値だけで描画する。

- **持つもの**: Props の受け取りと JSX の構築。テーマ適用
- **持たないもの**: feature への参照、ドメイン用語、状態保有
- **配置**: `src/components/`
- **例**: Button, Modal, TextField, Select, Card, Spinner
- **テスト**: Storybook でカタログ化 + VRT

## 2. 区分間の依存方向

```
Page (routes/)
   └─ Container (features/<f>/containers/)
        └─ Domain Presentational (features/<f>/components/)
             └─ Generic Presentational (components/)
```

- 上から下への一方向のみ
- Domain Presentational から Generic Presentational への参照は OK
- **Generic Presentational が `features/` を参照するのは禁止** (依存方向の逆転)
- **Domain Presentational が直接 `createXxxQuery` などを呼ぶのも禁止** (データ取得を抱え込んだら Container に分離する)

## 3. インフラ抽象の引き渡し (Page → Container Props)

フロント側にも「ブラウザというインフラを使わなければ実現できない」関心事がある (現在時刻、LocalStorage、URL ナビゲーション等)。これらを直接コンポーネント内で呼ぶと、テスト・Storybook で差し替えられなくなる。

### 配置と生成

```
src/lib/infra/
├── clock.ts              # Clock 型 + 実ブラウザ実装
├── local-storage.ts      # LocalStorageStore 型 + 実装
├── ...
└── context.tsx           # InfraContext + Provider + 取り出し用フック
```

- `lib/infra/<thing>.ts`: 抽象型と実装を定義
- `lib/infra/context.tsx`: フレームワークの Context 機能で `InfraContext` を定義し、取り出し用フックも併設
- `App.tsx` (またはエントリポイント): 実ブラウザ向け具象を生成して `InfraContext.Provider` でアプリ全体をラップする。テスト・Storybook ではフェイクを差し替える

### Page 経由での Container への引き渡し

Page Component は `useContext(InfraContext)` で抽象を取り出し、必要なものを Container に **Props として明示的に渡す**。Container 自身が `useContext` を直接呼ぶことは禁止する。理由:

- Container のテスト時にコンテキスト依存が透けない方が、薄いグルーである Container の差し替えやすさが保てる
- Storybook での Container Story が Provider セットアップなしで動く

```
// routes/sessions/[id].tsx (Page)
function SessionEditorPage() {
    const { clock } = useInfraContext()
    const params = useParams()
    return <SessionEditorContainer sessionId={params.id} clock={clock} />
}

// features/sessions/containers/session-editor-container.tsx (Container)
type Props = { sessionId: string; clock: Clock }
function SessionEditorContainer(props: Props) {
    // useContext は呼ばない。clock は Props で来る
    ...
}
```

### 区分ごとの責務 (インフラ抽象まわり)

| 区分 | インフラ抽象との関わり |
|---|---|
| エントリポイント | 実ブラウザ向け具象を生成し Provider で配る |
| Page | useContext で抽象を取り出し、必要なものだけ Container に Props で渡す |
| Container | Props で受け取って使う。useContext は呼ばない |
| Domain Presentational | インフラ抽象に触れない。必要な値は Container から Props で来る |
| Generic Presentational | 同上 |

## 4. 「コンポーネントテストで API モックが必要」になったら設計のサイン

それは Container と Presentational の区分けが甘いサイン。Presentational が API を直接呼んでいないか確認し、呼んでいたら Container に切り出す。

Presentational は Storybook で Props のバリエーションを描画できればテスト目的を果たすので、API モックライブラリ (MSW 等) は要らない。

「とりあえず MSW でモックして Testing Library で叩く」は React 由来の慣習を雑に持ち込んでいるだけで、4 区分が守られていれば不要 (逃げ E に該当)。

## 5. ファイル命名と 1 ファイル 1 リアクティブ単位

`features/<f>/` の中は以下のように分割する:

```
features/<feature>/
├── queries/       # サーバー状態リード (1 ファイル 1 リアクティブ単位)
│   └── <noun>.ts
├── mutations/     # サーバー状態ライト (1 ファイル 1 リアクティブ単位)
│   └── <verb>-<noun>.ts
├── state/         # 画面状態 (1 ファイル 1 リアクティブ単位)
│   └── <noun>.ts
├── keys.ts        # クエリキー定義
├── containers/
└── components/    # Domain Presentational
```

**1 ファイル 1 リアクティブ単位のルール**:

- `queries/<noun>.ts` はクエリリアクティブ単位を 1 つだけエクスポートする
- `mutations/<verb>-<noun>.ts` はミューテーションリアクティブ単位を 1 つだけエクスポートする
- `state/<noun>.ts` は画面状態リアクティブ単位を 1 つだけエクスポートする
- 1 ファイル内で複数定義したくなったら、それは責務が複数あるサイン
- `api.ts` のような全部入りファイルは禁止 (肥大化する)

**命名規約**: フレームワークの慣習に従う。

| フレームワーク | リアクティブプリミティブ | 慣習プレフィックス |
|---|---|---|
| React | Hooks | `use` (例: `useExerciseListQuery`) |
| SolidJS | Signal / Resource | `create` (例: `createExerciseListQuery`) |
| Vue | Composables | `use` (例: `useExerciseList`) |

クエリキーは各ファイルにベタ書きせず `features/<feature>/keys.ts` に集約する。`invalidateQueries` のときに参照しやすく、キーの重複・齟齬を防げる。
