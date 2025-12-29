# OpenTube Local Deployment Guide

Complete guide for deploying OpenTube on your local machine or home server.


## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Using the Deployment Script](#using-the-deployment-script)
- [Using the Management Script](#using-the-management-script)
- [Common Operations](#common-operations)


## Overview

OpenTube provides a fully automated deployment system that handles:

 - **Automated dependency installation** - Docker, Nginx, Avahi, OpenSSL
 - **Multi-environment support** - Works on Arch, Ubuntu, Debian, Fedora, and more
 - **SSL/HTTPS support** - Automatic certificate generation
 - **mDNS configuration** - Access via friendly `.local` domains names


## Prerequisites

 - Docker
 - Docker Compose
 - Nginx
 - Avahi (mDNS)
 - OpenSSL

 These will **automatically be installed** if missing.


## Quick Start

### 1. Navigate to the deployment directory

```bash
cd deployment/
```

### 2. Deploy the application

#### Production mode
```bash
# Production deployment with HTTP
./deploy.sh production

# Production deployment with HTTPS
./deploy.sh production ssl_true
```

#### Development mode
```bash
./deploy.sh development
```

You can run production and development mode simultaneously.

### 3. Access OpenTube

Open your browser and navigate to:
  - **http://opentube.local** (or https://opentube.local if SSL enabled)
  - **http://localhost**

For development mode access each service here:
  - http://opentube.local
  - http://localhost:3200 (direct frontend access)
  - http://localhost:8280 (direct backend access)
  - localhost:5005 (debugger)


## Using the Deployment Script
The `deploy.sh` script is your main deployment tool.

```bash
./deploy.sh <environment> [ssl_option] [domain]
```

  1. **environment** (required)
    - `production` or `prod` - Production deployment
    - `development` or `dev` - Development deployment

  2. **ssl_options** (optional)
    - `ssl_true` or `true` - Enable HTTPS
    - `ssl_false` or `false` - Use HTTP (default)

  3. **domain** (optional)
    - Custom domain name (default: `opentube.local`)


## Using the Management Script

The `manage.sh` script provides convenient commands for daily operations.

### Available Commands

#### Service Control

```bash
./manage.sh start          # Start all services
./manage.sh stop           # Stop all services
./manage.sh restart        # Restart all services
./manage.sh status         # Show detailed service status
```

#### Logging

```bash
./manage.sh logs               # View all logs (live tail)
./manage.sh logs-frontend      # Frontend logs only
./manage.sh logs-backend       # Backend logs only
./manage.sh logs-proxy         # Proxy logs only
./manage.sh logs-nginx         # Nginx logs (system journal)
```

#### Maintenance

```bash
./manage.sh rebuild        # Rebuild all images and restart
./manage.sh update         # Pull latest base images and rebuild
./manage.sh clean          # Remove containers (keeps data)
./manage.sh reset          # Remove everything including data
./manage.sh backup         # Backup backend data
```

#### Debugging

```bash
./manage.sh test               # Test all endpoints
./manage.sh shell-frontend     # Open shell in frontend container
./manage.sh shell-backend      # Open shell in backend container
./manage.sh shell-proxy        # Open shell in proxy container
```

### Command Examples

**1. Check Service Status:**
```bash
./manage.sh status
```
Output:
```
Service Status:

Docker Services:
NAME                    STATUS         PORTS
opentube-frontend-1     Up (healthy)   0.0.0.0:3100->3000/tcp
opentube-backend-1      Up (healthy)   0.0.0.0:8180->8080/tcp
opentube-proxy-1        Up (healthy)   0.0.0.0:8181->8081/tcp

Nginx Status:
● nginx.service - A high performance web server
     Active: active (running)

Avahi Status:
● avahi-daemon.service - Avahi mDNS/DNS-SD Stack
     Active: active (running)
```

**2. View Logs:**
```bash
# All logs (follows in real-time)
./manage.sh logs

# Backend only
./manage.sh logs-backend

# Last 100 lines
docker-compose -f docker-compose.active.yml logs --tail=100
```

**3. Restart Services:**
```bash
# Quick restart (keeps containers)
./manage.sh restart

# Full rebuild (after code changes)
./manage.sh rebuild
```

**4. Test Deployment:**
```bash
./manage.sh test
```
Output:
```
Testing endpoints...

Testing health endpoint...
✓ Health check passed

Testing backend API...
✓ Backend API responding

Testing frontend...
✓ Frontend responding

Testing domain resolution...
✓ opentube.local resolves

Access URLs:
  Primary:  http://opentube.local
  Local:    http://localhost
```

**5. Backup Data:**
```bash
./manage.sh backup
```
Output:
```
Creating backup: opentube-backup-20241229-143022.tar.gz
✓ Backup created: opentube-backup-20241229-143022.tar.gz
```

**6. Access Container Shell:**
```bash
# Backend container
./manage.sh shell-backend

# Now you're inside the container
ls -la /app
ps aux
exit
```

**7. Update Images:**
```bash
./manage.sh update
```
This will:
- Pull latest base images (node, maven, golang)
- Rebuild all application images
- Restart services with new images


## Common Operations

### Daily Operations

**Check status:**
```bash
./manage.sh status
```

**View logs:**
```bash
./manage.sh logs
```

**Restart after system reboot:**
```bash
# Services auto-start on boot, but if needed:
./manage.sh start
```

### After Code Changes

**1. Frontend changes:**
```bash
# Development (auto-reload)
# Just save files - changes appear immediately

# Production
./manage.sh rebuild
```

**2. Backend changes:**
```bash
# Development
docker-compose -f docker-compose.dev.yml restart backend

# Production
./manage.sh rebuild
```

**3. Proxy changes:**
```bash
./manage.sh rebuild
```

### Updating OpenTube

**Get latest code:**
```bash
cd /path/to/opentube
git pull
```

**Rebuild and restart:**
```bash
cd deployment
./manage.sh rebuild
```

**Or update base images:**
```bash
./manage.sh update
```

### Backup and Restore

**Create backup:**
```bash
./manage.sh backup
# Creates: opentube-backup-YYYYMMDD-HHMMSS.tar.gz
```

**Restore from backup:**
```bash
# Stop services
./manage.sh stop

# Restore
docker run --rm \
  -v deployment_backend-data:/data \
  -v $(pwd):/backup \
  ubuntu tar xzf /backup/opentube-backup-YYYYMMDD-HHMMSS.tar.gz -C /

# Start services
./manage.sh start
```

**Automated backups (cron):**
```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * cd /path/to/opentube/deployment && ./manage.sh backup

# Keep only last 7 days
0 3 * * * find /path/to/opentube/deployment -name "opentube-backup-*.tar.gz" -mtime +7 -delete
```

### Switching Environments

**From production to development:**
```bash
# Stop production
docker-compose -f docker-compose.prod.yml down

# Start development
./deploy.sh development
```

**Running both:**
```bash
# They use different ports, so both can run simultaneously
./deploy.sh production    # Ports 3100/8180/8181
./deploy.sh development   # Ports 3200/8280/8281
```

### Cleanup

**Remove containers (keep data):**
```bash
./manage.sh clean
```

**Remove everything (including data):**
```bash
./manage.sh reset
```

**Clean Docker system:**
```bash
# Remove unused images
docker image prune -a

# Remove unused volumes (CAUTION!)
docker volume prune

# Remove everything unused
docker system prune -af --volumes
```



