FROM eclipse-temurin:17-jre-jammy as lavalink

WORKDIR /lavalink

# Install curl for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download Lavalink
RUN curl -L https://github.com/freyacodes/Lavalink/releases/download/3.7.11/Lavalink.jar -o Lavalink.jar

# Create Lavalink config
RUN echo 'server:\n\
  port: 2333\n\
  address: 0.0.0.0\n\
authorization:\n\
  password: "youshallnotpass"\n\
lavalink:\n\
  server:\n\
    password: "youshallnotpass"\n\
    sources:\n\
      youtube: true\n\
      bandcamp: true\n\
      soundcloud: true\n\
      twitch: true\n\
      vimeo: true\n\
      http: true\n\
    bufferDurationMs: 400\n\
    youtubePlaylistLoadLimit: 6\n\
    playerUpdateInterval: 5\n\
    youtubeSearchEnabled: true\n\
    soundcloudSearchEnabled: true\n\
    gc-warnings: true\n\
' > application.yml

# Start Lavalink
CMD ["java", "-jar", "Lavalink.jar"]

# Second stage for the Discord bot
FROM python:3.10-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Create non-root user
RUN useradd -m -u 1000 appuser

# Create necessary directories
RUN mkdir -p /app/configs /app/lava /app/locale && \
    chown -R appuser:appuser /app

# Copy application files
COPY --chown=appuser:appuser main.py /app/
COPY --chown=appuser:appuser extensions.json /app/
COPY --chown=appuser:appuser lava/ /app/lava/
COPY --chown=appuser:appuser locale/ /app/locale/

# Create config files
RUN echo '{"type": 0, "name": "Musics", "url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}' > /app/configs/activity.json && \
    echo '{\
    "nodes": [\
        {\
            "host": "lavalink",\
            "port": 2333,\
            "password": "youshallnotpass",\
            "name": "local",\
            "region": "us"\
        }\
    ]\
}' > /app/configs/lavalink.json && \
    echo '{\
    "empty": "",\
    "progress": {\
        "start_point": "",\
        "start_fill": "",\
        "mid_point": "",\
        "end_fill": "",\
        "end_point": "",\
        "end": ""\
    },\
    "control": {\
        "rewind": "",\
        "forward": "",\
        "pause": "",\
        "resume": "",\
        "stop": "",\
        "previous": "",\
        "next": "",\
        "shuffle": "",\
        "repeat": "",\
        "autoplay": "",\
        "lyrics": ""\
    }\
}' > /app/configs/icons.json && \
    chown appuser:appuser /app/configs/activity.json /app/configs/lavalink.json /app/configs/icons.json

USER appuser

# Start the Discord bot
CMD ["python3", "main.py"]
