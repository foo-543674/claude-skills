# State Design

状態設計に関する品質レンズ。フロントエンドの状態管理に特化。

## この観点で重視すること

- **Boolean Explosion の防止**: 複数フラグではなく Discriminated Union で状態を表現
- **明示的な状態遷移**: 直接代入ではなく、遷移関数で条件を検証してから遷移する
- **Single Source of Truth**: 導出可能な値は保存しない。`items.length` があるなら `totalCount` は持たない
- **楽観的更新 vs 悲観的更新**: UX とデータ整合性のトレードオフを意識的に選択する

## 判断基準

- 状態の組み合わせで「ありえない状態」が型レベルで表現不能になっているか
- 楽観的更新を使うなら、失敗時のロールバック戦略が定義されているか
- サーバーとクライアントの状態の同期戦略が明確か (stale-while-revalidate 等)

## アンチパターン

- **Flag Soup**: `isLoading + isError + isSuccess + hasData` の組み合わせ
- **Direct Assignment**: `state.status = "approved"` で条件チェックなし
- **Derived State Storage**: 計算で導出できる値を独立して保存・同期
- **Optimistic Without Rollback**: 楽観更新するが失敗時の復元がない

## 品質チェックポイント

- [ ] 状態が Discriminated Union で型安全に表現されているか
- [ ] 状態遷移が関数で明示的に行われているか
- [ ] 導出可能な値を独立して保存していないか
- [ ] 楽観更新に失敗時のロールバックがあるか
