# 依存関係設計レビュー

コードレビュー時に依存関係管理の観点で指摘すべきポイントを定義する。パッケージ・ライブラリの依存と、モジュール間の構造的な依存の両方を対象とする。

このスキルには筆者の設計思想が含まれる。依存関係は「追加は簡単、除去は困難」であり、慎重な判断を推奨する。ただし過度な依存回避（車輪の再発明）も保守コストを増やすため、バランスが重要。

## Why: なぜ依存関係設計レビューが重要か

依存関係の品質は、システムの長期的な保守性とセキュリティを決定する。不適切な依存管理は、技術的負債とセキュリティリスクを累積させる。

**根本的な理由**:
1. **除去の困難さとコスト**: 依存関係は追加が簡単だが除去は極めて困難。一度依存すると、API がアプリケーション全体に散在し、差し替えに膨大なコストがかかる。ライブラリが EOL（End of Life）になった際、選択肢は「セキュリティリスクを抱えて使い続ける」か「全体を書き換える」の二択になる
2. **セキュリティリスクの連鎖**: 依存ライブラリの脆弱性は、アプリケーション全体のセキュリティを脅かす。推移的依存を含めると、数百〜数千の依存が存在し、1つでも脆弱性があれば攻撃対象となる。定期的な更新が必須だが、破壊的変更への対応コストが高いと更新が滞り、脆弱性が放置される
3. **保守コストの増大**: 依存が増えるほど、バージョン互換性の維持・更新の追従・破壊的変更への対応コストが累積する。特にメジャーバージョンアップは、アプリケーション全体に影響し、数日〜数週間の作業を要する。メンテナンスされていない依存は、最新の言語・ランタイムとの互換性を失う
4. **バンドルサイズへの影響**: フロントエンドでは、依存の肥大化がバンドルサイズを増大させ、初回ロード時間・パフォーマンスに直接影響する。ユーザー体験の悪化はビジネス指標（コンバージョン率等）に影響する
5. **技術的負債の累積**: 循環依存・無秩序な依存グラフは、モジュールの独立性を失わせ、変更の影響範囲を予測不能にする。リファクタリング・機能追加が困難になり、技術的負債が累積する

**依存関係設計レビューの目的**:
- 除去困難な依存を慎重に選択し、将来の差し替えコストを最小化する
- セキュリティリスクを継続的に管理し、脆弱性を早期に検出・対応する
- 保守コストを抑制し、長期的な更新可能性を担保する
- バンドルサイズを最適化し、ユーザー体験を確保する
- 依存グラフを健全に保ち、変更容易性を維持する

## 判断プロセス（決定ツリー）

依存関係設計のレビュー時は、以下の順序で判断する。除去困難で長期的な影響が大きい問題から確認し、問題があれば指摘する。

### ステップ1: ライブラリ選定基準（最優先）

**判断基準**:
不適切なライブラリ選定は、後から修正が極めて困難で、長期的な技術的負債となる。

**チェック項目**:

1. **メンテナンス状況の確認**:
   ```typescript
   // ❌ メンテナンスされていないライブラリ
   // - 最終リリースが3年前
   // - Issue が100件以上未対応
   // - メンテナが1名のみ
   import { parse } from 'abandoned-parser';

   // ✅ 活発にメンテナンスされているライブラリ
   // - 最終リリースが1ヶ月前
   // - Issue 対応が活発
   // - 複数のメンテナ
   import { parse } from 'active-parser';

   // ✅ 標準ライブラリで代替可能
   // import { parse } from 'date-parser';
   const date = new Date('2024-01-01');  // 標準機能で十分
   ```

2. **標準ライブラリとの比較**:
   ```typescript
   // ❌ 標準機能で代替可能なのに依存追加
   import { isEmpty } from 'lodash';
   if (isEmpty(array)) { ... }

   // ✅ 標準機能を使用
   if (array.length === 0) { ... }

   // ❌ trivial な機能のために依存追加（Left-Pad Problem）
   import leftPad from 'left-pad';
   const padded = leftPad('5', 3, '0');  // '005'

   // ✅ 標準機能で実装
   const padded = '5'.padStart(3, '0');
   ```

3. **バンドルサイズの考慮**（フロントエンド）:
   ```typescript
   // ❌ 巨大な依存を追加（moment.js: 70KB）
   import moment from 'moment';
   const date = moment().format('YYYY-MM-DD');

   // ✅ 軽量な代替（date-fns: 10KB、必要な関数のみ）
   import { format } from 'date-fns';
   const date = format(new Date(), 'yyyy-MM-dd');

   // ✅ または標準 API
   const date = new Date().toISOString().split('T')[0];
   ```

4. **ライセンスの確認**:
   ```typescript
   // ❌ GPL ライセンス（商用利用に制限）
   import { transform } from 'gpl-library';

   // ✅ MIT/Apache ライセンス（商用利用可能）
   import { transform } from 'mit-library';
   ```

**判定フロー**:
```
依存追加を確認
  ↓
標準ライブラリで代替可能か？
  ↓ Yes → [Important] 標準ライブラリを使用すべき
  ↓ No
  ↓
メンテナンスされているか？（最終リリース1年以内、Issue 対応活発）
  ↓ No → [Important] メンテナンスされている代替を検討すべき
  ↓ Yes
  ↓
ライセンスは互換性があるか？
  ↓ No → [Important] ライセンス互換性のある代替を使用すべき
  ↓ Yes
  ↓
バンドルサイズへの影響は許容範囲か？（フロントエンド）
  ↓ No → [Minor] 軽量な代替を検討すべき
  ↓ Yes → OK
```

**判定**: 標準ライブラリで代替可能、メンテナンス不足、ライセンス不適合は**必ず指摘**（Important）

### ステップ2: 依存方向と循環依存（高優先度）

**判断基準**:
循環依存は、モジュールの独立性を失わせ、変更の影響範囲を予測不能にする。

**チェック項目**:

1. **循環依存の検出**:
   ```typescript
   // ❌ 循環依存（A → B → C → A）
   // moduleA.ts
   import { funcB } from './moduleB';
   export function funcA() { funcB(); }

   // moduleB.ts
   import { funcC } from './moduleC';
   export function funcB() { funcC(); }

   // moduleC.ts
   import { funcA } from './moduleA';  // 循環
   export function funcC() { funcA(); }

   // ✅ DAG（有向非巡回グラフ）
   // moduleA.ts
   import { funcB } from './moduleB';
   export function funcA() { funcB(); }

   // moduleB.ts
   import { funcC } from './moduleC';
   export function funcB() { funcC(); }

   // moduleC.ts
   // import なし（末端ノード）
   export function funcC() { ... }
   ```

2. **レイヤー間の依存方向**:
   ```typescript
   // ❌ 下位層が上位層に依存
   // domain/User.ts
   import { UserRepository } from '../infrastructure/UserRepository';
   // ドメイン層がインフラ層に依存（逆依存）

   // ✅ 依存の逆転（DIP）
   // domain/User.ts
   export interface IUserRepository {
     save(user: User): Promise<void>;
   }

   // infrastructure/UserRepository.ts
   import { IUserRepository } from '../domain/User';
   export class UserRepository implements IUserRepository {
     // インフラ層がドメイン層のインターフェースに依存
   }
   ```

**判定フロー**:
```
モジュール間の依存を確認
  ↓
循環依存があるか？
  ↓ Yes → [Important] 依存を整理してDAG構造にすべき
  ↓ No
  ↓
下位層が上位層に依存していないか？
  ↓ Yes → [Important] 依存の逆転を適用すべき
  ↓ No → OK
```

**判定**: 循環依存、逆依存は**必ず指摘**（Important）

### ステップ3: 外部依存の隔離（高優先度）

**判断基準**:
外部ライブラリの API が散在すると、ライブラリ差し替え時の変更範囲が広がり、EOL 時に対応不能になる。

**チェック項目**:

1. **ラッパーによる隔離**:
   ```typescript
   // ❌ 外部ライブラリの API が散在
   // featureA.ts
   import axios from 'axios';
   const response = await axios.get('/api/users');

   // featureB.ts
   import axios from 'axios';
   const response = await axios.post('/api/orders', data);

   // ✅ ラッパーで隔離
   // infrastructure/HttpClient.ts
   import axios from 'axios';

   export class HttpClient {
     async get<T>(path: string): Promise<T> {
       const response = await axios.get(path);
       return response.data;
     }

     async post<T>(path: string, data: unknown): Promise<T> {
       const response = await axios.post(path, data);
       return response.data;
     }
   }

   // featureA.ts
   import { httpClient } from '../infrastructure/HttpClient';
   const users = await httpClient.get<User[]>('/api/users');
   ```

2. **外部ライブラリの型の漏洩防止**:
   ```typescript
   // ❌ 外部ライブラリの型がドメイン層に漏れる
   // domain/User.ts
   import { AxiosResponse } from 'axios';
   export function processUser(response: AxiosResponse<UserData>) {
     // axios の型がドメインに漏れている
   }

   // ✅ アプリケーション固有の型に変換
   // domain/User.ts
   export interface UserResponse {
     data: UserData;
     status: number;
   }

   export function processUser(response: UserResponse) {
     // アプリケーション固有の型
   }
   ```

3. **適切な隔離の範囲**:
   ```typescript
   // ❌ Full Surface Wrapper（薄いラップのみ）
   export class DateWrapper {
     format(date: Date, format: string) {
       return dateFns.format(date, format);  // 全APIを薄くラップ
     }
     parse(date: string, format: string) {
       return dateFns.parse(date, format, new Date());
     }
     // ... 全メソッドをラップ（アプリ固有の設計なし）
   }

   // ✅ アプリケーションが必要とするインターフェースに絞る
   export class DateService {
     formatForDisplay(date: Date): string {
       return format(date, 'yyyy-MM-dd HH:mm');  // アプリ固有の表示形式
     }

     parseUserInput(input: string): Date {
       // アプリ固有のパース処理（バリデーション含む）
       const parsed = parse(input, 'yyyy-MM-dd', new Date());
       if (!isValid(parsed)) {
         throw new InvalidDateError(input);
       }
       return parsed;
     }
   }
   ```

**判定フロー**:
```
外部ライブラリの使用を確認
  ↓
複数箇所で直接使用されているか？
  ↓ Yes → [Important] ラッパーで隔離すべき
  ↓ No
  ↓
外部ライブラリの型がドメイン層に漏れているか？
  ↓ Yes → [Important] アプリケーション固有の型に変換すべき
  ↓ No → OK
```

**判定**: 外部ライブラリの散在、型の漏洩は**必ず指摘**（Important）

### ステップ4: バージョン固定戦略（中優先度）

**判断基準**:
バージョン管理が不適切だと、セキュリティリスクと再現性の問題が発生する。

**チェック項目**:

1. **lock ファイルのコミット**:
   ```bash
   # ❌ lock ファイルが .gitignore に含まれている
   # .gitignore
   package-lock.json
   yarn.lock

   # ✅ lock ファイルをコミット
   git add package-lock.json
   ```

2. **バージョン範囲指定のリスク**:
   ```json
   // ❌ 緩いバージョン範囲（予期しない破壊的変更）
   {
     "dependencies": {
       "express": "^4.0.0"  // 4.0.0 ~ 5.0.0 未満（破壊的変更の可能性）
     }
   }

   // ✅ 固定バージョンまたは狭い範囲
   {
     "dependencies": {
       "express": "4.18.2"  // 固定
     }
   }
   ```

3. **セキュリティアップデートの自動化**:
   ```yaml
   # ✅ Dependabot 設定
   # .github/dependabot.yml
   version: 2
   updates:
     - package-ecosystem: "npm"
       directory: "/"
       schedule:
         interval: "weekly"
       open-pull-requests-limit: 10
   ```

**判定**: lock ファイルの欠如は**指摘**（Minor）

### ステップ5: 依存グラフの肥大化防止（中優先度）

**判断基準**:
依存の肥大化は、バンドルサイズ・ビルド時間・セキュリティリスクを増大させる。

**チェック項目**:

1. **推移的依存の確認**:
   ```bash
   # 推移的依存の量を確認
   npm ls --depth=10
   yarn why <package-name>

   # ❌ 小さな機能のために巨大な推移的依存
   # library-a を追加すると、100個の推移的依存が入る

   # ✅ 推移的依存が少ない代替を選択
   ```

2. **重複依存の検出**:
   ```json
   // ❌ 同じ目的のライブラリが複数
   {
     "dependencies": {
       "lodash": "^4.17.21",
       "underscore": "^1.13.6"  // lodash と重複
     }
   }

   // ✅ 統一
   {
     "dependencies": {
       "lodash": "^4.17.21"
     }
   }
   ```

3. **devDependencies の分離**:
   ```json
   // ❌ 本番不要な依存が dependencies に
   {
     "dependencies": {
       "jest": "^29.0.0",  // テストツール（devDependencies に属す）
       "express": "^4.18.2"
     }
   }

   // ✅ 適切な分離
   {
     "dependencies": {
       "express": "^4.18.2"
     },
     "devDependencies": {
       "jest": "^29.0.0"
     }
   }
   ```

**判定**: 巨大な推移的依存、重複依存は**指摘**（Minor）

### ステップ6: 依存の更新戦略（低優先度）

**判断基準**:
定期的な更新がないと、セキュリティリスクが累積し、後からの更新コストが増大する。

**チェック項目**:

1. **定期更新の仕組み**:
   ```yaml
   # ✅ 定期的な依存更新
   # - 週次でマイナーバージョン更新
   # - 月次でメジャーバージョン更新の検討
   # - セキュリティパッチは即座に適用
   ```

2. **破壊的変更への対応**:
   ```typescript
   // メジャーバージョンアップ時の影響評価
   // - CHANGELOG の確認
   // - 破壊的変更の特定
   // - テストでの動作確認
   ```

**判定**: 更新戦略が不明確な場合は**指摘**（Nit）

## レビュー観点（詳細チェックリスト）

上記の判断プロセスを実行するための具体的なチェックリスト。

### 1. ライブラリ選定基準

- [ ] 標準ライブラリや言語組み込み機能で代替できないか
- [ ] メンテナンス状況は健全か（最終リリース1年以内、Issue 対応活発、複数のメンテナ）
- [ ] ライセンスがプロジェクトの利用条件と互換性があるか
- [ ] バンドルサイズへの影響を考慮しているか（フロントエンド）
- [ ] trivial な機能のために依存を追加していないか（Left-Pad Problem）
- [ ] 自前実装の品質とライブラリの品質を比較評価しているか

### 2. 依存方向と循環依存

- [ ] 循環依存が発生していないか（A → B → C → A）
- [ ] 依存グラフが DAG（有向非巡回グラフ）になっているか
- [ ] 下位層が上位層に依存していないか（依存の逆転を適用すべき）
- [ ] パッケージ境界をまたぐ依存が最小限か
- [ ] モジュール間の依存が一方向になっているか

### 3. 外部依存の隔離

- [ ] 外部ライブラリの API が複数箇所に散在していないか
- [ ] ラッパーを介して「捨てやすい構成」を実現しているか
- [ ] 外部ライブラリの型がドメイン層に漏れていないか
- [ ] ラップする範囲がアプリケーションが必要とするインターフェースに絞られているか
- [ ] Full Surface Wrapper（薄いラップのみ）になっていないか

### 4. バージョン固定戦略

- [ ] lock ファイル（package-lock.json, Cargo.lock 等）がコミットされているか
- [ ] バージョン範囲指定（^, ~）のリスクを理解しているか
- [ ] セキュリティアップデートの自動検出の仕組みがあるか（Dependabot, Renovate 等）
- [ ] メジャーバージョンアップの影響評価プロセスが定義されているか

### 5. 依存グラフの肥大化防止

- [ ] 小さな機能のために巨大な依存（推移的依存が多い）を追加していないか
- [ ] 推移的依存の量を把握しているか
- [ ] 同じ目的のライブラリが複数入っていないか
- [ ] devDependencies と dependencies の区別が適切か

### 6. 依存の更新戦略

- [ ] 定期的な依存更新の仕組みがあるか
- [ ] セキュリティパッチの適用プロセスが明確か
- [ ] 破壊的変更への対応手順が定義されているか

## よくあるアンチパターン

- **Left-Pad Problem**: trivial な機能のために外部依存を追加する
- **Full Surface Wrapper**: ライブラリの全 API を薄くラップしただけで、アプリケーション固有のインターフェース設計がない
- **Diamond Dependency**: 同じライブラリの異なるバージョンが推移的に依存される

## 指摘の出し方

### 指摘の構造

```
【問題点】この依存関係設計は○○の問題があります
【理由】△△だからです
【影響】この問題により××のリスクが発生します
【提案】□□に変更すると改善します
【トレードオフ】◇◇とのバランスを考慮する必要があります
```

### 指摘の例

#### 標準ライブラリで代替可能な依存の指摘

```
【問題点】この lodash の isEmpty 関数は標準機能で代替可能です
【理由】配列の空判定は `array.length === 0` で十分です
【影響】不要な依存追加により以下のリスクが発生します:
  - バンドルサイズの増大（lodash 全体で 24KB）
  - セキュリティアップデートの追従コスト
  - 依存グラフの肥大化
【提案】以下のように標準機能に置き換えてください
  ```typescript
  // Before: lodash に依存
  import { isEmpty } from 'lodash';
  if (isEmpty(array)) { ... }

  // After: 標準機能
  if (array.length === 0) { ... }
  ```
【トレードオフ】標準機能のみで実装することにより、依存は減りますが、trivial なユーティリティ関数が増える場合があります
```

#### 循環依存の指摘

```
【問題点】この依存関係に循環があります（moduleA → moduleB → moduleC → moduleA）
【理由】循環依存により、モジュールの独立性が失われ、変更の影響範囲が予測不能になります
【影響】以下のリスクが発生します:
  - モジュールの独立したテストが困難
  - ビルドツールによっては循環依存を解決できずエラー
  - リファクタリング・機能追加が困難
【提案】以下のように依存を整理してDAG構造にしてください
  ```typescript
  // Before: 循環依存
  // moduleA.ts → moduleB.ts → moduleC.ts → moduleA.ts

  // After: 共通部分を抽出してDAG化
  // moduleCommon.ts（共通機能を抽出）
  export function commonFunc() { ... }

  // moduleA.ts
  import { commonFunc } from './moduleCommon';

  // moduleB.ts
  import { commonFunc } from './moduleCommon';

  // moduleC.ts
  import { commonFunc } from './moduleCommon';
  ```
【トレードオフ】依存整理によりモジュール数が増えますが、独立性と変更容易性が向上します
```

#### 外部依存の散在の指摘

```
【問題点】この axios の API が複数箇所に直接使用されています
【理由】外部ライブラリの API が散在すると、ライブラリが EOL になった際の差し替えが困難です
【影響】以下のリスクが発生します:
  - ライブラリ差し替え時に全ファイルの修正が必要
  - axios の型がアプリケーション全体に漏れる
  - EOL 時に対応不能になる可能性
【提案】以下のようにラッパーで隔離してください
  ```typescript
  // Before: axios が散在
  // featureA.ts
  import axios from 'axios';
  const response = await axios.get('/api/users');

  // featureB.ts
  import axios from 'axios';
  const response = await axios.post('/api/orders', data);

  // After: ラッパーで隔離
  // infrastructure/HttpClient.ts
  import axios from 'axios';

  export class HttpClient {
    async get<T>(path: string): Promise<T> {
      const response = await axios.get(path);
      return response.data;
    }

    async post<T>(path: string, data: unknown): Promise<T> {
      const response = await axios.post(path, data);
      return response.data;
    }
  }

  // featureA.ts
  import { httpClient } from '../infrastructure/HttpClient';
  const users = await httpClient.get<User[]>('/api/users');
  ```
【トレードオフ】ラッパー実装により初期コストは増えますが、将来の差し替えコストは大幅に削減されます
```

### 指摘の優先度ラベル

- **[Important]**: 標準ライブラリで代替可能、メンテナンス不足、循環依存、外部依存の散在、ライセンス不適合（除去困難・セキュリティリスク）
- **[Minor]**: バージョン固定戦略の不備、推移的依存の肥大化、重複依存、lock ファイルの欠如
- **[Nit]**: devDependencies の分離不足、更新戦略の不明確さ

## テストケース

レビュー判断の精度を検証するためのテストケース。

### Case 1: 標準ライブラリで代替可能（Important指摘）

**コード**:
```typescript
import { isEmpty } from 'lodash';

if (isEmpty(array)) {
  // 配列が空の場合の処理
}
```

**期待される指摘**:
- [Important] lodash の isEmpty は標準機能で代替可能
- `array.length === 0` で十分
- 不要な依存追加によるバンドルサイズ増大・セキュリティリスク

### Case 2: 循環依存（Important指摘）

**コード**:
```typescript
// moduleA.ts
import { funcB } from './moduleB';
export function funcA() { funcB(); }

// moduleB.ts
import { funcC } from './moduleC';
export function funcB() { funcC(); }

// moduleC.ts
import { funcA } from './moduleA';  // 循環
export function funcC() { funcA(); }
```

**期待される指摘**:
- [Important] 循環依存（A → B → C → A）が発生
- モジュールの独立性が失われ、テストが困難
- 共通部分を抽出してDAG構造にすべき

### Case 3: 外部依存の散在（Important指摘）

**コード**:
```typescript
// featureA.ts
import axios from 'axios';
const response = await axios.get('/api/users');

// featureB.ts
import axios from 'axios';
const response = await axios.post('/api/orders', data);

// featureC.ts
import axios from 'axios';
const response = await axios.put('/api/products', data);
```

**期待される指摘**:
- [Important] axios の API が複数箇所に散在
- ライブラリ差し替え時に全ファイルの修正が必要
- ラッパーで隔離すべき（捨てやすい構成）

### Case 4: lock ファイルの欠如（Minor指摘）

**コード**:
```bash
# .gitignore
node_modules/
package-lock.json  # lock ファイルが除外されている
```

**期待される指摘**:
- [Minor] lock ファイルが .gitignore に含まれている
- 依存のバージョンが固定されず、再現性が失われる
- lock ファイルをコミットすべき

### Case 5: 許容されるケース（指摘なし）

**コード**:
```typescript
// ラッパーで隔離
// infrastructure/HttpClient.ts
import axios from 'axios';

export class HttpClient {
  async get<T>(path: string): Promise<T> {
    const response = await axios.get(path);
    return response.data;
  }
}

// featureA.ts
import { httpClient } from '../infrastructure/HttpClient';
const users = await httpClient.get<User[]>('/api/users');

// DAG構造
// moduleA.ts → moduleB.ts → moduleC.ts（循環なし）

// 標準機能の使用
if (array.length === 0) { ... }

// lock ファイルのコミット
package-lock.json がリポジトリに含まれている
```

**期待される判断**:
- 外部依存がラッパーで隔離されている
- DAG構造で循環依存がない
- 標準機能を優先している
- lock ファイルが適切に管理されている
- 指摘なし
