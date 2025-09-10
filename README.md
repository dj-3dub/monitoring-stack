# 🍕 Monitoring Stack — Observability in a Box

🚀 A self-contained monitoring and observability stack built with Docker Compose — combining metrics, logs, and synthetic checks into one cohesive platform.

✨ **Overview**

This project provisions a full monitoring suite for containers and hosts. It emulates enterprise observability practices in a lightweight, portable setup that’s ideal for homelabs, demos, and troubleshooting workflows.

**What it builds:**
- **Grafana** — dashboards & alerting  
- **Prometheus** — metrics scraping & time-series DB  
- **Node Exporter** — host metrics  
- **Blackbox Exporter** — HTTP/ICMP/TCP probes  
- **Loki + Promtail** — log aggregation & queries  
- **Uptime-Kuma** — synthetic monitoring & status page  
- **(Optional) Traefik** — reverse proxy + TLS  

✅ A Python smoke test validates endpoints with clear success/failure output.

🛠️ **Tech Stack**
- **Containerization:** Docker Compose  
- **Metrics:** Prometheus, Node Exporter, Blackbox  
- **Logs:** Loki, Promtail  
- **Dashboards & Alerts:** Grafana  
- **Synthetic Monitoring:** Uptime-Kuma  
- **Reverse Proxy:** Traefik (optional)  
- **Automation & Testing:** Python smoke tests, `.env`-driven config  

📊 **Architecture**

![Architecture](docs/architecture.png)

---

## Why this matters to teams
- **Faster incident triage:** Correlate logs, metrics, and checks in one place.  
- **Production-shaped:** Prometheus scraping, Loki log streams, and alerting patterns.  
- **Portable:** Compose-based, quick to spin up anywhere.  
- **Secure & maintainable:** Volumes for state, TLS proxy (Traefik), and backup/restore workflow.  

---

## Elevator pitch
Monitoring isn’t a tool, it’s a habit. I packaged a small, production-shaped observability stack that I can deploy in minutes, then use to troubleshoot anything I’m running—containers, services, endpoints. It proves I can design clean pipelines for metrics, logs, and synthetic checks, wire them into Grafana, and use them to drive decisions.

---

## Quick start

```bash
cd ~/monitoring-stack
cp .env.sample .env
# edit .env: admin creds, TZ=America/Chicago, domain names (if using Traefik)

docker compose pull
docker compose up -d
