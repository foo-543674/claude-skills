# Known Pitfalls Registry

bootstrap 中に AI と人間の双方が参照する「既知の CI/Infra 落とし穴」レジストリ。技術インフラを組み立てるとき、踏み抜くと再現が難しい罠を症状ベースで記録する。

新しいプロジェクトで該当する技術 (CI、bot 連携、外部 action 等) を扱う場合は、対応するエントリの「症状」「回避策」「検出方法」を確認した上で構築する。エントリ追加の基準は「実際に踏んで解決した」こと。仮説段階のものは登録しない。

## CI/Infra Pitfalls

### `anthropics/claude-code-action` + Copilot Coding Agent

- **症状**: Copilot Coding Agent が author の commit を pull_request event で processing するとき、`anthropics/claude-code-action@v1` が 2 段階で連続失敗する
  - 段階 1: Anthropic 側の App-token 交換が 401 (`User does not have write access`) — actor=`Copilot` (`[bot]` サフィックス無し) のため
  - 段階 2: github_token フォールバック後も action 内部の permission チェックで `octokit.repos.getCollaboratorPermissionLevel({ username: "Copilot" })` が 404 (`Copilot is not a user`)
- **回避策** (workflow yaml):
  - `claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}` だけでなく `github_token: ${{ secrets.GITHUB_TOKEN }}` も併せて渡す
  - `allowed_non_write_users: "Copilot"` を設定する
- **検出方法**: AI 自動レビュー workflow が pull_request event の actor=Copilot で連続失敗したログを観測した場合
- **参考**: triary commit `1d921e32` (github_token フォールバック追加), `b8c9a595` (allowed_non_write_users 追加)
