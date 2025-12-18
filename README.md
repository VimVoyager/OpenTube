# OpenTube

A self-hostable Youtube alternative that provides a clean, private, performant video streaming experience. OpenTube can be deployed on your personal computer, home server, or cloud service provider.

## Project Overview

OpenTube is video streaming platform that utilises the NewPipe Extractor to access YouTube content without requiring official APIs. Built with modern technologies and a microservices architecture, it provides

 - **Privacy-focused**: No tracking, no ads, complete control over your data
 - **Self-hostable**: Run on your local machine or deploy to your own server
 - **Performance**: Optimized video streaming with DASH manifest generation
 - **Modern stack**: Spring Boot backend, SvelteKit frontend, Go proxy server

## Architecture Overview

![OpenTube Archiecture](opentube-architecture.drawio.png)

## Deployment Options

### Option 1: Local Development

Perfect for development and personal use on your local machine.

```
┌───────────────────────────────────┐
│      Your Computer (localhost)    │
│                                   │
│  Frontend:  http://localhost:5173 │
│  API:       http://localhost:8080 │
│  Proxy:     http://localhost:8081 │
└───────────────────────────────────┘
```

**Setup:**
```bash
# Terminal 1: Backend API
cd NewPipeExtractorApi
mvn spring-boot:run

# Terminal 2: Stream Proxy
go run main.go

# Terminal 3: Frontend
npm run dev
```

### Option 2: Self-Hosted Server

Add self-hosted server setup instructions

### Option 3: Cloud Deployment

Scale to handle multiple users with contanerised deployment.

## Docker Deployment

Each service includes a Dockerfile for containerized deployment

## Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Frontend | SvelteKit + TypeScript | Modern reactive UI with SSR |
| Backend API | Spring Boot (Java) | RESTful API and business logic |
| Stream Proxy | Go | High-performance video proxying |
| Video Player | Shaka Player | DASH manifest playback |
| Data Source | NewPipe Extractor | YouTube data extraction |
| Build Tools | Maven, npm, Go modules | Dependency management |

## Configuration

### Environment Variables

**Frontend:**
```bash
PUBLIC_API_URL=http://localhost:8080
PUBLIC_PROXY_URL=http://localhost:8081
```

**Backend API:**
```bash
SERVER_PORT=8080
SPRING_PROFILES_ACTIVE=dev
```

## Getting Started

### Prerequisites

 - **Node.js**
 - **Java**
 - **Go**
 - **Maven**

### Quick Start
 1. **clone the repository
 ```bash
 git clone --recursive-submodules https://github.com/VimVoyager/OpenTube.git
 cd OpenTube
 ```

 2. **Start all services**

---

**Note**: OpenTube is an independent project and is not affiliated with YouTube or Google. It uses publicly available data through the NewPipe Extractor library


