#!/bin/bash

set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Check if running as root
# ─────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo "❌ This script must be run as root. Exiting."
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# Check for supported OS (Ubuntu 22.04 preferred)
# ─────────────────────────────────────────────────────────────
os_version=$(lsb_release -rs)
if ! lsb_release -is | grep -qi ubuntu; then
  echo "❌ This script supports only Ubuntu. Detected: $(lsb_release -is)"
  exit 1
fi

if [[ "$os_version" != "22.04" ]]; then
  echo "⚠️ Warning: This script was tested on Ubuntu 22.04. Detected version: $os_version"
fi

# ─────────────────────────────────────────────────────────────
# Prompt for n8n admin password or allow environment variable
# ─────────────────────────────────────────────────────────────
if [ -z "${N8N_ADMIN_PASSWORD:-}" ]; then
  read -s -p "🔐 Enter a strong password for n8n admin user (min 8 characters): " N8N_ADMIN_PASSWORD
  echo
fi

if [ ${#N8N_ADMIN_PASSWORD} -lt 8 ]; then
  echo "❌ Password too short. Must be at least 8 characters."
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# Create dedicated user
# ─────────────────────────────────────────────────────────────
USERNAME=n8nuser
HOME_DIR=/home/$USERNAME

if id "$USERNAME" &>/dev/null; then
  echo "👤 User $USERNAME already exists."
else
  useradd -m -s /bin/bash $USERNAME
  echo "✅ Created non-root user: $USERNAME"
fi

# ─────────────────────────────────────────────────────────────
# Define project directories
# ─────────────────────────────────────────────────────────────
INSTALL_DIR=$HOME_DIR/n8n
BACKUP_DIR=$HOME_DIR/n8n-backups

mkdir -p "$INSTALL_DIR/n8n_data" "$BACKUP_DIR"
chown -R $USERNAME:$USERNAME "$INSTALL_DIR" "$BACKUP_DIR"

# ─────────────────────────────────────────────────────────────
# Install dependencies
# ─────────────────────────────────────────────────────────────
echo "🛠️ Installing Docker and utilities..."
apt update && apt upgrade -y
apt install -y docker.io docker-compose curl ufw unzip nano
systemctl enable --now docker

# ─────────────────────────────────────────────────────────────
# Configure firewall (UFW)
# ─────────────────────────────────────────────────────────────
echo "🧱 Configuring UFW firewall..."
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# ─────────────────────────────────────────────────────────────
# Create Docker Compose file
# ─────────────────────────────────────────────────────────────
cat <<EOF > "$INSTALL_DIR/docker-compose.yml"
version: "3"
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=$N8N_ADMIN_PASSWORD
    volumes:
      - ./n8n_data:/home/node/.n8n
EOF

chown $USERNAME:$USERNAME "$INSTALL_DIR/docker-compose.yml"

# ─────────────────────────────────────────────────────────────
# Start n8n service
# ─────────────────────────────────────────────────────────────
su - $USERNAME -c "cd $INSTALL_DIR && docker-compose up -d"

# Check if container is running
sleep 5
if ! docker ps | grep -q n8n; then
  echo "❌ n8n container failed to start."
  exit 1
fi

# ─────────────────────────────────────────────────────────────
# Install Cloudflare Tunnel
# ─────────────────────────────────────────────────────────────
echo "🔐 Installing cloudflared..."
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

cloudflared tunnel login || { echo "❌ Cloudflare login failed."; exit 1; }

# ─────────────────────────────────────────────────────────────
# Setup backups and remote upload placeholder
# ─────────────────────────────────────────────────────────────
echo "💾 Setting up backup and cleanup cron jobs..."
(crontab -l -u $USERNAME 2>/dev/null; echo "0 2 * * * tar -czf $BACKUP_DIR/n8n-\$(date +\%F).tar.gz -C $INSTALL_DIR n8n_data && echo Backup created") | crontab -u $USERNAME -
(crontab -l -u $USERNAME 2>/dev/null; echo "0 3 * * * find $BACKUP_DIR -type f -mtime +7 -delete") | crontab -u $USERNAME -

# Optional placeholder for remote backup upload:
# echo "🔁 Uploading backup to remote (not implemented)"

# ─────────────────────────────────────────────────────────────
# Schedule weekly auto-update
# ─────────────────────────────────────────────────────────────
(crontab -l -u $USERNAME 2>/dev/null; echo "0 4 * * 0 cd $INSTALL_DIR && docker-compose pull && docker-compose down && docker-compose up -d") | crontab -u $USERNAME -

# ─────────────────────────────────────────────────────────────
# Final output
# ─────────────────────────────────────────────────────────────
echo "✅ n8n setup complete and secured."
echo "📍 Access via Cloudflare Tunnel or use reverse proxy with TLS."
echo "🔐 Admin login: admin / your custom password"
echo "🧱 Firewall is active and only allows SSH, HTTP, HTTPS."
echo "💾 Backups stored in $BACKUP_DIR, updated daily."
