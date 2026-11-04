# herdr-desktop-config

Como eu configuro o [Herdr](https://herdr.dev) desktop no Mac: atalhos, layouts,
um mod próprio para pular para o agente que precisa de mim e a sidebar
organizada em pastas. Dá para reproduzir tudo na sua máquina com um comando.

## As peças

| peça | arquivo | o que faz |
|---|---|---|
| atalhos | `config/keys.json` | atalhos globais, de terminal e uma seção só do layout `main-folders` |
| settings | `config/settings.json` | zoom 0.9, tema escuro, sons ligados |
| layout `ary` | `config/layouts/ary.json` | o layout `main` com a sidebar padrão (spaces + agents) |
| layout `main-folders` | `config/layouts/main-folders.json` | igual ao `ary`, mas a lista de spaces vira o mod `space-folders` |
| mod `next-needed` | `mods/next-needed/` | ⌘J foca o próximo agente que precisa de você |
| mod `space-folders` | clonado pelo `install.sh` | sidebar em pastas, de [jankeesvw/herdr-space-folders](https://github.com/jankeesvw/herdr-space-folders) (MIT), commit `63a78b2`. O código não está neste repo |
| pastas automáticas | `space-folders/auto-pastas.sh` | cria uma pasta por projeto a partir de uma lista que você edita |

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
| ⌘⌥[ / ⌘⌥] | space anterior / próximo |
| ⌥↑ / ⌥↓ | space anterior / próximo **na ordem das pastas** (só no layout `main-folders`) |
| ⌘⇧L | troca de layout (`layout.switch`) |
| ⌘[ / ⌘] | agente anterior / próximo |
| ⌘B | mostra/esconde a sidebar |
| ⌘D / ⌘⇧D | divide o pane à direita / abaixo |
| ⌘W / ⌘⇧W | fecha o pane / a tab |

O resto está em `config/keys.json`.

## Instalar

Pré-requisitos: Herdr desktop com `herdr-app` no PATH, `git` e, para as
pastas automáticas, `jq`.

```bash
git clone https://github.com/aryrabelo/herdr-desktop-config.git
cd herdr-desktop-config
bash install.sh --dry-run   # mostra o que faria
bash install.sh             # instala
```

O `install.sh`:

1. faz backup do que vai sobrescrever em `~/.config/herdr-app/backup-<data>/`;
2. copia `keys.json`, `settings.json` e os dois layouts (apaga antes o
   destino, então um symlink do home-manager é trocado por arquivo);
3. copia o mod `next-needed` — **cópia, nunca symlink**: o Herdr não percebe
   mudança dentro de pasta de mod linkada;
4. clona o space-folders no commit `63a78b2` e copia para `mods/space-folders`;
5. roda `herdr-app check` em cada mod.

Outra pasta de config: `HERDR_APP_DIR=/caminho bash install.sh`.

Depois, ⌘⇧L e escolha `main-folders`.

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
     "path": "~/Sites/work-team", "match": "~/Sites/work-team"}
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

## Licença

MIT (`LICENSE`). O space-folders é de Jankees van Woezik, também MIT, e não é
redistribuído aqui.
