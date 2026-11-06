# herdr-desktop-config — notas para agentes

Este repo é a **única fonte** da config do Herdr desktop (`~/.config/herdr-app`).
Nada mais linka arquivo do Herdr; cada máquina roda `just update` (= `bash install.sh`).
Repo público: nada de token, host privado ou nome de cliente.

## Editar

- Mod instalado é **cópia**, não symlink (o Herdr não percebe mudança dentro de
  pasta linkada). Editar = editar aqui e `just update`; ou editar em
  `~/.config/herdr-app/mods/<nome>/` para testar e trazer de volta para cá.
- `herdr-app check <pasta do mod>` grava `jsconfig.json` e `gpui-kit.d.ts` na
  pasta; em `mods/*/` o `.gitignore` já os ignora.
- Uma sessão omp não grava em `~/.config` (fora da lane). Monte o comando
  (`just dry-run` primeiro) e entregue ao humano.
- Rode `just test` antes de dizer que terminou: lógica do `pane-head` e do
  `space-folders`, `herdr-lane` com mutantes e um install numa config falsa.
  Documentação não é testada.

## session-status (barra de baixo do `ary`)

Substitui o `workspace-status` do Herdr: mesma informação (máquina, branch,
agentes, atalho da paleta) e, no meio, o resumo da sessão do agente em foco.

- O resumo vem do título do terminal (`agents()[i].title`). O omp põe
  `π <spinner|>> <ícone> TAG: resumo`; o mod mostra a `TAG` num selo e o resumo
  ao lado, com a bolinha da cor do status. Título sem `TAG:` aparece inteiro.
- Agente mostrado: o do pane em foco; se não for agente, o que mudou por
  último na tab em foco.
- **Passeio de agentes por prioridade**: `session-status.agent-next`/`agent-prev`
  (`keys.json`, `layout:ary`: ⌥⇧⌘] / ⌥⇧⌘[). Ordem blocked > done > idle >
  working, e dentro de cada grupo a de `agents()`. O primeiro aperto congela a
  ordem (olhar um `done` o vira `idle`; reordenar pularia os outros `done`); ela
  vale enquanto o foco está no agente aonde o último aperto levou, por até 30 s.
  Mora neste mod porque `<mod>.<command>` só chega à cópia viva na tela, e esta
  barra está sempre no `ary`.

## ary-menu (botão direito no pane)

`terminal_menu` do `ary` aponta para `mods/ary-menu/`, cópia do `menu` do Herdr
0.1.13 com **Copy pane info**: endereço do terminal (`t1v`), programa, status,
título da sessão, pasta, space/tab e os comandos `hc send|read|wait <endereço>`.

- `terminal_menu` troca o menu inteiro; menus de tab e space seguem o `menu`
  do Herdr. Herdr novo pode mudar o `menu`: compare antes de atualizar a cópia.
- O clipboard vai por `exec("/bin/sh", ["-c", 'printf %s "$1" | pbcopy', "sh",
  texto])`: o texto entra como argumento, nunca no script. `exec` não tem stdin.

## space-folders

Pastas em `~/.config/herdr-space-folders.json`; formato, o `at` que precisa
subir e o `bin/auto-pastas.sh` estão no README. Os únicos comandos do mod
são `space-folders.next`/`prev` (navegar); nenhum muda a pasta de um space.

## App GUI aberto de um pane

Vai com `env -i HOME="$HOME" /usr/bin/open …`, senão morre quando o pane fecha
(porquê no README, "Armadilha").
