FROM alpine:3.19

# Install dependencies
RUN apk add --no-cache \
    rclone \
    openssh-client \
    bash \
    curl \
    tzdata

# Install supercronic (container-friendly cron, no setpgid issues)
RUN curl -fsSL \
    "https://github.com/aptible/supercronic/releases/download/v0.2.33/supercronic-linux-amd64" \
    -o /usr/local/bin/supercronic \
    && chmod +x /usr/local/bin/supercronic

# Create non-root user
RUN addgroup -S backup && adduser -S backup -G backup

# App directories
RUN mkdir -p /config /secrets /app \
    && chown -R backup:backup /config /secrets /app

WORKDIR /app

COPY backup.sh /app/backup.sh
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/backup.sh /app/entrypoint.sh

# /config  → mount your rclone.conf here
# /secrets → mount your SSH private key here

ENTRYPOINT ["/app/entrypoint.sh"]
