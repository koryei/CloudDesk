#!/bin/bash
# ==============================================================================
#  CloudDesk — Production Grade
#  Installs: TigerVNC · XFCE4 · noVNC · nginx (SSL) · Fail2Ban · Chrome
# ==============================================================================
set -euo pipefail
IFS=$'\n\t'

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
LOG_FILE="/var/log/clouddesk.log"

_log()    { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }
info()    { echo -e "${CYAN}  ›${NC} $*";               _log "INFO  $*"; }
success() { echo -e "${GREEN}  ✔${NC} $*";              _log "OK    $*"; }
warn()    { echo -e "${YELLOW}  ⚠${NC}  $*";            _log "WARN  $*"; }
die()     { echo -e "\n${RED}  ✖  ERROR:${NC} $*\n" >&2; _log "ERROR $*"; exit 1; }
step()    {
  local pad
  pad=$(printf '─%.0s' {1..45})
  echo -e "\n${BOLD}${BLUE}  ── $* ${NC}${DIM}${pad}${NC}"
  _log "STEP  $*"
}

# ── Sanity checks ─────────────────────────────────────────────────────────────
require_root() {
  [[ $EUID -eq 0 ]] || die "Please run as root:  sudo bash $0"
}

require_ubuntu() {
  grep -qi "ubuntu" /etc/os-release 2>/dev/null \
    || warn "Tested on Ubuntu. Other distros may need adjustments."
}

require_arch() {
  [[ "$(uname -m)" == "x86_64" ]] \
    || die "Only x86_64 supported. Detected: $(uname -m)"
}

# ── Banner ────────────────────────────────────────────────────────────────────
print_banner() {
  clear
  echo -e "${CYAN}"
  cat << 'BANNER'
              __     __ _   _   ____     ___              _           _  _
 _ __    ___  \ \   / /| \ | | / ___|   |_ _| _ __   ___ | |_   __ _ | || |  ___  _ __
| '_ \  / _ \  \ \ / / |  \| || |        | | | '_ \ / __|| __| / _` || || | / _ \| '__|
| | | || (_) |  \ V /  | |\  || |___     | | | | | |\__ \| |_ | (_| || || ||  __/| |
|_| |_| \___/    \_/   |_| \_| \____|   |___||_| |_||___/ \__| \__,_||_||_| \___||_|
BANNER
  echo -e "${NC}"
  echo -e "  ${DIM}TigerVNC + XFCE4 + noVNC + nginx + SSL + Fail2Ban${NC}"
  echo -e "${CYAN}  $(printf '─%.0s' {1..70})${NC}\n"
}

# ── Success footer ────────────────────────────────────────────────────────────
print_success_footer() {
  echo -e "${GREEN}"
  cat << 'FOOTER'
 ____   _____  _____  _   _  ____      ____   _   _   ____   ____  _____  ____   ____   _____  _   _  _
/ ___| | ____||_   _|| | | ||  _ \    / ___| | | | | / ___| / ___|| ____|/ ___| / ___| |  ___|| | | || |
\___ \ |  _|    | |  | | | || |_) |   \___ \ | | | || |    | |    |  _|  \___ \ \___ \ | |_   | | | || |
 ___) || |___   | |  | |_| ||  __/     ___) || |_| || |___ | |___ | |___  ___) | ___) ||  _|  | |_| || |___
|____/ |_____|  |_|   \___/ |_|       |____/  \___/  \____| \____||_____||____/ |____/ |_|     \___/ |_____|
FOOTER
  echo -e "${NC}"
}

# ── Input collection ──────────────────────────────────────────────────────────
collect_input() {
  echo -e "${BOLD}  Provide the following details:${NC}\n"

  while true; do
    read -rp "  $(echo -e "${CYAN}Domain${NC}")        (e.g. vnc.example.com) : " DOMAIN
    [[ -n "$DOMAIN" ]] && break
    warn "Domain cannot be empty."
  done

  while true; do
    read -rp "  $(echo -e "${CYAN}Email${NC}")         (for SSL certificate)  : " EMAIL
    [[ "$EMAIL" == *@*.* ]] && break
    warn "Enter a valid email address."
  done

  while true; do
    read -rp "  $(echo -e "${CYAN}Username${NC}")      (Linux user to create) : " USERNAME
    [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && break
    warn "Lowercase letters/numbers/underscores only, max 32 chars."
  done

  while true; do
    read -rp "  $(echo -e "${CYAN}deSEC token${NC}")   (required for DNS/SSL) : " AUTH_TOKEN
    [[ -n "$AUTH_TOKEN" ]] && break
    warn "A deSEC API token is required. Get yours at: https://desec.io → Account → Token"
  done

  echo
  info "Detecting public IP..."
  PUBLIC_IP=$(curl -fsSL --max-time 10 ifconfig.me 2>/dev/null) \
    || die "Could not detect public IP. Check your internet connection."
  success "Public IP: ${BOLD}${PUBLIC_IP}${NC}"

  echo
  echo -e "${CYAN}  $(printf '─%.0s' {1..70})${NC}"
  echo -e "  ${BOLD}Summary${NC}"
  echo -e "${CYAN}  $(printf '─%.0s' {1..70})${NC}"
  echo -e "  Domain     : ${GREEN}${DOMAIN}${NC}"
  echo -e "  Email      : ${GREEN}${EMAIL}${NC}"
  echo -e "  Username   : ${GREEN}${USERNAME}${NC}"
  echo -e "  Public IP  : ${GREEN}${PUBLIC_IP}${NC}"
  echo -e "  deSEC DNS  : ${GREEN}enabled${NC}"
  echo -e "${CYAN}  $(printf '─%.0s' {1..70})${NC}\n"

  read -rp "  Proceed with installation? [y/N] : " confirm
  echo
  [[ "${confirm,,}" == "y" ]] || { warn "Aborted."; exit 0; }
}

# ── System packages ───────────────────────────────────────────────────────────
install_packages() {
  step "System Update & Packages"
  export DEBIAN_FRONTEND=noninteractive

  info "Updating package lists..."
  apt-get update -qq >> "$LOG_FILE" 2>&1

  info "Upgrading system..."
  apt-get upgrade -y -qq >> "$LOG_FILE" 2>&1

  info "Installing packages..."
  apt-get install -y -qq \
    nginx certbot python3-certbot-nginx \
    tigervnc-standalone-server \
    xfce4 xfce4-goodies \
    novnc websockify \
    ufw fail2ban \
    wget curl unzip net-tools htop dnsutils >> "$LOG_FILE" 2>&1

  success "All packages installed."
}

# ── Google Chrome ─────────────────────────────────────────────────────────────
install_chrome() {
  step "Google Chrome"

  if command -v google-chrome &>/dev/null; then
    warn "Chrome already installed. Skipping."
    return
  fi

  info "Downloading Google Chrome..."
  local deb="/tmp/google-chrome-stable.deb"
  wget -qO "$deb" \
    https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    >> "$LOG_FILE" 2>&1 \
    || die "Failed to download Chrome."

  info "Installing..."
  apt-get install -y -qq "$deb" >> "$LOG_FILE" 2>&1
  rm -f "$deb"
  success "Google Chrome installed."
}

# ── Firewall ──────────────────────────────────────────────────────────────────
configure_firewall() {
  step "UFW Firewall"

  ufw allow OpenSSH >> "$LOG_FILE" 2>&1
  ufw allow 80/tcp  >> "$LOG_FILE" 2>&1
  ufw allow 443/tcp >> "$LOG_FILE" 2>&1
  # Block direct VNC access — only nginx tunnel allowed
  ufw deny 5900/tcp >> "$LOG_FILE" 2>&1
  ufw deny 5901/tcp >> "$LOG_FILE" 2>&1
  ufw deny 6080/tcp >> "$LOG_FILE" 2>&1
  ufw --force enable >> "$LOG_FILE" 2>&1

  success "Firewall enabled — SSH/HTTP/HTTPS open; VNC ports blocked externally."
}

# ── User account ──────────────────────────────────────────────────────────────
create_user() {
  step "User Account: ${USERNAME}"

  if id "$USERNAME" &>/dev/null; then
    warn "User '${USERNAME}' already exists. Skipping creation."
  else
    useradd -m -s /bin/bash "$USERNAME" >> "$LOG_FILE" 2>&1
    success "User '${USERNAME}' created."
  fi

  usermod -aG sudo "$USERNAME" >> "$LOG_FILE" 2>&1

  info "Set a login password for ${BOLD}${USERNAME}${NC}:"
  until passwd "$USERNAME"; do
    warn "Passwords did not match. Try again."
  done

  success "User account ready."
}

# ── VNC + XFCE ────────────────────────────────────────────────────────────────
configure_vnc() {
  step "TigerVNC + XFCE4"

  su - "$USERNAME" -c "echo 'xfce4-session' > ~/.xsession && chmod 644 ~/.xsession"
  su - "$USERNAME" -c "mkdir -p ~/.vnc"

  info "Set a VNC password for ${BOLD}${USERNAME}${NC}:"
  su - "$USERNAME" -c "vncpasswd"

  # Clean xstartup
  su - "$USERNAME" -c "cat > ~/.vnc/xstartup << 'XEOF'
#!/bin/bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export XKL_XMODMAP_DISABLE=1
exec xfce4-session
XEOF
chmod +x ~/.vnc/xstartup"

  cat > /etc/systemd/system/vnc-server.service << EOF
[Unit]
Description=TigerVNC Server (display :1)
After=network.target
Wants=network.target

[Service]
Type=forking
User=${USERNAME}
WorkingDirectory=/home/${USERNAME}
Environment=HOME=/home/${USERNAME}
ExecStartPre=-/usr/bin/vncserver -kill :1 -clean
ExecStart=/usr/bin/vncserver :1 -geometry 1280x800 -depth 24 -localhost yes
ExecStop=/usr/bin/vncserver -kill :1
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload          >> "$LOG_FILE" 2>&1
  systemctl enable vnc-server      >> "$LOG_FILE" 2>&1
  systemctl start  vnc-server      >> "$LOG_FILE" 2>&1
  sleep 3

  systemctl is-active --quiet vnc-server \
    && success "VNC server running on localhost:5901." \
    || die "VNC server failed to start. Run: journalctl -u vnc-server"
}

# ── CloudDesk WebSocket proxy ─────────────────────────────────────────────────────
configure_novnc() {
  step "CloudDesk WebSocket Proxy"

  [[ -d /usr/share/novnc ]] \
    || die "/usr/share/novnc not found. Package installation may have failed."

  cat > /etc/systemd/system/novnc.service << EOF
[Unit]
Description=CloudDesk WebSocket Proxy
After=network.target vnc-server.service
Requires=vnc-server.service

[Service]
Type=simple
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ 6080 localhost:5901
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload     >> "$LOG_FILE" 2>&1
  systemctl enable novnc      >> "$LOG_FILE" 2>&1
  systemctl start  novnc      >> "$LOG_FILE" 2>&1
  sleep 2

  systemctl is-active --quiet novnc \
    && success "CloudDesk proxy running on localhost:6080." \
    || die "noVNC failed to start. Run: journalctl -u novnc"
}

# ── Optional: deSEC DNS ───────────────────────────────────────────────────────
update_desec_dns() {
  step "deSEC DNS Update"
  info "Updating A record: ${DOMAIN} → ${PUBLIC_IP}..."

  # Use the deSEC dynDNS update endpoint (docs: https://desec.readthedocs.io/en/latest/dyndns/update-api.html)
  # --ipv4 forces IPv4 connection so the server detects our IPv4 address correctly
  # myipv6=preserve keeps any existing AAAA record untouched
  local response
  response=$(curl -s --ipv4     "https://update.dedyn.io/?hostname=${DOMAIN}&myipv4=${PUBLIC_IP}&myipv6=preserve"     -H "Authorization: Token ${AUTH_TOKEN}")

  if [[ "$response" == "good"* || "$response" == "nochg"* ]]; then
    success "DNS updated successfully (response: ${response}). TTL: 60s"
  else
    die "deSEC DNS update failed (response: '${response}'). Check your token and domain name."
  fi

  # Wait for DNS to propagate before certbot runs its HTTP-01 challenge
  info "Waiting 20s for DNS propagation..."
  local elapsed=0
  while [[ $elapsed -lt 20 ]]; do
    sleep 5
    elapsed=$((elapsed + 5))
    local resolved
    resolved=$(dig +short A "${DOMAIN}" @8.8.8.8 2>/dev/null | head -1)
    if [[ "$resolved" == "$PUBLIC_IP" ]]; then
      success "DNS propagated — ${DOMAIN} → ${PUBLIC_IP}"
      return
    fi
    info "Still propagating... (${elapsed}s / 60s)"
  done

  # Extended wait if needed
  while [[ $elapsed -lt 60 ]]; do
    sleep 5
    elapsed=$((elapsed + 5))
    local resolved
    resolved=$(dig +short A "${DOMAIN}" @8.8.8.8 2>/dev/null | head -1)
    if [[ "$resolved" == "$PUBLIC_IP" ]]; then
      success "DNS propagated — ${DOMAIN} → ${PUBLIC_IP}"
      return
    fi
    info "Still propagating... (${elapsed}s / 60s)"
  done

  warn "DNS did not confirm propagation within 60s. Proceeding anyway — certbot may retry."
}

# ── nginx reverse proxy (HTTP only — certbot upgrades to HTTPS) ───────────────
configure_nginx() {
  step "nginx Reverse Proxy (HTTP — pre-SSL)"

  rm -f /etc/nginx/sites-enabled/default

  # Write HTTP-only config — NO ssl_certificate lines yet.
  # Certbot will read this, get the cert, then inject the SSL server block itself.
  cat > /etc/nginx/sites-available/novnc << EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};

    # Serve CloudDesk static files
    root  /usr/share/novnc;
    index vnc.html;

    location / {
        try_files \$uri \$uri/ /vnc.html;
    }

    # WebSocket proxy → websockify (which then speaks raw VNC to localhost:5901)
    location /websockify {
        proxy_pass          http://127.0.0.1:6080;
        proxy_http_version  1.1;
        proxy_set_header    Upgrade     \$http_upgrade;
        proxy_set_header    Connection  "Upgrade";
        proxy_set_header    Host        \$host;
        proxy_set_header    X-Real-IP   \$remote_addr;
        proxy_read_timeout  3600s;
        proxy_send_timeout  3600s;
        proxy_buffering     off;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/novnc /etc/nginx/sites-enabled/novnc

  nginx -t >> "$LOG_FILE" 2>&1 \
    || die "nginx config is invalid. Run: nginx -t"
  systemctl restart nginx >> "$LOG_FILE" 2>&1
  success "nginx HTTP config applied and running."
}

# ── SSL Certificate ───────────────────────────────────────────────────────────
# Certbot --nginx will:
#   1. Obtain the cert via HTTP-01 challenge (port 80 must be open)
#   2. Automatically rewrite the nginx config to add the SSL server block
#   3. Add the HTTP→HTTPS redirect
# We then append our security + proxy headers to the SSL block after the fact.
provision_ssl() {
  step "Let's Encrypt SSL Certificate"

  # Hard wait — give DNS and nginx a full 60s to settle before the HTTP-01 challenge
  info "Waiting 60s for DNS + nginx to fully settle before requesting certificate..."
  for i in $(seq 60 -1 1); do
    printf "\r  ${CYAN}›${NC} Starting in %2ds..." "$i"
    sleep 1
  done
  echo

  local conf="/etc/nginx/sites-available/novnc"
  local max_attempts=4
  local attempt=0
  local success_flag=false

  while [[ $attempt -lt $max_attempts ]]; do
    attempt=$((attempt + 1))
    info "Certbot attempt ${attempt} of ${max_attempts} for: ${BOLD}${DOMAIN}${NC}"

    if certbot --nginx \
        -d "$DOMAIN" \
        --non-interactive \
        --agree-tos \
        -m "$EMAIL" \
        --redirect \
        >> "$LOG_FILE" 2>&1; then
      success_flag=true
      break
    else
      warn "Certbot attempt ${attempt} failed."
      if [[ $attempt -lt $max_attempts ]]; then
        info "Retrying in 30s..."
        sleep 30
      fi
    fi
  done

  if [[ "$success_flag" != "true" ]]; then
    echo
    echo -e "${RED}  $(printf '═%.0s' {1..70})${NC}"
    echo -e "${RED}  ✖  SSL PROVISIONING FAILED after ${max_attempts} attempts.${NC}"
    echo -e "${RED}  $(printf '═%.0s' {1..70})${NC}"
    echo
    echo -e "  Possible causes:"
    echo -e "  ${DIM}  • DNS not fully propagated — ${DOMAIN} may not resolve to ${PUBLIC_IP}${NC}"
    echo -e "  ${DIM}  • Port 80 is blocked by your VPS firewall/security group${NC}"
    echo -e "  ${DIM}  • Let's Encrypt rate limit hit (max 5 certs per domain per week)${NC}"
    echo -e "  ${DIM}  • deSEC token has insufficient permissions${NC}"
    echo
    echo -e "  Diagnose with:"
    echo -e "  ${CYAN}    dig A ${DOMAIN} @8.8.8.8${NC}"
    echo -e "  ${CYAN}    curl -v http://${DOMAIN}/.well-known/acme-challenge/test${NC}"
    echo -e "  ${CYAN}    cat ${LOG_FILE}${NC}"
    echo
    die "Exiting. Fix the issue above and re-run:  certbot --nginx -d ${DOMAIN} --agree-tos -m ${EMAIL} --redirect"
  fi

  # Inject security headers ONLY — certbot already writes ssl_protocols/ciphers/session
  # via /etc/letsencrypt/options-ssl-nginx.conf — duplicating them causes nginx to fail
  info "Hardening SSL nginx config..."
  if ! grep -q "X-Frame-Options" "$conf"; then
    sed -i '/ssl_certificate_key/a\
\
    # Security headers\
    add_header X-Frame-Options        SAMEORIGIN      always;\
    add_header X-Content-Type-Options nosniff         always;\
    add_header Referrer-Policy        strict-origin   always;\
    add_header X-XSS-Protection       "1; mode=block" always;' "$conf"
  fi

  nginx -t >> "$LOG_FILE" 2>&1 \
    || die "nginx config invalid after SSL hardening. Run: nginx -t"
  systemctl reload nginx >> "$LOG_FILE" 2>&1

  systemctl enable certbot.timer >> "$LOG_FILE" 2>&1
  success "SSL installed + hardened. Auto-renewal enabled via certbot.timer."
}

# ── Fail2Ban ──────────────────────────────────────────────────────────────────
configure_fail2ban() {
  step "Fail2Ban"

  cat > /etc/fail2ban/jail.d/novnc.conf << 'EOF'
[nginx-http-auth]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 5
bantime  = 3600

[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
maxretry = 5
bantime  = 3600
EOF

  systemctl enable fail2ban  >> "$LOG_FILE" 2>&1
  systemctl restart fail2ban >> "$LOG_FILE" 2>&1
  success "Fail2Ban active — 5 retries / 1hr ban on SSH + nginx."
}

# ── Health check ──────────────────────────────────────────────────────────────
health_check() {
  step "Health Check"
  local all_ok=true

  check_svc() {
    if systemctl is-active --quiet "$1"; then
      success "Service ${BOLD}$1${NC} is running."
    else
      warn "Service ${BOLD}$1${NC} is NOT running — check: journalctl -u $1"
      all_ok=false
    fi
  }

  check_svc vnc-server
  check_svc novnc
  check_svc nginx
  check_svc fail2ban

  $all_ok && success "All services healthy." \
           || warn   "Some services need attention (see above)."
}

# ── Final summary ─────────────────────────────────────────────────────────────
print_summary() {
  echo
  echo -e "${CYAN}  $(printf '═%.0s' {1..70})${NC}"
  print_success_footer
  echo -e "${CYAN}  $(printf '═%.0s' {1..70})${NC}\n"

  echo -e "  ${BOLD}🌐 Access URL   :${NC}  ${GREEN}https://${DOMAIN}${NC}"
  echo -e "  ${BOLD}👤 VNC User     :${NC}  ${USERNAME}"
  echo -e "  ${BOLD}🖥  Server IP   :${NC}  ${PUBLIC_IP}"
  echo -e "  ${BOLD}📄 Install Log  :${NC}  ${LOG_FILE}"
  echo -e "  ${BOLD}🕒 Completed    :${NC}  $(date '+%Y-%m-%d %H:%M:%S')"

  echo
  echo -e "  ${BOLD}Useful commands:${NC}"
  echo -e "  ${DIM}  Restart VNC     :${NC}  systemctl restart vnc-server"
  echo -e "  ${DIM}  Restart noVNC   :${NC}  systemctl restart novnc"
  echo -e "  ${DIM}  VNC logs        :${NC}  journalctl -u vnc-server -f"
  echo -e "  ${DIM}  Fail2Ban status :${NC}  fail2ban-client status"
  echo -e "  ${DIM}  Renew SSL       :${NC}  certbot renew --dry-run"
  echo
  echo -e "${CYAN}  $(printf '─%.0s' {1..70})${NC}\n"

  _log "=== Installation Complete ==="
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  require_root
  require_ubuntu
  require_arch

  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
  _log "=== CloudDesk Started ==="

  print_banner
  collect_input
  install_packages
  install_chrome
  configure_firewall
  create_user
  configure_vnc
  configure_novnc
  update_desec_dns
  configure_nginx
  provision_ssl
  configure_fail2ban
  health_check
  print_summary
}

main "$@"
