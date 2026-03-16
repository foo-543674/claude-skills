# コンポーネント指向設計レビュー

コードレビュー時にコンポーネント指向設計の観点で指摘すべきポイントを定義する。

コンポーネント指向の本質は **Props による状態制御の公開** にある。オブジェクト指向の「状態のカプセル化」とは異なり、コンポーネントは「親から受け取った状態を映し出すディスプレイ」として機能する。

## Why: なぜコンポーネント指向設計が重要か

コンポーネント指向設計は、フロントエンド開発における関心の分離と再利用性の基盤である。

**根本的な理由**:
1. **テスタビリティの確保**: 描画とロジックが混在すると、テストが困難になる。Presentational コンポーネント（描画のみ）とロジック層（ロジックのみ）に分離することで、各層を独立してテストでき、テストカバレッジが向上する
2. **再利用性の向上**: 内部状態を持つコンポーネントは、異なる文脈で再利用できない。Props で完全に制御可能なコンポーネントは、任意の文脈で再利用でき、開発速度を向上させる
3. **変更の局所化**: 責務が明確に分離されていれば、変更の影響範囲が限定される。デザイン変更は Presentational のみ、ロジック変更はロジック層のみの修正で済む。混在していると、変更が広範囲に波及する
4. **認知負荷の削減**: 描画とロジックが混在したコンポーネントは、読解時に両方を同時に理解する必要があり、認知負荷が高い。明確な責務分離により、各レイヤーを独立して理解できる
5. **技術移行の容易性**: フレームワークやライブラリは変化する。Presentational コンポーネントをロジックから分離しておけば、フレームワーク移行時に Presentational を再利用でき、移行コストを削減できる

**コンポーネント指向設計レビューの目的**:
- 描画とロジックの明確な分離を保証する
- Props による完全な状態制御を実現する
- 各レイヤーの再利用性とテスタビリティを確保する
- 変更の影響範囲を最小化する
- フレームワーク移行等の技術的変化に強い構造を作る

## 判断プロセス（決定ツリー）

コンポーネント指向設計のレビュー時は、以下の順序で判断する。影響範囲が大きく、テスタビリティと保守性に直結する問題から確認し、問題があれば指摘する。

### ステップ1: Container & Presentational の分離が適切か（最優先）

**判断基準**:
描画（Presentational）と接続（Container）が混在すると、テストが困難になり、再利用性が失われる。

**チェック項目**:

**Presentational コンポーネントの判定**:
```typescript
// ❌ State を保有している
function Button({ label }) {
  const [isHovered, setIsHovered] = useState(false);
  return <button onMouseEnter={() => setIsHovered(true)}>{label}</button>;
  // 内部状態があるため、外部から制御できない
}

// ✅ Props で完全に制御可能
function Button({ label, isHovered, onMouseEnter }) {
  return <button onMouseEnter={onMouseEnter}>{label}</button>;
  // すべての状態が Props で制御可能
}

// 【例外】CSS 疑似クラスで表現可能な場合は内部状態も不要
function Button({ label }) {
  return <button className="hover:bg-blue-500">{label}</button>;
  // :hover は CSS で制御
}
```

**Container コンポーネントの判定**:
```typescript
// ❌ Container にロジックと描画が混在
function UserListContainer() {
  const users = useUsers();
  return (
    <div>
      {users.map(user => (
        <div key={user.id}>{user.name}</div>  // 描画ロジックが混在
      ))}
    </div>
  );
}

// ✅ Container はロジックと Presentational の結合のみ
function UserListContainer() {
  const users = useUsers();
  return <UserList users={users} />;  // 単一の Presentational を返す
}
```

**判定フロー**:
```
コンポーネントを発見
  ↓
State を保有しているか？
  ↓ Yes
  → 描画ロジックもあるか？
      ↓ Yes → [Important] Container と Presentational に分離すべき
      ↓ No（ロジックのみ）→ OK（Container）
  ↓ No
  → Context を使用しているか？
      ↓ Yes
      → Compound パターンか（親コンポーネント名がプレフィックス）？
          ↓ Yes → OK（例外）
          ↓ No → [Important] Props で明示的に受け渡すべき
      ↓ No → OK（Presentational）
```

**判定**: State と描画が混在している場合は**必ず指摘**（Important）

### ステップ2: Presentational コンポーネントのレイヤーが適切か（高優先度）

**判断基準**:
異なるレイヤーの責務が一つのコンポーネントに混在すると、再利用性が低下する。

**4つのレイヤー**:
1. **基本 UI 部品**: ボタン、入力フィールド等
2. **アニメーション**: children の動作方法のみを制御
3. **レイアウト**: 配置・間隔の管理。内容には関与しない
4. **複合 UI**: 上記を組み合わせた画面単位のコンポーネント

**チェック項目**:
```typescript
// ❌ レイアウトとUI部品が混在
function Card({ title, content }) {
  return (
    <div className="flex gap-4">  // レイアウトの責務
      <button>{title}</button>     // UI部品の責務
      <p>{content}</p>
    </div>
  );
}

// ✅ レイヤーを分離
function Card({ children }) {  // レイアウト層
  return <div className="flex gap-4">{children}</div>;
}

function CardContent({ title, content }) {  // 複合UI層
  return (
    <Card>
      <Button>{title}</Button>
      <Text>{content}</Text>
    </Card>
  );
}
```

**判定**: レイヤーの混在がある場合は**指摘**（Minor）

### ステップ3: Props で完全に状態制御できるか（高優先度）

**判断基準**:
独立した内部状態を持つコンポーネントは、外部から制御できず、テストと再利用が困難。

**チェック項目**:

1. **独立した内部状態**:
   ```typescript
   // ❌ 内部状態が外部から制御できない
   function Modal() {
     const [isOpen, setIsOpen] = useState(false);
     return (
       <>
         <button onClick={() => setIsOpen(true)}>Open</button>
         {isOpen && <div>Modal content</div>}
       </>
     );
     // 親から開閉を制御できない
   }

   // ✅ Props で制御可能
   function Modal({ isOpen, onClose }) {
     return isOpen ? <div>Modal content</div> : null;
     // 親から完全に制御可能
   }
   ```

2. **手続き的UI操作**:
   ```typescript
   // ❌ $refs での手続き的操作
   function Parent() {
     const modalRef = useRef();
     return (
       <>
         <button onClick={() => modalRef.current.open()}>Open</button>
         <Modal ref={modalRef} />
       </>
     );
   }

   // ✅ Props での宣言的制御
   function Parent() {
     const [isOpen, setIsOpen] = useState(false);
     return (
       <>
         <button onClick={() => setIsOpen(true)}>Open</button>
         <Modal isOpen={isOpen} onClose={() => setIsOpen(false)} />
       </>
     );
   }
   ```

**判定**: 外部から制御できない内部状態がある場合は**必ず指摘**（Important）

### ステップ4: ロジック層との役割分担が明確か（中優先度）

**判断基準**:
「ロジック層があるから Container は不要」は誤解。両者は協調関係にある。

**役割分担**:
- **ロジック層（Hooks/Composables等）**: ロジックの整理と再利用
- **Container**: ロジックと描画の結合ポイント
- **Presentational**: UI の再利用

**チェック項目**:
```typescript
// ❌ ロジック層があるが Container がなく、ロジックと描画が混在
function UserList() {
  const { users, loading } = useUsers();  // ロジック層
  return (
    <div>
      {loading && <Spinner />}
      {users.map(user => <div key={user.id}>{user.name}</div>)}
    </div>
  );
  // ロジックと描画が混在
}

// ✅ Container でロジックと描画を結合
function UserListContainer() {  // Container
  const { users, loading } = useUsers();  // ロジック層
  return <UserList users={users} loading={loading} />;  // Presentational
}

function UserList({ users, loading }) {  // Presentational
  return (
    <div>
      {loading && <Spinner />}
      {users.map(user => <div key={user.id}>{user.name}</div>)}
    </div>
  );
}
```

**判定**: ロジックと描画が混在している場合は**指摘**（Minor）

### ステップ5: 副作用が適切に管理されているか（中優先度）

**判断基準**:
副作用（API呼び出し、購読、タイマー等）が Presentational に漏れると、テストが困難になる。

**チェック項目**:
```typescript
// ❌ Presentational に副作用が漏れている
function UserList() {
  const [users, setUsers] = useState([]);
  useEffect(() => {
    fetch('/api/users').then(res => res.json()).then(setUsers);
  }, []);
  return <div>{users.map(user => <div key={user.id}>{user.name}</div>)}</div>;
}

// ✅ 副作用は Container / ロジック層に集約
function UserListContainer() {
  const users = useUsers();  // 副作用はロジック層
  return <UserList users={users} />;
}
```

**判定**: Presentational に副作用がある場合は**指摘**（Minor）

### ステップ6: テスト方針との整合性（低優先度）

**判断基準**:
適切な責務分離があれば、テスト方針は自然に決まる。

**テスト方針**:
- **Presentational**: Storybook 等のカタログ化。単体テストを書きたくなるならロジックが混入している兆候
- **ロジック層**: 単体テストのみ（純粋なロジックなので）
- **Container / Page**: 統合テスト（API モックサーバー利用）

**チェック項目**:
- Presentational に複雑な単体テストが書かれていないか
- ロジック層のテストが描画に依存していないか

**判定**: テスト方針が責務分離と矛盾している場合は**指摘**（Nit）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

## レビュー観点（詳細チェックリスト）

### 1. Container & Presentational の分離

**Presentational コンポーネント**:
- [ ] State を保有していないか
- [ ] Context を使用していないか（Compound パターンは例外）
- [ ] すべての見た目の状態が Props で制御可能か
- [ ] ビジネスロジックや API 呼び出しが含まれていないか
- [ ] ユーザー操作はコールバック Props で親へ通知しているか

**Container コンポーネント**:
- [ ] return で返すのは原則として単一の Presentational コンポーネントか
- [ ] ロジック層と Presentational の結合に徹しているか
- [ ] 複雑な条件分岐による描画が Container 内に漏れていないか
- [ ] ロジック層がインフラの知識（Cookie、localStorage、ルーター等）に直接依存していないか

**Page コンポーネント**:
- [ ] パスパラメータやクエリパラメータのパースを担当しているか
- [ ] Cookie、localStorage 等のアクセスを抽象化し、Container に引き渡しているか
- [ ] Container が呼ぶ Hooks からインフラの知識が排除されているか

### 2. Presentational コンポーネントのレイヤー

- [ ] 基本 UI 部品、アニメーション、レイアウト、複合 UI のどのレイヤーに属するか明確か
- [ ] 異なるレイヤーの責務が一つのコンポーネントに混在していないか

### 3. Props 設計と状態制御

- [ ] 子コンポーネントが独立した内部状態を持っていないか
- [ ] `$refs` 等を使った手続き的な UI 操作になっていないか
- [ ] バケツリレーを避けるために Context で暗黙の依存を作っていないか
- [ ] ホバー、フォーカス等は CSS 疑似クラスで制御しているか

### 4. ロジック層との役割分担

- [ ] 「ロジック層があるから Container は不要」と誤解してロジックと描画が混在していないか
- [ ] ロジックがロジック層に抽出され、Container が結果を Presentational に渡す構造か

### 5. 再利用性と捨てやすさ

- [ ] 汎用コンポーネントとドメイン固有コンポーネントが明確に分離されているか
- [ ] 特定のフレームワークや技術に強く結合しすぎていないか
- [ ] 一部の変更が広範囲に波及する構造になっていないか

### 6. 副作用の管理

- [ ] 副作用が Presentational に漏れず Container / ロジック層に集約されているか
- [ ] 副作用の開始と後片付けが対になっているか
- [ ] 副作用の依存関係が正しく宣言されているか

### 7. テスト方針との整合

- [ ] Presentational に対して複雑な単体テストが書かれていないか
- [ ] ロジック層のテストが描画やインフラに依存していないか
- [ ] Container / Page に対して単体テストではなく統合テストを使っているか

## 指摘の出し方

### 指摘の構造

```
【問題点】このコンポーネントは○○の問題があります
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□に分離/変更すると改善します
【メリット】◇◇が可能になります
```

### 指摘の例

#### State と描画の混在の指摘

```
【問題点】このコンポーネントは State を持ちつつ描画も行っています
【理由】`useState` でモーダルの開閉状態を管理し、同時に JSX で描画しています
【影響】外部から開閉を制御できず、テストと再利用が困難です
【提案】Container と Presentational に分離してください
  ```typescript
  // Before: State と描画が混在
  function Modal() {
    const [isOpen, setIsOpen] = useState(false);
    return (
      <>
        <button onClick={() => setIsOpen(true)}>Open</button>
        {isOpen && <div>Modal content</div>}
      </>
    );
  }

  // After: 分離
  function ModalContainer() {  // Container
    const [isOpen, setIsOpen] = useState(false);
    return (
      <>
        <button onClick={() => setIsOpen(true)}>Open</button>
        <Modal isOpen={isOpen} onClose={() => setIsOpen(false)} />
      </>
    );
  }

  function Modal({ isOpen, onClose }) {  // Presentational
    return isOpen ? <div>Modal content</div> : null;
  }
  ```
【メリット】Modal が Props で完全に制御可能になり、任意の文脈で再利用できます
```

#### ロジックと描画の混在の指摘

```
【問題点】このコンポーネントはロジック層があるにもかかわらず、ロジックと描画が混在しています
【理由】`useUsers()` でロジックを呼び出しつつ、同じコンポーネントで JSX を記述しています
【影響】ロジック層があるのに Container がないため、描画のテストが困難です
【提案】Container を追加してロジックと描画を結合してください
  ```typescript
  // Before: ロジックと描画が混在
  function UserList() {
    const { users, loading } = useUsers();  // ロジック層
    return (
      <div>
        {loading && <Spinner />}
        {users.map(user => <div key={user.id}>{user.name}</div>)}
      </div>
    );
  }

  // After: Container で結合
  function UserListContainer() {  // Container
    const { users, loading } = useUsers();
    return <UserList users={users} loading={loading} />;
  }

  function UserList({ users, loading }) {  // Presentational
    return (
      <div>
        {loading && <Spinner />}
        {users.map(user => <div key={user.id}>{user.name}</div>)}
      </div>
    );
  }
  ```
【メリット】UserList が純粋な Presentational になり、Storybook でカタログ化できます
```

#### 副作用の漏洩の指摘

```
【問題点】この Presentational コンポーネントに副作用（API 呼び出し）が含まれています
【理由】`useEffect` で `/api/users` を fetch しています
【影響】Presentational のテストが困難になり、再利用性が失われます
【提案】副作用を Container / ロジック層に移動してください
  ```typescript
  // Before: Presentational に副作用
  function UserList() {
    const [users, setUsers] = useState([]);
    useEffect(() => {
      fetch('/api/users').then(res => res.json()).then(setUsers);
    }, []);
    return <div>{users.map(user => <div key={user.id}>{user.name}</div>)}</div>;
  }

  // After: 副作用をロジック層に移動
  function useUsers() {  // ロジック層
    const [users, setUsers] = useState([]);
    useEffect(() => {
      fetch('/api/users').then(res => res.json()).then(setUsers);
    }, []);
    return users;
  }

  function UserListContainer() {  // Container
    const users = useUsers();
    return <UserList users={users} />;
  }

  function UserList({ users }) {  // Presentational
    return <div>{users.map(user => <div key={user.id}>{user.name}</div>)}</div>;
  }
  ```
【メリット】UserList が純粋な描画ロジックのみになり、Props でテストできます
```

### 指摘の優先度ラベル

- **[Important]**: State と描画の混在、外部から制御できない内部状態（テスタビリティと再利用性に直結）
- **[Minor]**: ロジックと描画の混在、副作用の漏洩、レイヤーの混在
- **[Nit]**: テスト方針の不整合

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: State と描画の混在（Important指摘）

**コード**:
```typescript
function Modal() {
  const [isOpen, setIsOpen] = useState(false);
  return (
    <>
      <button onClick={() => setIsOpen(true)}>Open</button>
      {isOpen && <div>Modal content</div>}
    </>
  );
}
```

**期待される指摘**:
- [Important] State と描画が混在
- Container と Presentational に分離すべき
- Props で完全に制御可能にすべき

### Case 2: ロジックと描画の混在（Minor指摘）

**コード**:
```typescript
function UserList() {
  const { users, loading } = useUsers();
  return (
    <div>
      {loading && <Spinner />}
      {users.map(user => <div key={user.id}>{user.name}</div>)}
    </div>
  );
}
```

**期待される指摘**:
- [Minor] ロジック層があるのに Container がない
- Container を追加してロジックと描画を結合すべき

### Case 3: 副作用の漏洩（Minor指摘）

**コード**:
```typescript
function UserList() {
  const [users, setUsers] = useState([]);
  useEffect(() => {
    fetch('/api/users').then(res => res.json()).then(setUsers);
  }, []);
  return <div>{users.map(user => <div key={user.id}>{user.name}</div>)}</div>;
}
```

**期待される指摘**:
- [Minor] Presentational に副作用が漏れている
- 副作用をロジック層に移動すべき

### Case 4: 許容されるケース（指摘なし）

**コード**:
```typescript
// Container
function UserListContainer() {
  const users = useUsers();  // ロジック層
  return <UserList users={users} />;
}

// Presentational
function UserList({ users }) {
  return <div>{users.map(user => <div key={user.id}>{user.name}</div>)}</div>;
}

// Compound パターン（例外）
function Accordion({ children }) {
  return <AccordionContext.Provider>{children}</AccordionContext.Provider>;
}

Accordion.Header = function Header() {
  const context = useContext(AccordionContext);  // Context 使用
  // 親コンポーネント名がプレフィックスで依存関係が明確
  return <div>{/* ... */}</div>;
};
```

**期待される判断**:
- Container と Presentational が適切に分離されている
- Compound パターンは例外として許容
- 指摘なし
