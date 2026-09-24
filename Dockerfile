FROM ubuntu:22.04

ARG GODOT_VERSION=4.7
ENV PORT=8787

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl unzip libfontconfig1 libgl1 libx11-6 libxcursor1 \
        libxinerama1 libxrandr2 libxi6 libasound2 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/godot \
    && curl --fail --location --retry 3 \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
        --output /tmp/godot.zip \
    && unzip -q /tmp/godot.zip -d /opt/godot \
    && mv /opt/godot/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /opt/godot/godot \
    && chmod +x /opt/godot/godot \
    && rm /tmp/godot.zip

WORKDIR /app
COPY . .

EXPOSE 8787

CMD ["sh", "-c", "exec /opt/godot/godot --headless --path /app --script res://scripts/multiplayer_server.gd -- --port=${PORT}"]
