# Aplica a config deste repo no Herdr desktop (~/.config/herdr-app, ou $HERDR_APP_DIR).
default:
    @just --list

# Instala tudo deste repo (com backup do que já existe)
update:
    bash install.sh

# Mostra o que o update faria, sem gravar nada
dry-run:
    bash install.sh --dry-run
