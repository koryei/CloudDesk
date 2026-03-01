# CloudDesk

> **CloudDesk** — One-command browser-based Linux desktop with TigerVNC + XFCE4 + noVNC + nginx + SSL + Fail2Ban, fully automated.

![Platform](https://img.shields.io/badge/platform-Ubuntu%20x86__64-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Shell](https://img.shields.io/badge/shell-bash-lightgrey)

[![Watch the demo video](https://img.youtube.com/vi/da82ZglaZ1U/maxresdefault.jpg)](https://www.youtube.com/watch?v=da82ZglaZ1U)
---

## One-Line Install

```bash
curl -fsSL https://raw.githubusercontent.com/Koryei/CloudDesk/main/clouddesk.sh -o clouddesk.sh && chmod +x clouddesk.sh && sudo ./clouddesk.sh
```

---

## What It Installs

| Component | Role |
|---|---|
| TigerVNC | VNC server, bound to localhost only |
| XFCE4 | Lightweight desktop environment |
| noVNC + websockify | Browser-based VNC client over WebSocket |
| nginx | Reverse proxy + HTTPS termination |
| Let's Encrypt (Certbot) | Free SSL cert with auto-renewal |
| Fail2Ban | Brute-force protection on SSH + nginx |
| Google Chrome | Pre-installed browser in the desktop |

---

## Architecture

```
Browser (HTTPS)
     │
     ▼
nginx :443  ──►  /websockify  ──►  websockify :6080  ──►  TigerVNC :5901
     │
     └──►  /  ──►  CloudDesk static files (/usr/share/novnc)
```

VNC is **never exposed publicly** — only accessible through the encrypted nginx tunnel.

---

## Requirements

- Ubuntu 22.04+ (x86_64)
- A domain on **deSEC** (free at [desec.io](https://desec.io)) — required for DNS + SSL
- A deSEC API token ([get one here](https://desec.io/tokens))
- Root / sudo access
- Ports **80** and **443** open on your VPS firewall/security group

---

## What the Installer Asks For

| Prompt | Example |
|---|---|
| Domain | `yourdomain.dedyn.io` |
| Email | `you@email.com` (for SSL cert) |
| Linux username | `john` |
| deSEC API token | `abc123...` (required) |

The installer then handles everything automatically:

1. Updates & installs all packages
2. Creates your Linux user
3. Configures TigerVNC + XFCE4
4. Updates your DNS A record via deSEC
5. Starts nginx on HTTP
6. Runs Certbot (up to 4 attempts with retries)
7. Hardens the SSL config
8. Enables Fail2Ban
9. Runs a health check on all services

---

## After Install

Open your browser and navigate to:

```
https://your-domain.dedyn.io
```

Your XFCE4 desktop will load directly in the browser. Enter your VNC password to connect.

---

## Useful Commands

```bash
# Service management
sudo systemctl restart vnc-server
sudo systemctl restart novnc
sudo systemctl restart nginx

# Logs
sudo journalctl -u vnc-server -f
sudo journalctl -u novnc -f
sudo tail -f /var/log/clouddesk.log

# Security
sudo fail2ban-client status
sudo fail2ban-client status sshd

# SSL
sudo certbot renew --dry-run
```

---

## Troubleshooting

**"Can't connect" after install**
```bash
sudo ss -tlnp | grep -E '443|6080|5901'
sudo nginx -t
sudo systemctl status vnc-server novnc nginx
```

**`nginx -t` says "Permission denied" on cert**
Always run `nginx -t` with `sudo` — the error is a false alarm when run as a regular user.

**Certbot failed**
```bash
dig A your-domain.dedyn.io @8.8.8.8
curl -v http://your-domain.dedyn.io/
sudo certbot --nginx -d your-domain.dedyn.io --agree-tos -m you@email.com --redirect
```

**VNC not starting**
```bash
sudo journalctl -u vnc-server -n 50 --no-pager
```

---

## Security

- VNC ports (5900, 5901, 6080) are **blocked by UFW** — never exposed publicly
- All browser traffic goes through **TLS 1.2/1.3** via nginx
- Fail2Ban bans IPs after **5 failed attempts** for 1 hour
- SSL auto-renews via `certbot.timer`

---

## License
```MIT License — Copyright (c) 2026 Koryei

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.```
