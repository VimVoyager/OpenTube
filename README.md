<div align="center">


# OpenTube

**A self-hostable YouTube frontend — private, ad-free, and yours.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![SvelteKit](https://img.shields.io/badge/Frontend-SvelteKit-FF3E00?style=flat-square&logo=svelte&logoColor=white)](https://kit.svelte.dev)
[![Spring Boot](https://img.shields.io/badge/API-Spring%20Boot-6DB33F?style=flat-square&logo=springboot&logoColor=white)](https://spring.io/projects/spring-boot)
[![Go](https://img.shields.io/badge/Proxy-Go-00ADD8?style=flat-square&logo=go&logoColor=white)](https://golang.org)
[![Docker](https://img.shields.io/badge/Deploy-Docker-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com)

OpenTube uses the [NewPipe Extractor](https://github.com/TeamNewPipe/NewPipeExtractor) to access YouTube content without official APIs — no tracking, no ads, complete control over your data.

</div>

---

## ✨ Features

- 🔒 **Privacy-first** — No tracking, no ads, no Google APIs
- 🏠 **Self-hostable** — Run locally or on your own server
- ⚡ **Performant** — DASH manifest generation for optimized video streaming
- 🧩 **Modular** — Clean microservices architecture, easy to extend

---

## 🏗️ Architecture

<div align="center">
<img src="opentube-architecture.png" alt="OpenTube Architecture Diagram" width="700" />
</div>

---

## 🚀 Deployment

Choose the deployment option that suits your setup:

| Option | Description | Guide |
|--------|-------------|-------|
| 💻 **Local Development** | Run everything on your own machine — ideal for development and personal use | [Local Deployment Guide](docs/DEPLOYMENT.md) |
| 🖥️ **Self-Hosted Server** | Deploy to your home server or a VPS for persistent, always-on access | [Server Deployment Guide](docs/SERVER_DEPLOYMENT.md) |

### Quick Start (Local)

```bash
# Clone the repository (includes submodules)
git clone --recursive-submodules https://github.com/VimVoyager/OpenTube.git
cd OpenTube
```

```bash
# Terminal 1 — Backend API
cd NewPipeExtractorApi && mvn spring-boot:run

# Terminal 2 — Stream Proxy
go run main.go

# Terminal 3 — Frontend
npm run dev
```

| Service  | URL |
|----------|-----|
| Frontend | http://localhost:5173 |
| API      | http://localhost:8080 |
| Proxy    | http://localhost:8081 |

---

## 🛠️ Tech Stack

<div align="center">

| Component | Technology | Purpose |
|-----------|-----------|---------|
| <img src="https://img.shields.io/badge/-SvelteKit-FF3E00?style=flat-square&logo=svelte&logoColor=white" /> | SvelteKit + TypeScript | Reactive UI with SSR |
| <img src="https://img.shields.io/badge/-Spring%20Boot-6DB33F?style=flat-square&logo=springboot&logoColor=white" /> | Spring Boot (Java) | RESTful API & business logic |
| <img src="https://img.shields.io/badge/-Go-00ADD8?style=flat-square&logo=go&logoColor=white" /> | Go | High-performance video proxying |
| <img src="https://img.shields.io/badge/-Shaka%20Player-4285F4?style=flat-square&logo=google&logoColor=white" /> | Shaka Player | DASH manifest playback |
| <img src="https://img.shields.io/badge/-NewPipe-FF0000?style=flat-square&logo=youtube&logoColor=white" /> | NewPipe Extractor | YouTube data extraction |
| <img src="https://img.shields.io/badge/-Docker-2496ED?style=flat-square&logo=docker&logoColor=white" /> | Docker | Containerised deployment |

</div>

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**OpenTube** is an independent project and is not affiliated with YouTube or Google.  
It uses publicly available data via the [NewPipe Extractor](https://github.com/TeamNewPipe/NewPipeExtractor) library.

</div>