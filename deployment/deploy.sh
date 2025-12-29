#!/bin/bash
# OpenTube Unified Deployment Script
# Supports: Production, Development, and HTTPS configurations
# Compatible with: Manjaro, Arch, Ubuntu, Debian, Fedora

set -e

# ============================================================================
# COLOR DEFINITIONS
# ============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# ============================================================================
# CONFIGURATION VARIABLES
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENVIRONMENT="${1:-production}"  # production, development, or dev
USE_SSL="${2:-false}"           # true or false
DOMAIN="${3:-opentube.local}"   # Domain name

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(production|development|dev)$ ]]; then
    echo -e "${RED}Error: Invalid environment. Use 'production' or 'development'${NC}"
    echo "Usage: $0 [production|development] [ssl_true|ssl_false] [domain]"
    exit 1
fi

# Normalize dev to development
[[ "$ENVIRONMENT" == "dev" ]] && ENVIRONMENT="development"

# Parse SSL argument
if [[ "$USE_SSL" =~ ^(true|yes|1|ssl_true)$ ]]; then
    USE_SSL=true
elif [[ "$USE_SSL" =~ ^(false|no|0|ssl_false)$ ]]; then
    USE_SSL=false
else
    echo -e "${YELLOW}Warning: Invalid SSL argument, defaulting to false${NC}"
    USE_SSL=false
fi

# ============================================================================
# BANNER
# ============================================================================
print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║            OpenTube Unified Deployment Script                ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${BLUE}Environment:${NC} ${MAGENTA}$ENVIRONMENT${NC}"
    echo -e "${BLUE}SSL Enabled:${NC} ${MAGENTA}$USE_SSL${NC}"
    echo -e "${BLUE}Domain:${NC} ${MAGENTA}$DOMAIN${NC}"
    echo ""
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} ✓ $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} ⚠ $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} ✗ $1"
}

log_step() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

confirm_action() {
    local message="$1"
    local default="${2:-y}"
    
    if [[ "$default" == "y" ]]; then
        read -p "$(echo -e ${YELLOW}$message [Y/n]:${NC}) " -n 1 -r
    else
        read -p "$(echo -e ${YELLOW}$message [y/N]:${NC}) " -n 1 -r
    fi
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY && "$default" == "y" ]]
}

# ============================================================================
# DISTRO DETECTION
# ============================================================================
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_LIKE=$ID_LIKE
    elif command -v lsb_release &> /dev/null; then
        DISTRO=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    else
        log_error "Cannot detect Linux distribution"
        exit 1
    fi
    
    log_info "Detected distribution: $DISTRO"
}

# ============================================================================
# PACKAGE MANAGER ABSTRACTION
# ============================================================================
install_package() {
    local package=$1
    
    case "$DISTRO" in
        arch|manjaro|endeavouros)
            sudo pacman -S --noconfirm --needed "$package"
            ;;
        ubuntu|debian|pop|linuxmint)
            sudo apt-get install -y "$package"
            ;;
        fedora|rhel|centos|rocky|almalinux)
            sudo dnf install -y "$package"
            ;;
        opensuse*)
            sudo zypper install -y "$package"
            ;;
        *)
            log_error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

update_package_cache() {
    case "$DISTRO" in
        arch|manjaro|endeavouros)
            sudo pacman -Sy
            ;;
        ubuntu|debian|pop|linuxmint)
            sudo apt-get update
            ;;
        fedora|rhel|centos|rocky|almalinux)
            sudo dnf check-update || true
            ;;
        opensuse*)
            sudo zypper refresh
            ;;
    esac
}

# ============================================================================
# PREREQUISITES CHECK AND INSTALLATION
# ============================================================================
check_prerequisites() {
    log_step "Step 1: Checking Prerequisites"
    
    # Update package cache
    log_info "Updating package cache..."
    update_package_cache
    
    local missing_packages=()
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_warning "Docker not found"
        missing_packages+=("docker")
    else
        log_success "Docker installed: $(docker --version | head -1)"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_warning "Docker Compose not found"
        case "$DISTRO" in
            arch|manjaro|endeavouros)
                missing_packages+=("docker-compose")
                ;;
            *)
                missing_packages+=("docker-compose")
                ;;
        esac
    else
        if command -v docker-compose &> /dev/null; then
            log_success "Docker Compose installed: $(docker-compose --version)"
        else
            log_success "Docker Compose (plugin) installed"
        fi
    fi
    
    # Check Nginx
    if ! command -v nginx &> /dev/null; then
        log_warning "Nginx not found"
        missing_packages+=("nginx")
    else
        log_success "Nginx installed: $(nginx -v 2>&1 | head -1)"
    fi
    
    # Check Avahi (mDNS)
    if ! systemctl is-active --quiet avahi-daemon 2>/dev/null; then
        log_warning "Avahi daemon not running"
        case "$DISTRO" in
            arch|manjaro|endeavouros)
                missing_packages+=("avahi" "nss-mdns")
                ;;
            ubuntu|debian|pop|linuxmint)
                missing_packages+=("avahi-daemon" "libnss-mdns")
                ;;
            fedora|rhel|centos|rocky|almalinux)
                missing_packages+=("avahi" "nss-mdns")
                ;;
            opensuse*)
                missing_packages+=("avahi" "nss-mdns")
                ;;
        esac
    else
        log_success "Avahi daemon running"
    fi
    
    # Check OpenSSL (for SSL)
    if [[ "$USE_SSL" == true ]] && ! command -v openssl &> /dev/null; then
        log_warning "OpenSSL not found"
        missing_packages+=("openssl")
    fi
    
    # Install missing packages
    if [ ${#missing_packages[@]} -gt 0 ]; then
        log_warning "Missing packages: ${missing_packages[*]}"
        if confirm_action "Install missing packages?"; then
            for package in "${missing_packages[@]}"; do
                log_info "Installing $package..."
                install_package "$package"
            done
            log_success "All packages installed"
        else
            log_error "Cannot continue without required packages"
            exit 1
        fi
    else
        log_success "All prerequisites satisfied"
    fi
    
    # Enable and start Docker
    if ! systemctl is-active --quiet docker; then
        log_info "Starting Docker service..."
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
    
    # Add user to docker group
    if ! groups | grep -q docker; then
        log_warning "User not in docker group"
        if confirm_action "Add current user to docker group? (requires logout)"; then
            sudo usermod -aG docker "$USER"
            log_success "User added to docker group"
            log_warning "You must LOG OUT and LOG BACK IN for this to take effect!"
            log_warning "After logging back in, run this script again."
            exit 0
        fi
    fi
}

# ============================================================================
# HOSTNAME AND mDNS CONFIGURATION
# ============================================================================
configure_hostname() {
    log_step "Step 2: Hostname and mDNS Configuration"
    
    local current_hostname=$(hostnamectl --static 2>/dev/null || hostname)
    local target_hostname="${DOMAIN%.local}"
    
    log_info "Current hostname: $current_hostname"
    log_info "Target hostname: $target_hostname"
    
    if [[ "$current_hostname" != "$target_hostname" ]]; then
        if confirm_action "Change hostname to '$target_hostname'?"; then
            sudo hostnamectl set-hostname "$target_hostname"
            log_success "Hostname changed to $target_hostname"
        else
            log_warning "Keeping hostname as $current_hostname"
            DOMAIN="$current_hostname.local"
            log_info "Domain will be: $DOMAIN"
        fi
    else
        log_success "Hostname already set correctly"
    fi
    
    # Enable and start Avahi
    if ! systemctl is-active --quiet avahi-daemon; then
        log_info "Starting Avahi daemon..."
        sudo systemctl enable avahi-daemon
        sudo systemctl start avahi-daemon
    fi
    
    # Configure mDNS resolution
    log_info "Configuring mDNS resolution..."
    
    if ! grep -q "mdns_minimal" /etc/nsswitch.conf 2>/dev/null; then
        log_info "Updating /etc/nsswitch.conf..."
        sudo cp /etc/nsswitch.conf /etc/nsswitch.conf.backup
        sudo sed -i 's/^hosts:.*/hosts: mymachines mdns_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] files myhostname dns/' /etc/nsswitch.conf
        log_success "mDNS configured in nsswitch.conf"
    else
        log_success "mDNS already configured"
    fi
    
    # Restart Avahi
    sudo systemctl restart avahi-daemon
    
    # Test resolution
    log_info "Testing mDNS resolution..."
    sleep 3
    if ping -c 1 "$DOMAIN" &> /dev/null; then
        log_success "$DOMAIN resolves correctly!"
    else
        log_warning "$DOMAIN doesn't resolve yet (may need a few seconds)"
    fi
}

# ============================================================================
# SSL CERTIFICATE GENERATION
# ============================================================================
generate_ssl_certificate() {
    if [[ "$USE_SSL" != true ]]; then
        return 0
    fi
    
    log_step "Step 3: SSL Certificate Generation"
    
    local cert_path="/etc/ssl/certs/opentube.crt"
    local key_path="/etc/ssl/private/opentube.key"
    
    if [[ -f "$cert_path" ]] && [[ -f "$key_path" ]]; then
        log_success "SSL certificate already exists"
        if ! confirm_action "Regenerate certificate?" "n"; then
            return 0
        fi
    fi
    
    log_info "Generating self-signed SSL certificate..."
    
    # Ensure directories exist
    sudo mkdir -p /etc/ssl/certs /etc/ssl/private
    
    # Generate certificate
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$key_path" \
        -out "$cert_path" \
        -subj "/C=US/ST=Local/L=Local/O=OpenTube/OU=Development/CN=$DOMAIN" \
        2>/dev/null
    
    # Set permissions
    sudo chmod 644 "$cert_path"
    sudo chmod 600 "$key_path"
    
    log_success "SSL certificate generated"
    log_warning "This is a self-signed certificate - browsers will show a warning"
    log_info "Certificate: $cert_path"
    log_info "Key: $key_path"
}

# ============================================================================
# NGINX CONFIGURATION
# ============================================================================
configure_nginx() {
    log_step "Step 4: Nginx Configuration"
    
    # Detect nginx user
    local nginx_user="www-data"
    if [[ "$DISTRO" =~ ^(arch|manjaro|endeavouros)$ ]]; then
        nginx_user="http"
    fi
    
    # Create sites directories
    sudo mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    
    # Check if nginx.conf includes sites-enabled
    if ! sudo grep -q "include.*sites-enabled" /etc/nginx/nginx.conf 2>/dev/null; then
        log_info "Creating nginx.conf with sites-enabled support..."
        sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup 2>/dev/null || true
        
        sudo tee /etc/nginx/nginx.conf > /dev/null << EOF
user $nginx_user;
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
    client_max_body_size 100M;

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
        log_success "nginx.conf created"
    fi
    
    # Generate nginx site configuration
    local nginx_conf="/etc/nginx/sites-available/opentube"
    local protocol="http"
    local port=80
    
    if [[ "$USE_SSL" == true ]]; then
        protocol="https"
        port=443
    fi
    
    # Determine upstream ports based on environment
    local frontend_port=3100
    local backend_port=8180
    local proxy_port=8181
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        frontend_port=3200
        backend_port=8280
        proxy_port=8281
    fi
    
    log_info "Creating nginx configuration..."
    
    if [[ "$USE_SSL" == true ]]; then
        # HTTPS configuration
        sudo tee "$nginx_conf" > /dev/null << EOF
# OpenTube Nginx Configuration - $ENVIRONMENT (HTTPS)

upstream opentube_frontend {
    server localhost:$frontend_port;
}

upstream opentube_backend {
    server localhost:$backend_port;
}

upstream opentube_stream_proxy {
    server localhost:$proxy_port;
}

# HTTP -> HTTPS redirect
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL configuration
    ssl_certificate /etc/ssl/certs/opentube.crt;
    ssl_certificate_key /etc/ssl/private/opentube.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    client_max_body_size 100M;

    # Backend API
    location /api/ {
        proxy_pass http://opentube_backend/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Stream Proxy
    location /proxy/ {
        proxy_pass http://opentube_stream_proxy/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Critical for video streaming
        proxy_buffering off;
        proxy_request_buffering off;
        
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        proxy_set_header Range \$http_range;
        proxy_set_header If-Range \$http_if_range;
    }

    # Frontend
    location / {
        proxy_pass http://opentube_frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    else
        # HTTP configuration
        sudo tee "$nginx_conf" > /dev/null << EOF
# OpenTube Nginx Configuration - $ENVIRONMENT (HTTP)

upstream opentube_frontend {
    server localhost:$frontend_port;
}

upstream opentube_backend {
    server localhost:$backend_port;
}

upstream opentube_stream_proxy {
    server localhost:$proxy_port;
}

server {
    listen 80;
    server_name $DOMAIN;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    client_max_body_size 100M;

    # Backend API
    location /api/ {
        proxy_pass http://opentube_backend/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Stream Proxy
    location /proxy/ {
        proxy_pass http://opentube_stream_proxy/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Critical for video streaming
        proxy_buffering off;
        proxy_request_buffering off;
        
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        proxy_set_header Range \$http_range;
        proxy_set_header If-Range \$http_if_range;
    }

    # Frontend
    location / {
        proxy_pass http://opentube_frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    fi
    
    # Enable site
    sudo ln -sf /etc/nginx/sites-available/opentube /etc/nginx/sites-enabled/opentube
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    if sudo nginx -t 2>&1 | grep -q "syntax is ok"; then
        log_success "Nginx configuration valid"
    else
        log_error "Nginx configuration has errors:"
        sudo nginx -t
        exit 1
    fi
}

# ============================================================================
# DOCKER COMPOSE SETUP
# ============================================================================
setup_docker_compose() {
    log_step "Step 5: Docker Compose Configuration"
    
    local compose_file="$SCRIPT_DIR/docker-compose.yml"
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        compose_file="$SCRIPT_DIR/docker-compose.dev.yml"
    fi
    
    if [[ ! -f "$compose_file" ]]; then
        log_error "Docker compose file not found: $compose_file"
        exit 1
    fi
    
    log_info "Using compose file: $compose_file"
    
    # Create symlink for active compose file
    ln -sf "$(basename $compose_file)" "$SCRIPT_DIR/docker-compose.active.yml"
    
    log_success "Docker Compose configured for $ENVIRONMENT"
}

# ============================================================================
# BUILD AND START SERVICES
# ============================================================================
build_and_start() {
    log_step "Step 6: Building and Starting Services"
    
    cd "$SCRIPT_DIR"
    
    local compose_file="docker-compose.active.yml"
    
    # Stop existing services
    if docker-compose -f "$compose_file" ps -q 2>/dev/null | grep -q .; then
        log_info "Stopping existing services..."
        docker-compose -f "$compose_file" down
    fi
    
    # Build images
    log_info "Building Docker images (this may take 10-15 minutes)..."
    docker-compose -f "$compose_file" build --pull
    
    log_success "Docker images built"
    
    # Start services
    log_info "Starting services..."
    docker-compose -f "$compose_file" up -d
    
    # Wait for services
    log_info "Waiting for services to initialize..."
    sleep 10
    
    # Check status
    if docker-compose -f "$compose_file" ps | grep -q "Up"; then
        log_success "Docker services started"
    else
        log_error "Some services failed to start"
        docker-compose -f "$compose_file" ps
        exit 1
    fi
    
    # Start nginx
    log_info "Starting Nginx..."
    sudo systemctl enable nginx
    sudo systemctl restart nginx
    
    if systemctl is-active --quiet nginx; then
        log_success "Nginx started"
    else
        log_error "Nginx failed to start"
        sudo systemctl status nginx
        exit 1
    fi
}

# ============================================================================
# VERIFICATION
# ============================================================================
verify_deployment() {
    log_step "Step 7: Verification"
    
    local protocol="http"
    [[ "$USE_SSL" == true ]] && protocol="https"
    
    # Check Docker services
    log_info "Docker services:"
    docker-compose -f docker-compose.active.yml ps
    echo ""
    
    # Test health endpoint
    log_info "Testing health endpoint..."
    if curl -sf${USE_SSL:+k} $protocol://localhost/health > /dev/null; then
        log_success "Health check passed"
    else
        log_warning "Health check failed (services may still be starting)"
    fi
    
    # Test API
    log_info "Testing backend API..."
    sleep 5
    if curl -sf${USE_SSL:+k} "$protocol://localhost/api/v1/search?query=test" > /dev/null 2>&1; then
        log_success "Backend API responding"
    else
        log_warning "Backend API not responding yet"
    fi
    
    # Test domain resolution
    log_info "Testing domain resolution..."
    if ping -c 1 "$DOMAIN" &> /dev/null; then
        log_success "$DOMAIN resolves correctly"
    else
        log_warning "$DOMAIN resolution pending"
    fi
}

# ============================================================================
# COMPLETION SUMMARY
# ============================================================================
print_summary() {
    log_step "Deployment Complete!"
    
    local protocol="http"
    local port_display=""
    [[ "$USE_SSL" == true ]] && protocol="https"
    
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  Deployment Successful!                       ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Access URLs:${NC}"
    echo -e "  ${GREEN}●${NC} Primary:  $protocol://$DOMAIN"
    echo -e "  ${GREEN}●${NC} Local:    $protocol://localhost"
    echo ""
    
    if [[ "$ENVIRONMENT" == "development" ]]; then
        echo -e "${CYAN}Development Direct Access:${NC}"
        echo -e "  ${GREEN}●${NC} Frontend: http://localhost:3200"
        echo -e "  ${GREEN}●${NC} Backend:  http://localhost:8280"
        echo -e "  ${GREEN}●${NC} Proxy:    http://localhost:8281"
        echo ""
    fi
    
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "  ${YELLOW}View logs:${NC}        docker-compose -f docker-compose.active.yml logs -f"
    echo -e "  ${YELLOW}Restart:${NC}          docker-compose -f docker-compose.active.yml restart"
    echo -e "  ${YELLOW}Stop:${NC}             docker-compose -f docker-compose.active.yml down"
    echo -e "  ${YELLOW}Rebuild:${NC}          docker-compose -f docker-compose.active.yml build && docker-compose -f docker-compose.active.yml up -d"
    echo -e "  ${YELLOW}Nginx logs:${NC}       sudo journalctl -u nginx -f"
    echo ""
    
    if [[ "$USE_SSL" == true ]]; then
        echo -e "${YELLOW}Note: Self-signed certificate will show browser warnings${NC}"
        echo -e "${YELLOW}This is normal for development. Click 'Advanced' -> 'Proceed'${NC}"
        echo ""
    fi
    
    echo -e "${CYAN}Environment:${NC} ${MAGENTA}$ENVIRONMENT${NC}"
    echo -e "${CYAN}Configuration:${NC} /etc/nginx/sites-available/opentube"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
main() {
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
    
    print_banner
    
    detect_distro
    check_prerequisites
    configure_hostname
    
    if [[ "$USE_SSL" == true ]]; then
        generate_ssl_certificate
    fi
    
    configure_nginx
    setup_docker_compose
    build_and_start
    verify_deployment
    print_summary
}

# Run main function
main

exit 0