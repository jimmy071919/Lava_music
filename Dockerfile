FROM eclipse-temurin:17-jre-jammy

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/python3 /usr/bin/python

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
    echo '{"server": {"address": "0.0.0.0", "port": 2333}, "lavalink": {"server": {"password": "youshallnotpass"}}}' > /app/configs/lavalink.json && \
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

# Download Lavalink
RUN curl -L https://github.com/freyacodes/Lavalink/releases/download/3.7.11/Lavalink.jar -o Lavalink.jar && \
    chown appuser:appuser Lavalink.jar

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
' > /app/configs/application.yml && \
    chown appuser:appuser /app/configs/application.yml

USER appuser

# Start both Lavalink and the bot
CMD java -jar Lavalink.jar & python3 main.py
