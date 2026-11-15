# Build from the PROJECT ROOT:  docker build -f backend/Dockerfile -t mystery-box-api .
FROM python:3.12-slim

# Official Godot Linux build, used only in --headless mode to run the game's own generator.
# CHECK this URL against https://godotengine.org/download/archive/ before building.
ARG GODOT_URL=https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip ca-certificates libfontconfig1 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/godot && curl -fsSL "$GODOT_URL" -o /tmp/godot.zip \
    && unzip -q /tmp/godot.zip -d /opt/godot && rm /tmp/godot.zip \
    && mv /opt/godot/Godot_v*_linux.x86_64 /opt/godot/godot && chmod +x /opt/godot/godot

WORKDIR /srv/api
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY backend/app ./app

# Only the generator scripts are needed on the server (no art).
COPY project.godot /srv/game/project.godot
COPY scripts /srv/game/scripts
COPY tools /srv/game/tools

RUN useradd -m runner && chown -R runner /srv
USER runner
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
