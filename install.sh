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

# Add user to docker group for Docker access
usermod -aG docker $USERNAME

echo "ℹ️ Added $USERNAME to the docker group. A reboot is required before Docker commands will work."

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
# Notify to reboot
# ─────────────────────────────────────────────────────────────
echo "✅ Setup complete. Please reboot your server before continuing to allow Docker permissions to take effect."
echo "After reboot, switch to the n8n user and run:"
echo "  sudo -i -u $USERNAME"
echo "  cd ~/n8n && docker-compose up -d"
