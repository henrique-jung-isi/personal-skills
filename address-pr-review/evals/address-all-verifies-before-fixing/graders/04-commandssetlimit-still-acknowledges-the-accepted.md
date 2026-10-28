---
type: llm
focus: trace
weight: 1
---

Commands::set_limit still acknowledges the accepted limit (the ACK is not changed to the effective value and limits above the cap are not rejected), and the final answer cites docs/api.md as the reason
