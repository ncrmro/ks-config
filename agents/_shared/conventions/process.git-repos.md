# Git repos

Repositories clone to `~/repos/{owner}/{repo}/`. Main checkouts stay on the default branch. Implementation work happens in git worktrees at `~/repos/{owner}/worktrees/{repo}/{branch}/`. Branch slashes are preserved as directories (e.g. branch `feat/foo` → `~/repos/{owner}/worktrees/{repo}/feat/foo/`).
