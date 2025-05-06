# n8n Cloudflare Installer

A beginner-friendly one-line installer to set up n8n with Docker and Cloudflare Tunnel on an EU-based VPS.

## 🚀 What It Does
- Installs Docker + Docker Compose
- Deploys n8n with secure basic auth
- Installs `cloudflared` (Cloudflare Tunnel)
- Prompts for Cloudflare login
- **Automates daily backups** of `n8n_data`
- **Automates weekly updates** of n8n Docker image

## 📦 Installation (1-liner)
Paste this into your VPS terminal (Ubuntu 22.04 recommended):

```bash
bash <(curl -s https://raw.githubusercontent.com/tbokan/n8n-cloudflare-installer/main/install.sh)
```

> 🔐 Change `YOUR_USERNAME` to your actual GitHub username

## ✅ Requirements
- Ubuntu 22.04 VPS (e.g. Hetzner/Contabo)
- A domain name managed through [Cloudflare](https://dash.cloudflare.com/)

## 📁 Files Created
- `/root/n8n/docker-compose.yml`: n8n Docker config
- `/root/n8n/n8n_data`: Persistent storage for n8n
- `/root/n8n-backups`: Daily compressed backups (kept for 7 days)

## 🔧 Next Steps
1. Follow the browser prompt to log in to Cloudflare
2. Create a tunnel and config file
3. Point your subdomain (e.g. `n8n.yourdomain.com`) to the tunnel
4. Secure with free HTTPS via Cloudflare

## 🔄 Updates & Backups
- **Auto-update**: Weekly every Sunday at 4 AM (via cron)
- **Auto-backup**: Daily at 2 AM, auto-cleaned after 7 days

## 🛡️ Security Note
Default password is set to `strongpassword123`. Please change it in `docker-compose.yml`.

## 📬 Support
Need help? [Open an issue](https://github.com/YOUR_USERNAME/n8n-cloudflare-installer/issues) or message Tadej.
