"""Pruebas de compile_mo.py: descarta traducciones con error de formato y fuzzy, y compila el resto."""
import gettext
import subprocess
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent

PO = '''msgid ""
msgstr ""
"Content-Type: text/plain; charset=UTF-8\\n"
"Plural-Forms: nplurals=2; plural=(n != 1);\\n"

msgid "Dashboards"
msgstr "Paneles de control"

#, python-format
msgid "Hello %(name)s"
msgstr "Hola %(nombre)s"

#, fuzzy
msgid "Maybe"
msgstr "Quizá"

msgid "Untranslated"
msgstr ""

#, python-format
msgid "Total: %(n)d rows"
msgstr "Total: %(n)d filas"
'''


def compilar(tmp_path):
    d = tmp_path / "es" / "LC_MESSAGES"
    d.mkdir(parents=True)
    (d / "messages.po").write_text(PO, encoding="utf-8")
    r = subprocess.run(
        [sys.executable, str(RAIZ / "compile_mo.py"), "es", str(tmp_path)],
        capture_output=True, text=True, check=False,
    )
    return r, d / "messages.mo"


def test_compila_aunque_haya_errores_y_lo_informa(tmp_path):
    r, mo = compilar(tmp_path)
    assert r.returncode == 0, r.stderr
    assert mo.stat().st_size > 0
    assert "1 descartados" in r.stdout  # el de %(nombre)s


def test_traduce_lo_valido_y_deja_en_ingles_lo_descartado(tmp_path):
    r, mo = compilar(tmp_path)
    assert r.returncode == 0, r.stderr
    with open(mo, "rb") as f:
        t = gettext.GNUTranslations(f)
    assert t.gettext("Dashboards") == "Paneles de control"
    assert t.gettext("Total: %(n)d rows") == "Total: %(n)d filas"
    assert t.gettext("Hello %(name)s") == "Hello %(name)s"  # marcador mal escrito: no se usa
    assert t.gettext("Maybe") == "Maybe"  # fuzzy: no se incluye
    assert t.gettext("Untranslated") == "Untranslated"


def test_falla_si_no_existe_el_po(tmp_path):
    r = subprocess.run(
        [sys.executable, str(RAIZ / "compile_mo.py"), "es", str(tmp_path)],
        capture_output=True, text=True, check=False,
    )
    assert r.returncode != 0
