# MikroTik → OneDrive Backup (Docker + rclone)

Backs up your MikroTik router config to OneDrive on a cron schedule.  
Two files are saved per run: a binary `.backup` and a human-readable `.rsc` export.

---

## Directory structure

```
mikrotik-backup/
├── Dockerfile
├── docker-compose.yml
├── backup.sh
├── entrypoint.sh
├── config/
│   └── rclone.conf        ← your rclone config (with OneDrive token)
└── secrets/
    └── mikrotik_id_rsa    ← SSH private key for the rclone-backup user
```

---

## 1. Generate an SSH key pair

```bash
ssh-keygen -t ed25519 -C "mikrotik-backup" -f secrets/mikrotik_id_rsa
```

Add the **public key** to your MikroTik:

```routeros
/user ssh-keys add user=rclone-backup key-owner="backup-docker" \
    public-key="<paste contents of secrets/mikrotik_id_rsa.pub>"
```

Make sure the key file has tight permissions:
```bash
chmod 600 secrets/mikrotik_id_rsa
```

---

## 2. Configure rclone for OneDrive

On a machine with a browser (not the server), run:

```bash
rclone config
```

- Choose **n** (new remote)
- Name it **onedrive**
- Type: **onedrive**
- Follow the OAuth flow in your browser
- When done, copy `~/.config/rclone/rclone.conf` into `config/rclone.conf`

---

## 3. Set MikroTik permissions for rclone-backup user

The user needs:
- **read** access to `/file` (to create and serve the backup file)
- **read** access to `/system backup`
- **read** access to `/export`

Minimal policy in RouterOS:
```routeros
/user group add name=backup-ro policy=read,ftp,ssh,!local,!telnet,!api,!romon,!sniff,!sensitive,!reboot,!write
/user set rclone-backup group=backup-ro
```

---

## 4. Edit docker-compose.yml

Update these values:

| Variable | Description |
|---|---|
| `MIKROTIK_HOST` | Router IP address |
| `MIKROTIK_USER` | SSH username (default: `rclone-backup`) |
| `RCLONE_REMOTE` | Must match the remote name in `rclone.conf` |
| `RCLONE_PATH` | Folder path inside OneDrive |
| `RETAIN_DAYS` | How many days of backups to keep |
| `CRON_SCHEDULE` | Cron expression for backup frequency |
| `TZ` | Your timezone |

---

## 5. Build and run

```bash
# Build
docker compose build

# Start (runs an immediate backup, then continues on schedule)
docker compose up -d

# Watch logs
docker compose logs -f

# Run a manual backup right now
docker compose exec mikrotik-backup /app/backup.sh
```

---

## Backup files

Files are stored in OneDrive under `RCLONE_PATH/` and named:

```
mikrotik_192.168.88.1_20240315_020001.backup   ← binary backup
mikrotik_192.168.88.1_20240315_020001.rsc      ← plaintext export
```

Backups older than `RETAIN_DAYS` days are automatically deleted from OneDrive.
