# Cloud-Native Observability Stack

🚀 A self-contained monitoring and observability stack built with Docker Compose — combining **high-performance metrics, synthetic checks, and automated dashboards** into one cohesive platform.

## Why This Matters

Modern infrastructure lives and dies by its observability. This project demonstrates how production-grade monitoring systems are designed to be **repeatable, scalable, and disposable**, not manually tuned or UI-dependent. By codifying dashboards, alerts, and infrastructure itself, the stack mirrors real-world SRE and Platform Engineering practices where reliability, performance, and operational clarity directly impact uptime and business outcomes. It showcases how metrics-driven visibility enables faster incident response, informed capacity planning, and confidence when scaling systems in high-availability environments.

---

✨ **Overview**

This project provisions a full monitoring suite for containers and hosts. It emulates enterprise observability practices using **VictoriaMetrics** for high-performance storage and **Grafana Provisioning** for a stateless dashboard experience.

**What it builds:**
* **Grafana** — dashboards & alerting (auto-provisioned)
* **Prometheus** — metrics scraping & alerting logic
* **VictoriaMetrics** — long-term time-series DB via Remote Write
* **Node Exporter** — host-level performance metrics
* **cAdvisor** — container resource usage & stats
* **Blackbox Exporter** — HTTP/ICMP/TCP synthetic probing

✅ **Stateless Configuration**: No manual dashboard imports. Everything is defined in code.  
📈 **Performance-First**: VictoriaMetrics ensures minimal resource footprint for long-term data.

---

## 📊 Architecture

![Architecture](docs/architecture.png)

➡️ [View scalable SVG version](docs/architecture.svg)

---

## ⚡ Quick Start

### Prerequisites
- Docker & Docker Compose
- Terraform
- Git
- Linux host or VM (recommended)

### Provision Infrastructure
```bash
cd terraform
terraform init
terraform apply
```

### Launch the Stack
```bash
cd ..
docker compose up -d
```

### Access Services
| Service | URL |
|------|------|
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| VictoriaMetrics | http://localhost:8428 |

---

## 🛠️ Tech Stack

- **Containerization:** Docker Compose  
- **Infrastructure as Code:** Terraform  
- **Metrics:** Prometheus, VictoriaMetrics  
- **Exporters:** Node Exporter, cAdvisor, Blackbox  
- **Dashboards & Alerts:** Grafana (Provisioned)  

---

## 📂 Repository Structure

```
monitoring-stack/
├─ config/
├─ docs/
├─ scripts/
├─ terraform/
├─ tools/
├─ compose.yaml
└─ Makefile
```

---

## 📜 License
MIT

---

### 👋 Author

**Built by Tim Heverin (dj-3dub)**  
Cloud Engineer / SRE  

If this project is useful, ⭐ the repo and say hi on GitHub.
