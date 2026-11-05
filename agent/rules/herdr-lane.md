---
description: "Como mandar trabalho pra outro repo com o herdr-lane. Ler ANTES de escrever/criar/mover qualquer coisa fora do repo atual, sempre que uma escrita falhar com Operation not permitted / EPERM ou for recusada com [repo-lane:...], e antes de despachar trabalho pra outro repo."
---

# herdr-lane: o trabalho em outro repo vai pro agente daquele repo

Escrita fora da tua lane (raiz git do cwd) falha por design: `EPERM` ou
`[repo-lane:...]` não é bug e não é pra contornar (nada de outro caminho,
`sudo`, symlink, `git -C <outro repo>`, subagente escrevendo por você). Faça:

1. Escreva o brief (o quê, onde, critério de pronto) em
   `~/Sites/.agent-notes/YYYY-MM-DD-<tua lane>-to-<repo>-<slug>.md`.
2. `herdr-lane <caminho alvo> --brief-file <brief> --from <tua lane>`
   (`--dry-run` mostra o que faria sem criar nada). Ele abre (ou reaproveita)
   um agente omp num space do Herdr desktop na raiz daquele repo.
3. Pelo exit:
   - **0**: diga ao Ary em UMA linha o que abriu (repo → agente, `pane` do JSON).
   - **3** (agente `working` lá, ou worktree linkada de outra tarefa): pare e
     pergunte ao Ary, nomeando o `pane` do JSON.
   - **4**: o alvo é a tua lane; escreva você.
   - **2**: uso errado ou caminho fora de repo git; corrija ou pergunte.
   - **1**: o hc/herdr-app falhou ou o agente não começou; a mensagem nomeia
     space e terminal (o space fica aberto). Mostre ao Ary.
4. Acompanhe com `hc wait <agent> --timeout 3600` num bash com `async: true`.
   `"reason":"timeout"` é só check-in: rode de novo. Outro reason = o agente
   parou (done/idle/blocked/exited).
5. `hc read <agent> --lines 80` mostra a tela dele; `hc send <agent> "<texto>"`
   manda mais texto (exit 9 = ele está bloqueado esperando resposta).
6. Subagente nunca chama `herdr-lane`: devolve ao pai o caminho e o motivo, e o
   pai despacha.
7. O slug do nome do brief vira o nome do space (`<repo>·<slug>`; sem a data e
   sem o `<lane>-to-<repo>-`). Escolha um slug que diga o assunto.

`bora-lane` é o nome antigo (alias por algumas semanas). Script e porquês:
`~/Sites/personal-team/herdr-desktop-config` (`bin/herdr-lane`, README).
