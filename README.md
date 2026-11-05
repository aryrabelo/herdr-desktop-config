# herdr-desktop-config

Como eu configuro o [Herdr](https://herdr.dev) desktop no Mac: atalhos, layouts,
um mod próprio para pular para o agente que precisa de mim e a sidebar
organizada em pastas. Dá para reproduzir tudo na sua máquina com um comando.

## As peças

| peça | arquivo | o que faz |
|---|---|---|
| atalhos | `config/keys.json` | atalhos globais, de terminal e a seção `layout:ary` (⌘⌥] / ⌘⌥[ e ⌥⇧⌘] / ⌥⇧⌘[) |
| settings | `config/settings.json` | zoom 0.9, tema escuro, sons ligados |
| layout `ary` | `config/layouts/ary.json` | o layout `main` com a sidebar em pastas (`space-folders`), a barra de baixo `session-status` e o menu de terminal `ary-menu` |
| mod `next-needed` | `mods/next-needed/` | ⌘J foca o próximo agente que precisa de você |
| mod `session-status` | `mods/session-status/` | barra de baixo: o que o `workspace-status` mostra mais o resumo da sessão do agente em foco; passeio de agentes por prioridade (⌥⇧⌘] / ⌥⇧⌘[) |
| mod `ary-menu` | `mods/ary-menu/` | menu do botão direito no terminal: o `menu` do Herdr 0.1.13 com **Copy pane info** |
| mod `pane-head` | `mods/pane-head/` | opcional, instalado mas fora do layout: cabeçalho do pane com o nome do agente e o endereço no hc (`t2y`). Para usar, troque `"mod": "pane"` por `"mod": "pane-head"` no `ary.json` |
| mod `html-viewer` | não está no repo | abre `.html`/`.md` numa aba (veja "html-viewer" abaixo) |
| mod `space-folders` | `mods/space-folders/` | sidebar em pastas, de [jankeesvw/herdr-space-folders](https://github.com/jankeesvw/herdr-space-folders) (MIT), commit `63a78b20d5ed30d57166a3c7165a6eb558c3ef84`, com o `LICENSE` do autor junto e um patch nosso: o estado do PR da branch na linha do space (veja abaixo) |
| pastas automáticas | `space-folders/auto-pastas.sh` | cria uma pasta por projeto a partir de uma lista que você edita |
| `herdr-lane` | `bin/herdr-lane` + `agent/rules/herdr-lane.md` | manda trabalho para o agente omp de outro repo, num space do Herdr (instalado com symlink em `~/.local/bin` e `~/.omp/agent/rules`) |

### Estado do PR na linha do space

Cada space numa branch que não é `main`/`master` mostra o PR dela, lido com
`gh pr view --json number,state,isDraft,statusCheckRollup` na pasta do space:
o ícone de branch (worktree) ganha a cor e o fim da linha ganha `✓ #108`.

| estado | cor | sinal |
|---|---|---|
| merged | roxo forte (`#b16cff`) | `✓` |
| aberto, checks rodando | amarelo forte (`#ffc400`) | `●` |
| aberto, checks verdes | verde forte (`#22e05a`) | `✓` |
| aberto, algum check falhou | vermelho (`ansi1`) | `✗` |
| draft | apagado (`dim`) | `◌` |
| fechado | vermelho | `×` |

Sem PR, nada muda (ícone cinza). Cache por repo e branch, uma chamada ao `gh`
por vez e só com a janela em frente: checks rodando a cada 1 min, aberto a cada
3, sem PR a cada 5, merged/fechado a cada 30. O `gh` precisa estar logado na
conta dona do repo.

## A sidebar com pastas

```
┌──────────────────────────┬────────────────────────────────────────┐
│ ● ● ●   workspace        │ tab 1 │ tab 2 │ tab 3                   │
├──────────────────────────┤────────────────────────────────────────┤
│ ▾ Trabalho          (3)  │                                        │
│     api                  │                                        │
│     web            ●     │          pane do terminal              │
│     infra                │                                        │
│ ▾ Cliente A         (1)  │                                        │
│     landing              │                                        │
│ ▸ Pessoal           (4)  │  ← pasta fechada                       │
│ ▾ Avulso                 │                                        │
│     scratch              │                                        │
│ ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄ │  ← solte aqui para tirar da pasta      │
├──────────────────────────┤                                        │
│ AGENTS                   │                                        │
│   claude · web  blocked  │                                        │
│   codex  · api  done     │                                        │
├──────────────────────────┤────────────────────────────────────────┤
│ footer                   │ status                                 │
└──────────────────────────┴────────────────────────────────────────┘
```

Cada space cai na pasta cuja regra (`match`) casa com a pasta onde o terminal
dele está agora. Arrastar um space para uma pasta vence qualquer regra.

## Atalhos que importam

| atalho | ação |
|---|---|
| ⌘J | pula para o próximo agente que precisa de você: primeiro os `blocked`, depois os `done`; apertar de novo passa para o seguinte |
| ⌘⌥[ / ⌘⌥] | space anterior / próximo **na ordem das pastas** (pula pasta dobrada) |
| ⌥⇧⌘[ / ⌥⇧⌘] | agente anterior / próximo por prioridade: blocked > done > idle > working |
| ⌘⇧L | troca de layout (`layout.switch`) |
| ⌘[ / ⌘] | agente anterior / próximo |
| ⌘B | mostra/esconde a sidebar |
| ⌘D / ⌘⇧D | divide o pane à direita / abaixo |
| ⌘W / ⌘⇧W | fecha o pane / a tab |

O resto está em `config/keys.json`.

## Instalar

Pré-requisitos: Herdr desktop com `herdr-app` no PATH e, para as pastas
automáticas, `jq`. O `html-viewer` precisa de `git` e rede (sem eles o resto instala).

```bash
git clone https://github.com/aryrabelo/herdr-desktop-config.git
cd herdr-desktop-config
bash install.sh --dry-run   # mostra o que faria
bash install.sh             # instala
```

O `install.sh`:

1. faz backup do que vai sobrescrever em `~/.config/herdr-app/backup-<data>/`;
2. copia `keys.json`, `settings.json` e o layout `ary` (apaga antes o
   destino, então um symlink do home-manager é trocado por arquivo);
3. copia os mods `next-needed`, `session-status`, `ary-menu`, `pane-head` e
   `space-folders` de `mods/` — **cópia, nunca symlink**: o Herdr não percebe
   mudança dentro de pasta de mod linkada;
4. baixa o `html-viewer` (veja abaixo) e copia o mod dele;
5. roda `herdr-app check` em cada mod.

Outra pasta de config: `HERDR_APP_DIR=/caminho bash install.sh`.

Com [`just`](https://github.com/casey/just): `just update` aplica tudo que
estiver no repo (é o `install.sh`), `just dry-run` só mostra e `just test`
roda o teste do `herdr-lane`.

Depois, ⌘⇧L e escolha `ary`.

O layout `main-folders` saiu: o `ary` já usa o `space-folders`, e dois layouts
iguais só davam dois lugares para manter. Quem tinha `main-folders.json`
instalado fica com o arquivo antigo; pode apagá-lo.

Editar um mod: edite aqui e rode `just update` (ou edite em
`~/.config/herdr-app/mods/` e traga de volta). Mais em `AGENTS.md`.

### html-viewer

[frizynn/html-viewer](https://github.com/frizynn/html-viewer) abre `.html` ou
`.md` numa aba: um Chrome headless desenha a página (com JS) e a aba recebe a
imagem, só leitura. Precisa de Node 22+ e Chrome.

```bash
herdr-app do tab.new '{"mod":"html-viewer","props":{"file":"~/x.html"}}'
```

O upstream não tem licença, então ele **não é redistribuído** aqui: o
`install.sh` clona o commit `84f56798735fc59be467cd9f3942e98f257d3908` em
`${XDG_CACHE_HOME:-~/.cache}/herdr-desktop-config/` e copia o mod de lá. Sem
rede, avisa e segue.

## Pastas automáticas

Edite a lista `NEW` em `space-folders/auto-pastas.sh` (nome, cor, pasta de
início e regra) e rode:

```bash
bash space-folders/auto-pastas.sh --dry-run
bash space-folders/auto-pastas.sh
```

O script só acrescenta pastas que faltam (compara nome sem acento nem caixa)
e faz backup de `~/.config/herdr-space-folders.json` antes de gravar.

Formato desse arquivo:

```json
{
  "list": [
    {"id": "fauto1", "name": "Trabalho", "folded": false, "color": "ansi4",
     "path": "~/code/trabalho", "match": "~/code/trabalho"}
  ],
  "of": {"<id do space>": "<id da pasta>"},
  "at": 1793812463000
}
```

- `list`: as pastas na ordem da sidebar. `color` é `ansi1..ansi6`, `#hex` ou
  `null`. `match` são regras separadas por vírgula: `~` vale qualquer home,
  `*` vale um nome de pasta, e uma regra sem `/` nem `~` no começo casa um
  nome de pasta em qualquer profundidade. Se duas casam, vence a mais funda.
- `of`: o que você arrastou à mão (`""` = fora de pasta). Arrasto vence regra.
- `at`: milissegundos desde a epoch. **Tem que ser maior que o atual**, senão
  o mod ignora o arquivo e fica com a cópia em memória. Por isso restaurar um
  backup com `mv` não desfaz nada; suba o `at` antes:
  `jq --argjson now "$(($(date +%s)*1000))" '.at = $now'`.

O mod relê o arquivo em até 15 s. Pela tela: botão direito na pasta (cor,
**Edit folder…**, **Delete**), arraste spaces para dentro ou para a faixa
tracejada, arraste pastas para reordenar.

## Voltar ao padrão

```bash
herdr-app do layout.switch --name main
```

Isso volta para a sidebar original do Herdr. Para desfazer tudo, copie de
volta os arquivos de `~/.config/herdr-app/backup-<data>/` e apague
`~/.config/herdr-app/mods/next-needed` e `mods/space-folders`.

## Armadilha: app aberto de um pane morre quando o pane fecha

O Herdr manda SIGHUP para todo processo com o `HC_TERMINAL_ID` do terminal que
fecha, e o `open` repassa esse ambiente ao app. App GUI aberto de dentro de um
pane deve ir com `env -i HOME="$HOME" /usr/bin/open …`.

## herdr-lane

Uma sessão omp lê em qualquer lugar e só escreve no próprio repo (a lane, raiz
git do cwd). Para escrever em outro repo, ela escreve um brief na pasta de
notas (`notes_dir` do config, abaixo), por exemplo
`~/notes/2026-11-05-alfa-to-web-corrige-login.md`, e chama:

```bash
herdr-lane <caminho alvo> --brief-file <brief> --from <lane> [--dry-run]
```

O `herdr-lane` reaproveita um agente parado naquele repo (`hc send`) ou abre
um space novo `<repo>·<slug>` com `herdr-app do space.new --folder <raiz>
--argv <agent_argv> --task "Leia <brief> e execute"`. Exits 0/1/2/3/4 e o
JSON de uma linha estão no cabeçalho do script.

### Config

O que é de cada máquina fica num arquivo fora do repo:
`${HERDR_LANE_CONFIG:-~/.config/herdr-lane/config}`. Sem ele, valem os
padrões.

```
# argv do agente no space.new (array JSON de strings; padrão ["omp"])
agent_argv=["omp"]
# onde os briefs ficam; só aparece no uso e nas mensagens de erro
notes_dir=~/notes
```

- Uma linha `chave=valor` por opção; linha que começa com `#` é comentário e
  chave desconhecida é ignorada.
- O arquivo é lido linha a linha, nunca com `source`: `$(…)` nele é texto.
- `agent_argv` que não é um array JSON não vazio de strings → exit 2,
  dizendo de onde veio o valor.
- `HERDR_LANE_AGENT_ARGV` vence o arquivo (vazia = não definida).
- O `notes_dir` não tem padrão. O brief continua explícito em `--brief-file`;
  `herdr-lane --help` mostra a pasta.

O arquivo é de config e não de shell porque o `herdr-lane` roda sob agente, e
lá `.envrc` e variável de shell não chegam de forma confiável.

### Links globais

`just update` cria `~/.local/bin/herdr-lane`, o alias
`~/.local/bin/bora-lane → herdr-lane` (nome antigo, por algumas semanas) e
`~/.omp/agent/rules/herdr-lane.md`, a regra que ensina o agente a usar o
script. Os três são symlink para este repo. Um destino que já existe só é
trocado se for symlink "nosso": para a própria origem, para `herdr-lane`, para
`/nix/store/…` ou para um caminho que case com o glob `HERDR_LANE_ADOPT_FROM`
(vazio por padrão; ex.: `HERDR_LANE_ADOPT_FROM='*/meus-dotfiles/*'`). O resto é
avisado e pulado. As pastas mudam com `HERDR_LANE_BIN_DIR` e
`HERDR_LANE_RULES_DIR`.

### Os porquês

- **O nome do space é o assunto.** Com `--brief-file`, o slug é o nome do
  brief sem a data e sem o `<from>-to-<repo>-` (até 48 caracteres, cortado num
  `-`). Sem slug, ou com `--brief` em texto, vira `de-<from>`. No reuso o space
  não é renomeado.
- **O brief entra pelo argv (`--task`), não por colagem.** Chega ao omp como
  mensagem do usuário, sem corrida. Um `hc send` chega como
  `<hc from="tNN">…</hc>`, que um agente desconfiado pode tratar como relato e
  não como ordem. Por isso `--brief` que começa com `-` é exit 2: o omp leria
  como flag.
- **Idle da partida.** Logo depois do `space.new` o hc diz `idle`/`turn 0` por
  uns 2 s. Um `hc wait` nessa janela volta na hora. O `herdr-lane` só sai com
  0 depois de ver o turno começar (`turn` sobe ou `working`); no reuso guarda o
  `turn` de antes do send, porque o `done` do turno anterior ainda aparece.
  Espera até `HERDR_LANE_START_S` (90 s; `BORA_LANE_START_S` ainda vale).
- **Principal × worktree linkada.** `--git-dir` igual a `--git-common-dir` é
  checkout principal: reusa agente `idle` (antes) ou `done` com cwd na raiz.
  Worktree linkada é território de uma tarefa: qualquer agente lá → exit 3.
  Agente `working` no repo também → exit 3; quem decide é o humano.
- **"Agente no repo" é cwd na raiz ou num subdiretório cujo toplevel é a
  raiz.** Prefixo de caminho erra com worktree aninhada (`<repo>/.wt/x`).
- **`hc ls` é lido por `\x1f`, não TAB**: terminal sem name colapsaria dois
  TABs no `read` e deslocaria as colunas.
- **As recusas mantêm `[repo-lane:...]`**: a extensão `repo-lane.ts` do omp
  depende desse prefixo.
- **Só lê o disco** (`git rev-parse`) e fala com os sockets do hc/herdr-app:
  roda sob o sandbox sem write.

Teste: `just test` (`hc` e `herdr-app` falsos, repos git reais numa fixture em
`${TMPDIR:-/tmp}` com `mktemp -d`, config do herdr-lane da fixture, nunca o
real, e um mutante por ramo, morto pelo nome).

## Licença

MIT (`LICENSE`). O `mods/space-folders/` é de Jankees van Woezik, também MIT,
redistribuído com o `LICENSE` original dentro da pasta e um patch nosso (estado
do PR), marcado no código. `mods/pane-head/` e `mods/ary-menu/` partem dos mods
`pane` e `menu` que vêm com o Herdr. O `html-viewer` não é redistribuído.
