# Superset con la interfaz en español ya compilada. Solo agrega las traducciones a la imagen oficial.
# Las imágenes oficiales de Superset ya no traen traducciones (apache/superset PR 30099) ni los .po.
# No cambia el idioma por defecto: eso se configura en la imagen que usa esta como base (superset_config.py).
ARG SUPERSET_VERSION=6.1.0
# Idiomas a incluir, separados por espacio (códigos de superset/translations). Con varios, sube el tamaño de la imagen.
ARG LOCALES="es"

# ---- Etapa 1: genera el paquete de idioma del navegador (messages.json) con la misma herramienta que usa Superset ----
FROM node:22-slim AS front
ARG SUPERSET_VERSION
ARG LOCALES
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g po2json@0.4.5
WORKDIR /i18n
# Se usa el .po de la MISMA etiqueta de Superset que la imagen base, para que coincidan los textos.
RUN set -eu; for l in $LOCALES; do \
      mkdir -p "$l/LC_MESSAGES"; \
      curl -fsSL "https://raw.githubusercontent.com/apache/superset/${SUPERSET_VERSION}/superset/translations/${l}/LC_MESSAGES/messages.po" \
        -o "$l/LC_MESSAGES/messages.po"; \
      # Mismas opciones que superset-frontend/scripts/po2json.sh
      po2json --domain superset --format jed1.x --fuzzy "$l/LC_MESSAGES/messages.po" "$l/LC_MESSAGES/messages.json"; \
    done

# ---- Etapa 2: imagen final ----
FROM apache/superset:${SUPERSET_VERSION}
ARG LOCALES
USER root
# Un comando por RUN a propósito: si falla, el error de Actions indica cuál.
COPY --from=front /i18n/ /app/superset/translations/
# messages.mo: lo usa el servidor. Se compila con la librería Babel (dependencia de flask-babel), igual que `pybabel compile`
# (sin los textos "fuzzy"); no depende de que exista el script pybabel en la imagen.
RUN set -eu; for l in $LOCALES; do       /app/.venv/bin/python -c "import sys; from babel.messages.pofile import read_po; from babel.messages.mofile import write_mo; l=sys.argv[1]; d='/app/superset/translations/%s/LC_MESSAGES/' % l; write_mo(open(d+'messages.mo','wb'), read_po(open(d+'messages.po','rb'), locale=l))" "$l";     done
RUN set -eu; for l in $LOCALES; do rm -f "/app/superset/translations/$l/LC_MESSAGES/messages.po"; chmod -R a+rX "/app/superset/translations/$l"; done
# Comprobación: el build falla si falta algún archivo o si el paquete de idioma está casi vacío.
RUN set -eu; for l in $LOCALES; do       d="/app/superset/translations/$l/LC_MESSAGES";       test -s "$d/messages.mo"; test -s "$d/messages.json";       /app/.venv/bin/python -c "import json,sys; d=json.load(open('$d/messages.json',encoding='utf8')); n=len(d['locale_data']['superset']); print('$l: textos en el paquete =', n); sys.exit(0 if n > 1000 else 1)";     done
USER superset
