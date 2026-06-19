# workon

`workon` opens an iTerm worktree cockpit for an existing Git branch.

The durable source of truth for this helper is yadm-tracked dotfiles under
`~/.config/workon`, sourced by the yadm-tracked `~/.shared_shell_env_safe`.
Personal Workbench tracks the PRD and issues for the work, but the shell and
iTerm behavior lives in dotfiles.

## Commands

- `workon <branch>`: find or create a worktree for an existing local branch and
  open a new iTerm window for it.
- `workon --dry-run <branch>`: print the branch, worktree, repo, and layout
  without opening iTerm.
- `co <branch>`: current-pane helper. If the branch is already checked out in a
  worktree, `co` changes the current pane to that worktree and says so loudly.
  Otherwise it falls back to `git checkout`.
- `wt`: compact worktree list.
- `whereami`: show actual repo/branch/worktree and compare it with the intended
  `workon` context when present.

## Worktree Locations

Existing worktrees are discovered through `git worktree list --porcelain`, so
Codex-created, Claude-created, and hand-created worktrees are all valid.

When `workon` creates a new worktree, it uses:

```text
<current-worktree-root>/.worktrees/<branch-slug>
```

It adds `.worktrees/` to Git's local exclude file via `git rev-parse --git-path
info/exclude`, avoiding repo noise without changing tracked `.gitignore`.

## Visual Model

Each pane colors itself by actual repo plus branch identity. Panes inside the
intended worktree share the cockpit color, even when they move into different
subdirectories. If a pane moves into another worktree, it changes to that
worktree's deterministic color and shows a mismatch badge.

No existing live panes are synchronized. `workon` creates a fresh window.

Cursor support is intentionally deferred.
