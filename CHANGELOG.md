# CloudDesk — Changelog

All notable changes to this project will be documented here.

---

## CloudDesk v1.0.0 — 2026-03-01

### Initial Release

- One-command CloudDesk installer for TigerVNC + XFCE4 + noVNC + nginx + SSL + Fail2Ban
- deSEC dynDNS integration (required) — automatic A record update before SSL provisioning
- HTTP-only nginx config written first, certbot upgrades to HTTPS automatically
- Certbot with 60s pre-wait and up to 4 retry attempts before hard failure
- UFW firewall blocks VNC ports (5900, 5901, 6080) externally
- Fail2Ban configured for SSH + nginx (5 retries, 1hr ban)
- Security headers injected into SSL nginx block post-certbot
- Live DNS propagation check with polling before certbot runs
- Full install log written to /var/log/clouddesk.log
- Post-install health check on all 4 services
- Google Chrome pre-installed in desktop environment
- ASCII banner + success footer
