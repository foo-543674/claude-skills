# Naming

命名に関する品質レンズ。

## この観点で重視すること

- **名前と動作の一致**: `get` は副作用なし (純粋取得)、`fetch` は I/O あり。名前が嘘をつかない
- **型と名前の一致**: `userList` なら List 型、`userSet` なら Set 型。型と名前が食い違うとバグの温床
- **概念語の統一**: 同じドメイン概念を「user」と「account」で呼び分けない。1 概念 1 語
- **スコープに応じた長さ**: public API は意図を説明する長さ。ループ変数やラムダ引数は短くてよい

## 判断基準

- 名前が自己文書化しているか。コメントが必要な名前は名前自体を改善すべき
- 略語はチーム共通語彙にあるもののみ。そうでなければフルスペル
- 否定形 (`isNotValid`, `disableCheck`) は避ける。HTML の `disabled` のような確立したパターンは例外

## アンチパターン

- **Misleading Name**: `getUser` が DB アクセスする、`isValid` が状態を変更する
- **Type Mismatch**: `userList` が実際は Map
- **Concept Inconsistency**: user / account / member が混在
- **Role-less Name**: `User user` ではなく `User admin` のように役割を表す

## 品質チェックポイント

- [ ] 関数名が副作用の有無と一致しているか (get = pure, fetch = I/O)
- [ ] コレクション名が実際の型と一致しているか
- [ ] 同じ概念が同じ語で統一されているか
- [ ] 名前がコメントなしで意図を伝えているか
- [ ] public API の名前が役割を十分に説明しているか
