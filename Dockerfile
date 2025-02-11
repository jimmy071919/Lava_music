FROM eclipse-temurin:17-jre-jammy

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install minimal dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3-minimal \
    python3-pip \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Download Lavalink
RUN curl -L https://github.com/freyacodes/Lavalink/releases/download/3.7.11/Lavalink.jar -o Lavalink.jar

# Copy application files
COPY . .

# Create non-root user
RUN useradd -m -u 1000 appuser && \
    chown -R appuser:appuser /app

USER appuser

# Start both Lavalink and the bot
CMD java -jar Lavalink.jar & python3 main.py
