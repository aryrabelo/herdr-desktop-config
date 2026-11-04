#!/usr/bin/env bash
# Pastas automáticas (smart folders) do space-folders, uma por projeto/time.
# Cada pasta coleta os spaces cujo terminal trabalha dentro do caminho em "match";
# "Avulso" pega o resto de ~/Sites (a regra mais funda vence). O que você já
# arrastou à mão continua valendo: arrasto vence regra.
# Só ACRESCENTA pastas cujo nome ainda não existe; nas que já existem, completa
# só regra, pasta de início e cor que estiverem faltando.
# O mod relê o arquivo em até 15 s (vence o "at" mais novo).
#   ./auto-pastas.sh            aplica
#   ./auto-pastas.sh --dry-run  só mostra o resultado
set -euo pipefail

FILE="$HOME/.config/herdr-space-folders.json"
NOW_MS=$(( $(date +%s) * 1000 ))

# EDITE AQUI: uma linha por pasta. Os nomes e caminhos abaixo são exemplos.
# color: ansi1..ansi6, "#hex" ou null (cinza). path: onde o "+" da pasta abre
# um space novo. match: regras separadas por vírgula (~ = qualquer home).
NEW='[
  {"name":"Trabalho",  "color":"ansi4","path":"~/Sites/work-team",     "match":"~/Sites/work-team"},
  {"name":"Cliente A", "color":"ansi2","path":"~/Sites/cliente-a",     "match":"~/Sites/cliente-a"},
  {"name":"Open source","color":"ansi3","path":"~/Sites/oss",          "match":"~/Sites/oss"},
  {"name":"Pessoal",   "color":"ansi5","path":"~/Sites/personal-team", "match":"~/Sites/personal-team"},
  {"name":"Avulso",    "color":null,   "path":"~/Sites",               "match":"~/Sites"}
]'

current='{"list":[],"of":{},"at":0}'
[ -s "$FILE" ] && current=$(cat "$FILE")

# Pasta que você já tem com o mesmo nome (sem acento/caixa: "aguia" = "Águia")
# ganha as regras, a pasta de início e a cor que faltarem; as outras entram no fim.
result=$(jq -n --argjson cur "$current" --argjson add "$NEW" --argjson now "$NOW_MS" '
  def norm: ascii_downcase | gsub("[áàâãÁÀÂÃ]"; "a") | gsub("[éêÉÊ]"; "e") | gsub("[íÍ]"; "i") | gsub("[óôõÓÔÕ]"; "o") | gsub("[úÚ]"; "u");
  ($add | map({key: (.name | norm), value: .}) | from_entries) as $want
  | ($cur.list // []) as $have
  | ($have | map(.name | norm)) as $names
  | [ $have[] | (.name | norm) as $k
      | if $want[$k] then . + {match: (.match // $want[$k].match), path: (.path // $want[$k].path), color: (.color // $want[$k].color)} else . end ]
    + [ $add | to_entries[] | select((.value.name | norm) as $n | $names | index($n) | not)
      | .value + {id: ("fauto" + (.key | tostring)), folded: false} ]
  | {list: ., of: ($cur.of // {}), at: $now}')

if [ "${1:-}" = "--dry-run" ]; then echo "$result" | jq .; exit 0; fi

[ -s "$FILE" ] && cp "$FILE" "$FILE.bak-$(date +%Y%m%d-%H%M%S)"
printf '%s\n' "$result" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
echo "ok: $(echo "$result" | jq -r '.list | map(.name) | join(", ")')"
echo "desfazer: botão direito na pasta → Delete. O backup $FILE.bak-* é só referência:"
echo "  o mod fica com a cópia de 'at' mais novo, então mover o backup de volta não basta."
