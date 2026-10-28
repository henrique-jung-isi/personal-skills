#!/usr/bin/env python3
"""Stage selected hunks of one file without an interactive prompt.

  stage_hunks.py show  <file>            list hunks with their first changed lines
  stage_hunks.py apply <file> <i,j,...>  stage only the listed hunks (0-based)

Hunks come from `git diff -U3` against the index, so run `show` again after each
`apply`: indices shift once hunks are staged.
"""
import subprocess
import sys


def hunks(path):
    diff = subprocess.run(
        ["git", "diff", "-U3", "--", path], capture_output=True, text=True, check=True
    ).stdout
    lines = diff.splitlines(keepends=True)
    start = next((i for i, line in enumerate(lines) if line.startswith("@@")), None)
    if start is None:
        sys.exit(f"no unstaged changes in {path}")
    header, chunks = "".join(lines[:start]), []
    for line in lines[start:]:
        if line.startswith("@@"):
            chunks.append([line])
        else:
            chunks[-1].append(line)
    return header, ["".join(chunk) for chunk in chunks]


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in {"show", "apply"}:
        sys.exit(__doc__)
    header, chunks = hunks(sys.argv[2])
    if sys.argv[1] == "show":
        for index, chunk in enumerate(chunks):
            changed = [l.rstrip() for l in chunk.splitlines()[1:] if l[:1] in "+-"][:3]
            print(index, chunk.splitlines()[0], "|", " / ".join(c.strip() for c in changed))
        return
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    selected = [int(value) for value in sys.argv[3].split(",")]
    patch = header + "".join(chunks[index] for index in selected)
    result = subprocess.run(["git", "apply", "--cached", "--recount", "-"], input=patch, text=True)
    sys.exit(result.returncode)


if __name__ == "__main__":
    main()
