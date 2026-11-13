#!/usr/bin/env bash
# Pruebas de la imagen ya construida. Uso: tests/smoke.sh <imagen> [idioma]
set -uo pipefail
IMG="${1:?uso: smoke.sh <imagen> [idioma]}"
L="${2:-es}"
D="/app/superset/translations/$L/LC_MESSAGES"
FALLOS=0
ok()  { echo "  OK    $1"; }
mal() { echo "  FALLA $1"; FALLOS=$((FALLOS+1)); }
sh_() { docker run --rm --entrypoint sh "$IMG" -c "$1"; }
py_() { docker run --rm --entrypoint /app/.venv/bin/python "$IMG" -c "$1"; }

echo "== Funcional =="
sh_ "test -s $D/messages.mo && test -s $D/messages.json" && ok "existen messages.mo y messages.json" || mal "faltan archivos de traduccion"
sh_ "test ! -e $D/messages.po" && ok "no queda el .po en la imagen" || mal "queda el .po en la imagen"
sh_ "test ! -e /tmp/compile_mo.py" && ok "no queda compile_mo.py en la imagen" || mal "queda compile_mo.py"

py_ "
import json, gettext
d = json.load(open('$D/messages.json', encoding='utf8'))['locale_data']['superset']
assert d[''].get('lang') == '$L', d['']
assert len(d) > 1000, len(d)
assert d['Dashboards'][0] and d['Dashboards'][0] != 'Dashboards', d['Dashboards']
t = gettext.GNUTranslations(open('$D/messages.mo', 'rb'))
for k in ('Dashboards', 'Export to .CSV', 'Settings'):
    assert t.gettext(k) != k, k
print('json:', len(d), 'claves;  mo: Dashboards ->', t.gettext('Dashboards'))
" && ok "el paquete del navegador y el .mo del servidor traducen" || mal "las traducciones no cargan"

py_ "import babel, flask_babel; import superset" >/dev/null 2>&1 \
  && ok "Superset, Babel y flask_babel importan" || mal "Superset no importa en la imagen"

echo "== Seguridad =="
U="$(docker run --rm --entrypoint id "$IMG" -un)"
[ "$U" = "superset" ] && ok "corre como usuario no root ($U)" || mal "corre como '$U' (debe ser superset)"
CFG="$(docker inspect -f '{{.Config.User}}' "$IMG")"
[ "$CFG" = "superset" ] && ok "USER final = superset" || mal "USER final = '$CFG'"
if sh_ "find /app -maxdepth 3 \( -name '*.pem' -o -name '.env' -o -name '*.key' \) | grep -q ."; then
  mal "hay claves o .env dentro de la imagen"
else
  ok "no hay .pem, .key ni .env en /app"
fi
if sh_ "find /app/superset/translations -perm -o+w | grep -q ."; then
  mal "hay archivos de traduccion escribibles por todos"
else
  ok "traducciones sin permiso de escritura global"
fi

echo
if [ "$FALLOS" -eq 0 ]; then echo "TODO OK"; else echo "$FALLOS comprobaciones fallaron"; exit 1; fi
