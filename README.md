# Cloud-Native Observability Stack

🚀 A self-contained monitoring and observability stack built with Docker Compose — combining **high-performance metrics, synthetic checks, and automated dashboards** into one cohesive platform.

## Why This Matters

Modern platforms require observability systems that are deterministic, reproducible, and operationally boring. This project demonstrates how production-grade monitoring is built as part of the platform itself—fully automated, version-controlled, and resilient to rebuilds. By treating metrics, alerting, and dashboards as code, the stack supports fast incident triage, predictable performance analysis, and confident infrastructure changes. This mirrors the expectations of high-availability environments where visibility, repeatability, and low operational overhead are critical to system reliability and engineering velocity.

---

✨ **Overview**

This project provisions a fully automated observability platform for containerized and host-based workloads. It reflects real-world platform engineering practices by separating data ingestion, long-term storage, and visualization concerns while maintaining a single, code-defined source of truth. The stack is designed to be rebuilt frequently, operate with minimal manual intervention, and scale predictably as infrastructure grows.

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
## 🧪 Design Principles

- **Deterministic & Reproducible**  
  All dashboards, alert rules, and data sources are defined declaratively and applied consistently across environments.

- **Low Operational Overhead**  
  Grafana provisioning and Prometheus remote write eliminate manual configuration and reduce ongoing maintenance.

- **Failure-Tolerant by Design**  
  The stack can be destroyed and rebuilt without configuration drift, enabling safe experimentation and rapid recovery.

- **Performance-Conscious Metrics Pipeline**  
  VictoriaMetrics provides efficient long-term storage with reduced resource usage and predictable query latency.

- **Single Source of Truth**  
  All configuration lives under version control, preventing runtime divergence and undocumented changes.

---

## 🧠 Operational Use Cases

This observability stack is designed to support real-world platform operations, including:

- **Rapid root-cause analysis** during service degradation, host contention, or container instability
- **Baseline performance tracking** prior to infrastructure or configuration changes
- **Alert-driven detection** of resource exhaustion, service unavailability, and failed probes
- **Capacity planning** using long-term historical metrics with low storage overhead
- **Post-change validation** after rebuilds, upgrades, or Terraform-driven infrastructure changes
- **Confidence during failure scenarios**, where fast, deterministic visibility is required to reduce mean time to recovery (MTTR)

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
