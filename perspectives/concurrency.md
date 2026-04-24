# Concurrency

並行処理に関する品質レンズ。

## この観点で重視すること

- **共有データの保護**: 複数スレッド/非同期タスクからアクセスされる可変データは mutex/lock/atomic で保護
- **Read-Modify-Write の原子性**: 読み取りと書き込みの間に await/yield が入ると TOCTOU 問題
- **デッドロック防止**: 複数ロックの取得順序をグローバルに統一する
- **非同期エラーの捕捉**: fire-and-forget (await 忘れ、.catch なし) を避ける

## 判断基準

- ロック内で I/O (API 呼び出し、DB クエリ) をしない。I/O はロック外に移動する
- トランザクションスコープは最小限に。ロック競合を減らす
- 楽観ロック vs 悲観ロック: 競合頻度が低ければ楽観ロック (ETag/version)

## アンチパターン

- **Unprotected Shared State**: 同期なしで共有データにアクセス
- **TOCTOU**: Read → await → Write で間にデータが変わる
- **Lock Order Inconsistency**: A→B と B→A の取得順が混在 (デッドロック)
- **Lock During I/O**: ロック保持中に外部呼び出し
- **Fire-and-Forget**: await なし、.catch なしの非同期処理

## 品質チェックポイント

- [ ] 共有可変データに適切な同期機構があるか
- [ ] Read-Modify-Write が原子的か (間に await がないか)
- [ ] 複数ロックの取得順序が統一されているか
- [ ] ロック保持中に I/O をしていないか
- [ ] すべての非同期処理に await + エラーハンドリングがあるか
