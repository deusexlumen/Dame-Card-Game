# DAME Online-Server: dasselbe Godot-Projekt, headless gestartet.
# Bauen (im Repo-Wurzelverzeichnis):  docker build -f server/Dockerfile -t dame-server .
# Starten:                             docker run -p 8910:8910 dame-server
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
 && curl -sSL -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip \
 && unzip -q /tmp/godot.zip -d /opt/godot \
 && mv /opt/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
 && rm -rf /tmp/godot.zip /var/lib/apt/lists/* \
 && useradd --create-home dame

COPY --chown=dame:dame godot /app/godot
USER dame
WORKDIR /app
# Ressourcen einmal importieren, damit der Start schnell geht.
RUN godot --headless --path godot --import || true

EXPOSE 8910
CMD ["godot", "--headless", "--path", "godot", "res://scenes/server.tscn", "--", "--port=8910"]
