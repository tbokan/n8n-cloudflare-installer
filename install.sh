#!/bin/bash

# Exit on any error and show commands being run
set -ex

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run as root"
    exit 1
fi

# Validate system requirements
if [ ! -f /etc/os-release ]; then
    echo "❌ Cannot determine OS distribution"
    exit 1
fi

# Load OS info
. /etc/os-release

# Check for Ubuntu/Debian
if [ "$ID" != "ubuntu" ] && [ "$ID" != "debian" ]; then
    echo "❌ This script only supports Ubuntu/Debian"
    exit 1
fi

# Check for minimum Ubuntu version if Ubuntu
if [ "$ID" = "ubuntu" ] && [ "$VERSION_ID" != "22.04" ]; then
    echo "⚠️  This script is tested on Ubuntu 22.04, you're using $VERSION_ID"
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Prompt for n8n credentials
echo "🔐 n8n Authentication Setup"
read -p "Enter username [admin]: " N8N_USER
N8N_USER=${N8N_USER:-admin}

while true; do
    read -s -p "Enter password (min 12 chars): " N8N_PASS
    echo
    if [ ${#N8N_PASS} -ge 12 ]; then
        break
    else
        echo "Password must be at least 12 characters"
    fi
done

# Create dedicated user for n8n
if ! id n8nuser &>/dev/null; then
    useradd -m -s /bin/bash -G docker n8nuser
    echo "👤 Created n8nuser"
fi

# Print info
echo "🛠️ Updating system and installing dependencies..."
apt-get update && apt-get upgrade -y
apt-get install -y docker.io docker-compose curl unzip nano

# Enable and start Docker
systemctl start docker
systemctl enable docker

# Create n8n folder with proper permissions
mkdir -p /home/n8nuser/n8n
chown n8nuser:n8nuser /home/n8nuser/n8n
cd /home/n8nuser/n8n

# Create docker-compose.yml
cat <<EOF > docker-compose.yml
version: "3"
services:
  n8n:
    image: n8nio/n8n
    restart: unless-stopped
    ports:
      - "127.0.0.1:5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASS}
    volumes:
      - ./n8n_data:/home/node/.n8n
EOF

# Start n8n container as n8nuser
echo "🚀 Starting n8n..."
sudo -u n8nuser docker-compose up -d

# Check if n8n is running
if ! sudo -u n8nuser docker-compose ps | grep -q "Up"; then
    echo "❌ Failed to start n8n container"
    exit 1
fi

# Install cloudflared (Cloudflare Tunnel)
echo "🔐 Installing Cloudflare Tunnel..."
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# Cloudflare login
echo "🌐 Please complete Cloudflare login in your browser..."
cloudflared tunnel login

# Setup daily automatic backup of n8n_data
mkdir -p /home/n8nuser/n8n-backups
chown n8nuser:n8nuser /home/n8nuser/n8n-backups

# Add backup cron job as n8nuser
(sudo -u n8nuser crontab -l 2>/dev/null; echo "0 2 * * * tar -czf /home/n8nuser/n8n-backups/n8n-\$(date +\\%F).tar.gz -C /home/n8nuser/n8n n8n_data") | sudo -u n8nuser crontab -
(sudo -u n8nuser crontab -l 2>/dev/null; echo "0 3 * * * find /home/n8nuser/n8n-backups/ -type f -mtime +7 -delete") | sudo -u n8nuser crontab -

# Setup weekly auto-update for n8n
(sudo -u n8nuser crontab -l 2>/dev/null; echo "0 4 * * 0 cd /home/n8nuser/n8n && docker-compose pull && docker-compose down && docker-compose up -d") | sudo -u n8nuser crontab -

# Setup basic firewall
if command -v ufw &>/dev/null; then
    ufw allow 22/tcp   # SSH
    ufw allow 80/tcp   # HTTP
    ufw allow 443/tcp  # HTTPS
    ufw --force enable
    echo "🔥 Configured firewall (UFW)"
fi

# Final message
echo "✅ Installation completed successfully!"
echo "➡️ n8n is running at: http://localhost:5678 (only accessible locally)"
echo "➡️ Next steps:"
echo "   1. Create a Cloudflare Tunnel with: cloudflared tunnel create <tunnel-name>"
echo "   2. Create config.yml in ~/.cloudflared/"
echo "   3. Run the tunnel with: cloudflared tunnel run <tunnel-name>"
echo "   4. Set up DNS to point to your tunnel"
echo "ℹ️ Daily backups are stored in /home/n8nuser/n8n-backups"
echo "ℹ️ n8n will auto-update weekly on Sundays at 4 AM"
