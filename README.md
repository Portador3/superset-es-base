# superset-es-base

Imagen de **Apache Superset con la interfaz en español ya compilada** (`messages.json` del navegador y `messages.mo` del servidor).
Es una capa mínima sobre `apache/superset:<versión>`; no incluye drivers, configuración ni secretos.

## Por qué existe
Desde apache/superset PR 30099 las imágenes oficiales ya no traen las traducciones. Se construyen aquí una vez por versión,
en vez de compilarlas en cada despliegue del proyecto.

## Uso
En la imagen del proyecto (`superset-platform/docker/Dockerfile`):

    FROM ghcr.io/<usuario>/superset-es-base:6.1.0

y en `superset/superset_config.py` (la imagen NO cambia el idioma por sí sola):

    BABEL_DEFAULT_LOCALE = "es"
    LANGUAGES = {"es": {"flag": "es", "name": "Español"}, "en": {"flag": "us", "name": "English"}}

## Publicar o actualizar
- Primera vez / nueva versión: Actions → **build-base-es** → *Run workflow* → versión (p. ej. `6.1.0`). Etiqueta resultante: `ghcr.io/<usuario>/superset-es-base:6.1.0`.
- El paquete debe ser **público** para que el CD del proyecto lo lea sin credenciales extra:
  GitHub → Packages → `superset-es-base` → *Package settings* → *Change visibility* → *Public*.
  Contiene solo Superset oficial y traducciones; no pongas aquí secretos.

## Qué incluye y sus límites
- Idiomas: `es` (cambia `LOCALES` en el Dockerfile para más).
- El español de Superset 6.1.0 está traducido en ~84,5 %; ~11,5 % está marcado *fuzzy* (sin revisar) y ~4 % sin traducir.
  El paquete del navegador incluye los *fuzzy* (igual que el script oficial de Superset); el del servidor los excluye (`pybabel` por defecto).
- Licencia: Apache 2.0 (la de Superset).

## Pruebas (corren en GitHub Actions, en cada push; solo se publica si todas pasan)
| Qué | Dónde | Comprueba |
|---|---|---|
| Unitarias | `tests/test_compile_mo.py` | `compile_mo.py` compila lo válido, descarta traducciones con error de formato y *fuzzy*, y falla sin `.po` |
| Imagen (funcional) | `tests/smoke.sh` | Existen `messages.mo` y `messages.json`; traducen (p. ej. `Dashboards`); no queda el `.po`; Superset importa |
| Imagen (seguridad) | `tests/smoke.sh` | Corre como `superset` (no root); sin `.pem`/`.key`/`.env` en `/app`; sin escritura global en las traducciones |
| Integridad | `Dockerfile` + `translations.sha256` | El `.po` descargado debe coincidir con su SHA-256; si no, el build falla |
| Dockerfile | hadolint | Errores de buenas prácticas del `Dockerfile` |
| Vulnerabilidades | Trivy (informativo) | Lista CRITICAL/HIGH con arreglo disponible; **no bloquea** (la mayoría vienen de la imagen oficial) |

Al **cambiar de versión de Superset o añadir un idioma**, agrega su hash a `translations.sha256`:
`git show <etiqueta>:superset/translations/<idioma>/LC_MESSAGES/messages.po | sha256sum` en un clon de apache/superset.
