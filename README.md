# 🍕 Monitoring Stack — Observability in a Box

🚀 A self-contained monitoring and observability stack built with Docker Compose — combining **metrics, logs, traces, and synthetic checks** into one cohesive platform.

✨ **Overview**

This project provisions a full monitoring suite for containers and hosts. It emulates enterprise observability practices in a lightweight, portable setup that’s ideal for homelabs, demos, and troubleshooting workflows.

**What it builds:**
- **Grafana** — dashboards & alerting  
- **Prometheus** — metrics scraping & time-series DB  
- **Node Exporter** — host metrics  
- **Blackbox Exporter** — HTTP/ICMP/TCP probes  
- **Loki + Promtail** — log aggregation & queries  
- **Uptime Kuma** — synthetic monitoring & status page  
- **(Optional) Tempo + OTel Collector** — distributed tracing  
- **(Optional) Demo API (Flask)** — instrumented with OpenTelemetry  
- **(Optional) Traefik** — reverse proxy + TLS  

✅ A Python smoke test validates endpoints with clear success/failure output.  
📈 Traces and logs from the demo app can be explored in Grafana for full-service views.

---

## 📊 Architecture

![Architecture](docs/architecture.png)

---

## 🎯 Why this matters
- **Unified observability:** Correlate logs, metrics, traces, and checks in one place.  
- **Production-shaped:** Prometheus scraping, Loki log streams, alert rules, and trace pipelines.  
- **Portable:** Compose-based, quick to spin up anywhere.  
- **Extendable:** Optional OTel Collector + Tempo bring distributed tracing into the mix.  
- **Secure & maintainable:** Volumes for state, TLS proxy (Traefik), and backup/restore workflow.  

---

## 🚀 Elevator pitch
Monitoring isn’t a tool, it’s a habit. This stack packages a small, production-shaped observability platform that can be deployed in minutes to troubleshoot anything — containers, services, endpoints. It proves clean pipelines for metrics, logs, traces, and synthetic checks, all wired into Grafana dashboards and alerts.

---

## ⚡ Quick start

```bash
cd ~/monitoring-stack
cp .env.sample .env
# edit .env: admin creds, TZ=America/Chicago, domain names (if using Traefik)

docker compose pull
docker compose up -d
```

### 🧩 Add Tracing + Demo App
```bash
docker compose -f docker-compose.yml -f docker-compose.otel.yml up -d
```

Now hit the demo API:
```bash
for i in {1..20}; do curl -s http://localhost:5001/work >/dev/null; done
```

Open Grafana → Explore traces/logs for `demo-api`.

---

## 🔍 Smoke test
Run the included Python script to verify services:

```bash
python3 monitoring_smoke_test.py
```

Outputs ✅ success or ❌ failure for Grafana, Prometheus, Loki, and Kuma endpoints.

---

## 🖼️ Screenshots
Add images here for quick reference:

- Grafana overview dashboard  
- Trace waterfall (Tempo + demo-api)  
- Loki log search  
- Uptime Kuma status page  

```md
<p align="center">
  <img src="docs/screens/grafana-overview.png" width="800" alt="Grafana Overview"/>
</p>
```

---

## ⏰ Alerts & SLOs
Prometheus includes sample alert rules:

```yaml
- alert: HighCpu
  expr: avg by(instance)(rate(node_cpu_seconds_total{mode!="idle"}[5m])) > 0.8
  for: 10m
  labels: {severity: warning}
  annotations:
    summary: "High CPU on {{ $labels.instance }}"
```

Grafana dashboards include placeholders for SLO panels (availability, latency, error rate).

---

## 🛠️ Tech Stack
- **Containerization:** Docker Compose  
- **Metrics:** Prometheus, Node Exporter, Blackbox  
- **Logs:** Loki, Promtail  
- **Dashboards & Alerts:** Grafana  
- **Tracing:** OpenTelemetry Collector, Tempo (optional)  
- **Synthetic Monitoring:** Uptime-Kuma  
- **Reverse Proxy:** Traefik (optional)  
- **Automation & Testing:** Python smoke tests, `.env`-driven config  

---

## 📂 Repo Structure
```
monitoring-stack/
├─ docker-compose.yml
├─ docker-compose.otel.yml
├─ apps/demo-api/
│  ├─ app.py
│  └─ Dockerfile
├─ config/
│  ├─ tempo.yaml
│  ├─ otel-collector.yaml
│  ├─ alerts.rules.yml
│  └─ grafana/provisioning/...
├─ docs/
│  ├─ architecture.png
│  └─ screens/
├─ Makefile
└─ monitoring_smoke_test.py
```

---

## 🗺️ Roadmap
- [ ] Add Grafana dashboards for SLOs  
- [ ] Add multi-step Blackbox probes  
- [ ] Provide Helm charts for k3s  
- [ ] Extend demo API with DB calls for richer traces  

---

## 📜 License
MIT
