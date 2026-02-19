FROM alpine:3.19

# Install dependencies
RUN apk add --no-cache \
    rclone \
    openssh-client \
    bash \
    curl \
    tzdata

# Create non-root user
RUN addgroup -S backup && adduser -S backup -G backup

# App directories
RUN mkdir -p /config /secrets /app \
    && chown -R backup:backup /config /secrets /app

WORKDIR /app

COPY backup.sh /app/backup.sh
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/backup.sh /app/entrypoint.sh

# Bake in secrets from private repo
COPY config/rclone.conf /config/rclone.conf
COPY secrets/mikrotik_id_rsa /secrets/mikrotik_id_rsa
RUN chmod 600 /secrets/mikrotik_id_rsa \
    && chown backup:backup /config/rclone.conf /secrets/mikrotik_id_rsa

ENTRYPOINT ["/app/entrypoint.sh"]
