## Git freshness

Before starting code work in any Git repository, fetch `origin` and identify the repository's default branch, such as `main` or `master`, preferably from `origin/HEAD` or the remote's configured default branch. Start new task work and worktrees from an up-to-date default branch or from an explicitly chosen current feature branch. Do not silently base new work on a stale local default branch.

If the default branch is checked out in a clean local worktree, fast-forward it before starting. If it is dirty, checked out elsewhere, missing, or cannot fast-forward, report that clearly and prefer creating work from `origin/<default-branch>` rather than from an old local commit. For detached worktrees, verify whether `HEAD` is behind `origin/<default-branch>` before treating the worktree as a fresh base.

## Publishing durable agent changes

When changing agent skills, hooks, settings, or project guidance, prefer editing the source-of-truth files that can be committed. Installed or generated copies are deployment artifacts unless the user explicitly asks for a direct hotfix. After verifying the change, offer to commit and push it, or explicitly report where the unpushed change lives. Durable agent improvements should not end the task stuck only in a local worktree.
