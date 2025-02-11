FROM eclipse-temurin:17-jre-jammy as builder

# Install Python and build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-dev \
    git \
    curl \
    gcc \
    g++ \
    libjpeg-dev \
    zlib1g-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN python3 -m pip install -r requirements.txt --prefix=/install

FROM eclipse-temurin:17-jre-jammy as runtime

# Install Python runtime
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

ARG UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    appuser

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Copy Python dependencies
COPY --from=builder /install /usr/local

# Download Lavalink
RUN curl -L https://github.com/freyacodes/Lavalink/releases/download/3.7.11/Lavalink.jar -o /app/Lavalink.jar

# Copy application files
COPY configs/ /app/configs/
COPY lava/ /app/lava/
COPY locale/ /app/locale/
COPY main.py /app/
COPY extensions.json /app/

RUN chown -R appuser:appuser /app

USER appuser

# Start both Lavalink and the bot
CMD java -jar Lavalink.jar & python3 main.py
