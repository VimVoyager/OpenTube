# OpenTube Local Deployment Guide

Complete guide for deploying OpenTube on your local machine or home server.

---

## Table of Contents

- [Overview](#overview)
- [Why Local Deployment?](#why-local-deployment)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Deployment Steps](#deployment-steps)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)
- [Advanced Configuration](#advanced-configuration)

---

## Overview

This guide walks you through deploying OpenTube on your local machine using:
- **Docker & Docker Compose** - For containerized services
- **System Nginx** - As reverse proxy
- **mDNS/Avahi** - For `.local` domain support

**Tested On**: Manjaro Linux, Arch Linux, Ubuntu 20.04+, Debian 11+

---

## Why Local Deployment?

### Advantages Over Cloud Deployment

- ✅ **No YouTube IP blocking** - Residential IPs work perfectly
- ✅ **Full video playback** - All features work without restrictions
- ✅ **Zero hosting costs** - No monthly AWS/cloud fees
- ✅ **Network-wide access** - Available to all devices on your network (if configured for this)
- ✅ **Privacy** - Your data stays on your hardware
- ✅ **Custom domain** - Use `opentube.local` instead of `localhost`

### Use Cases

- **Home media server** - Personal YouTube alternative
- **Development environment** - Test changes before deploying
- **Privacy-focused setup** - Full control over data
- **Network sharing** - Family/roommates can access

---

## Architecture

### System Overview

```
┌─────────────────────────────────────────────────────┐
│           Your Computer (opentube.local)            │
│                                                     │
│  ┌─────────────────────────────────────────────┐  │
│  │         System Nginx (Port 80)              │  │
│  │                                             │  │
│  │  Routes:                                    │  │
│  │  • / → Frontend (localhost:3100)           │  │
│  │  • /api/ → Backend (localhost:8180)        │  │
│  │  • /proxy/ → Proxy (localhost:8181)        │  │
│  └─────────────────────────────────────────────┘  │
│                                                     │
│  ┌─────────────────────────────────────────────┐  │
│  │         Docker Compose Network              │  │
│  │                                             │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐ │  │
│  │  │ Frontend │  │ Backend  │  │  Proxy   │ │  │
│  │  │SvelteKit │  │  Spring  │  │   Go     │ │  │
│  │  │Port 3000 │  │Port 8080 │  │Port 8081 │ │  │
│  │  │Ext: 3100 │  │Ext: 8180 │  │Ext: 8181 │ │  │
│  │  └──────────┘  └──────────┘  └──────────┘ │  │
│  └─────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Request Flow

```
Browser Request (http://opentube.local/api/v1/search?query=cats)
    │
    ├─→ Avahi/mDNS resolves opentube.local → 127.0.0.1
    │
    ├─→ Nginx receives request on port 80
    │
    ├─→ Nginx matches location /api/
    │
    ├─→ Nginx forwards to localhost:8180/api/
    │
    ├─→ Docker backend container receives request
    │
    ├─→ Spring Boot processes and queries YouTube
    │
    └─→ Returns JSON response back through chain
```

### Port Mapping

| Service | Container Port | Host Port | Direct Access |
|---------|----------------|-----------|---------------|
| Frontend | 3000 | 3100 | http://localhost:3100 |
| Backend | 8080 | 8180 | http://localhost:8180 |
| Proxy | 8081 | 8181 | http://localhost:8181 |
| Nginx | - | 80 | http://opentube.local |

**Why non-standard ports?** Ports 3000, 8080, and 8081 are kept free for other development projects.

---

## Prerequisites

### Required Software

#### On Manjaro/Arch Linux

```bash
# Install all prerequisites
sudo pacman -S docker docker-compose nginx avahi nss-mdns

# Verify installation
docker --version          # Should show Docker version
docker-compose --version  # Should show Docker Compose version
nginx -v                  # Should show Nginx version
```

#### On Ubuntu/Debian

```bash
# Update package list
sudo apt update

# Install prerequisites
sudo apt install docker.io docker-compose nginx avahi-daemon libnss-mdns

# Verify installation
docker --version
docker-compose --version
nginx -v
```

### User Configuration

```bash
# Add your user to the docker group
sudo usermod -aG docker $USER

# IMPORTANT: Log out and log back in for this to take effect
# Verify after logging back in
groups | grep docker
# Should show 'docker' in your groups
```

**⚠️ Critical**: You must log out and log back in after adding yourself to the docker group, or the changes won't take effect.

### Enable Docker Service

```bash
# Enable Docker to start on boot
sudo systemctl enable docker

# Start Docker now
sudo systemctl start docker

# Verify Docker is running
systemctl status docker
# Should show: active (running)
```

### Required Files

Before starting, ensure you have these files in your `deployment/` directory:

- `docker-compose.yml` - Docker configuration with correct ports
- `nginx.conf` - Nginx reverse proxy configuration
- `fix-local-dns.sh` - Script to configure mDNS (optional)

---

## Deployment Steps

### Step 1: System Configuration

#### 1.1 Set Hostname

Setting your hostname to `opentube` enables network-wide access via `opentube.local`:

```bash
# Set hostname
sudo hostnamectl set-hostname opentube

# Verify
hostnamectl
# Should show: Static hostname: opentube
```

**What this does**: Your machine announces itself on the network as `opentube`, making it accessible at `opentube.local` from any device.

#### 1.2 Enable Avahi (mDNS) Service

Avahi enables `.local` domain resolution on your network:

```bash
# Enable and start Avahi
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# Verify it's running
systemctl status avahi-daemon
# Should show: active (running)
```

**What this does**: Avahi broadcasts your hostname on the network, allowing other devices to discover and connect to `opentube.local`.

#### 1.3 Configure mDNS Resolution

Configure your system to resolve `.local` domains:

```bash
# Install mDNS support (if not already installed)
sudo pacman -S nss-mdns  # Manjaro/Arch
# or
sudo apt install libnss-mdns  # Ubuntu/Debian

# Backup current configuration
sudo cp /etc/nsswitch.conf /etc/nsswitch.conf.backup

# Edit nsswitch.conf
sudo nano /etc/nsswitch.conf

# Find the line starting with "hosts:" and replace it with:
hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns

# Save and exit (Ctrl+O, Enter, Ctrl+X)
```

**What this does**: Tells your system to use mDNS for resolving `.local` domains before trying DNS.

```bash
# Apply changes
sudo systemctl restart avahi-daemon
sudo systemctl restart NetworkManager

# Test (wait 10 seconds first)
sleep 10
ping -c 3 opentube.local
# Should respond from 127.0.0.1
```

**Automated alternative**: Use the provided script:

```bash
chmod +x fix-local-dns.sh
./fix-local-dns.sh
```

---

### Step 2: Nginx Configuration

#### 2.1 Create Nginx Directory Structure

Manjaro/Arch doesn't include `sites-available/sites-enabled` by default:

```bash
# Create directories
sudo mkdir -p /etc/nginx/sites-available
sudo mkdir -p /etc/nginx/sites-enabled

# Verify
ls -ld /etc/nginx/sites-available /etc/nginx/sites-enabled
```

#### 2.2 Create/Update nginx.conf

Create the main Nginx configuration:

```bash
# Backup existing config if present
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup 2>/dev/null || true

# Create new nginx.conf
sudo tee /etc/nginx/nginx.conf > /dev/null << 'EOF'
user http;
worker_processes auto;
worker_cpu_affinity auto;

events {
    multi_accept on;
    worker_connections 1024;
}

http {
    charset utf-8;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    server_tokens off;
    log_not_found off;
    types_hash_max_size 4096;
    client_max_body_size 16M;

    # MIME types
    include mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # Load site configurations
    include /etc/nginx/sites-enabled/*;
}
EOF
```

**What this does**: 
- Sets up Nginx to run as the `http` user (standard on Arch)
- Configures performance settings
- Includes site-specific configurations from `sites-enabled/`

#### 2.3 Install OpenTube Nginx Configuration

```bash
# Navigate to deployment directory
cd deployment

# Copy OpenTube nginx config
sudo cp nginx-local.conf /etc/nginx/sites-available/opentube

# Verify it's a file (not a directory)
file /etc/nginx/sites-available/opentube
# Should show: ASCII text

# Create symbolic link to enable the site
sudo ln -sf /etc/nginx/sites-available/opentube /etc/nginx/sites-enabled/opentube

# Remove default site if it exists
sudo rm -f /etc/nginx/sites-enabled/default

# Verify symlink
ls -l /etc/nginx/sites-enabled/
# Should show: opentube -> /etc/nginx/sites-available/opentube
```

**Common mistake**: If `opentube` becomes a directory instead of a file, remove it and re-copy:

```bash
sudo rm -rf /etc/nginx/sites-available/opentube
sudo cp nginx-local.conf /etc/nginx/sites-available/opentube
```

#### 2.4 Test Nginx Configuration

```bash
# Test configuration for syntax errors
sudo nginx -t

# Should show:
# nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
# nginx: configuration file /etc/nginx/nginx.conf test is successful
```

**If you get errors**: See the [Troubleshooting](#troubleshooting) section.

---

### Step 3: Docker Setup

#### 3.1 Stop Any Existing Containers

Clean up any previously running containers:

```bash
# Stop and remove all deployment containers
docker-compose down

# Force remove any lingering containers
docker ps -a | grep deployment | awk '{print $1}' | xargs -r docker rm -f

# Remove any orphaned networks
docker network prune -f

# Verify nothing is running
docker ps
# Should show no deployment containers
```

#### 3.2 Build Docker Images

This is the longest step (10-15 minutes):

```bash
# Build all three services
docker-compose build

# You'll see output like:
# Building frontend...
# Building backend...
# Building proxy...
# Successfully built...
# Successfully tagged opentube-frontend:latest
# Successfully tagged opentube-backend:latest
# Successfully tagged opentube-proxy:latest
```

**Why this takes time**:
- Frontend: npm installs dependencies and builds SvelteKit app
- Backend: Maven downloads Java dependencies and compiles Spring Boot app
- Proxy: Go builds the streaming proxy

#### 3.3 Start Docker Services

```bash
# Start all services in detached mode
docker-compose up -d

# Should show:
# Container deployment-frontend-1  Started
# Container deployment-backend-1   Started
# Container deployment-proxy-1     Started
```

#### 3.4 Verify Services Are Running

```bash
# Wait for backend to fully initialize (takes 30-60 seconds)
sleep 30

# Check service status
docker-compose ps

# Should show all three services as "Up (healthy)":
# NAME                    STATUS
# deployment-frontend-1   Up (healthy)   0.0.0.0:3100->3000/tcp
# deployment-backend-1    Up (healthy)   0.0.0.0:8180->8080/tcp
# deployment-proxy-1      Up (healthy)   0.0.0.0:8181->8081/tcp
```

**Health check meanings**:
- `Up (starting)` - Service is booting up
- `Up (healthy)` - Service is ready and responding
- `Up (unhealthy)` - Service started but health check failed

#### 3.6 Monitor Backend Startup

The backend takes the longest to start:

```bash
# Follow backend logs
docker-compose logs -f backend

# Look for this line:
# Started App in X seconds (process running for Y)

# Press Ctrl+C when you see it

# Or check if it's ready:
docker-compose logs backend | grep "Started App"
```

**Typical startup time**: 30-90 seconds depending on your hardware.

---

### Step 4: Start Nginx

#### 4.1 Enable and Start Nginx

```bash
# Enable Nginx to start on boot
sudo systemctl enable nginx

# Start Nginx
sudo systemctl start nginx

# Verify Nginx is running
systemctl status nginx
# Should show: active (running)
```

#### 4.2 Verify Nginx Configuration

```bash
# Check Nginx is listening on port 80
sudo netstat -tlnp | grep :80
# Should show: 0.0.0.0:80 ... nginx

# Check for errors in logs
sudo journalctl -u nginx -n 50 --no-pager

# No critical errors should appear
```

---

### Step 5: Verification

#### 5.1 Test Local Endpoints

```bash
# Test health endpoint
curl http://localhost/health
# Should return: healthy

# Test backend API
curl http://localhost/api/v1/search?query=test
# Should return JSON with search results

# Test frontend
curl -I http://localhost
# Should return: HTTP/1.1 200 OK
```

#### 5.2 Test .local Domain

```bash
# Test DNS resolution
ping -c 3 opentube.local
# Should respond from 127.0.0.1

# Test health via .local
curl http://opentube.local/health
# Should return: healthy

# Test API via .local
curl http://opentube.local/api/v1/search?query=test
# Should return JSON
```

**If opentube.local doesn't resolve**, see [Troubleshooting](#troubleshooting).

#### 5.3 Test in Web Browser

```bash
# Open in default browser
xdg-open http://opentube.local

# Or manually open: http://opentube.local
```

**Expected behavior**:
1. OpenTube homepage loads
2. Search bar is visible
3. No console errors in browser developer tools

#### 5.4 Test Full Application Functionality

**In the browser at http://opentube.local:**

1. **Search** - Type "test" and press Enter
   - Search results should appear within 2-3 seconds
   - Thumbnails should load

2. **Video Details** - Click on any video
   - Video page should load
   - Title, description, and metadata visible

3. **Video Playback** - Video should start playing
   - Player controls visible
   - Quality selector available (gear icon)
   - Video plays smoothly

4. **Related Videos** - Related videos appear on the right/below
   - Thumbnails load
   - Clicking works

**All features working?** ✅ Deployment successful!

#### 5.5 Test from Another Device (Optional)

**From a phone, tablet, or another computer on the same network:**

```bash
# On the OpenTube server, find your local IP
ip addr show | grep "inet " | grep -v 127.0.0.1
# Example: inet 192.168.1.100/24

# From another device, try both:
# 1. http://opentube.local
# 2. http://192.168.1.100 (use your actual IP)
```

**If firewall is blocking**:

```bash
# Allow HTTP traffic
sudo ufw allow 80/tcp

# Or allow only from local network
sudo ufw allow from 192.168.0.0/16 to any port 80
```

---

## Troubleshooting

### opentube.local Doesn't Resolve

**Symptom**: `ping opentube.local` fails or browser can't find server

**Solutions**:

**Option 1: Quick fix - Add to /etc/hosts**

```bash
sudo nano /etc/hosts

# Add this line:
127.0.0.1   opentube.local

# Save and exit
# Now opentube.local works immediately
```

**Option 2: Fix mDNS properly**

```bash
# Check Avahi is running
systemctl status avahi-daemon
# If not: sudo systemctl start avahi-daemon

# Check hostname
hostnamectl
# Should show: opentube

# Check nsswitch.conf
grep "^hosts:" /etc/nsswitch.conf
# Should include: mdns_minimal

# Run the fix script
./fix-local-dns.sh

# Restart network
sudo systemctl restart NetworkManager

# Wait and test
sleep 10
ping opentube.local
```

**Option 3: Use localhost instead**

```bash
# Just use localhost - works the same
xdg-open http://localhost
```

---

### Nginx Won't Start

**Symptom**: `systemctl status nginx` shows failed or inactive

**Check 1: Configuration errors**

```bash
# Test config
sudo nginx -t

# Fix any errors shown
# Common: missing semicolon, wrong file path, invalid directive
```

**Check 2: Port 80 already in use**

```bash
# Check what's using port 80
sudo netstat -tlnp | grep :80

# If Apache or another web server:
sudo systemctl stop apache2  # or httpd
sudo systemctl disable apache2
```

**Check 3: Permissions**

```bash
# Check nginx user exists
grep ^http: /etc/passwd

# Check log directory
ls -ld /var/log/nginx
sudo mkdir -p /var/log/nginx
sudo chown -R http:http /var/log/nginx  # Arch
# or
sudo chown -R www-data:www-data /var/log/nginx  # Ubuntu
```

**Check logs**:

```bash
sudo journalctl -u nginx -xe
sudo cat /var/log/nginx/error.log
```

---

### Docker Services Won't Start

**Symptom**: `docker-compose ps` shows containers as exited or unhealthy

**Check 1: Docker daemon**

```bash
systemctl status docker
# If not running: sudo systemctl start docker
```

**Check 2: Port conflicts**

```bash
# Check if ports are in use
sudo netstat -tlnp | grep -E ':(3100|8180|8181)'

# If something else is using them, stop it or change ports in docker-compose.yml
```

**Check 3: View container logs**

```bash
# Check each service
docker-compose logs frontend
docker-compose logs backend
docker-compose logs proxy

# Follow logs in real-time
docker-compose logs -f
```

**Check 4: Rebuild containers**

```bash
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

---

### Backend Takes Too Long to Start

**Symptom**: Backend shows "Up (starting)" for more than 2 minutes

**This is usually normal** - Java applications are slow to start.

**Check progress**:

```bash
# Follow backend logs
docker-compose logs -f backend

# Look for:
# - Loading Spring context
# - Initializing beans
# - Started App in X seconds (this is the success message)
```

**If truly stuck** (no log output for 5+ minutes):

```bash
# Restart backend
docker-compose restart backend

# Check for errors
docker-compose logs backend | grep -i error
```

---

### Video Playback Doesn't Work

**This should NOT happen with local deployment** (YouTube doesn't block residential IPs).

**If videos won't play**:

**Check 1: Backend is responding**

```bash
# Test video details endpoint
curl http://localhost:8180/api/v1/streams/details?id=dQw4w9WgXcQ

# Should return JSON, not an error
```

**Check 2: Proxy is working**

```bash
# Check proxy logs
docker-compose logs proxy

# Should show: YouTube Stream Proxy starting on port 8081
```

**Check 3: Browser console**

```
Open browser developer tools (F12)
Go to Console tab
Look for errors
```

Common issues:
- Network errors → Check if backend/proxy are running
- CORS errors → Check Nginx configuration
- 404 errors → Check URL routing in Nginx

---

### Can't Access from Other Devices

**Symptom**: Works on server but not from phone/other computers

**Check 1: Firewall**

```bash
# Check firewall status
sudo ufw status

# Allow port 80
sudo ufw allow 80/tcp

# Or allow from local network only
sudo ufw allow from 192.168.0.0/16 to any port 80
```

**Check 2: mDNS works on other device**

```bash
# From the other device, try ping
ping opentube.local

# If doesn't work, use IP address instead
# On server: ip addr show
# Use: http://192.168.1.100 (your actual IP)
```

**Check 3: Network routing**

```bash
# Verify both devices are on same network
# Check IP ranges match (e.g., both 192.168.1.x)
```

---

## Maintenance

### Daily Operations

**View Logs**:

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f backend

# Nginx logs
sudo journalctl -u nginx -f
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

**Restart Services**:

```bash
# Restart all Docker services
docker-compose restart

# Restart specific service
docker-compose restart backend

# Restart Nginx
sudo systemctl restart nginx
```

**Stop Everything**:

```bash
# Stop Docker services
docker-compose down

# Stop Nginx
sudo systemctl stop nginx
```

**Start Everything**:

```bash
# Start Docker services
docker-compose up -d

# Start Nginx
sudo systemctl start nginx
```

---

### Updating the Application

**When you pull new code from Git**:

```bash
cd /path/to/OpenTube

# Pull latest changes
git pull

# Navigate to deployment
cd deployment

# Stop services
docker-compose down

# Rebuild images
docker-compose build

# Start services
docker-compose up -d

# Check everything started
docker-compose ps

# Reload Nginx (if config changed)
sudo systemctl reload nginx
```

---

### Backups

**Backup Backend Data**:

```bash
# Create backup of backend data volume
docker run --rm \
  -v deployment_backend-data:/data \
  -v $(pwd):/backup \
  ubuntu tar czf /backup/backend-data-$(date +%Y%m%d).tar.gz /data

# Backup stored in: backend-data-YYYYMMDD.tar.gz
```

**Backup Configuration Files**:

```bash
# Backup Nginx config
sudo cp /etc/nginx/sites-available/opentube ~/backups/nginx-opentube-$(date +%Y%m%d).conf

# Backup docker-compose
cp docker-compose.yml ~/backups/docker-compose-$(date +%Y%m%d).yml
```

**Restore Backend Data**:

```bash
# Stop services
docker-compose down

# Restore from backup
docker run --rm \
  -v deployment_backend-data:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/backend-data-YYYYMMDD.tar.gz -C /

# Start services
docker-compose up -d
```

---

### System Updates

**Update System Packages**:

```bash
# Manjaro/Arch
sudo pacman -Syu

# Ubuntu/Debian
sudo apt update && sudo apt upgrade
```

**Update Docker Images**:

```bash
cd deployment

# Pull latest base images
docker-compose pull

# Rebuild with new base images
docker-compose build --pull

# Restart
docker-compose up -d
```

---

## Advanced Configuration

### Custom Ports

**To change the external ports**, edit `docker-compose.yml`:

```yaml
services:
  frontend:
    ports:
      - "4000:3000"  # Change 4000 to your desired port
  backend:
    ports:
      - "9000:8080"  # Change 9000 to your desired port
  proxy:
    ports:
      - "9001:8081"  # Change 9001 to your desired port
```

Then update `nginx-local.conf`:

```nginx
upstream opentube_frontend {
    server localhost:4000;  # Match your new port
}
upstream opentube_backend {
    server localhost:9000;  # Match your new port
}
upstream opentube_stream_proxy {
    server localhost:9001;  # Match your new port
}
```

Reload:

```bash
docker-compose down
docker-compose up -d
sudo systemctl reload nginx
```

---

### SSL/HTTPS Setup

**For local development with self-signed certificate**:

```bash
# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/opentube.key \
  -out /etc/ssl/certs/opentube.crt \
  -subj "/CN=opentube.local"

# Update Nginx config
sudo nano /etc/nginx/sites-available/opentube
```

Add SSL configuration:

```nginx
server {
    listen 80;
    server_name opentube.local;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name opentube.local;

    ssl_certificate /etc/ssl/certs/opentube.crt;
    ssl_certificate_key /etc/ssl/private/opentube.key;

    # ... rest of your configuration
}
```

Reload Nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

Access via: `https://opentube.local` (you'll get a security warning - this is normal for self-signed certs)

---

### Performance Tuning

**Increase Backend Memory**:

Edit `docker-compose.yml`:

```yaml
backend:
  environment:
    - JAVA_OPTS=-Xmx2g -Xms1g  # 2GB max, 1GB initial
```

**Optimize Nginx**:

Edit `/etc/nginx/nginx.conf`:

```nginx
worker_processes auto;  # Use all CPU cores
worker_connections 2048;  # Increase if needed
```

**Docker Resource Limits**:

Edit `docker-compose.yml`:

```yaml
backend:
  deploy:
    resources:
      limits:
        cpus: '2.0'
        memory: 2G
```

---

### Auto-Start on Boot

**Verify services start automatically**:

```bash
# Check Docker
systemctl is-enabled docker
# Should show: enabled

# Check Nginx
systemctl is-enabled nginx
# Should show: enabled

# Check Avahi
systemctl is-enabled avahi-daemon
# Should show: enabled

# Docker Compose services auto-restart with:
# restart: unless-stopped (already in docker-compose.yml)
```

---

## Quick Reference

### Access URLs

- **Primary**: http://opentube.local
- **Alternative**: http://localhost
- **From network**: http://YOUR_LOCAL_IP
- **Frontend direct**: http://localhost:3100
- **Backend direct**: http://localhost:8180
- **Proxy direct**: http://localhost:8181

### Key Commands

```bash
# Start everything
docker-compose up -d && sudo systemctl start nginx

# Stop everything
docker-compose down && sudo systemctl stop nginx

# Restart
docker-compose restart && sudo systemctl restart nginx

# View logs
docker-compose logs -f
sudo journalctl -u nginx -f

# Rebuild after code changes
docker-compose down && docker-compose build && docker-compose up -d

# Check status
docker-compose ps
systemctl status nginx
systemctl status avahi-daemon
```

### Service Status

```bash
# Check all services
docker-compose ps
systemctl status nginx
systemctl status avahi-daemon
systemctl status docker

# Check if ports are open
sudo netstat -tlnp | grep -E ':(80|3100|8180|8181)'

# Test endpoints
curl http://localhost/health
curl http://localhost/api/v1/search?query=test
ping opentube.local
```

---

## Success Criteria

Your deployment is successful when:

- ✅ `docker-compose ps` shows all services as "Up (healthy)"
- ✅ `systemctl status nginx` shows "active (running)"
- ✅ `curl http://localhost/health` returns "healthy"
- ✅ `curl http://localhost/api/v1/search?query=test` returns JSON
- ✅ `ping opentube.local` responds from 127.0.0.1
- ✅ Browser at http://opentube.local shows homepage
- ✅ Search works and returns results
- ✅ Videos play without errors
- ✅ Can access from other devices on network

---

## Getting Help

### Check Logs First

```bash
# Docker logs
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f proxy

# Nginx logs
sudo journalctl -u nginx -xe
sudo tail -50 /var/log/nginx/error.log

# System logs
sudo journalctl -xe
```

### Common Log Locations

- Docker: `docker-compose logs`
- Nginx access: `/var/log/nginx/access.log`
- Nginx error: `/var/log/nginx/error.log`
- System: `journalctl -u nginx` or `journalctl -u docker`

### Debugging Steps

1. Check all services are running
2. Check logs for errors
3. Test each service individually
4. Verify network connectivity
5. Check firewall rules
6. Review configuration files

---

## Additional Resources

- **Docker Documentation**: https://docs.docker.com/
- **Nginx Documentation**: https://nginx.org/en/docs/
- **Avahi/mDNS**: https://avahi.org/
- **Spring Boot**: https://spring.io/projects/spring-boot
- **SvelteKit**: https://kit.svelte.dev/

---

**Deployment Guide Version**: 1.0  
**Last Updated**: December 26, 2024  
**Tested On**: Manjaro Linux, Ubuntu 22.04  
**Status**: ✅ Production Ready