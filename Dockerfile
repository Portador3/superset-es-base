# Superset con la interfaz en español ya compilada. Solo agrega las traducciones a la imagen oficial.
# Las imágenes oficiales de Superset ya no traen traducciones (apache/superset PR 30099) ni los .po.
# No cambia el idioma por defecto: eso se configura en la imagen que usa esta como base (superset_config.py).
ARG SUPERSET_VERSION=6.1.0
# Idiomas a incluir, separados por espacio (códigos de superset/translations). Con varios, sube el tamaño de la imagen.
# Cada <versión>/<idioma> debe tener su hash en translations.sha256 (si no, el build falla).
ARG LOCALES="es"

# ---- Etapa 1: genera el paquete de idioma del navegador (messages.json) con la misma herramienta que usa Superset ----
FROM node:22-slim AS front
ARG SUPERSET_VERSION
ARG LOCALES
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g po2json@0.4.5
WORKDIR /i18n
COPY translations.sha256 /translations.sha256
# Se usa el .po de la MISMA etiqueta de Superset que la imagen base, para que coincidan los textos, y se verifica su
# SHA-256 contra translations.sha256 antes de usarlo (integridad de lo descargado).
RUN set -eu; for l in $LOCALES; do \
      mkdir -p "$l/LC_MESSAGES"; \
      curl -fsSL "https://raw.githubusercontent.com/apache/superset/${SUPERSET_VERSION}/superset/translations/${l}/LC_MESSAGES/messages.po" \
        -o "$l/LC_MESSAGES/messages.po"; \
      esperado="$(awk -v k="${SUPERSET_VERSION}/${l}" '$2==k {print $1}' /translations.sha256)"; \
      [ -n "$esperado" ] || { echo "Falta el hash de ${SUPERSET_VERSION}/${l} en translations.sha256"; exit 1; }; \
      echo "$esperado  $l/LC_MESSAGES/messages.po" | sha256sum -c -; \
      po2json --domain superset --format jed1.x --fuzzy "$l/LC_MESSAGES/messages.po" "$l/LC_MESSAGES/messages.json"; \
    done

# ---- Etapa 2: imagen final ----
FROM apache/superset:${SUPERSET_VERSION}
ARG LOCALES
USER root
COPY --from=front /i18n/ /app/superset/translations/
# messages.mo: lo usa el servidor. compile_mo.py equivale a `pybabel compile` pero descarta (en vez de abortar) las traducciones
# con errores de formato; el .po de `es` de 6.1.0 tiene 14 y `pybabel compile` falla con "14 errors encountered".
COPY compile_mo.py /tmp/compile_mo.py
RUN set -eu; for l in $LOCALES; do /app/.venv/bin/python /tmp/compile_mo.py "$l"; done
RUN set -eu; for l in $LOCALES; do rm -f "/app/superset/translations/$l/LC_MESSAGES/messages.po"; chmod -R a+rX "/app/superset/translations/$l"; done; rm -f /tmp/compile_mo.py
# El build falla si falta algún archivo o si el paquete de idioma está casi vacío.
RUN set -eu; for l in $LOCALES; do \
      d="/app/superset/translations/$l/LC_MESSAGES"; \
      test -s "$d/messages.mo"; test -s "$d/messages.json"; \
      /app/.venv/bin/python -c "import json,sys; d=json.load(open('$d/messages.json',encoding='utf8')); n=len(d['locale_data']['superset']); print('$l: textos en el paquete =', n); sys.exit(0 if n > 1000 else 1)"; \
    done
USER superset
