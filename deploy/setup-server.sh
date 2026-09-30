#!/usr/bin/env bash
# One-time server setup for the PK Management web cabinet on Ubuntu 22.04/24.04.
# Run as root by .github/workflows/server-setup.yml (or by hand over SSH).
# Idempotent: safe to re-run.
set -euo pipefail

DEPLOY_USER="deploy"
APP_ROOT="/var/www/app"

echo "== Packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq debian-keyring debian-archive-keyring apt-transport-https curl gnupg rsync ufw >/dev/null

echo "== Caddy (official apt repo)"
if ! command -v caddy >/dev/null 2>&1; then
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  apt-get update -qq
  apt-get install -y -qq caddy >/dev/null
fi
caddy version

echo "== Deploy user and directories"
if ! id -u "$DEPLOY_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi
mkdir -p "/home/$DEPLOY_USER/.ssh"
# Reuse root's authorized keys so the same key that ran this script can deploy.
if [ -f /root/.ssh/authorized_keys ]; then
  cp /root/.ssh/authorized_keys "/home/$DEPLOY_USER/.ssh/authorized_keys"
fi
chown -R "$DEPLOY_USER:$DEPLOY_USER" "/home/$DEPLOY_USER/.ssh"
chmod 700 "/home/$DEPLOY_USER/.ssh"
chmod 600 "/home/$DEPLOY_USER/.ssh/authorized_keys" 2>/dev/null || true

mkdir -p "$APP_ROOT/releases"
chown -R "$DEPLOY_USER:$DEPLOY_USER" "$APP_ROOT"
chmod 755 "$APP_ROOT" "$APP_ROOT/releases"
# Placeholder so Caddy starts before the first deploy.
if [ ! -e "$APP_ROOT/current" ]; then
  mkdir -p "$APP_ROOT/releases/bootstrap"
  echo '<!doctype html><title>PK Management</title><p>Deploy pending.' > "$APP_ROOT/releases/bootstrap/index.html"
  ln -sfn "$APP_ROOT/releases/bootstrap" "$APP_ROOT/current"
  chown -R "$DEPLOY_USER:$DEPLOY_USER" "$APP_ROOT"
fi

echo "== Caddyfile"
install -m 644 "$(dirname "$0")/Caddyfile" /etc/caddy/Caddyfile
mkdir -p /var/log/caddy && chown caddy:caddy /var/log/caddy
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
systemctl enable caddy >/dev/null
systemctl reload caddy || systemctl restart caddy

echo "== Firewall (SSH, HTTP, HTTPS)"
ufw allow OpenSSH >/dev/null
ufw allow 80/tcp >/dev/null
ufw allow 443/tcp >/dev/null
ufw --force enable >/dev/null
ufw status | head -8

echo "== Done. Caddy will obtain the certificate once DNS for app.pk.management points to this server."
