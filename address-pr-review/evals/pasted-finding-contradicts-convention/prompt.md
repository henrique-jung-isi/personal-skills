---
tags: [address-pr-review]
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

o revisor deixou esse comentário no PR 42, pode corrigir?

> **[Média] `set-mode` deveria recusar `auto` com o interlock engajado**
>
> Hoje o ACK de `set-mode` devolve `mode: auto` enquanto `info/mode` publica `manual` por causa do interlock, então o HMI mostra sucesso para um modo que não vale. Sugestão: devolver `status: false` enquanto o interlock estiver ativo.

Input files: make-fixture.sh
