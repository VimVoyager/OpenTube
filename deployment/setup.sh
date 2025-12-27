#!/bin/bash
set -e

echo "=== OpenTube Local Deployment Setup ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running on Linux
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}This script is designed for Linux. Exiting.${NC}"
    exit 1
fi

# 1. Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

# Check for nginx
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}Nginx not found. Please install: sudo pacman -S nginx${NC}"
    exit 1
fi

# Check for avahi (mDNS)
if ! systemctl is-active --quiet avahi-daemon; then
    echo -e "${YELLOW}Avahi daemon not running. Installing and starting...${NC}"
    sudo pacman -S --noconfirm avahi
    sudo systemctl enable avahi-daemon
    sudo systemctl start avahi-daemon
fi

# Check for docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker not found. Please install Docker first.${NC}"
    exit 1
fi

# Check for docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose not found. Please install Docker Compose first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# 2. Set hostname
echo -e "${YELLOW}Step 2: Setting up hostname...${NC}"
CURRENT_HOSTNAME=$(hostnamectl --static)

if [ "$CURRENT_HOSTNAME" != "opentube" ]; then
    echo "Current hostname: $CURRENT_HOSTNAME"
    read -p "Set hostname to 'opentube'? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo hostnamectl set-hostname opentube
        echo -e "${GREEN}✓ Hostname set to opentube${NC}"
        echo -e "${GREEN}  You can now access at: http://opentube.local${NC}"
    else
        echo -e "${YELLOW}  Skipping hostname change${NC}"
        echo -e "${YELLOW}  You'll access at: http://$CURRENT_HOSTNAME.local${NC}"
    fi
else
    echo -e "${GREEN}✓ Hostname already set to opentube${NC}"
fi
echo ""

# 3. Copy docker-compose file
echo -e "${YELLOW}Step 3: Setting up Docker Compose...${NC}"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEPLOYMENT_DIR="$SCRIPT_DIR"

if [ -f "$DEPLOYMENT_DIR/docker-compose.local.yml" ]; then
    cp "$DEPLOYMENT_DIR/docker-compose.local.yml" "$DEPLOYMENT_DIR/docker-compose.yml"
    echo -e "${GREEN}✓ Docker Compose configured for local deployment${NC}"
else
    echo -e "${RED}docker-compose.local.yml not found!${NC}"
    exit 1
fi
echo ""

# 4. Configure Nginx
echo -e "${YELLOW}Step 4: Configuring Nginx...${NC}"

# Detect Nginx configuration directory structure
NGINX_AVAILABLE="/etc/nginx/sites-available"
NGINX_ENABLED="/etc/nginx/sites-enabled"

# Manjaro/Arch may not have sites-available/sites-enabled by default
if [ ! -d "$NGINX_AVAILABLE" ]; then
    echo "Creating Nginx sites directories..."
    sudo mkdir -p "$NGINX_AVAILABLE"
    sudo mkdir -p "$NGINX_ENABLED"
    
    # Check if nginx.conf includes sites-enabled
    if ! sudo grep -q "include.*sites-enabled" /etc/nginx/nginx.conf 2>/dev/null; then
        echo "Updating nginx.conf to include sites-enabled..."
        
        # Backup original nginx.conf
        sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
        
        # Add include directive to http block
        sudo sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
    fi
fi

# Copy nginx config
if [ -f "$DEPLOYMENT_DIR/nginx-local.conf" ]; then
    sudo cp "$DEPLOYMENT_DIR/nginx-local.conf" "$NGINX_AVAILABLE/opentube"
    
    # Enable the site
    sudo ln -sf "$NGINX_AVAILABLE/opentube" "$NGINX_ENABLED/"
    
    # Remove default site if it exists
    sudo rm -f "$NGINX_ENABLED/default"
    
    echo -e "${GREEN}✓ Nginx configuration installed${NC}"
else
    echo -e "${RED}nginx-local.conf not found!${NC}"
    exit 1
fi

# Test nginx config
if sudo nginx -t 2>&1 | grep -q "syntax is ok"; then
    echo -e "${GREEN}✓ Nginx configuration valid${NC}"
else
    echo -e "${RED}Nginx configuration error:${NC}"
    sudo nginx -t
    echo ""
    echo -e "${YELLOW}Attempting to fix...${NC}"
    
    # If nginx.conf doesn't exist, create a basic one
    if [ ! -f /etc/nginx/nginx.conf ]; then
        echo "Creating basic nginx.conf..."
        sudo tee /etc/nginx/nginx.conf > /dev/null << 'NGINX_CONF'
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

    # MIME
    include mime.types;
    default_type application/octet-stream;

    # Logging
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log warn;

    # Load configs
    include /etc/nginx/sites-enabled/*;
}
NGINX_CONF
        
        # Test again
        if sudo nginx -t 2>&1 | grep -q "syntax is ok"; then
            echo -e "${GREEN}✓ Nginx configuration fixed${NC}"
        else
            echo -e "${RED}Could not fix Nginx configuration${NC}"
            sudo nginx -t
            exit 1
        fi
    else
        exit 1
    fi
fi
echo ""

# 5. Build Docker images
echo -e "${YELLOW}Step 5: Building Docker images (this may take 10-15 minutes)...${NC}"
cd "$DEPLOYMENT_DIR"

docker-compose build

echo -e "${GREEN}✓ Docker images built${NC}"
echo ""

# 6. Start services
echo -e "${YELLOW}Step 6: Starting services...${NC}"

docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

echo -e "${GREEN}✓ Docker services started${NC}"
echo ""

# 7. Start/reload Nginx
echo -e "${YELLOW}Step 7: Starting Nginx...${NC}"

sudo systemctl enable nginx
sudo systemctl restart nginx

if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx running${NC}"
else
    echo -e "${RED}Nginx failed to start${NC}"
    sudo systemctl status nginx
    exit 1
fi
echo ""

# 8. Verify deployment
echo -e "${YELLOW}Step 8: Verifying deployment...${NC}"

# Check Docker services
echo "Docker services:"
docker-compose ps

echo ""

# Test health endpoint
if curl -sf http://localhost/health > /dev/null; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${RED}Health check failed${NC}"
fi

# Test API
if curl -sf http://localhost/api/v1/search?query=test > /dev/null; then
    echo -e "${GREEN}✓ Backend API responding${NC}"
else
    echo -e "${RED}Backend API not responding${NC}"
fi

echo ""
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo "Access OpenTube at:"
echo "  - http://opentube.local (from any device on your network)"
echo "  - http://localhost (from this machine)"
echo ""
echo "Useful commands:"
echo "  View logs:        cd $DEPLOYMENT_DIR && docker-compose logs -f"
echo "  Restart services: cd $DEPLOYMENT_DIR && docker-compose restart"
echo "  Stop services:    cd $DEPLOYMENT_DIR && docker-compose down"
echo "  Nginx logs:       sudo journalctl -u nginx -f"
echo ""