#!/bin/bash

# Exit on any error
set -e

# Print info
echo "🛠️ Updating system and installing dependencies..."
apt update && apt upgrade -y
apt install -y docker.io docker-compose curl unzip nano

# Enable and start Docker
systemctl start docker
systemctl enable docker

# Create n8n folder and go into it
mkdir -p /root/n8n && cd /root/n8n

# Create docker-compose.yml
cat <<EOF > docker-compose.yml
version: "3"
services:
  n8n:
    image: n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=strongpassword123
    volumes:
      - ./n8n_data:/home/node/.n8n
EOF

# Start n8n container
echo "🚀 Starting n8n..."
docker-compose up -d

# Install cloudflared (Cloudflare Tunnel)
echo "🔐 Installing Cloudflare Tunnel..."
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
chmod +x /usr/local/bin/cloudflared

# Cloudflare login
echo "🌐 Please complete Cloudflare login in your browser..."
cloudflared tunnel login

# Setup daily automatic backup of n8n_data
mkdir -p /root/n8n-backups
(crontab -l 2>/dev/null; echo "0 2 * * * tar -czf /root/n8n-backups/n8n-\$(date +\%F).tar.gz -C /root/n8n n8n_data") | crontab -
(crontab -l 2>/dev/null; echo "0 3 * * * find /root/n8n-backups/ -type f -mtime +7 -delete") | crontab -

# Setup weekly auto-update for n8n
(crontab -l 2>/dev/null; echo "0 4 * * 0 cd /root/n8n && docker-compose pull && docker-compose down && docker-compose up -d") | crontab -

# Final message
echo "✅ Done!"
echo "➡️ n8n is running at: http://YOUR_SERVER_IP:5678"
echo "➡️ Next: Set up a Cloudflare Tunnel with your domain and point it to port 5678"
echo "ℹ️ Daily backups are stored in /root/n8n-backups and updated weekly."
