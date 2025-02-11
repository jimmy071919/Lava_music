FROM python:3.13.1-alpine as builder

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apk update && apk add --no-cache \
    git \
    curl \
    xz \
    gcc \
    g++ \
    zlib-dev \
    libffi-dev \
    build-base \
    cmake \
    jpeg-dev

COPY requirements.txt .
RUN python -m pip install -r requirements.txt --prefix=/install

FROM openjdk:17-slim as runtime

# Install Python
RUN apt-get update && apt-get install -y python3 python3-pip

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
CMD java -jar Lavalink.jar & python main.py
