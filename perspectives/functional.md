# Functional

関数型プログラミングの実践に関する品質レンズ。philosophy/technology-choices.md の「関数型を好む理由」を具体的な品質基準として展開。

## この観点で重視すること

- **Pure functions の優先**: 同じ入力に対して常に同じ出力。副作用なし。テストが容易
- **Immutable data**: データの変更ではなく新しいデータの生成。予測不能な状態変更を排除
- **高階関数の活用**: map/filter/reduce で宣言的に書く。ループと条件分岐の命令的スタイルより意図が明確
- **関数合成**: 小さな関数を組み合わせてパイプラインを構築。英文のように左から右へ読める

## 判断基準

- 副作用は関数の境界に押し出す (Pure core, Impure shell)
- `null` / `undefined` より Option/Maybe 型。存在しない可能性を型で表現する
- エラーは Result/Either 型。例外は予期しないバグ専用

## アンチパターン

- **Mutable Accumulator**: `let result = []; for (...) { result.push(...) }` → `map` で書ける
- **Side Effect in Pure Context**: 計算ロジック内で I/O や状態変更
- **Null Proliferation**: `if (x !== null && x !== undefined)` の連鎖 → Optional chaining や Maybe 型
- **Imperative Loop**: `for (let i = 0; i < arr.length; i++)` → `arr.map/filter/reduce`

## 品質チェックポイント

- [ ] 副作用のない関数が pure function として分離されているか
- [ ] データが immutable に扱われているか (コピーオンライト)
- [ ] map/filter/reduce 等の高階関数が活用されているか
- [ ] null/undefined の代わりに Option/Maybe 型が使われているか
- [ ] エラーが Result/Either 型で表現されているか
