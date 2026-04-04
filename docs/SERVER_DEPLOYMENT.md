# OpenTube - Server Deployment Guide

> Deploy OpenTube on any Linux server using Docker and Docker Compose. This guide dovers a clean server setup through a  running stack, with information on managing it iva [Dockge](https://github.com/louislam/dockge)

---

## Prerequisites

<table>
    <thead>
        <tr><th>Tool</th><th>Min. Version</th><th>Purpose</th></tr>
    </thead>
    <tbody>
        <tr><td><a href="https://docs.docker.com/get-docker/">Docker</a></td><td>24.x</td><td>Container runtime</td></tr>
        <tr><td><a href="https://docs.docker.com/compose/install/">Docker Compose</a></td><td>2.x</td><td>Multi-container orchestration</td></tr>
        <tr><td>A Linux server</td><td>—</td><td>Ubuntu, Debian, Arch, TrueNAS SCALE, etc.</td></tr>
    </tbody>
</table>

> ℹ️ On most modern systems Docker Compose ships as a plugin (`docker compose`). This guide uses that form. If you have the older standalone binary, replace `docker compose` with `docker-compose` throughout.

---

## 1. Install Docker

If Docker is not already installed run the official convenience script:

```bash
curl -fsSL https://get.docker.com | sh
```

---

Then enable and start the service:

```bash
sudo systemctl enable --now docker
```

Optionally add you user to the `docker` group so you don't need `sudo` for every command:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Verify your installation:

```bash
docker --version
docker-compose version
```

---

## 2. Prepare the Stack Directory

Choose a location on your server to store the stack. A clean convection is `/opt/stacks/<name>`

```bash
sudo mkdir -p /opt/stacks/opentube/nginx
sudo chown -R $USER:$USER /opt/stacks/opentube
cd /opt/stacks/opentube
```

> ℹ️ **Dockge users:** Dockge manages stacks from a directory you configure at install time — commonly `/opt/stacks` or a path on your data drive (e.g. `/mnt/tank/applications/dockge/stacks`). Create the `opentube/` folder inside whichever root Dockge is pointed at, and it will automatically detect the stack.

---

## 3. Create the nginx config

OpenTube uses a containerised nginx as its reverse proxy. Create the config before starting the stack - nginx will fail to start without it.

```bash
vim /opt/stacks/opentube/nginx.conf
```

Here is an nginx config that will work

```nginx
events {}
 
http {
    server {
        listen 80;
 
        location /health {
            return 200 'ok';
            add_header Content-Type text/plain;
        }
 
        location /api/ {
            proxy_pass         http://backend:8080/;
            proxy_set_header   Host $host;
            proxy_read_timeout 30s;
        }
 
        location /proxy/ {
            proxy_pass       http://proxy:8081/;
            proxy_set_header Host $host;
        }
 
        location / {
            proxy_pass       http://frontend:3000;
            proxy_set_header Host $host;
        }
    }
}
```

> ⚠️ Always use Docker service names (`frontend`, `backend`, `proxy`) as upstream hostnames — never hardcoded IPs. Container IPs change on every restart.

---

## 4. Create the Compose File

Create `docker-compose.yml` in the stack directory

```bash
vim /opt/stacks/opentube/docker-compose.yml
```

Use the following - images are pulled directly from Docker Hub.

```yaml
services:
  # ── Reverse proxy ────────────────────────────────────────────────────────────
  nginx:
    image: nginx:alpine
    ports:
      - "8090:80"        # change 8090 to any free port on your host
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - /dev/null:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - frontend
      - backend
      - proxy
    restart: unless-stopped
    networks:
      - opentube-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 5s
      retries: 3
 
  # ── SvelteKit frontend ────────────────────────────────────────────────────────
  frontend:
    image: mrtumble/opentube-frontend:latest
    expose:
      - "3000"
    depends_on:
      - backend
      - proxy
    restart: unless-stopped
    networks:
      - opentube-network
    environment:
      - NODE_ENV=production
      - PORT=3000
      - PUBLIC_API_URL=/api
      - PUBLIC_PROXY_URL=/proxy
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
 
  # ── Go stream proxy ───────────────────────────────────────────────────────────
  proxy:
    image: mrtumble/opentube-proxy:latest
    expose:
      - "8081"
    restart: unless-stopped
    networks:
      - opentube-network
    environment:
      - GIN_MODE=release
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8081/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
 
  # ── Spring Boot API ───────────────────────────────────────────────────────────
  backend:
    image: mrtumble/opentube-backend:latest
    expose:
      - "8080"
    volumes:
      - backend-data:/app/data
    restart: unless-stopped
    networks:
      - opentube-network
    environment:
      - SPRING_PROFILES_ACTIVE=prod
      - JAVA_OPTS=-Xmx1g -Xms512m -XX:+UseG1GC -XX:MaxGCPauseMillis=200
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/api/v1/search?searchString=test"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
 
volumes:
  backend-data:
    driver: local
 
networks:
  opentube-network:
    driver: bridge
```

Your stack directory should now look like this:

```
/opt/stacks/opentube/
├── docker-compose.yml
└── nginx/
    └── nginx.conf
```

---

## 5. Start the Stack

```bash
cd /opt/stacks/opentube
docker-compose up -d
```

Docker will pull all images from Docker Hub on first run. This may take a minute or two depending on your connection.

> ℹ️ **Dockge users:** If the `opentube/` folder is inside Dockge's stacks root, Dockge will detect it automatically and show it in the UI. You can start, stop, and monitor the stack from there instead of the CLI — both approaches are equivalent.

---

## 6. Verify the Stack

Check that all containers are running and healthy:

```bash
docker-compose ps
```

The backend has a 60 seconds `start_period` - it takestime for the JVM and NewPipe Extractor to initialise. Wait for all services to show `(healthy)` before testing.

Test the health endpoint

```bash
curl http://localhost:8090/health
# Expected: ok
```

Test the backend API:

```bash 
curl "http://localhost/api/v1/search?String=test"
# Expected: JSON array of search results
```

Then open **http://your-server-ip:8090** in a browser.

---

## 7. External Access

To make OpenTube accessible outside your local network, place a reverse proxy in front of port `8090`. Two common approaches:

### Option A - Nginx Proxy Manager (recommended for homelab setups)

If you already run NPM on the same server, create a new proxy host:

<table>
      <thead>
            <tr><th>Field</th><th>Value</th></tr>
      </thead>
      <tbody>
            <tr><td>Domain name</td><td><code>opentube.yourdomain.com</code></td></tr> 
            <tr><td>Scheme</td><td><code>http</code></td></tr> 
            <tr><td>Forward hostname</td><td><code>localhost</code> or your server's LAN IP</td></tr> 
            <tr><td>Forward port</td><td><code>8090</code></td></tr> 
            <tr><td>SSL</td><td>Request a Let's Encrypt certificate</td></tr>
      </tbody>
</table>

### Option B - Cloudflare Tunnel / self-hosted tunnel (Pangolin, netbird, etc.)

Point the tunnel target at `your-server-ip:8090` over HTTP. The tunnel handles TLS termination at the edge. Make sure the target scheme is se to **HTTP** (not HTTPS) since the OpenTube nginx container does not have TLS configured.

---

## 8. Common Issues

<table>
      <thead>
            <tr><th>Symptom</th><th>Cause</th><th>Fix</th></tr>
      </thead>
      <tbody>
            <tr>
                  <td>Frontend <code>(unhealthy)</code>, 502 from nginx</td>
                  <td>SvelteKit not binding to port 3000</td>
                  <td>Ensure <code>PORT=3000</code> is set in the frontend environment</td>
            </tr>
            <tr>
                  <td><code>Connection reset by peer</code> in backend logs</td>
                  <td>nginx timeout too short for the backend response</td>
                  <td>Add <code>proxy_read_timeout 30s;</code> to the <code>/api/</code> location block</td>
            </tr>
            <tr>
                  <td>Backend stuck on <code>(health: starting)</code></td>
                  <td>Normal — JVM takes &gt;60s to initialise on first start</td>
                  <td>Wait up to 90s. If still failing: <code>docker compose logs backend --tail 100</code></td>
            </tr>
            <tr>
                  <td>Port 8090 already in use</td>
                  <td>Another service is bound to that port</td>
                  <td>Change <code>8090:80</code> to any free port: <code>ss -ltnp | grep LISTEN</code></td>
            </tr>
            <tr>
                  <td>nginx config not found on startup</td>
                  <td>The <code>./nginx/nginx.conf</code> file doesn't exist at the expected path</td>
                  <td>Ensure the file is at <code>nginx/nginx.conf</code> relative to <code>docker-compose.yml</code></td>
            </tr>
            <tr>
                  <td>Tunnel shows "page not found"</td>
                  <td>Tunnel target scheme set to HTTPS but container only speaks HTTP</td>
                  <td>Set the tunnel target scheme to <strong>HTTP</strong>, not HTTPS</td>
            </tr>
      </tbody>
</table>

---

## 9. Useful Commands

```bash
# View logs for all services
docker compose logs -f

# View logs for a specific service
docker compose logs -f backend

# Restart a single service
docker compose restart frontend

# Pull latest images and recreate containers
docker compose pull && docker compose up -d

# Stop the stack (preserves volumes)
docker compose down

# Stop and wipe all data volumes
docker compose down -v
```

## Quick Reference

<table>
      <thead>
            <tr><th>What</th><th>URL</th></tr>
      </thead>
      <tbody>
            <tr><td>OpenTube UI</td><td><code>http://your-server-ip:8090</code></td></tr>
            <tr><td>Health check</td><td><code>http://your-server-ip:8090/health</code></td></tr>
            <tr><td>Backend API</td><td><code>http://your-server-ip:8090/api/v1/</code></td></tr>
            <tr><td>Stream proxy</td><td><code>http://your-server-ip:8090/proxy/</code></td></tr>
      </tbody>
</table>
