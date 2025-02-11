FROM eclipse-temurin:17-jre-jammy

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV SERVER_PORT=8080

WORKDIR /app

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-dev \
    git \
    curl \
    tini \
    procps \
    netcat \
    && rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/python3 /usr/bin/python

# Copy requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Create non-root user
RUN useradd -m -u 1000 appuser

# Create necessary directories
RUN mkdir -p /app/configs /app/lava /app/locale /app/logs && \
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
            "host": "127.0.0.1",\
            "port": 8080,\
            "password": "youshallnotpass",\
            "name": "local",\
            "region": "us",\
            "identifier": "main",\
            "version": "v4"\
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

# Download Lavalink
RUN curl -L https://github.com/freyacodes/Lavalink/releases/download/3.7.11/Lavalink.jar -o Lavalink.jar && \
    chown appuser:appuser Lavalink.jar

# Create Lavalink config
RUN echo 'server:\n\
  port: 8080\n\
  address: 0.0.0.0\n\
  version: v4\n\
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
    websocket:\n\
      path: /v4/websocket\n\
logging:\n\
  file:\n\
    path: /app/logs/lavalink.log\n\
    max-history: 30\n\
    max-size: 1GB\n\
  path: /app/logs/\n\
  level:\n\
    root: INFO\n\
    lavalink: DEBUG\n\
    lavaplayer: DEBUG\n\
' > /app/configs/application.yml && \
    chown appuser:appuser /app/configs/application.yml

# Create startup script
RUN echo '#!/bin/bash\n\
\n\
# Function to check if a process is running\n\
is_process_running() {\n\
    local pid=$1\n\
    if ps -p $pid > /dev/null; then\n\
        return 0\n\
    else\n\
        return 1\n\
    fi\n\
}\n\
\n\
# Function to cleanup processes\n\
cleanup() {\n\
    echo "Cleaning up..."\n\
    if [ ! -z "$LAVALINK_PID" ]; then\n\
        kill $LAVALINK_PID 2>/dev/null\n\
    fi\n\
    if [ ! -z "$TAIL_PID" ]; then\n\
        kill $TAIL_PID 2>/dev/null\n\
    fi\n\
    if [ ! -z "$BOT_PID" ]; then\n\
        kill $BOT_PID 2>/dev/null\n\
    fi\n\
    if [ ! -z "$BOT_LOG_PID" ]; then\n\
        kill $BOT_LOG_PID 2>/dev/null\n\
    fi\n\
    exit 0\n\
}\n\
\n\
# Set up trap for cleanup\n\
trap cleanup SIGTERM SIGINT\n\
\n\
echo "Starting Lavalink..."\n\
mkdir -p /app/logs\n\
\n\
# Start Lavalink with debug options\n\
java -Dlog4j2.debug=true -jar Lavalink.jar > /app/logs/lavalink.log 2>&1 &\n\
LAVALINK_PID=$!\n\
\n\
echo "Waiting for Lavalink to start (PID: $LAVALINK_PID)..."\n\
tail -f /app/logs/lavalink.log & \n\
TAIL_PID=$!\n\
\n\
# Wait for Lavalink to be ready\n\
COUNTER=0\n\
while ! grep -q "Lavalink is ready to accept connections." /app/logs/lavalink.log 2>/dev/null; do\n\
    if ! is_process_running $LAVALINK_PID; then\n\
        echo "Lavalink failed to start. Log output:"\n\
        cat /app/logs/lavalink.log\n\
        cleanup\n\
        exit 1\n\
    fi\n\
    sleep 1\n\
    COUNTER=$((COUNTER + 1))\n\
    if [ $COUNTER -ge 60 ]; then\n\
        echo "Timeout waiting for Lavalink to start. Log output:"\n\
        cat /app/logs/lavalink.log\n\
        cleanup\n\
        exit 1\n\
    fi\n\
    echo "Waiting... ($COUNTER/60)"\n\
done\n\
\n\
kill $TAIL_PID\n\
echo "Lavalink is ready!"\n\
\n\
# Test if Lavalink is responding\n\
echo "Testing Lavalink connection..."\n\
if ! nc -z localhost 8080; then\n\
    echo "ERROR: Cannot connect to Lavalink on port 8080"\n\
    cleanup\n\
    exit 1\n\
fi\n\
\n\
# Check Lavalink process status\n\
echo "Lavalink process info:"\n\
ps -p $LAVALINK_PID -o pid,ppid,user,%cpu,%mem,stat,start,time\n\
\n\
# Wait a bit for Lavalink to fully initialize\n\
sleep 5\n\
\n\
echo "Starting Discord bot..."\n\
# Ensure logs directory exists and is writable\n\
mkdir -p /app/logs && chown appuser:appuser /app/logs\n\
\n\
# Start bot with output to both console and file\n\
python3 -u main.py 2>&1 | tee /app/logs/bot.log & \n\
BOT_PID=$!\n\
\n\
# Start background tail of bot log\n\
tail -f /app/logs/bot.log & \n\
BOT_LOG_PID=$!\n\
\n\
# Monitor both processes\n\
while true; do\n\
    if ! is_process_running $LAVALINK_PID; then\n\
        echo "Lavalink process died! Log tail:"\n\
        tail -n 50 /app/logs/lavalink.log\n\
        cleanup\n\
        exit 1\n\
    fi\n\
    if ! ps -p $BOT_PID > /dev/null; then\n\
        echo "Discord bot process died! Log tail:"\n\
        tail -n 50 /app/logs/bot.log\n\
        cleanup\n\
        exit 1\n\
    fi\n\
    sleep 5\n\
    echo "Status check - $(date)"\n\
    echo "Lavalink status:"\n\
    ps -p $LAVALINK_PID -o pid,ppid,user,%cpu,%mem,stat,start,time\n\
    echo "Bot status:"\n\
    ps -p $BOT_PID -o pid,ppid,user,%cpu,%mem,stat,start,time\n\
done\n\
' > /app/start.sh && \
    chmod +x /app/start.sh

USER appuser

# Use tini as init
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/app/start.sh"]
