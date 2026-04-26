# Bootstrap チェックリスト

各 Phase の完了判定に使う。

## Phase 1: Seed

- [ ] プロジェクトの目的が 1-2 文に凝縮されている
- [ ] 技術スタック (言語・FW・ランタイム) が確定している
- [ ] プロジェクトの規模感 (個人/チーム、短期/長期) が明確
- [ ] 既存プロジェクトの場合、現状調査が完了している

## Phase 2: Context Design

- [ ] philosophy/ を読み込んだ
- [ ] 関連する perspectives を選定した
- [ ] プロジェクト固有の例外・調整をユーザーに確認した

## Phase 3: Generate AI Context

- [ ] CLAUDE.md が生成された
- [ ] .github/copilot-instructions.md が生成された (GitHub 利用の場合)
- [ ] .cursorrules が生成された (Cursor 利用者がいる場合)
- [ ] コミット規約が CLAUDE.md に含まれている
- [ ] AI の判断委任範囲が明示されている
- [ ] .contexts/bootstrap-decisions.md に判断記録が残されている

## Phase 4: Generate Architecture Tests

- [ ] テストツールが選定・導入された
- [ ] 依存方向のテストが生成された
- [ ] 型漏出のテストが生成された (該当する場合)
- [ ] CI にアーキテクチャテストが組み込まれた

## Phase 5: Technical Infrastructure

- [ ] **書ける**: 追加 install なしにコードが書き始められる
- [ ] **走る**: テスト・lint・format・型チェック・ビルドが成功する
- [ ] **止まる**: 規約違反・型エラー・テスト失敗が検知されて止まる
- [ ] **再現する**: devcontainer 等で別環境でも同じ結果になる
- [ ] **見える**: ログ・エラー・テストレポートが読める
- [ ] CLAUDE.md の「開発コマンド」が実際のコマンドで埋まっている
- [ ] .claude/settings.json の許可コマンドが設定されている
- [ ] known-pitfalls.md の該当エントリを確認し、該当する場合は回避策を適用した
