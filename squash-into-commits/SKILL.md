---
name: squash-into-commits
description: Incorporate requested uncommitted changes or task corrections into the relevant existing commits of the current Git branch, including older commits, without adding repair or fixup commits. Use when asked to absorb changes into their original commits. Does not update the branch onto main or combine a series of existing commits into one.
---

# Incorporate changes into existing commits

Place each requested change in the existing branch commit responsible for the affected code. A request to perform this operation authorizes the necessary local history rewrite; do not ask for redundant confirmation. Merely loading, creating, explaining, or previewing this skill does not authorize rewriting history. Publishing requires separate authorization.

## Establish scope and recovery

- Read applicable `AGENTS.md` instructions. Inspect the current branch, status, staged and unstaged diffs, untracked files, remotes, upstream, and active Git operations. Do not interrupt an unrelated merge, cherry-pick, or rebase. Establish the intended branch before rewriting a detached HEAD.
- Identify exactly which changes the user wants incorporated. User-selected local changes are the input to this operation; preserve unrelated local work separately. If the request includes making corrections, keep those corrections within its scope. Ask only when the intended changes cannot be distinguished from unrelated work.
- Identify the branch's base from the user's request, repository configuration, or clear history evidence. An upstream tracking the feature branch is not necessarily its base. Record an immutable boundary commit and the eligible branch-only commits above it. Do not fetch or move onto a newer base merely to perform this operation. Ask if the eligible history remains ambiguous. Do not rewrite commits belonging to the base branch, or rewrite a shared base branch itself, by default.
- Record the original branch, HEAD, boundary, and local state. Before rewriting, retain HEAD through a unique recovery ref such as `refs/codex/squash-backups/<unique-id>`. Preserve the requested changes and unrelated work outside the worktree as needed, including binary and untracked content. Do not rely solely on a patch stored inside files that the rewrite may replace.
- If using a stash, name it uniquely and record its object ID. Restore that exact entry, preserving staged state with `stash apply --index` where possible. Never assume `stash@{0}` belongs to this task, discard local changes, or make an unsolicited WIP commit.

## Assign changes to commits

Inspect history and commit diffs within the eligible range, following renames when relevant. Prefer the commit responsible for the affected behavior over the newest commit touching the file. Map each change to its target commit before editing history; split by hunk when one file contains changes belonging to different commits.

Target an existing branch commit that changed the affected file. If no eligible commit changed it, explain the mismatch and ask how to place that change. Do not silently add a commit, amend base history, or select an unrelated commit. Respect explicit user-selected targets within the authorized range.

Retain a recoverable copy of each correction and the expected final result before removing selected changes from the worktree. Keep unrelated staged, unstaged, and untracked work out of amended commits. If there are no requested changes, report that no rewrite is needed.

## Amend and replay

When the only target is HEAD, stage only its assigned changes and use `git commit --amend --no-edit`. For older targets, use an interactive rebase from the recorded boundary, marking target commits for `edit`; apply their assigned changes at each stop and amend them. Do not rebase onto an updated remote tip. Preserve meaningful merge topology with `--rebase-merges`; target merge commits using the appropriate merge-aware todo edit rather than flattening them.

Adapt corrections to each stopped commit's state. A patch made against the final tree may depend on later changes; do not pull unrelated later code into an older commit merely to make it apply. If a correction cannot meaningfully belong to its planned target, reassess the mapping before continuing and ask when placement requires a user decision.

Preserve existing commit messages and authors unless the user requests otherwise or applicable repository instructions require a message change. Do not add coauthor trailers. Do not create standalone repair commits or temporary fixup commits, or squash existing commits together as a shortcut.

Resolve replay conflicts by inspecting the replayed commit and surrounding code, preserving both the correction and later intended changes. During rebase, `ours` is the already replayed history and `theirs` is the commit being replayed. Do not skip commits merely to clear conflicts or use hard resets to force completion. Drop an empty commit only after verifying its intent is already present and explain the drop. If the same failure repeats without new evidence, stop retrying and report the recoverable state. Preserve recovery artifacts when a user decision is needed.

## Verify and restore local work

Before restoring unrelated local work, verify the committed result: no active rebase or unresolved conflicts; the recorded boundary remains an ancestor; each correction is in its intended commit; no extra repair commits remain. Compare original and final series with `git range-diff` or equivalent inspection, accounting for merge topology. Inspect the final tree against the expected changes for lost or unintended content, and run the repository's required relevant validation. Report failed or unavailable checks accurately.

Restore unrelated local work after validating the committed result, including if an operation started by this task is aborted. Restore only changes that were not intentionally incorporated, so requested changes are not duplicated in the worktree. If restoration conflicts, keep the stash or other recovery copy and report the unresolved state. Drop only this task's stash after successful restoration is verified.

Report the branch, amended commits (old and new IDs), validation, local-work restoration, and recovery ref concisely. Push only when authorized. For an existing remote branch, record its remote tip before publishing and use `--force-with-lease` tied to that tip; never use plain `--force`. If the lease fails, inspect the remote change and stop before overwriting someone else's work.
