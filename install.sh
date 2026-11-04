#!/usr/bin/env bash
# Instala a configuração do Herdr desktop deste repo em ~/.config/herdr-app.
#   bash install.sh            instala (com backup do que já existe)
#   bash install.sh --dry-run  só lista o que faria
set -euo pipefail

SPACE_FOLDERS_REPO="https://github.com/jankeesvw/herdr-space-folders.git"
SPACE_FOLDERS_COMMIT="63a78b2"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${HERDR_APP_DIR:-$HOME/.config/herdr-app}"
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
need git
if [ "$DRY" = 0 ]; then need herdr-app; fi
command -v herdr-app >/dev/null 2>&1 || echo "aviso: herdr-app não está no PATH (o check dos mods vai falhar fora do dry-run)"

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$DEST/backup-$STAMP"

# 1. Backup do que vai ser sobrescrito. -L copia o conteúdo de symlinks.
TARGETS=(keys.json settings.json layouts/ary.json layouts/main-folders.json mods/next-needed mods/space-folders)
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

# 3. Mods: sempre cópia, nunca symlink (o Herdr não percebe mudança dentro de pasta linkada).
run rm -rf "$DEST/mods/next-needed"
run mkdir -p "$DEST/mods"
run cp -R "$REPO/mods/next-needed" "$DEST/mods/next-needed"

# 4. space-folders: clona o commit fixado e copia sem o .git.
TMP="$(mktemp -d "${TMPDIR:-/tmp}/herdr-space-folders.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
run git clone --quiet "$SPACE_FOLDERS_REPO" "$TMP/src"
run git -C "$TMP/src" checkout --quiet "$SPACE_FOLDERS_COMMIT"
run rm -rf "$TMP/src/.git"
run rm -rf "$DEST/mods/space-folders"
run cp -R "$TMP/src" "$DEST/mods/space-folders"

# 5. Valida cada mod.
for m in next-needed space-folders; do
  run herdr-app check "$DEST/mods/$m"
done

if [ "$DRY" = 1 ]; then
  echo "dry-run: nada foi gravado. Backup iria para $BACKUP"
else
  [ -d "$BACKUP" ] && echo "backup: $BACKUP"
  echo "ok. Troque de layout com cmd-shift-l (ou: herdr-app do layout.switch --name main-folders)."
  echo "Pastas por projeto: edite e rode space-folders/auto-pastas.sh --dry-run"
fi
