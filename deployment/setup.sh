#!/bin/bash
set -e

echo "=== OpenTube Deployment Setup ==="

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "Please don't run as root"
  exit 1
fi

# Create directory structure
mkdir -p /opt/opentube
cd /opt/opentube

# Copy deployment files (you'll need to transfer these)
echo "Copy your docker-compose.yml and nginx.conf to /opt/opentube/"
echo "Then run this script again with the 'deploy' argument"

if [ "$1" == "deploy" ]; then
    echo "Starting deployment..."
    
    # Stop existing containers
    docker-compose down 2>/dev/null || true
    
    # Pull/build images
    docker-compose build
    
    # Start services
    docker-compose up -d
    
    # Configure Nginx
    sudo cp nginx.conf /etc/nginx/sites-available/opentube
    sudo ln -sf /etc/nginx/sites-available/opentube /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t
    sudo systemctl restart nginx
    
    echo "=== Deployment complete! ==="
    echo "Check status with: docker-compose ps"
    echo "View logs with: docker-compose logs -f"
fi
