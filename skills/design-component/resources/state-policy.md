# フロントエンドの状態管理ポリシー

JavaScript で扱う状態の置き場所、コンポーネントが状態を持たない原則、CSS に任せるべき状態の判断を定義する。

前提として `../../design-architecture/resources/principles.md` の語彙定義義務と逃げの禁止を適用する。

## 1. 原則: コンポーネントは状態を持たない (fully controlled)

**JavaScript で扱う状態はすべてリアクティブ単位 (シグナル / Hook / Composable / Store 等) に住む。コンポーネントは JavaScript の状態を一切持たず、Props 経由で受け取った値と Props 経由で受け取ったコールバックだけで動作する (fully controlled component)。**

### なぜ必要か

- **Storybook で全カタログ化できる**: `useState` / `createSignal` をコンポーネント内で呼ぶと、開閉等のバリエーションを Storybook で Props 制御できなくなり、バリエーションを Story に並べて VRT する戦略が破綻する
- **テストの境界が明確になる**: 状態のリアクティブ挙動はリアクティブ単位の単体テストで、描画の正しさは Storybook + VRT で、と分担できる
- **状態管理ロジックの再利用**: 状態管理ロジックを `state/` に切り出せば、別のコンポーネントから再利用できる

### 適用範囲

Domain Presentational / Generic Presentational の両方に適用する。Container にも適用する (Container 内でリアクティブプリミティブを直接呼ばない。`state/` のリアクティブ単位を呼ぶだけにする)。

## 2. 例外: CSS の擬似クラスで表現できる視覚状態は CSS に任せる

`:hover` / `:focus` / `:focus-within` / `:active` / `:disabled` / `:checked` / `:placeholder-shown` などで表現できる見た目変化は、JavaScript リアクティブ単位に持ち上げない。

### なぜか

- ブラウザ DevTools の擬似クラス強制機能でエミュレートできる
- Storybook の擬似クラス操作プラグイン (`@storybook/addon-pseudo-states` 相当) で Story から擬似クラスを切り替えられる
- JS 経由で持ち上げると DevTools / アドオンの恩恵を捨てることになり、CSS と JS の二重管理にもなる

### 例: ボタンのホバー時色変化

❌ JS で表現:
```
function Button(props) {
    const [hovered, setHovered] = createSignal(false)
    return (
        <button
            onMouseEnter={() => setHovered(true)}
            onMouseLeave={() => setHovered(false)}
            style={{ background: hovered() ? "blue" : "gray" }}
        >
            {props.children}
        </button>
    )
}
```

✅ CSS で表現:
```css
.button { background: gray; }
.button:hover { background: blue; }
```

```
function Button(props) {
    return <button class="button">{props.children}</button>
}
```

## 3. 何をリアクティブ単位に上げ、何を CSS に任せるか

| 種類 | 例 | 配置 |
|---|---|---|
| サーバー側の真実 | リソース取得結果 | `features/<f>/queries/` |
| サーバーへの書き込み | 作成・更新・削除 | `features/<f>/mutations/` |
| 画面状態のうち **構造や条件分岐を変えるもの** | モーダル開閉、選択中の ID、フォーム入力値、現在のステップ、エラー表示中か | `features/<f>/state/` |
| 永続化が必要な画面状態 | テーマ、最後に使った種別 ID、ドラフト | `features/<f>/state/` (LocalStorage 経由) |
| **CSS 擬似クラスで表現できる視覚状態** | `:hover` ハイライト、`:focus` リング、`:active` 押下、`:disabled` グレーアウト、`:checked` チェック | **リアクティブ単位にしない**。CSS 擬似クラスバリアントで書く |
| クロスカット状態 | ログイン中ユーザー | `features/<auth>/queries/` (キャッシュ共有) |
| ルーティング | URL | ルーティングライブラリ |
| 現在時刻・タイムゾーン | Clock | `lib/infra/clock.ts` (Provider 経由) |

## 4. 判断フロー: リアクティブ単位 vs CSS

```
その状態を切り替えると…
  ├─ レンダリングされる要素そのものが変わる → リアクティブ単位
  ├─ 別のリクエストが必要になる              → リアクティブ単位 (query/mutation)
  ├─ 永続化したい                            → リアクティブ単位 (LocalStorage 経由)
  ├─ 同じ要素の見た目だけが変わる
  │     ├─ CSS 擬似クラスで表現できる        → CSS に任せる
  │     └─ できない (例: 「3 秒後に消える通知バー」など) → リアクティブ単位
```

## 5. Container と画面状態リアクティブ単位の関係

Container は `features/<f>/state/` のリアクティブ単位を呼び出して状態と更新関数を取得し、Domain Presentational に Props としてばらして渡す。

```
// features/exercises/state/exercise-picker.ts
// 1 ファイル 1 リアクティブ単位
export function createExercisePickerState() {
    const [open, setOpen] = createSignal(false)
    const [selectedId, setSelectedId] = createSignal<string | null>(null)
    return {
        open,
        selectedId,
        openPicker: () => setOpen(true),
        closePicker: () => setOpen(false),
        select: (id: string) => setSelectedId(id),
    }
}

// features/exercises/containers/exercise-picker-container.tsx
function ExercisePickerContainer(props: Props) {
    const picker = createExercisePickerState()
    const exercises = createExerciseListQuery()
    return (
        <ExercisePickerModal
            open={picker.open()}
            selectedId={picker.selectedId()}
            exercises={exercises.data}
            onOpen={picker.openPicker}
            onClose={picker.closePicker}
            onSelect={picker.select}
        />
    )
}

// features/exercises/components/exercise-picker-modal.tsx
// fully controlled。状態を一切持たない
type Props = {
    open: boolean
    selectedId: string | null
    exercises: Exercise[]
    onOpen: () => void
    onClose: () => void
    onSelect: (id: string) => void
}
function ExercisePickerModal(props: Props) {
    // createSignal / useState を呼ばない。Props だけで描画する
    return (...)
}
```

これにより `ExercisePickerModal` は Storybook で `open: true/false`、`selectedId: null/'a'/'b'`、`exercises: []/['短い']/['長いリスト']` のバリエーションを Story として並べられる。VRT でデザインの差分をレビューできる。

## 6. テスト対象としての各リアクティブ単位

| 対象 | テスト方法 |
|---|---|
| 純粋ロジック (`lib/`) | 純粋関数として単体テスト (property-based testing 推奨) |
| サーバー状態リアクティブ単位 (`queries/` / `mutations/`) | 単体テスト。API クライアントを差し替えて、キー・引数・成功時の `invalidateQueries`・エラー時の挙動を検証する。API モックライブラリ (MSW 等) は使わずクライアントを差し替える |
| 画面状態リアクティブ単位 (`state/`) | 単体テスト。初期値・更新・派生計算・永続化連動などをリアクティブに検証する |
| Domain / Generic Presentational | Storybook + VRT。Props のバリエーションを Story に並べる |
| Container | テストしない (薄いグルー) |
| Page | テストしない (実 HTTP 経路は API 統合テストで担保) |

詳細は `implement-testing` スキルの `test-value-matrix.md` を参照。
