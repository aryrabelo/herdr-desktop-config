#!/usr/bin/env bash
# Exercita bin/herdr-lane (e os links globais do install.sh) contra um `hc` e um `herdr-app` FALSOS
# (HC_BIN/HERDR_APP_BIN: gravam o argv de cada chamada e respondem JSON
# enlatado) e repos git DE VERDADE numa fixture em ${TMPDIR:-/tmp} (mktemp -d):
# checkout principal, worktree linkada e uma worktree aninhada dentro do
# principal. Não fala com o Herdr real nem lê o config real do herdr-lane
# (cada caso aponta HERDR_LANE_CONFIG para a fixture).
#
# Two-sided: a suíte roda no script de verdade (tem que passar) e depois em
# MUTANTES, um por ramo crítico; cada um tem que reprovar ao menos um caso,
# nomeado na saída.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${SRC:-$REPO/bin/herdr-lane}"
INST_SRC="$REPO/install.sh"
T="$(mktemp -d "${TMPDIR:-/tmp}/herdr-lane-fixture-XXXXXX")"
T="$(cd "$T" && pwd -P)"
trap 'rm -rf "$T"' EXIT

g() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@" >/dev/null 2>&1; }
ALFA="$T/repos/alfa"         # checkout principal
WT="$T/repos/alfa-wt"        # worktree linkada do alfa
NINHO="$ALFA/.wt/ninho"      # worktree linkada DENTRO do alfa (outra lane)
BETA="$T/repos/beta"         # checkout principal sem agente
CHAMA="$T/repos/chamador"    # lane de quem chama
for r in "$ALFA" "$BETA" "$CHAMA"; do
  mkdir -p "$r" && g -C "$r" init -q && g -C "$r" commit -q --allow-empty -m init
done
mkdir -p "$ALFA/src"
mkdir -p "$ALFA/.git/info" && echo .wt >> "$ALFA/.git/info/exclude"
g -C "$ALFA" worktree add -q --detach "$WT"
g -C "$ALFA" worktree add -q --detach "$NINHO"
mkdir -p "$T/solto" "$T/notes"
ln -s "$BETA" "$T/link-beta"
echo "faz a coisa" > "$T/notes/brief.md"
echo "faz a coisa" > "$T/notes/2026-11-05-chamador-to-beta-merge-nomes-sidebar.md"
echo "faz a coisa" > "$T/notes/2026-11-05-ajuste-solto.md"
echo "faz a coisa" > "$T/notes/2026-11-05-chamador-to-beta-.md"
echo "faz a coisa" > "$T/notes/2026-11-05-chamador-to-beta-um-dois-tres-quatro-cinco-seis-sete-oito-nove-dez-onze.md"
# Configs do herdr-lane (o $T/sem-config não existe: valem os padrões).
CF="$T/configs"; mkdir -p "$CF"
printf '# argv do agente\nnotes_dir = ~/notes\nagent_argv = ["meu-agente"]\nchave_nova=ignorada\n' > "$CF/argv"
printf 'agent_argv=["meu-agente",1]\n' > "$CF/argv-numero"
printf 'agent_argv=meu-agente\n' > "$CF/argv-cru"
cat > "$CF/sem-source" <<EOF
\$(touch "$T/executou-linha")
notes_dir=\$(touch "$T/executou-valor")
\`touch "$T/executou-crase"\`
agent_argv=["meu-agente"]
EOF
# Cópia mínima do repo pro install.sh (o mutante troca só o install.sh dela).
RC_REPO="$T/repo-copia"
mkdir -p "$RC_REPO"
cp -R "$REPO/bin" "$REPO/agent" "$REPO/config" "$REPO/mods" "$RC_REPO/"
[ -f "$WT/.git" ] && [ -f "$NINHO/.git" ] && [ -d "$ALFA/.git" ] || { echo "FIXTURE QUEBRADA"; exit 1; }

mkdir -p "$T/stub"
# hc falso. `get` responde a linha N de $STUB_GET (N = chamada, presa na
# última): dá pra encenar idle/turn 0 → working. `send` sai $STUB_SEND_RC.
cat > "$T/stub/hc" <<'EOF'
#!/bin/bash
{ printf '[hc]'; printf '[%s]' "$@"; echo; } >> "$STUB_LOG"
case "$1" in
  ls) cat "$STUB_LS" ;;
  get)
    n="$(cat "$STUB_GETN" 2>/dev/null || echo 0)"; n=$((n + 1)); echo "$n" > "$STUB_GETN"
    total="$(grep -c . "$STUB_GET")"
    [ "$n" -le "$total" ] || n="$total"
    sed -n "${n}p" "$STUB_GET" ;;
  send)
    rc="${STUB_SEND_RC:-0}"
    [ "$rc" = 0 ] || { echo '{"error":"blocked"}' >&2; exit "$rc"; }
    echo '{"sent":true}' ;;
  *) echo "stub: chamada inesperada: $*" >&2; exit 99 ;;
esac
EOF
# herdr-app falso: `do space.new` responde $STUB_SPACE e sai $STUB_SPACE_RC.
cat > "$T/stub/herdr-app" <<'EOF'
#!/bin/bash
{ printf '[app]'; printf '[%s]' "$@"; echo; } >> "$STUB_LOG"
case "$1 $2" in
  "do space.new")
    if [ -n "${STUB_SPACE:-}" ]; then echo "$STUB_SPACE"; else echo '{"space":"sp9Z","tab":"tb9Z","terminal":"t9z"}'; fi
    exit "${STUB_SPACE_RC:-0}" ;;
  "check "*) exit 0 ;;
  *) echo "stub: chamada inesperada: $*" >&2; exit 99 ;;
esac
EOF
chmod +x "$T/stub/hc" "$T/stub/herdr-app"

# --- fixtures de `hc ls --json` (valores literais; só o cwd é o da fixture)
A="$T/agents"; mkdir -p "$A"
cat > "$A/vazio.json" <<'EOF'
{"terminals":[],"machines":[],"hidden_finished":0}
EOF
cat > "$A/alfa-idle.json" <<EOF
{"terminals":[
 {"address":"t5c","agent":"omp","name":"outro","state":"live","status":"working","turn":3,"cwd":"$CHAMA","where":"chamador / 1"},
 {"address":"t7a","agent":"omp","name":"alfa-velho","state":"live","status":"done","turn":4,"cwd":"$ALFA","where":"alfa / 1"},
 {"address":"t7s","agent":null,"name":null,"state":"live","status":null,"turn":0,"cwd":"$ALFA","where":"alfa / 3"},
 {"address":"t7x","agent":"omp","name":null,"state":"finished","status":"idle","turn":5,"cwd":"$ALFA","where":"alfa / 4"},
 {"address":"t7b","agent":"omp","name":null,"state":"live","status":"idle","turn":2,"cwd":"$ALFA","where":"alfa / 2"}
],"machines":[],"hidden_finished":0}
EOF
cat > "$A/alfa-done.json" <<EOF
{"terminals":[
 {"address":"t7a","agent":"omp","name":"alfa-velho","state":"live","status":"done","turn":4,"cwd":"$ALFA","where":"alfa / 1"}
],"machines":[],"hidden_finished":0}
EOF
cat > "$A/alfa-blocked.json" <<EOF
{"terminals":[
 {"address":"t7d","agent":"omp","name":"alfa-preso","state":"live","status":"blocked","turn":1,"cwd":"$ALFA","where":"alfa / 1"}
],"machines":[],"hidden_finished":0}
EOF
cat > "$A/alfa-working.json" <<EOF
{"terminals":[
 {"address":"t7b","agent":"omp","name":"alfa-livre","state":"live","status":"idle","turn":2,"cwd":"$ALFA","where":"alfa / 2"},
 {"address":"t7w","agent":"omp","name":"alfa-ocupado","state":"live","status":"working","turn":7,"cwd":"$ALFA","where":"alfa / 3"}
],"machines":[],"hidden_finished":0}
EOF
cat > "$A/alfa-working-sub.json" <<EOF
{"terminals":[
 {"address":"t7u","agent":"omp","name":"alfa-sub","state":"live","status":"working","turn":2,"cwd":"$ALFA/src","where":"alfa / 1"}
],"machines":[],"hidden_finished":0}
EOF
cat > "$A/ninho-working.json" <<EOF
{"terminals":[
 {"address":"t7n","agent":"omp","name":"ninho","state":"live","status":"working","turn":2,"cwd":"$NINHO","where":"ninho / 1"},
 {"address":"t7a","agent":"omp","name":"alfa-livre","state":"live","status":"idle","turn":2,"cwd":"$ALFA","where":"alfa / 1"}
],"machines":[],"hidden_finished":0}
EOF
cat > "$A/wt-idle.json" <<EOF
{"terminals":[
 {"address":"t8w","agent":"omp","name":"wt-dono","state":"live","status":"idle","turn":1,"cwd":"$WT","where":"alfa-wt / 1"}
],"machines":[],"hidden_finished":0}
EOF
cat > "$A/wt-livre.json" <<EOF
{"terminals":[
 {"address":"t7a","agent":"omp","name":"alfa-livre","state":"live","status":"idle","turn":2,"cwd":"$ALFA","where":"alfa / 1"},
 {"address":"t9s","agent":null,"name":null,"state":"live","status":null,"turn":0,"cwd":"$WT","where":"alfa-wt / 1"}
],"machines":[],"hidden_finished":0}
EOF
# --- respostas de `hc get --json`, uma por chamada (formato medido no hc 0.1.18)
G="$T/gets"; mkdir -p "$G"
# Reuso: 1ª linha = antes do send (turn 4); depois o turno novo já trabalha.
cat > "$G/reusado.json" <<'EOF'
{"status":{"app":"omp","state":"idle"},"turn":4,"name":null,"state":"live","labels":{"herdr.space":"sp7A","herdr.tab":"tb7A"}}
{"status":{"app":"omp","state":"working"},"turn":4,"name":null,"state":"live","labels":{"herdr.space":"sp7A","herdr.tab":"tb7A"}}
EOF
cat > "$G/sem-space.json" <<'EOF'
{"status":{"app":"omp","state":"idle"},"turn":4,"name":null,"state":"live","labels":{}}
{"status":{"app":"omp","state":"working"},"turn":4,"name":null,"state":"live","labels":{}}
EOF
# Reuso com o done do turno anterior ainda na tela logo depois do send.
cat > "$G/reusado-velho.json" <<'EOF'
{"status":{"app":"omp","state":"done"},"turn":4,"name":null,"state":"live","labels":{"herdr.space":"sp7A"}}
{"status":{"app":"omp","state":"done"},"turn":4,"name":null,"state":"live","labels":{"herdr.space":"sp7A"}}
{"status":{"app":"omp","state":"done"},"turn":5,"name":null,"state":"live","labels":{"herdr.space":"sp7A"}}
EOF
echo '{"status":{"app":"omp","state":"working"},"turn":0,"name":null,"state":"live","labels":{"herdr.space":"sp9Z"}}' > "$G/working.json"
cat > "$G/partida.json" <<'EOF'
{"status":{"app":"omp","state":"idle"},"turn":0,"name":null,"state":"live","labels":{"herdr.space":"sp9Z"}}
{"status":{"app":"omp","state":"idle"},"turn":0,"name":null,"state":"live","labels":{"herdr.space":"sp9Z"}}
{"status":{"app":"omp","state":"working"},"turn":0,"name":null,"state":"live","labels":{"herdr.space":"sp9Z"}}
EOF
echo '{"status":{"app":"omp","state":"done"},"turn":1,"name":null,"state":"live","labels":{"herdr.space":"sp9Z"}}' > "$G/turno1.json"
cat > "$G/bloqueado.json" <<'EOF'
{"status":{"app":"omp","state":"idle"},"turn":0,"name":null,"state":"live","labels":{"herdr.space":"sp9Z"}}
{"status":{"app":"omp","state":"blocked"},"turn":0,"name":null,"state":"live","labels":{"herdr.space":"sp9Z"}}
EOF
echo '{"status":{"app":"omp","state":"idle"},"turn":0,"name":null,"state":"live","labels":{"herdr.space":"sp9Z"}}' > "$G/parado.json"

# run <ls.json> <cwd> <args...>: RC, $C/out (stdout), $C/err (stderr), $C/log
# (argv do hc/herdr-app). Env do caso: GET=<arquivo em $G> (padrão
# working.json), START_S, SEND_RC, SPACE, SPACE_RC, CFG=<config do herdr-lane>
# (padrão $T/sem-config, que não existe), AGENT_ARGV (vira HERDR_LANE_AGENT_ARGV).
C="$T/caso"
run() {
  local agents="$1" cwd="$2"; shift 2
  rm -rf "$C"; mkdir -p "$C"; : > "$C/log"
  ( cd "$cwd" && env HOME="$T" HC_BIN="$T/stub/hc" HERDR_APP_BIN="$T/stub/herdr-app" \
      HERDR_LANE_CONFIG="${CFG:-$T/sem-config}" HERDR_LANE_AGENT_ARGV="${AGENT_ARGV:-}" \
      STUB_LOG="$C/log" STUB_LS="$A/$agents" STUB_GET="$G/${GET:-working.json}" STUB_GETN="$C/getn" \
      STUB_SEND_RC="${SEND_RC:-0}" STUB_SPACE="${SPACE:-}" STUB_SPACE_RC="${SPACE_RC:-0}" \
      "${LANE_PFX:-HERDR}_LANE_START_S=${START_S:-5}" "${LANE_PFX:-HERDR}_LANE_POLL_S=0" \
      GIT_CEILING_DIRECTORIES="$T" /bin/bash "$S" "$@" ) > "$C/out" 2> "$C/err"
  RC=$?
}
js() { jq -e "$@" "$C/out" >/dev/null 2>&1; }   # asserção jq sobre o stdout
calls() { grep -c . "$C/log"; }
has() { grep -qxF -- "$1" "$C/log"; }
nlog() { grep -cF -- "$1" "$C/log"; }          # quantas chamadas contêm $1

suite() { # $1 script, $2 install.sh; ecoa casos, retorna o número de falhas
  S="$1"; INST="${2:-$INST_SRC}"; local f=0
  ok() { echo "  ok — $1"; }
  no() { echo "  FALHOU [$1] — $2"; f=$((f + 1)); }

  GET=reusado.json run alfa-idle.json "$CHAMA" "$ALFA/src/novo.txt" --brief "faz y" --from chamador
  if [ "$RC" = 0 ] && js --arg r "$ALFA" '. == {repo_root:$r, workspace_id:"sp7A", pane:"t7b", agent:"t7b", reused:true}' \
     && has "[hc][ls][--json]" && has "[hc][get][t7b][--json]" && has "[hc][send][t7b][faz y]" \
     && [ "$(nlog '[hc][get][t7b]')" = 2 ] && [ "$(calls)" = 4 ]; then
    ok "reuse-idle: principal reusa o agente idle (idle antes de done; name null vira endereço; shell e terminal finished não contam; espera o turno do send começar)"
  else no reuse-idle "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  GET=reusado.json run alfa-done.json "$CHAMA" "$ALFA" --brief "faz y" --from chamador
  if [ "$RC" = 0 ] && js --arg r "$ALFA" '. == {repo_root:$r, workspace_id:"sp7A", pane:"t7a", agent:"alfa-velho", reused:true}' \
     && grep -qxF "herdr-lane: alfa → alfa-velho (t7a)" "$C/err"; then
    ok "reuse-done: sem idle, reusa o done e diz quem abriu no stderr"
  else no reuse-done "rc=$RC out=$(cat "$C/out") err=$(cat "$C/err")"; fi

  GET=reusado-velho.json run alfa-done.json "$CHAMA" "$ALFA" --brief "faz y" --from chamador
  if [ "$RC" = 0 ] && js '.reused == true and .pane == "t7a"' && [ "$(nlog '[hc][get][t7a]')" = 3 ]; then
    ok "reuse-turno-velho: o done do turno anterior não conta; espera o turn passar de 4 (3 hc get)"
  else no reuse-turno-velho "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  GET=sem-space.json run alfa-done.json "$CHAMA" "$ALFA" --brief "faz y" --from chamador
  if [ "$RC" = 0 ] && js '.workspace_id == null and .pane == "t7a" and .reused == true'; then
    ok "reuse-sem-space: hc get sem herdr.space → workspace_id null, segue despachado"
  else no reuse-sem-space "rc=$RC out=$(cat "$C/out") err=$(cat "$C/err")"; fi

  SEND_RC=9 GET=reusado.json run alfa-done.json "$CHAMA" "$ALFA" --brief "faz y" --from chamador
  if [ "$RC" = 1 ] && [ ! -s "$C/out" ] && grep -qF "hc send t7a falhou" "$C/err"; then
    ok "send-recusado: hc send recusa (exit 9, bloqueado) → exit 1"
  else no send-recusado "rc=$RC out=$(cat "$C/out") err=$(cat "$C/err")"; fi

  run vazio.json "$CHAMA" "$BETA/a/b/c.txt" --brief "faz z"
  if [ "$RC" = 0 ] \
     && js --arg r "$BETA" '. == {repo_root:$r, workspace_id:"sp9Z", pane:"t9z", agent:"t9z", reused:false}' \
     && has "[app][do][space.new][--name][beta·de-chamador][--folder][$BETA][--argv][[\"omp\"]][--task][faz z]" \
     && has "[hc][get][t9z][--json]" && [ "$(nlog '[hc][send]')" = 0 ] \
     && grep -qxF "herdr-lane: beta → t9z (t9z)" "$C/err"; then
    ok "create-none: space.new com --folder = raiz, --argv [\"omp\"], --task = prompt, label <repo>·de-<lane do chamador>"
  else no create-none "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  run alfa-blocked.json "$CHAMA" "$ALFA" --brief "faz y" --from chamador
  if [ "$RC" = 0 ] && js '.reused == false and .pane == "t9z"' && ! grep -q '\[t7d\]' "$C/log"; then
    ok "blocked-cria: agente blocked não é reusado"
  else no blocked-cria "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log")"; fi

  run alfa-working.json "$CHAMA" "$ALFA/src" --brief "faz y" --from chamador
  if [ "$RC" = 3 ] && js --arg r "$ALFA" '.refused == "busy" and .repo_root == $r and .pane == "t7w" and .agent == "alfa-ocupado" and .agent_status == "working"' \
     && grep -qF "[repo-lane:busy]" "$C/err" && [ "$(calls)" = 1 ]; then
    ok "busy: agente working no repo → exit 3 nomeando o terminal, mesmo havendo um idle"
  else no busy "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log")"; fi

  run alfa-working-sub.json "$CHAMA" "$ALFA" --brief "faz y" --from chamador
  if [ "$RC" = 3 ] && js '.refused == "busy" and .pane == "t7u"'; then
    ok "busy-subdir: agente working num subdiretório do repo conta como no repo"
  else no busy-subdir "rc=$RC out=$(cat "$C/out")"; fi

  GET=reusado.json run ninho-working.json "$CHAMA" "$ALFA" --brief "faz y" --from chamador
  if [ "$RC" = 0 ] && js '.reused == true and .pane == "t7a"'; then
    ok "ninho: agente working numa worktree aninhada dentro do repo é outra lane"
  else no ninho "rc=$RC out=$(cat "$C/out")"; fi

  run wt-idle.json "$CHAMA" "$WT/x.txt" --brief "faz y" --from chamador
  if [ "$RC" = 3 ] && js --arg r "$WT" '.refused == "worktree-occupied" and .repo_root == $r and .pane == "t8w"' \
     && grep -qF "[repo-lane:worktree-occupied]" "$C/err" && [ "$(calls)" = 1 ]; then
    ok "wt-ocupada: worktree linkada com agente (mesmo idle) → exit 3"
  else no wt-ocupada "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log")"; fi

  run wt-livre.json "$CHAMA" "$WT/x.txt" --brief "faz y" --from chamador
  if [ "$RC" = 0 ] && js --arg r "$WT" '.repo_root == $r and .reused == false and .pane == "t9z"' \
     && has "[app][do][space.new][--name][alfa-wt·de-chamador][--folder][$WT][--argv][[\"omp\"]][--task][faz y]"; then
    ok "wt-livre: worktree linkada sem agente (um shell aberto lá não conta) → space novo na raiz da worktree"
  else no wt-livre "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log")"; fi

  run vazio.json "$CHAMA" "$T/solto/nada/arquivo.txt" --brief "faz y" --from chamador
  if [ "$RC" = 2 ] && [ "$(calls)" = 0 ]; then
    ok "fora-de-repo: caminho fora de repo git → exit 2 sem falar com o hc"
  else no fora-de-repo "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log")"; fi

  run alfa-idle.json "$ALFA/src" "$ALFA/README.md" --brief "faz y"
  if [ "$RC" = 4 ] && grep -qF "[repo-lane:own-lane]" "$C/err" && [ "$(calls)" = 0 ]; then
    ok "own-lane: alvo na lane do chamador → exit 4"
  else no own-lane "rc=$RC out=$(cat "$C/out") err=$(cat "$C/err")"; fi

  GET=reusado.json run alfa-done.json "$WT" "$ALFA" --brief "faz y"
  if [ "$RC" = 0 ] && js '.reused == true and .pane == "t7a"'; then
    ok "wt-para-principal: chamador numa worktree linkada roteia pro principal (lanes distintas)"
  else no wt-para-principal "rc=$RC out=$(cat "$C/out") err=$(cat "$C/err")"; fi

  GET=partida.json run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$RC" = 0 ] && js '.pane == "t9z" and .reused == false' && [ "$(nlog '[hc][get][t9z]')" = 3 ]; then
    ok "partida: idle/turn 0 da partida não conta; espera até working (3 hc get)"
  else no partida "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  GET=turno1.json run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$RC" = 0 ] && js '.pane == "t9z"' && [ "$(nlog '[hc][get][t9z]')" = 1 ]; then
    ok "turno1: turno já fechado (done, turn 1) conta como começado"
  else no turno1 "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  GET=bloqueado.json run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$RC" = 1 ] && [ ! -s "$C/out" ] && grep -qF "bloqueado antes do turno" "$C/err" \
     && grep -qF "sp9Z" "$C/err" && grep -qF "t9z" "$C/err"; then
    ok "bloqueado-partida: blocked com turn 0 → exit 1 nomeando space e terminal"
  else no bloqueado-partida "rc=$RC out=$(cat "$C/out") err=$(cat "$C/err")"; fi

  START_S=0 GET=parado.json run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$RC" = 1 ] && [ ! -s "$C/out" ] && grep -qF "não começou o turno em 0s" "$C/err" \
     && grep -qF "sp9Z" "$C/err" && grep -qF "fica aberto" "$C/err"; then
    ok "nao-comeca: sem working/turn 1 em HERDR_LANE_START_S → exit 1, space fica aberto"
  else no nao-comeca "rc=$RC out=$(cat "$C/out") err=$(cat "$C/err")"; fi

  SPACE='{"error":"no window"}' run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  local r1="$RC" e1; e1="$(cat "$C/err")"
  SPACE='{"error":"x"}' SPACE_RC=1 run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$r1" = 1 ] && grep -qF "no window" <<<"$e1" && [ "$RC" = 1 ] && [ "$(nlog '[hc][get]')" = 0 ]; then
    ok "host-falha: space.new sem space/terminal, ou com exit≠0 → exit 1 com a resposta crua"
  else no host-falha "rc1=$r1 err1=$e1 rc=$RC err=$(cat "$C/err")"; fi

  run vazio.json "$CHAMA" "$BETA" --brief-file ../../notes/brief.md --from chamador
  if [ "$RC" = 0 ] && grep -qF -- "[--task][Leia $T/notes/brief.md e execute]" "$C/log"; then
    ok "brief-file: task vira 'Leia <arquivo absoluto> e execute'"
  else no brief-file "rc=$RC log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  run vazio.json "$CHAMA" "$BETA" --brief-file "$T/notes/nao-existe.md" --from chamador
  if [ "$RC" = 2 ] && [ "$(calls)" = 0 ]; then ok "brief-file-ausente: exit 2"
  else no brief-file-ausente "rc=$RC"; fi

  run vazio.json "$CHAMA" "$BETA" --brief "--faz z" --from chamador
  if [ "$RC" = 2 ] && [ "$(calls)" = 0 ] && grep -qF "começar com '-'" "$C/err"; then
    ok "brief-traco: --brief começando com '-' → exit 2 (o omp leria como flag)"
  else no brief-traco "rc=$RC log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  run vazio.json "$CHAMA" "$BETA" --from chamador
  local r2="$RC"
  run vazio.json "$CHAMA" "$BETA" --brief x --brief-file "$T/notes/brief.md"
  if [ "$r2" = 2 ] && [ "$RC" = 2 ] && [ "$(calls)" = 0 ]; then ok "uso: sem brief, ou com os dois → exit 2"
  else no uso "sem-brief rc=$r2, dois rc=$RC"; fi

  run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador --dry-run
  if [ "$RC" = 0 ] && js --arg r "$BETA" '. == {repo_root:$r, workspace_id:null, pane:null, agent:null, reused:false, dry_run:true}' \
     && [ "$(cat "$C/log")" = "[hc][ls][--json]" ] \
     && grep -qF "herdr-app do space.new --name" "$C/err" && grep -qF -- "--folder $BETA --argv" "$C/err"; then
    ok "dry-run: só lê (hc ls), imprime JSON e o space.new que rodaria"
  else no dry-run "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  GET=reusado.json run alfa-done.json "$CHAMA" "$ALFA" --brief "faz y" --from chamador --dry-run
  if [ "$RC" = 0 ] && js '.reused == true and .pane == "t7a" and .workspace_id == "sp7A" and .dry_run == true' \
     && [ "$(nlog '[hc][send]')" = 0 ] && [ "$(nlog '[app]')" = 0 ] && grep -qF "/hc send t7a" "$C/err"; then
    ok "dry-run-reuse: não manda o hc send"
  else no dry-run-reuse "rc=$RC out=$(cat "$C/out") log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  run alfa-working.json "$CHAMA" "$ALFA" --brief "faz y" --from chamador --dry-run
  if [ "$RC" = 3 ] && js '.refused == "busy"'; then
    ok "dry-run-recusa: recusas valem no dry-run"
  else no dry-run-recusa "rc=$RC out=$(cat "$C/out")"; fi

  run vazio.json "$CHAMA" "$T/link-beta/x.txt" --brief "faz z" --from chamador
  if [ "$RC" = 0 ] && js --arg r "$BETA" '.repo_root == $r'; then
    ok "symlink: caminho por symlink resolve pro repo real"
  else no symlink "rc=$RC out=$(cat "$C/out")"; fi

  run vazio.json "$CHAMA" "~/${BETA#"$T"/}/x.txt" --brief "faz z" --from chamador
  if [ "$RC" = 0 ] && js --arg r "$BETA" '.repo_root == $r'; then
    ok "til: '~/' literal vira \$HOME"
  else no til "rc=$RC out=$(cat "$C/out") err=$(cat "$C/err")"; fi

  local n
  slug_de() { # $1 arquivo em $T/notes → $n = o --name do space.new (vazio se não teve)
    run vazio.json "$CHAMA" "$BETA" --brief-file "$T/notes/$1" --from chamador
    n="$(sed -n 's/.*\[space.new\]\[--name\]\[\([^]]*\)\].*/\1/p' "$C/log")"
  }
  slug_de 2026-11-05-chamador-to-beta-merge-nomes-sidebar.md
  if [ "$RC" = 0 ] && [ "$n" = "beta·merge-nomes-sidebar" ]; then
    ok "slug: <data>-<from>-to-<repo>-<assunto>.md → <repo>·<assunto>"
  else no slug "rc=$RC name=$n err=$(cat "$C/err")"; fi

  slug_de 2026-11-05-ajuste-solto.md
  if [ "$RC" = 0 ] && [ "$n" = "beta·ajuste-solto" ]; then
    ok "slug-sem-prefixo: sem <from>-to-<repo>-, só tira a data"
  else no slug-sem-prefixo "rc=$RC name=$n"; fi

  slug_de 2026-11-05-chamador-to-beta-.md
  if [ "$RC" = 0 ] && [ "$n" = "beta·de-chamador" ]; then
    ok "slug-vazio: assunto vazio cai em de-<from>"
  else no slug-vazio "rc=$RC name=$n"; fi

  slug_de 2026-11-05-chamador-to-beta-um-dois-tres-quatro-cinco-seis-sete-oito-nove-dez-onze.md
  if [ "$RC" = 0 ] && [ "$n" = "beta·um-dois-tres-quatro-cinco-seis-sete-oito-nove" ]; then
    ok "slug-48: mais de 48 caracteres corta num '-'"
  else no slug-48 "rc=$RC name=$n"; fi

  GET=parado.json START_S=0 LANE_PFX=BORA run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$RC" = 1 ] && grep -qF "não começou o turno em 0s" "$C/err"; then
    ok "env-fallback: BORA_LANE_START_S/POLL_S ainda valem sem as HERDR_LANE_*"
  else no env-fallback "rc=$RC err=$(cat "$C/err")"; fi

  CFG="$CF/argv" run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$RC" = 0 ] && has "[app][do][space.new][--name][beta·de-chamador][--folder][$BETA][--argv][[\"meu-agente\"]][--task][faz z]"; then
    ok "config-argv: agent_argv do config vira o --argv do space.new (espaços e chave desconhecida não atrapalham)"
  else no config-argv "rc=$RC log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$RC" = 0 ] && [ "$(nlog '[--argv][["omp"]]')" = 1 ]; then
    ok "config-padrao: sem arquivo de config, o --argv é [\"omp\"]"
  else no config-padrao "rc=$RC log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  local r3 e3 c3
  CFG="$CF/argv-numero" run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  r3="$RC" e3="$(cat "$C/err")" c3="$(calls)"
  CFG="$CF/argv-cru" run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$r3" = 2 ] && grep -qF "não é um array JSON não vazio de strings" <<<"$e3" && [ "$c3" = 0 ] \
     && [ "$RC" = 2 ] && grep -qF "agent_argv em $CF/argv-cru" "$C/err" && [ "$(calls)" = 0 ]; then
    ok "config-invalido: agent_argv que não é array de strings → exit 2 sem falar com o hc, dizendo de onde veio"
  else no config-invalido "rc1=$r3 err1=$e3 rc=$RC err=$(cat "$C/err") log=$(cat "$C/log")"; fi

  rm -f "$T/executou-linha" "$T/executou-valor" "$T/executou-crase"
  CFG="$CF/sem-source" run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$RC" = 0 ] && [ "$(nlog '[--argv][["meu-agente"]]')" = 1 ] \
     && [ ! -e "$T/executou-linha" ] && [ ! -e "$T/executou-valor" ] && [ ! -e "$T/executou-crase" ]; then
    ok "config-sem-source: \$(…) e crase no config não executam (lido linha a linha)"
  else no config-sem-source "rc=$RC executou=$(ls "$T" | grep executou | paste -sd, -) log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  AGENT_ARGV='["do-env","--x"]' CFG="$CF/argv" run vazio.json "$CHAMA" "$BETA" --brief "faz z" --from chamador
  if [ "$RC" = 0 ] && [ "$(nlog '[--argv][["do-env","--x"]]')" = 1 ] && [ "$(nlog 'meu-agente')" = 0 ]; then
    ok "env-vence: HERDR_LANE_AGENT_ARGV vence o agent_argv do config"
  else no env-vence "rc=$RC log=$(cat "$C/log") err=$(cat "$C/err")"; fi

  # install.sh: links globais em pastas da fixture; herdr-app falso no PATH.
  cp "$INST" "$RC_REPO/install.sh"
  local I="$T/inst" ir
  inst() { rm -rf "$I"; mkdir -p "$I/bin" "$I/rules"; "$@"
    ( env PATH="$T/stub:$PATH" STUB_LOG="$I/log" HERDR_APP_DIR="$I/app" \
        HERDR_LANE_BIN_DIR="$I/bin" HERDR_LANE_RULES_DIR="$I/rules" \
        bash "$RC_REPO/install.sh" ) > "$I/out" 2> "$I/err"; ir=$?; }
  inst :
  if [ "$ir" = 0 ] && [ "$(readlink "$I/bin/herdr-lane")" = "$RC_REPO/bin/herdr-lane" ] \
     && [ "$(readlink "$I/bin/bora-lane")" = herdr-lane ] \
     && [ "$(readlink "$I/rules/herdr-lane.md")" = "$RC_REPO/agent/rules/herdr-lane.md" ]; then
    ok "install-links: cria herdr-lane, bora-lane → herdr-lane e a regra"
  else no install-links "rc=$ir err=$(cat "$I/err") ls=$(ls -l "$I/bin" "$I/rules")"; fi

  inst eval 'echo meu > "$I/bin/bora-lane"'
  if [ "$ir" = 0 ] && [ ! -L "$I/bin/bora-lane" ] && [ "$(cat "$I/bin/bora-lane")" = meu ] \
     && grep -qF "$I/bin/bora-lane existe e não é symlink" "$I/err" \
     && [ -L "$I/bin/herdr-lane" ] && [ -L "$I/rules/herdr-lane.md" ]; then
    ok "install-pula-arquivo: destino arquivo comum é avisado e fica intacto"
  else no install-pula-arquivo "rc=$ir err=$(cat "$I/err")"; fi

  return "$f"
}

fail=0
echo "=== script real: $SRC"
suite "$SRC" || fail=1

mutante() { # $1 nome, $2 descrição, $3 programa sed, $4 alvo (script|install; padrão script), $5 caso que tem que matar (opcional)
  local m="$T/mut-$1" alvo="$SRC"
  [ "${4:-script}" = install ] && alvo="$INST_SRC"
  sed -e "$3" "$alvo" > "$m"
  if cmp -s "$m" "$alvo"; then echo "  FALHOU — mutante '$1' não mudou nada (sed desatualizado)"; fail=1; return; fi
  echo
  echo "=== MUTANTE $1: $2"
  local n por
  if [ "${4:-script}" = install ]; then suite "$SRC" "$m" > "$T/mut-$1.out" 2>&1; n=$?
  else suite "$m" > "$T/mut-$1.out" 2>&1; n=$?; fi
  por="$(sed -n 's/^  FALHOU \[\([^]]*\)\].*/\1/p' "$T/mut-$1.out" | paste -sd, -)"
  if [ "$n" = 0 ]; then
    echo "  FALHOU — suíte CEGA a este mutante"; fail=1
  elif [ -n "${5:-}" ] && [[ ",$por," != *",$5,"* ]]; then
    echo "  FALHOU — morto por $por, mas não por $5"; fail=1
  else
    echo "  ok — morto por $n caso(s): $por"
  fi
}
mutante busy-ignorado "agente working não recusa" 's/\[ "\$a_status" = working \]/[ "$a_status" = NUNCA ]/'
mutante wt-ocupada-reusa "worktree linkada com agente não recusa" 's/      refuse worktree-occupied /      : refuse worktree-occupied /'
mutante linked-como-main "worktree linkada tratada como checkout principal" 's/^\[ "\$gitdir" = "\$common" \] || linked=1$/:/'
mutante own-lane-cego "alvo na própria lane é despachado" 's/^if \[ "\$R" = "\$own" \]; then$/if false; then/'
mutante fora-de-repo "fora de repo vira lane = diretório" 's/|| die2 "fora de qualquer repo git: \$target (ancestral existente: \$dir)"$/|| R="$dir"/'
mutante sem-folder "space.new sem --folder" 's/ --folder "\$R"//g'
mutante argv-padrao "sem config, --argv diferente de [\"omp\"]" 's/^argv='"'"'\["omp"\]'"'"' argv_de=padrão$/argv='"'"'["outro"]'"'"' argv_de=padrão/' script config-padrao
mutante config-ignorado "agent_argv do config é ignorado" 's/^      agent_argv) cfg_argv="\$val" ;;$/      agent_argv) ;;/' script config-argv
mutante config-sem-validar "agent_argv inválido passa" 's/^  || die2 "argv do agente /  || echo "argv do agente /' script config-invalido
mutante config-com-source "config também lido com source" 's/^cfg_argv="" notes_dir=""$/cfg_argv="" notes_dir=""; [ ! -f "$CONFIG" ] || . "$CONFIG" 2>\/dev\/null || true/' script config-sem-source
mutante env-ignorada "HERDR_LANE_AGENT_ARGV não vence o config" 's/^\[ -z "\${HERDR_LANE_AGENT_ARGV:-}" \] || .*$/:/' script env-vence
mutante label-sem-from "label sem ·de-<from>" 's/^label="\${repo}·\${slug}"$/label="${repo}"/'
mutante label-sem-slug "label ignora o assunto do brief" 's/^\[ -n "\$slug" \] || slug="de-\${from}"$/slug="de-${from}"/'
mutante slug-com-data "slug mantém a data do brief" 's/^  slug="\$(sed -E .*$/  :/'
mutante install-sem-regra "install.sh não instala a regra" 's/^link_global "\$REPO\/agent\/rules\/herdr-lane.md".*$/:/' install
mutante from-padrao "--from padrão não é a lane do chamador" 's/^\[ -n "\$from" \] || from="\$(basename "\$own")"$/[ -n "$from" ] || from=voce/'
mutante brief-file-cru "--brief-file manda o caminho cru" 's/^  prompt="Leia \$brief_file e execute"$/  prompt="$brief_file"/'
mutante brief-traco-passa "--brief com '-' passa" 's/^  case "\$brief" in -\*) die2 /  case "$brief" in -NUNCA) die2 /'
mutante reusa-blocked "reusa agente blocked" 's/for want in idle done; do/for want in idle done blocked; do/'
mutante done-antes "prefere done a idle" 's/for want in idle done; do/for want in done idle; do/'
mutante shell-conta "terminal sem agente (shell) conta como agente" 's/select(.state == "live" and .agent != null)/select(.state == "live")/'
mutante finished-conta "terminal finished conta como agente" 's/select(.state == "live" and .agent != null)/select(.agent != null)/'
mutante subdir-ignorado "agente num subdiretório não conta como no repo" 's/^    "\$R"\/\*) \[ "\$(toplevel "\$a_cwd")" = "\$R" \] || continue ;;$/    "$R"\/*) continue ;;/'
mutante ninho-conta "worktree aninhada conta como o repo" 's/^    "\$R"\/\*) \[ "\$(toplevel "\$a_cwd")" = "\$R" \] || continue ;;$/    "$R"\/*) ;;/'
mutante dry-run-executa "--dry-run executa o space.new" 's/^if \[ "\$dry" = 1 \]; then$/if false; then/'
mutante dry-run-envia "--dry-run manda o hc send do reuse" 's/^    if \[ "\$dry" = 1 \]; then$/    if false; then/'
mutante sem-espera "não espera o turno começar (aceita o idle da partida)" 's/^      if \[ "\${t_turn:-0}" -gt "\$3" \] || \[ "\$t_state" = working \]; then$/      if true; then/'
mutante so-working "turno novo (turn > o de antes) não conta como começado" 's/^      if \[ "\${t_turn:-0}" -gt "\$3" \] || \[ "\$t_state" = working \]; then$/      if [ "$t_state" = working ]; then/'
mutante blocked-espera "blocked na partida espera o timeout" 's/^      if \[ "\$t_state" = blocked \]; then$/      if false; then/'
mutante reuso-sem-espera "reuso não espera o turno do send começar" 's/^      esperar_turno "\$p_ws" "\$p_addr" "\$p_turn"$/      :/'
mutante reuso-base-zero "reuso aceita o done do turno anterior" 's/^      esperar_turno "\$p_ws" "\$p_addr" "\$p_turn"$/      esperar_turno "$p_ws" "$p_addr" 0/'
mutante sem-space-ok "space.new sem space/terminal segue" 's/^\[ -n "\$space" \] && \[ -n "\$term" \] || die1 /[ -n "$space" ] \&\& [ -n "$term" ] || echo /'
mutante sem-til "'~/' não expande" 's/^    "~\/"\*) p="\$HOME\/\${p#\\~\/}" ;;$/    "~\/"*) ;;/'
mutante tab-colapsa "campos por TAB (nome null desloca colunas)" 's/^US=\$'"'"'\\x1f'"'"'$/US=$'"'"'\\t'"'"'/; s/join("\\u001f")/join("\\t")/'

echo
[ "$fail" = 0 ] && echo "PASSOU" || echo "FALHOU"
exit "$fail"
