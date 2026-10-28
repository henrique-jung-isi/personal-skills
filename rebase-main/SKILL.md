---
name: rebase-main
description: Rebase the current Git branch onto the latest remote main when requested. Preserve local work, resolve conflicts, and fix silent integration errors after the rebase by amending the relevant existing branch commits. Does not apply to requests explicitly choosing a merge or another base branch.
disable-model-invocation: true
---

# Rebase onto remote main

Complete the requested rebase in the current repository. A request to perform the rebase authorizes the local history rewrite and necessary conflict resolution; do not ask for redundant confirmation. A request to explain or preview a rebase does not authorize executing it. Creating this skill does not itself request a rebase.

## Establish the target and preserve work

- Read applicable `AGENTS.md` instructions. Inspect the current branch, worktree status, remotes, upstream, and any active Git operation before mutating anything. Do not interrupt an unrelated merge, cherry-pick, or rebase. Resume an existing rebase only when the user's request clearly covers it.
- Use the remote explicitly named by the user. Otherwise prefer `origin` when it contains the intended `main`; use another remote when repository configuration or context clearly identifies it. Ask only if the intended remote remains ambiguous. Do not silently substitute a different base when `main` is absent.
- Fetch `main` from the selected remote and update its remote-tracking ref explicitly, for example `git fetch origin +refs/heads/main:refs/remotes/origin/main`. If fetching fails, stop instead of rebasing onto a stale ref. Record the fetched target commit.
- Record the original branch, HEAD, merge base with the fetched target, and staged/unstaged/untracked state. Keep the original HEAD reachable through a unique local recovery ref, such as `refs/codex/rebase-backups/<unique-id>`, when a rewrite is needed. Report that ref at completion.
- If local changes prevent rebasing, preserve them with a uniquely named stash including untracked files as needed. Record its exact object ID and restore that entry specifically; do not assume `stash@{0}` still belongs to this task. Preserve staged state using `stash apply --index` where possible. Never discard user changes or make an unsolicited WIP commit.
- If HEAD is detached, establish which branch the user intends before rewriting. If already on local `main`, update it only by fast-forward to remote `main`; report divergence instead of rewriting local `main` commits by default.

## Rebase and resolve conflicts

Rebase the current branch onto the recorded target. Preserve existing merge topology with `--rebase-merges` when the branch contains meaningful merge commits. If the target is already an ancestor of HEAD, report that the branch is up to date without rewriting it.

For conflicts, inspect the replayed commit and surrounding code. Preserve the intent of both the branch and the updated base. Follow repository documentation for the affected areas. During a rebase, `ours` refers to the updated base plus already replayed commits, and `theirs` to the commit being replayed; do not select either side indiscriminately. Stage only resolved paths and continue until complete.

Do not skip commits merely to clear conflicts or use hard resets to force completion. Accept an empty commit being dropped only after verifying that its intended change is already present. If a resolution requires an unknown product decision, keep the recoverable state, explain the concrete conflict, and ask for that decision. If the same failure repeats without new evidence, stop retrying and report the blocking cause and recovery details.

## Fix silent integration errors after the rebase

A conflict-free rebase can still leave incompatible code or data. Complete the initial rebase before editing to correct errors that Git did not flag as conflicts, such as calls to a changed function signature or migration numbering collisions. Then inspect integration-sensitive changes and run the required validation against the rebased branch. Fix demonstrated incompatibilities caused by integrating remote `main`; keep unrelated repairs outside this task.

For migration collisions, follow the repository's migration rules and adjust this branch's new migrations and their dependent references consistently. Preserve migrations already published on remote `main`; do not renumber or rewrite them to accommodate the branch.

Incorporate every integration fix into an existing commit of the current branch that changed the affected file. Inspect file history and commit diffs in the branch-only range above the recorded remote target, following renames when relevant. Prefer the commit responsible for the affected code or migration, rather than automatically choosing the newest commit touching the file. Split fixes by their appropriate target commits, including by hunk when one file requires fixes belonging to different commits. Never amend a commit belonging to remote `main`. If no branch commit changed the file, explain the mismatch and ask how to place that fix instead of silently adding a new commit or changing an unrelated one.

Use `git commit --amend --no-edit` when the relevant commit is HEAD. Otherwise use an interactive rebase onto the same recorded target, mark the relevant existing commits for `edit`, amend each stopped commit, and replay the remaining commits. Preserve meaningful merge topology. Plan and retain the corrections before starting that history edit, with a recoverable copy outside the worktree if needed; apply each correction at its appropriate stop, adapting it to that commit's state. Resolve replay conflicts while preserving the intended fixes and later changes.

Do not create standalone repair commits or temporary fixup commits. Preserve the existing commit messages and authors unless the user requests otherwise, and do not add coauthor trailers. This additional local history rewrite is part of the requested workflow and needs no redundant confirmation.

Keep pre-existing user changes separate from integration fixes and out of amended commits. If they were stashed, restore them only after integration fixes have been incorporated and the committed result validated, including when a rebase started by this task is aborted. If unrelated changes remained in the worktree, preserve them before history editing. Stash restoration can itself conflict: preserve the stash until restoration is verified, and explain any remaining conflicts. Drop only this task's stash after confirming successful restoration.

## Verify and report

- Verify that the recorded remote `main` commit is an ancestor of HEAD and that no rebase or unresolved conflict remains. Check status and compare the original and final commit series with `git range-diff` or equivalent inspection for lost or unintended changes. Confirm integration fixes landed in their intended existing branch commits and no additional repair commits remain. Account for preserved merge topology and explain any commits legitimately dropped as already applied.
- Run the repository's required validation, especially after conflict resolution; for `smagbox-backend` follow `.docs/build-and-validation.md`. Report failures and unavailable checks accurately. Preserve pre-existing local changes during validation.
- Report the branch, remote/base, resolved conflicts, silent integration fixes and the existing commits amended to contain them, validation outcome, local-work restoration, and recovery ref concisely.
- Push only when the user also authorizes publishing. If rewriting an existing remote branch, use `--force-with-lease` tied to a recorded remote branch tip. Never use plain `--force`; if the lease fails, inspect the remote change and stop before overwriting someone else's work.
