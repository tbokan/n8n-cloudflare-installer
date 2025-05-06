# n8n Cloudflare Installer

A secure, beginner-friendly one-line installer to set up n8n with Docker and Cloudflare Tunnel on an EU-based VPS.

## 🚀 What It Does
- Installs Docker + Docker Compose
- Creates a non-root user for running services
- Deploys n8n with secure basic auth (prompt or environment variable)
- Installs `cloudflared` (Cloudflare Tunnel)
- Prompts for Cloudflare login
- Sets up daily backups with verification
- Adds weekly automatic updates via cron
- Enables basic firewall (UFW) for ports 22, 80, and 443
- Includes guidance for SSL/TLS configuration

## 📦 Installation (1-liner)
Paste this into your VPS terminal (Ubuntu 22.04 recommended):

```bash
bash <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/n8n-cloudflare-installer/main/install.sh)
```

> 🔐 Change `YOUR_USERNAME` to your actual GitHub username

You can also pass a password via environment variable:
```bash
N8N_ADMIN_PASSWORD=YourStrongPassword bash <(curl -s https://raw.githubusercontent.com/YOUR_USERNAME/n8n-cloudflare-installer/main/install.sh)
```

## ✅ Requirements
- Ubuntu 22.04 VPS (e.g. Hetzner/Contabo)
- A domain name managed through [Cloudflare](https://dash.cloudflare.com/)

## 📁 Files Created
- `/home/n8nuser/n8n/docker-compose.yml`: n8n Docker config
- `/home/n8nuser/n8n/n8n_data`: Persistent storage for n8n
- `/home/n8nuser/n8n-backups`: Daily backups (7-day retention)

## 🔧 After Installation
1. Reboot the server
2. Run:
```bash
sudo -i -u n8nuser
cd ~/n8n
docker-compose up -d
```

## 🔧 Next Steps
1. Login to Cloudflare via browser (link appears in terminal)
2. Create a tunnel and DNS route
3. Add a config file to `/etc/cloudflared/config.yml`
4. Secure access using Cloudflare Tunnel or your own TLS proxy

## 🔄 Maintenance & Automation
- **Auto-backup**: Daily at 2 AM (compressed and verified)
- **Auto-clean**: Deletes backups older than 7 days at 3 AM
- **Auto-update**: Weekly at 4 AM every Sunday

## 🛡️ Security Enhancements
- Docker containers run under non-root `n8nuser`
- Basic auth is required for all access
- UFW blocks all ports except SSH, HTTP, and HTTPS
- Existing installations are detected to prevent overwriting

## 📬 Support
Need help? [Open an issue](https://github.com/YOUR_USERNAME/n8n-cloudflare-installer/issues) or message Tadej.
