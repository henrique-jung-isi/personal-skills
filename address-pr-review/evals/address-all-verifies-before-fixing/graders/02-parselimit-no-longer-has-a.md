---
type: llm
focus: trace
weight: 1
---

parse_limit no longer has a raw output parameter: it returns std::optional<int> (or an equivalent named result) and its callers use it
