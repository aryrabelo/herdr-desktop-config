# Aplica a config deste repo no Herdr desktop (~/.config/herdr-app, ou $HERDR_APP_DIR).
default:
    @just --list

# Instala tudo deste repo (com backup do que já existe)
update:
    bash install.sh

# Mostra o que o update faria, sem gravar nada
dry-run:
    bash install.sh --dry-run

# Testa os mods (lógica pura), o herdr-lane + links globais (com mutantes) e o install.sh numa config falsa
test:
    node test/mods-test.mjs
    bash test/herdr-lane-test.sh
    bash test/install-smoke.sh
