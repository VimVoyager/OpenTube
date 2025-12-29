#!/bin/bash
# OpenTube Management Helper Script

set -e

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Find active compose file
if [ -L "docker-compose.active.yml" ]; then
    COMPOSE_FILE="docker-compose.active.yml"
elif [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"
else
    echo -e "${RED}Error: No docker-compose file found${NC}"
    exit 1
fi

show_usage() {
    echo -e "${CYAN}OpenTube Management Helper${NC}"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}start${NC}          - Start all services"
    echo -e "  ${GREEN}stop${NC}           - Stop all services"
    echo -e "  ${GREEN}restart${NC}        - Restart all services"
    echo -e "  ${GREEN}status${NC}         - Show service status"
    echo -e "  ${GREEN}logs${NC}           - View all logs (Ctrl+C to exit)"
    echo -e "  ${GREEN}logs-frontend${NC}  - View frontend logs"
    echo -e "  ${GREEN}logs-backend${NC}   - View backend logs"
    echo -e "  ${GREEN}logs-proxy${NC}     - View proxy logs"
    echo -e "  ${GREEN}logs-nginx${NC}     - View nginx logs"
    echo -e "  ${GREEN}rebuild${NC}        - Rebuild and restart all services"
    echo -e "  ${GREEN}clean${NC}          - Stop and remove containers (keeps data)"
    echo -e "  ${GREEN}reset${NC}          - Stop and remove everything (including data)"
    echo -e "  ${GREEN}update${NC}         - Pull latest images and rebuild"
    echo -e "  ${GREEN}backup${NC}         - Backup backend data"
    echo -e "  ${GREEN}shell-frontend${NC} - Open shell in frontend container"
    echo -e "  ${GREEN}shell-backend${NC}  - Open shell in backend container"
    echo -e "  ${GREEN}shell-proxy${NC}    - Open shell in proxy container"
    echo -e "  ${GREEN}test${NC}           - Test all endpoints"
    echo ""
}

cmd_start() {
    echo -e "${CYAN}Starting services...${NC}"
    docker-compose -f "$COMPOSE_FILE" up -d
    sudo systemctl start nginx
    echo -e "${GREEN}✓ Services started${NC}"
}

cmd_stop() {
    echo -e "${CYAN}Stopping services...${NC}"
    docker-compose -f "$COMPOSE_FILE" down
    sudo systemctl stop nginx
    echo -e "${GREEN}✓ Services stopped${NC}"
}

cmd_restart() {
    echo -e "${CYAN}Restarting services...${NC}"
    docker-compose -f "$COMPOSE_FILE" restart
    sudo systemctl restart nginx
    echo -e "${GREEN}✓ Services restarted${NC}"
}

cmd_status() {
    echo -e "${CYAN}Service Status:${NC}"
    echo ""
    echo -e "${YELLOW}Docker Services:${NC}"
    docker-compose -f "$COMPOSE_FILE" ps
    echo ""
    echo -e "${YELLOW}Nginx Status:${NC}"
    systemctl status nginx --no-pager -l
    echo ""
    echo -e "${YELLOW}Avahi Status:${NC}"
    systemctl status avahi-daemon --no-pager -l
}

cmd_logs() {
    docker-compose -f "$COMPOSE_FILE" logs -f "$@"
}

cmd_logs_nginx() {
    sudo journalctl -u nginx -f
}

cmd_rebuild() {
    echo -e "${CYAN}Rebuilding services...${NC}"
    docker-compose -f "$COMPOSE_FILE" down
    docker-compose -f "$COMPOSE_FILE" build --no-cache
    docker-compose -f "$COMPOSE_FILE" up -d
    sudo systemctl restart nginx
    echo -e "${GREEN}✓ Services rebuilt and restarted${NC}"
}

cmd_clean() {
    echo -e "${YELLOW}This will stop and remove all containers (data volumes preserved)${NC}"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose -f "$COMPOSE_FILE" down
        echo -e "${GREEN}✓ Containers removed${NC}"
    else
        echo "Cancelled"
    fi
}

cmd_reset() {
    echo -e "${RED}WARNING: This will remove ALL containers AND data volumes!${NC}"
    read -p "Are you sure? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose -f "$COMPOSE_FILE" down -v
        echo -e "${GREEN}✓ Everything removed${NC}"
    else
        echo "Cancelled"
    fi
}

cmd_update() {
    echo -e "${CYAN}Updating services...${NC}"
    docker-compose -f "$COMPOSE_FILE" pull
    docker-compose -f "$COMPOSE_FILE" build --pull
    docker-compose -f "$COMPOSE_FILE" up -d
    echo -e "${GREEN}✓ Services updated${NC}"
}

cmd_backup() {
    local backup_name="opentube-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    echo -e "${CYAN}Creating backup: $backup_name${NC}"
    
    docker run --rm \
        -v deployment_backend-data:/data \
        -v "$SCRIPT_DIR":/backup \
        ubuntu tar czf "/backup/$backup_name" /data
    
    echo -e "${GREEN}✓ Backup created: $backup_name${NC}"
}

cmd_shell() {
    local service=$1
    if [ -z "$service" ]; then
        echo -e "${RED}Error: Specify service (frontend, backend, proxy)${NC}"
        exit 1
    fi
    
    docker-compose -f "$COMPOSE_FILE" exec "$service" /bin/sh || \
    docker-compose -f "$COMPOSE_FILE" exec "$service" /bin/bash
}

cmd_test() {
    echo -e "${CYAN}Testing endpoints...${NC}"
    echo ""
    
    # Detect protocol
    local protocol="http"
    if grep -q "listen 443" /etc/nginx/sites-available/opentube 2>/dev/null; then
        protocol="https"
    fi
    
    # Test health
    echo -e "${YELLOW}Testing health endpoint...${NC}"
    if curl -sf${protocol:+k} "$protocol://localhost/health" > /dev/null; then
        echo -e "${GREEN}✓ Health check passed${NC}"
    else
        echo -e "${RED}✗ Health check failed${NC}"
    fi
    
    # Test API
    echo -e "${YELLOW}Testing backend API...${NC}"
    if curl -sf${protocol:+k} "$protocol://localhost/api/v1/search?query=test" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Backend API responding${NC}"
    else
        echo -e "${RED}✗ Backend API not responding${NC}"
    fi
    
    # Test frontend
    echo -e "${YELLOW}Testing frontend...${NC}"
    if curl -sf${protocol:+k} "$protocol://localhost/" > /dev/null; then
        echo -e "${GREEN}✓ Frontend responding${NC}"
    else
        echo -e "${RED}✗ Frontend not responding${NC}"
    fi
    
    # Test domain resolution
    echo -e "${YELLOW}Testing domain resolution...${NC}"
    local domain=$(grep "server_name" /etc/nginx/sites-available/opentube 2>/dev/null | head -1 | awk '{print $2}' | tr -d ';')
    if [ -n "$domain" ] && ping -c 1 "$domain" &> /dev/null; then
        echo -e "${GREEN}✓ $domain resolves${NC}"
    else
        echo -e "${YELLOW}⚠ $domain doesn't resolve (may be normal)${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Access URLs:${NC}"
    echo -e "  Primary:  $protocol://$domain"
    echo -e "  Local:    $protocol://localhost"
}

# Main command handler
case "${1:-}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    logs)
        shift
        cmd_logs "$@"
        ;;
    logs-frontend)
        cmd_logs frontend
        ;;
    logs-backend)
        cmd_logs backend
        ;;
    logs-proxy)
        cmd_logs proxy
        ;;
    logs-nginx)
        cmd_logs_nginx
        ;;
    rebuild)
        cmd_rebuild
        ;;
    clean)
        cmd_clean
        ;;
    reset)
        cmd_reset
        ;;
    update)
        cmd_update
        ;;
    backup)
        cmd_backup
        ;;
    shell-frontend)
        cmd_shell frontend
        ;;
    shell-backend)
        cmd_shell backend
        ;;
    shell-proxy)
        cmd_shell proxy
        ;;
    test)
        cmd_test
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

exit 0