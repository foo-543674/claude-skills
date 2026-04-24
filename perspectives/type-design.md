# Type Design

型設計に関する品質レンズ。

## この観点で重視すること

- **不正な状態を型で表現不能にする**: Boolean フラグの組み合わせではなく Discriminated Union で状態を表現。無効な組み合わせがコンパイル時に排除される
- **Branded/Newtype パターン**: `UserId` と `OrderId` を同じ `string` にしない。型レベルで混同を防ぐ
- **型による状態遷移の明示**: `Draft → Published → Archived` のような遷移を型で表現。不正な遷移はコンパイルエラー
- **未検証 / 検証済みの区別**: Input 型 (未検証) と Validated 型 (検証済み) を型レベルで区別する

## 判断基準

- Boolean フラグが 2 つ以上あるなら Discriminated Union を検討する
- `string` / `number` をそのまま使う場所で、混同リスクがあるなら Branded Type にする
- 状態遷移があるドメインモデルは状態を型で表現できないか検討する

## アンチパターン

- **Boolean Explosion**: `isLoading`, `isError`, `isSuccess` の 3 フラグ (8 通りの状態のうち有効は 3 つだけ)
- **Stringly Typed**: ドメイン概念を `string` で表現 (`userId: string` と `orderId: string` の混同)
- **Implicit State Machine**: 状態遷移が `status = "approved"` の直接代入で表現される
- **Unchecked Input**: 未検証の入力がそのまま集約に渡される

## 品質チェックポイント

- [ ] 状態の組み合わせが Discriminated Union で型安全か
- [ ] ドメインの識別子が Branded/Newtype で型レベルで区別されているか
- [ ] 状態遷移が型で表現されているか
- [ ] 未検証入力と検証済み入力が型レベルで区別されているか
