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

# Copy application files with explicit paths
COPY --chown=appuser:appuser configs/ /app/configs/
COPY --chown=appuser:appuser lava/ /app/lava/
COPY --chown=appuser:appuser locale/ /app/locale/
COPY --chown=appuser:appuser main.py /app/
COPY --chown=appuser:appuser extensions.json /app/

# Download Lavalink
RUN curl -L https://github.com/freyacodes/Lavalink/releases/download/3.7.11/Lavalink.jar -o Lavalink.jar && \
    chown appuser:appuser Lavalink.jar

# Verify file existence and permissions
RUN ls -la /app/configs/activity.json && \
    ls -la /app/configs/

USER appuser

# Start both Lavalink and the bot
CMD java -jar Lavalink.jar & python3 main.py
