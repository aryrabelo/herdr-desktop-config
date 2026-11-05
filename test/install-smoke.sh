#!/usr/bin/env bash
# Smoke do install.sh numa ~/.config/herdr-app falsa, com `herdr-app` falso.
# Cobre o que já quebrou: symlink quebrado de geração velha do home-manager no destino.
#   bash test/install-smoke.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/install-smoke-XXXXXX")"
trap 'rm -rf "$T"' EXIT

fail=0
ok() { if eval "$1"; then echo "  ok — $2"; else echo "  FALHOU — $2"; fail=$((fail + 1)); fi; }

mkdir -p "$T/bin"
printf '#!/bin/sh\necho "$*" >> "%s/checks"\n' "$T" > "$T/bin/herdr-app"
chmod +x "$T/bin/herdr-app"

D="$T/config"
# Destino como o home-manager deixou: links para uma geração que já não existe.
mkdir -p "$D/mods/session-status" "$D/layouts"
ln -s /nix/store/nao-existe/main.js "$D/mods/session-status/main.js"
ln -s /nix/store/nao-existe/ary.json "$D/layouts/ary.json"
echo '{"velho":true}' > "$D/settings.json"

inst() {
  PATH="$T/bin:$PATH" XDG_CACHE_HOME="$T/cache" HERDR_APP_DIR="$D" \
    HERDR_LANE_BIN_DIR="$T/lbin" HERDR_LANE_RULES_DIR="$T/rules" bash "$REPO/install.sh" "$@"
}

before="$(cd "$D" && find . | sort)"
inst --dry-run > "$T/dry.log" 2>&1; dcode=$?
ok '[ "$dcode" -eq 0 ] && [ "$(cd "$D" && find . | sort)" = "$before" ]' "dry-run sai 0 e não grava nada"
inst > "$T/run.log" 2>&1; code=$?
ok '[ "$code" -eq 0 ]' "install sai 0 com symlink quebrado no destino (exit $code)"
ok '! grep -q "^cp:" "$T/run.log"' "nenhum erro de cp"
for f in keys.json settings.json layouts/ary.json; do
  ok 'cmp -s "$REPO/config/$f" "$D/$f" && [ ! -L "$D/$f" ]' "$f = repo (arquivo, não link)"
done
for m in next-needed session-status ary-menu pane-head space-folders; do
  ok 'diff -rq "$REPO/mods/$m" "$D/mods/$m" >/dev/null' "mod $m = repo"
  ok 'grep -qx "check $D/mods/$m" "$T/checks"' "check rodou em $m"
done
ok 'ls -d "$D"/backup-*/mods/session-status >/dev/null 2>&1' "backup guardou o mod com link quebrado"
ok '[ -L "$T/lbin/herdr-lane" ]' "link global do herdr-lane"
# html-viewer depende de rede: com rede, instalado e checado; sem rede, só aviso.
if [ -d "$D/mods/html-viewer" ]; then
  ok 'grep -qx "check $D/mods/html-viewer" "$T/checks"' "html-viewer instalado e checado"
else
  ok 'grep -q "html-viewer" "$T/run.log"' "sem html-viewer: install avisou"
fi

[ "$fail" = 0 ] && echo "INSTALL OK" || { echo "FALHOU ($fail)"; sed 's/^/    log: /' "$T/run.log"; exit 1; }
