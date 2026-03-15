# Padelito – Raspberry Pi Local Web UI

Small Flask web UI to configure `padelito.data` and manage cron jobs on a Raspberry Pi.
Designed for **LAN-only** usage.

Access URLs:
- `http://{IP address}/` (bare-metal)
- `http://{IP address}:7070/` (Docker)
- `http://{DNS name}.local/`

---

## Requirements

- Raspberry Pi Zero 2 (or any Linux host)
- Raspberry Pi OS (Lite or Desktop)
- Python 3 **or** Docker

---

## Folder structure

```
padelito/
├── bookcourt.sh
├── docker-compose.yml
├── Dockerfile
├── entrypoint.sh
├── padelito_config.py
├── padelito.data
├── requirements.txt
└── templates/
    └── index.html
```

---

## Option A – Docker (recommended)

### 1. Clone the repo

```bash
cd ~
git clone https://github.com/michaelviegas/padelito.git
cd padelito
```

### 2. Start the container

```bash
docker compose up -d
```

The app is available at `http://{IP address}:7070/`.

Configuration is persisted in a named Docker volume (`padelito_data`).

### 3. Stop / restart

```bash
docker compose down
docker compose restart
```

### 4. View logs

```bash
docker compose logs -f
```

---

## Option B – Bare-metal (systemd)

### 1. Clone the repo

```bash
cd ~
git clone https://github.com/michaelviegas/padelito.git
cd padelito
```

### 2. Install dependencies

```bash
sudo apt update
sudo apt install -y python3-pip cron
pip3 install -r requirements.txt
```

### 3. Create systemd service

```bash
sudo nano /etc/systemd/system/padelito.service
```

Paste:

```ini
[Unit]
Description=Padelito Web UI (LAN-only, minimal)
After=network.target

[Service]
User=root
WorkingDirectory=/home/pi/padelito
ExecStart=/usr/bin/gunicorn -w 1 -b 0.0.0.0:80 padelito_config:app
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable & start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable padelito
sudo systemctl start padelito
```

Check status:

```bash
sudo systemctl status padelito
```

### 4. View logs

```bash
journalctl -u padelito -f
```

---

## Notes

- LAN-only and intentionally minimal. No authentication is enabled.
- Do not expose this service to the public internet.
- Docker: cron runs inside the container — no host sudoers changes needed.
- Bare-metal: cron is managed by the OS; the app calls `service cron reload` directly.
- Low resource usage (1 Gunicorn worker).
