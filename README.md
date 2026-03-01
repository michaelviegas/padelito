# Padelito – Raspberry Pi Local Web UI (Minimal Setup)

Small Flask web UI to configure `padelito.data` and manage cron jobs on a Raspberry Pi.
This setup is intentionally minimal: **no NGINX**, no reverse proxy. Gunicorn binds directly to port 80.
Designed for **LAN-only** usage.

Access URLs:
- http://{IP address}/
- http://{DNS name}.local/

---

## Requirements

- Raspberry Pi Zero 2
- Raspberry Pi OS (Lite or Desktop)
- Python 3
- Local network (LAN only)

---

## Installation

### 1. Clone the repo

```bash
cd ~
git clone https://github.com/michaelviegas/padelito.git
cd padelito
```

---

### 2. Install dependencies

```bash
sudo apt update
sudo apt install -y python3-pip
pip3 install flask gunicorn
```

---

### 3. Folder structure

Make sure your project looks like this:

```
padelito/
├── bookcourt.sh
├── padelito_config.py
├── padelito.data
└── templates/
    └── index.html
```

---

### 4. Update Flask dev port (do NOT use 80 in dev)

Edit `padelito_config.py`:

```python
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
```

> Port 80 will be handled by Gunicorn via systemd.

---

## Run as a Service (Auto-start on boot)

### 5. Create systemd service (bind directly to port 80)

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

---

## Allow Cron Restart (No Password Prompt)

The web UI restarts cron using sudo.
Allow this single command without password:

```bash
sudo visudo
```

Add:

```
pi ALL=NOPASSWD: /bin/systemctl restart cron
```

---

## Access

Open in your browser:

```
http://{IP address}/
http://{DNS name}.local/
```

Find the Pi IP if needed:

```bash
hostname -I
```

---

## Logs & Debugging

Service logs:

```bash
journalctl -u padelito -f
```

---

## Reboot Test

```bash
sudo reboot
```

After reboot, verify the URLs above load.

---

## Notes

- LAN-only and intentionally minimal.
- No authentication is enabled.
- Do not expose this service to the public internet.
- Low resource usage (1 Gunicorn worker).
