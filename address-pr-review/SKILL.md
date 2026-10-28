---
name: address-pr-review
description: Address review comments on a GitHub pull request end to end — fetch every review, inline thread and conversation comment, verify each finding against the actual code before acting, fix what holds up, defer what needs a decision, commit one finding per commit, and draft a single grouped reply. Use whenever the user asks to check, handle, answer, address, triage or "atender" PR comments or a code review, even when they only ask whether there are comments, or paste a review finding. Does not write PR descriptions (use the PR-description skill) and does not review code itself (use code-review).
---

# Address PR review comments

A review is input to weigh, not a list of orders. Reviewers work from the diff, from measurements and from their reading of the design; any of those can be stale or incomplete. The job is to find out which findings are true *in the current code*, fix those well, and explain the rest with evidence.

Loading this skill authorizes reading the PR and making local edits and commits. Pushing, posting comments, resolving threads and opening issues are visible to others: propose them, and do them only when the user asks.

## 1. Collect everything

Read applicable `AGENTS.md`/`CLAUDE.md` first: they define the validation pipeline, commit format and documents to consult per area.

Find the PR from the branch (a detached HEAD still has one): `gh pr list --search "$(git rev-parse HEAD)" --state all`. Then fetch all three comment sources — a review body often summarizes findings whose detail lives only in inline threads:

```bash
gh pr view <n> --json comments,reviews --jq '{comments: [.comments[] | {author: .author.login, createdAt, body}], reviews: [.reviews[] | {author: .author.login, state, submittedAt, body}]}'
gh api repos/<owner>/<repo>/pulls/<n>/comments --paginate --jq '.[] | {id, user: .user.login, path, line, created_at, in_reply_to_id, body}'
```

Keep each inline comment's `id`: the reply links to `<pr-url>#discussion_r<id>`. Note whether threads already have replies (`in_reply_to_id`) so settled ones are not reopened.

When the user only asked whether there are comments, do not edit anything, but still give each finding a quick pass of step 2 before describing it: a summary that repeats a stale number or a misread convention as fact sets up every later decision wrong. Then summarize the findings by severity with file links, say which look like local fixes, which need a decision and which rest on a premise that does not hold, and stop.

## 2. Verify each finding before touching code

This is the step that matters most. For every finding, open the code it cites and answer: is the claim true now, and is the proposed fix right?

- **Check the provenance of numbers.** A measurement, benchmark or estimate describes the code at the time it was taken. Compare its date or commit with later commits to the same area (`git log --date=short -- <paths>`). A benchmark that predates a behavior change can overstate a problem by orders of magnitude; say so instead of building on it.
- **Trace the real data path.** Confirm what actually feeds the structure being criticized, how often, and at what granularity — from the producer to the consumer, not from the reviewer's description.
- **Look for an existing convention.** Before "fixing" an inconsistency in a contract or API, search the docs and sibling features for the same pattern. If the project already documents that behavior elsewhere (an ACK that echoes the accepted preference while an info topic carries the effective state, for example), the finding is a documentation gap, not a bug — and changing it breaks symmetry and may remove a capability.
- **Follow the callers.** For exception-safety, `noexcept` or allocation findings, check whether the callers are themselves `noexcept`: removing `noexcept` then only moves `std::terminate` one level up, and the right fix is to stop allocating.
- **Weigh value against risk.** A correct fix with little practical effect (e.g. `bad_alloc` handling on an overcommitting Linux) can still be worth it if cheap, but report it as low value rather than as a resolved risk.

Classify each finding:

| Class | Meaning | Action |
| --- | --- | --- |
| Local fix | True, and the fix is contained and does not change agreed behavior | Implement |
| Needs decision | True or plausible, but the fix changes a contract, behavior in the field, a budget, or architecture | Do not implement; explain the options with a recommendation |
| Not accepted | False in the current code, or contradicts an established convention or scope decision | Explain why, with file or document evidence |
| Stale premise | Depends on data or code that no longer holds | Propose how to re-establish it (e.g. a new measurement) |

When verification overturns something already said to the user, say so plainly and correct the plan; do not keep defending the earlier reading.

## 3. Implement the local fixes

Follow the repository's layer, naming and documentation rules for each touched area. Keep each fix to its finding; unrelated cleanups go elsewhere.

- Add or adjust a test per behavioral fix, and make sure it would have failed before the change. When a new assertion fails, read why — the failure may reveal that the premise was subtly wrong (a value that changes for a legitimate reason, a second producer of the same event) and improve the fix itself.
- Update the docs and decision records that describe the changed behavior in the same change.
- Run the full validation pipeline from the repository instructions before committing. Run long suites in the background and do not report success before reading their summary.

## 4. Commit one finding per commit

Ask whether to commit if the user has not said so; once asked, group by finding, not by file. Write messages per the repository's commit rules, with the body carrying *why* — usually the reviewer's concern and why this fix answers it.

Files often mix several findings. To stage part of a file non-interactively:

- When the hunks separate cleanly, use `scripts/stage_hunks.py`: `show <file>` lists the hunks with their first changed lines; `apply <file> 0,2,5` stages only those hunks.
- When one hunk mixes two findings, build the intermediate file: start from `git show HEAD:<file>`, apply only that commit's edits, then stage it with `git hash-object -w` and `git update-index --cacheinfo 100644,<blob>,<path>`.
- Never run a formatter on a copy outside the repository: it will not find the project's config and will silently reformat the whole file, reflowing comments irreversibly. Write intermediate files already formatted, and check them with `clang-format --assume-filename=<repo path> --dry-run --Werror < file` or the project's equivalent.
- After staging, inspect `git diff --cached --stat`; a line count far larger than the fix means something reformatted the file.

Finally build every new commit in sequence (check each out, build, return to the branch) so each compiles on its own, and confirm the final tree matches the one that passed the full pipeline.

## 5. Re-audit before publishing

Before anything leaves the machine, go back over every commit with fresh eyes and ask whether the code still supports it, especially after later findings changed the picture. Drop or rework commits that do not hold up; while they are unpushed, remove them from history (`git rebase --onto <commit>^ <commit>`) instead of adding a revert, then rerun the pipeline. Tell the user what you are dropping and why before doing it.

## 6. Reply

Draft the reply in the language the review used. One PR comment, grouped:

- **Accepted** — table of finding (linked to its `#discussion_r<id>`), commit SHA, what changed; plus honest caveats about limited practical value.
- **Not accepted** — each with the reason and the evidence (convention, document, scope decision).
- **Open** — what is needed to decide, linking any issue created for it.

State the validation that ran (gate, build, test count, formatting). Do not reply thread by thread unless the user asks.

For deferred work, draft an issue with context (why the current data is not enough), the plan, the measurements or decision criteria, and inputs needed from the user as a checklist. Link files by commit permalink (`blob/<sha>/...`), not by branch name, so links survive the merge. Check available labels with `gh label list`.

When the user authorizes publishing: push with `git push -u origin <branch>` (use `--force-with-lease` only if history was rewritten after an earlier push), create the issue with `--body-file`, then post the comment with the issue number filled in. Report each URL.

## 7. Resolve threads

Resolving is visible to everyone, so propose which threads to resolve and wait for the user's go-ahead. A sensible default: resolve threads whose fix is pushed; leave not-accepted ones for the reviewer to close after reading the reason; leave open ones open until their decision lands.

REST has no resolve endpoint; use GraphQL. List threads with their state and permission, matching each to its finding by the first comment's `databaseId` (the `r<id>` in the discussion URL):

```bash
gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){nodes{id isResolved viewerCanResolve comments(first:1){nodes{databaseId}}}}}}}' -F o=<owner> -F r=<repo> -F n=<n>
gh api graphql -f query='mutation($t:ID!){resolveReviewThread(input:{threadId:$t}){thread{isResolved}}}' -F t=<thread-id>
```

`unresolveReviewThread` undoes it. Report which threads were resolved and which were left open, and why.
