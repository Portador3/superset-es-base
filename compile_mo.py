"""Compila messages.po -> messages.mo para el servidor de Superset.

Equivale a `pybabel compile`, pero en vez de abortar cuando hay traducciones con errores de formato
(p. ej. marcadores %(nombre)s que no coinciden con el texto original; el .po de `es` de 6.1.0 tiene 14),
las DESCARTA: esos textos quedan en inglés y el resto se compila. Los textos "fuzzy" tampoco se incluyen
(igual que pybabel por defecto).

Uso: python compile_mo.py <idioma> [carpeta-de-traducciones]
     (por defecto /app/superset/translations; espera <carpeta>/<idioma>/LC_MESSAGES/messages.po)
"""
import sys

from babel.messages.mofile import write_mo
from babel.messages.pofile import read_po

lang = sys.argv[1]
raiz = sys.argv[2] if len(sys.argv) > 2 else "/app/superset/translations"
base = f"{raiz}/{lang}/LC_MESSAGES/"
with open(base + "messages.po", "rb") as f:
    catalogo = read_po(f, locale=lang)

malos = [(m, errores) for m, errores in catalogo.check() if errores]
for m, errores in malos:
    print("descartado:", ascii(str(m.id))[:90], "->", ascii(str(errores[0]))[:120])
    catalogo.delete(m.id, m.context)

with open(base + "messages.mo", "wb") as f:
    write_mo(f, catalogo)
print(f"{lang}: {len(catalogo)} textos compilados, {len(malos)} descartados por errores de formato")
