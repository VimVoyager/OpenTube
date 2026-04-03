# OpenTube - Local Deployment Guide

> A self-hosted YouTube frontend built with SvelteKit, Spring boot, and  a Go stream proxy - orchestrated with Docker Compose

---

## Prerequisites

<table>
    <thead>
        <tr><th>Tool</th><th>Min. Version</th><th>Purpose</th></tr>
    </thead>
    <tbody>
        <tr><td><a href="https://docs.docker.com/get-docker/">Docker</a></td><td>24.x</td><td>Container runtime</td></tr>
        <tr><td><a href="https://docs.docker.com/compose/install/">Docker Compose</a></td><td>2.x</td><td>Multi-container orchestration</td></tr>
        <tr><td><a href="https://git-scm.com/">Git</a></td><td>Any</td><td>Cloning repositories</td></tr>
    </tbody>
</table>

---

## Repository Structure

OpenTube is split across multiple respositories. They must all be cloned **side by side** in the same parent directory - the `docker-compose.yml` uses relative paths to reference them.

```parent/
├── deployment/              ← This repo (docker-compose.yml lives here)
├── OpenTube-Frontend/       ← SvelteKit frontend
├── NewPipeExtractorApi/     ← Spring Boot backend
└── OpenTubeStreamProxy/     ← Go stream proxy
```

Clone all four into the same parent folder:

```bash
git clone --recurse-submodules --depth 1 https://github.com/VimVoyager/NewPipeExtractorAPI.git
```

>⚠️ **Folder names matter.** The build contexts in `docker-compose.yml` reference paths like `../OpenTube-Frontend`. If a repo is cloned under a different name, the build will fail.

---

## Services Overview

All traffic enters through nginx on port 80 and is routed internally by Docker service name

<table>
    <thead>
        <tr><th>Service</th><th>Internal Port</th><th>Technology</th><th>Description</th></tr>
    </thead>
    <tbody>
        <tr><td><code>nginx</code></td><td>80 (host-exposed)</td><td>nginx:alpine</td><td>Reverse proxy — single entry point</td></tr>
        <tr><td><code>frontend</code></td><td>3000</td><td>SvelteKit / Node</td><td>Server-side rendered frontend</td></tr>
        <tr><td><code>backend</code></td><td>8080</td><td>Spring Boot</td><td>NewPipe Extractor API</td></tr>
        <tr><td><code>proxy</code></td><td>8081</td><td>Go / Gin</td><td>YouTube stream proxy</td></tr>
    </tbody>
</table>

```
Browser → nginx:80 → frontend:3000
                   → backend:8080   (/api/)
                   → proxy:8081     (/proxy/)
```

## Configuration

### nginx

Create `deployment/nginx/nginx.conf` before starting the stack. A minimal working config:

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

> ℹ️ Always use Docker service names (`frontend`, `backend`, `proxy`) as upstream hostnames — never hardcoded IPs. Container IPs change on every restart.

### Frontend environment variables

<table>
    <thead>
        <tr><th>Variable</th><th>Value</th><th>Description</th></tr>
    </thead>
    <tbody>
        <tr><td><code>PORT</code></td><td><code>3000</code></td><td>Port the SvelteKit node server binds to</td></tr>
        <tr><td><code>NODE_ENV</code></td><td><code>production</code></td><td>Enables production mode</td></tr>
        <tr><td><code>PUBLIC_API_URL</code></td><td><code>/api</code></td><td>nginx path proxied to the backend</td></tr>
        <tr><td><code>PUBLIC_PROXY_URL</code></td><td><code>/proxy</code></td><td>nginx path proxied to the stream proxy</td></tr>
    </tbody>
</table>

### Backend environment variables

<table>
    <thead>
        <tr><th>Variable</th><th>Value</th><th>Description</th></tr>
    </thead>
    <tbody>
        <tr><td><code>SPRING_PROFILES_ACTIVE</code></td><td><code>prod</code></td><td>Activates the production Spring profile</td></tr>
        <tr><td><code>JAVA_OPTS</code></td><td><code>-Xmx1g -Xms512m ...</code></td><td>JVM memory and GC tuning</td></tr>
    </tbody>
</table>

---

## Building & Starting

Run all command from inside the `deployment/` directory.

**1. Build all images and start the stack:**

```bash
docker compose up -d --build
```

**2. Watch startup logs:**

```bash
docker compose logs -f
```

**3. Check container** (~60 seconds on first start - the JVM needs time to warm up):

```bash
docker compose ps
```

All services should show `(healthy)`. Once they do, open **http://localhost** in your browser.

---

## Verifying the Stack

Test the nginx health endpoint:

```bash
curl http://localhost/health
# Expected: ok
```

Test the backend API through nginx

```bash
curl "http://localhost/api/v1/search?searchString=test"
# Expected: JSON array of search results
```

Tail logs for a specific services:
```bash
docker compose logs -f backend
```

---

## Common Issues

<table>
      <thead>
            <tr><th>Symptom</th><th>Cause</th><th>Fix</th></tr>
      </thead>
      <tbody>
            <tr>
                  <td>Frontend/nginx <code>(unhealthy)</code>, 502 errors</td>
                  <td>SvelteKit not binding to the declared port — healthcheck always fails</td>
                  <td>Ensure <code>PORT=3000</code> is set in the frontend service environment</td>
            </tr>
            <tr>
                  <td><code>Connection reset by peer</code> in backend logs</td>
                  <td>nginx closing the upstream connection before the backend finishes — timeout too short</td>
                  <td>Add <code>proxy_read_timeout 30s;</code> to the <code>/api/</code> location block in nginx.conf</td>
            </tr>
            <tr>
                  <td>Backend stuck on <code>(health: starting)</code></td>
                  <td>Normal — JVM + NewPipe Extractor take &gt;60s to initialise on first start</td>
                  <td>Wait up to 90s. If still failing: <code>docker compose logs backend --tail 100</code></td>
            </tr>
            <tr>
                  <td>Code changes not reflected after restart</td>
                  <td>Docker uses cached image layers — restarting doesn't rebuild</td>
                  <td><code>docker compose build frontend</code> (or <code>backend</code> / <code>proxy</code>), then <code>docker compose up -d</code></td>
            </tr>
      </tbody>
</table>

---

##  Quick Reference

<table>
      <thead>
            <tr><th>What</th><th>URL</th></tr>
      </thead>
      <tbody>
            <tr><td>OpenTube UI</td><td><a href="http://localhost">http://localhost</a></td></tr>
            <tr><td>Backend API (via nginx)</td><td><a href="http://localhost/api/v1/">http://localhost/api/v1/</a></td></tr>
            <tr><td>Stream proxy (via nginx)</td><td><a href="http://localhost/proxy/">http://localhost/proxy/</a></td></tr>
            <tr><td>Health check</td><td><a href="http://localhost/health">http://localhost/health</a></td></tr>
      </tbody>
</table>
