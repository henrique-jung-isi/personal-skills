# personal-skills

A personal collection of reusable skills for coding agents, focused on Git workflows,
GitHub pull requests, and implementing plans with delegated agents. Some skills are
inspired by other open-source projects.

Each skill lives in its own directory and defines its workflow in `SKILL.md`.
The skills work with both Codex and Claude Code. Most also include Codex metadata in
`agents/openai.yaml`, which Claude Code ignores.

## Available skills

| Skill | Purpose |
| --- | --- |
| [address-pr-review](address-pr-review/SKILL.md) | Collect PR review comments, verify findings against the current code, fix accepted findings, and draft a grouped reply. Also supports checking comments without editing. |
| [btw](btw/SKILL.md) | Answer a quick side question using only existing conversation context, without tools or file reads. |
| [execute-plan-with-agents](execute-plan-with-agents/SKILL.md) | Implement a supplied plan through delegated agents, with dependency-aware stages, validation, focused commits, and a final review. |
| [github-pr](github-pr/SKILL.md) | Write PR titles and descriptions from changes already published on the intended remote branch, then create or update a PR when authorized. |
| [rebase-main](rebase-main/SKILL.md) | Rebase the current branch onto the latest remote `main`, preserve local work, resolve conflicts, and incorporate integration fixes into existing branch commits. |
| [squash-into-commits](squash-into-commits/SKILL.md) | Incorporate requested local changes into the existing branch commits responsible for them, including older commits, without adding repair commits. |

`squash-into-commits` distributes local changes across existing commits; it does not
combine a series of commits into one. `github-pr` requires a clean working tree and
a remote head matching local `HEAD`; it does not commit or push changes for you.

## Install for Codex

Codex discovers personal skills in `~/.agents/skills` and repository skills in
`.agents/skills`. It also supports symlinked skill directories. See the
[official OpenAI documentation](https://learn.chatgpt.com/docs/build-skills)
for discovery and invocation details.

Clone the collection and link the skills you want to use. For example, on a Unix-like shell:

```bash
git clone https://github.com/henrique-jung-isi/personal-skills.git
mkdir -p "$HOME/.agents/skills"
ln -s "$PWD/personal-skills/rebase-main" "$HOME/.agents/skills/rebase-main"
```

Repeat the last command with another skill name to install more skills. If you
prefer copies, copy each selected skill's entire directory into `~/.agents/skills`.
For a repository-specific installation, place those directories under that
repository's `.agents/skills` instead.

Keep any existing skill with the same name in mind before installing. Codex detects
skill changes automatically; restart it if a newly installed skill does not appear.

## Install for Claude Code

Claude Code discovers personal skills in `~/.claude/skills` and project skills in
`.claude/skills`, one directory per skill containing a `SKILL.md`. See the
[official Claude Code documentation](https://docs.claude.com/en/docs/claude-code/skills)
for discovery and invocation details.

Link the skills you want to use, the same way as for Codex:

```bash
mkdir -p "$HOME/.claude/skills"
ln -s "$PWD/personal-skills/rebase-main" "$HOME/.claude/skills/rebase-main"
```

To share one installation between both agents, link the whole Claude Code skills
directory to the Codex one (only if `~/.claude/skills` does not exist yet):

```bash
ln -s "$HOME/.agents/skills" "$HOME/.claude/skills"
```

For a project-specific installation, place the skill directories under that
project's `.claude/skills` instead. Claude Code picks up new skills when a session
starts; start a new session if a newly installed skill does not appear.

### Requirements

- A coding agent that can load `SKILL.md` instructions, such as Codex or Claude Code. The included UI metadata targets Codex.
- Git for repository workflows, and an authenticated GitHub CLI (`gh`) for the GitHub CLI steps.
- Python 3 for the optional [hunk-staging helper](address-pr-review/scripts/stage_hunks.py).
- Delegation support for `execute-plan-with-agents` (subagents in Claude Code), plus access to the models selected by its workflow.
- The target project's own build, formatting, and test tools when a workflow requires validation.

## Usage

### Codex

In Codex CLI or the IDE extension, mention a skill with `$skill-name` or select it
through `/skills`. Example prompts:

```text
Use $address-pr-review to check the review comments on this branch's PR.

Use $btw: which validation checks have already passed?

Use $execute-plan-with-agents to implement the plan in docs/implementation-plan.md.

Use $github-pr to write a description for this branch's published changes.

Use $rebase-main to rebase this branch onto origin/main.

Use $squash-into-commits to incorporate my local changes into their original commits.
```

`github-pr` and `rebase-main` disable implicit invocation in their Codex metadata,
so invoke them explicitly.

### Claude Code

In Claude Code, run a skill directly as a slash command with `/skill-name`, or describe
the task and let Claude load the matching skill from its description. Example prompts:

```text
/address-pr-review check the review comments on this branch's PR

/btw which validation checks have already passed?

/execute-plan-with-agents implement the plan in docs/implementation-plan.md

/github-pr write a description for this branch's published changes

/rebase-main

/squash-into-commits incorporate my local changes into their original commits
```

Claude Code does not read `agents/openai.yaml`, so `github-pr` and `rebase-main` also
set `disable-model-invocation: true` in their `SKILL.md` frontmatter. Invoke them
explicitly with `/github-pr` and `/rebase-main`.

Each skill defines its own rules for local changes,
history rewrites, and publishing; read its `SKILL.md` for the complete workflow.

## Repository layout

```text
<skill-name>/
├── SKILL.md             # Skill name, description, and workflow
├── agents/openai.yaml   # Optional Codex UI metadata and invocation policy (ignored by Claude Code)
├── scripts/             # Optional helper scripts
└── evals/               # Optional evaluation scenarios and graders
```

Currently, `address-pr-review` includes a hunk-staging helper and evaluation cases
for verifying findings, preserving read-only scope, and handling review claims
that contradict existing conventions. Each case includes a prompt, fixture setup,
and expected outcomes or graders.

To adapt a skill, edit its `SKILL.md` and keep any corresponding metadata and
evaluation cases aligned with the intended behavior.

## Credits and license

The PR description visuals in `github-pr` draw on Dex Horthy's `show-me` skill.
See [github-pr/CREDITS.md](github-pr/CREDITS.md) for attribution.

Licensed under [Apache License 2.0](LICENSE).
