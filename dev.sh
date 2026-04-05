#!/bin/bash

# Load .env if it exists, otherwise use defaults
if [ -f "$(dirname "$0")/.env" ]; then
    set -a
    source "$(dirname "$0")/.env"
    set +a
fi

# Fallback defaults if not set in .env
FRONTEND_PORT=${FRONTEND_PORT:-3000}
BACKEND_PORT=${BACKEND_PORT:-5000}
PROXY_PORT=${PROXY_PORT:-4000}

case "$1" in
  frontend)
    echo "Starting frontend on port $FRONTEND_PORT"
    cd OpenTube-Frontend && npm run dev
    ;;
  backend)
    echo "Starting backend on port $BACKEND_PORT"
    cd NewPipeExtractorApi/app && mvn spring-boot:run \
      -Dspring-boot.run.arguments="--server.port=$BACKEND_PORT"
    ;;
  proxy)
    echo "Starting proxy on port $PROXY_PORT"
    cd OpenTubeStreamProxy && PORT=$PROXY_PORT go run main.go
    ;;
  all)
    echo "Starting all services..."
    FRONTEND_PORT=$FRONTEND_PORT npm run dev --prefix OpenTube-Frontend &
    PORT=$PROXY_PORT go run OpenTubeStreamProxy/main.go &
    cd NewPipeExtractorApi/app && mvn spring-boot:run \
      -Dspring-boot.run.arguments="--server.port=$BACKEND_PORT"
    ;;
  *)
    echo "Usage: ./dev.sh [frontend|backend|proxy|all]"
    echo ""
    echo "Ports (override in .env):"
    echo "  Frontend : $FRONTEND_PORT"
    echo "  Backend  : $BACKEND_PORT"
    echo "  Proxy    : $PROXY_PORT"
    ;;
esac
