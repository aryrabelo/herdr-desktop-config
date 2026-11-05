#!/usr/bin/env bash
# Instala a configuração do Herdr desktop deste repo em ~/.config/herdr-app.
#   bash install.sh            instala (com backup do que já existe)
#   bash install.sh --dry-run  só lista o que faria
#
# Global (symlink para este repo; script e regra podem, mod não):
#   $HERDR_LANE_BIN_DIR/herdr-lane         → $REPO/bin/herdr-lane        (padrão ~/.local/bin)
#   $HERDR_LANE_BIN_DIR/bora-lane          → herdr-lane                   (alias temporário)
#   $HERDR_LANE_RULES_DIR/herdr-lane.md    → $REPO/agent/rules/herdr-lane.md (padrão ~/.omp/agent/rules)
#   Destino que não é symlink, ou symlink para fora de dotfiles-2026/herdr-lane/nix store: avisa e pula.
#
# Origem dos mods (copiados de mods/, nunca symlink):
#   next-needed    deste repo
#   pane-head      deste repo (clone do `pane` do Herdr 0.1.13 + nome e endereço do agente)
#   space-folders  jankeesvw/herdr-space-folders @ 63a78b20d5ed30d57166a3c7165a6eb558c3ef84 (MIT),
#                  com um patch daqui: estado do PR da branch (gh pr view) na linha do space
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HERDR_APP_DIR:-$HOME/.config/herdr-app}"
BIN_DIR="${HERDR_LANE_BIN_DIR:-$HOME/.local/bin}"
RULES_DIR="${HERDR_LANE_RULES_DIR:-$HOME/.omp/agent/rules}"
DRY=0
case "${1:-}" in
  --dry-run|-n) DRY=1 ;;
  "") ;;
  -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
  *) echo "opção desconhecida: $1" >&2; exit 2 ;;
esac

run() {
  if [ "$DRY" = 1 ]; then printf '[dry-run] %s\n' "$*"; else "$@"; fi
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "falta o comando: $1" >&2; exit 1; }; }
if [ "$DRY" = 0 ]; then need herdr-app; fi
command -v herdr-app >/dev/null 2>&1 || echo "aviso: herdr-app não está no PATH (o check dos mods vai falhar fora do dry-run)"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$DEST/backup-$STAMP"

# 1. Backup do que vai ser sobrescrito. -L copia o conteúdo de symlinks.
MODS=(next-needed pane-head space-folders)
TARGETS=(keys.json settings.json layouts/ary.json layouts/main-folders.json)
for m in "${MODS[@]}"; do TARGETS+=("mods/$m"); done
for t in "${TARGETS[@]}"; do
  if [ -e "$DEST/$t" ] || [ -L "$DEST/$t" ]; then
    run mkdir -p "$(dirname "$BACKUP/$t")"
    run cp -RL "$DEST/$t" "$BACKUP/$t"
  fi
done

# 2. Remove o alvo antes de copiar: se for symlink (ex.: home-manager), cp escreveria através dele.
install_file() { # origem destino
  run mkdir -p "$(dirname "$2")"
  run rm -rf "$2"
  run cp "$1" "$2"
}

install_file "$REPO/config/keys.json"               "$DEST/keys.json"
install_file "$REPO/config/settings.json"           "$DEST/settings.json"
install_file "$REPO/config/layouts/ary.json"          "$DEST/layouts/ary.json"
install_file "$REPO/config/layouts/main-folders.json" "$DEST/layouts/main-folders.json"

# 3. Mods de mods/: sempre cópia, nunca symlink (o Herdr não percebe mudança dentro de pasta linkada).
run mkdir -p "$DEST/mods"
for m in "${MODS[@]}"; do
  run rm -rf "$DEST/mods/$m"
  run cp -R "$REPO/mods/$m" "$DEST/mods/$m"
done

# 4. Valida cada mod.
for m in "${MODS[@]}"; do
  run herdr-app check "$DEST/mods/$m"
done

# 5. Links globais do herdr-lane. Só troca destino que não existe ou é symlink
#    "nosso" (dotfiles-2026, herdr-lane, /nix/store do home-manager).
link_global() { # origem(link) destino
  local src="$1" dst="$2" tgt
  if [ -L "$dst" ]; then
    tgt="$(readlink "$dst")"
    case "$tgt" in
      "$src"|*dotfiles-2026*|herdr-lane|*/herdr-lane|*/herdr-lane.md|/nix/store/*) ;;
      *) echo "aviso: $dst aponta para $tgt (não é nosso); pulei" >&2; return 0 ;;
    esac
    run mkdir -p "$BACKUP/global"
    run cp -P "$dst" "$BACKUP/global/$(basename "$dst")"
  elif [ -e "$dst" ]; then
    echo "aviso: $dst existe e não é symlink; pulei" >&2
    return 0
  fi
  run mkdir -p "$(dirname "$dst")"
  run rm -f "$dst"
  run ln -s "$src" "$dst"
}

link_global "$REPO/bin/herdr-lane"              "$BIN_DIR/herdr-lane"
link_global herdr-lane                          "$BIN_DIR/bora-lane"
link_global "$REPO/agent/rules/herdr-lane.md"   "$RULES_DIR/herdr-lane.md"

if [ "$DRY" = 1 ]; then
  echo "dry-run: nada foi gravado. Backup iria para $BACKUP"
else
  [ -d "$BACKUP" ] && echo "backup: $BACKUP"
  echo "ok. Troque de layout com cmd-shift-l (ou: herdr-app do layout.switch --name main-folders)."
  echo "Pastas por projeto: edite e rode space-folders/auto-pastas.sh --dry-run"
fi
