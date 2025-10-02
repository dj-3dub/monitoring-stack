#!/usr/bin/env python3
"""
Monitoring Stack Smoke Test (with --short and --json modes)
Checks Prometheus, Grafana, Alertmanager, node_exporter, cAdvisor, and Blackbox Exporter.
"""

import argparse
import sys
import time
import json
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
from base64 import b64encode

DEFAULT_HOST = "localhost"

def http_get(url, timeout=5, headers=None):
    try:
        req = Request(url, headers=headers or {"User-Agent": "stack-smoke/1.0"})
        with urlopen(req, timeout=timeout) as r:
            return r.status, r.read(), dict(r.headers)
    except HTTPError as e:
        return e.code, e.read(), dict(getattr(e, "headers", {}))
    except URLError:
        raise

def http_json(url, timeout=5, headers=None):
    code, body, hdrs = http_get(url, timeout=timeout, headers=headers)
    return code, json.loads(body.decode("utf-8") or "{}"), hdrs

def b64basic(user, pw):
    token = b64encode(f"{user}:{pw}".encode()).decode()
    return {"Authorization": f"Basic {token}"}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default=DEFAULT_HOST)
    ap.add_argument("--prom-port", type=int, default=9090)
    ap.add_argument("--grafana-port", type=int, default=3300)
    ap.add_argument("--alert-port", type=int, default=9093)
    ap.add_argument("--cadvisor-port", type=int, default=8080)
    ap.add_argument("--blackbox-port", type=int, default=9115)
    ap.add_argument("--node-port", type=int, default=9100)
    ap.add_argument("--timeout", type=int, default=6)
    ap.add_argument("--retries", type=int, default=10)
    ap.add_argument("--sleep", type=float, default=2.0)
    ap.add_argument("--grafana-user", default=None)
    ap.add_argument("--grafana-pass", default=None)
    ap.add_argument("--skip-grafana", action="store_true")
    ap.add_argument("--short", action="store_true", help="Only show warnings and failures")
    ap.add_argument("--json", action="store_true", help="Output results as JSON")
    args = ap.parse_args()

    # Prepare URLs
    host = args.host
    prom = f"http://{host}:{args.prom_port}"
    graf = f"http://{host}:{args.grafana_port}"
    alrt = f"http://{host}:{args.alert_port}"
    cadv = f"http://{host}:{args.cadvisor_port}"
    blbx = f"http://{host}:{args.blackbox_port}"
    node = f"http://{host}:{args.node_port}"

    results = {
        "failures": [],
        "warnings": [],
        "ok": [],
    }

    # Reachability checks
    endpoints = {
        "Prometheus": f"{prom}/-/ready",
        "Alertmanager": f"{alrt}/-/ready",
        "Grafana": f"{graf}/login",
        "cAdvisor": f"{cadv}/",
        "Blackbox Exporter": f"{blbx}/metrics",
        "node_exporter": f"{node}/metrics",
    }
    for name, url in endpoints.items():
        ok_flag = False
        for _ in range(args.retries):
            try:
                code, _, _ = http_get(url, timeout=args.timeout)
                if 200 <= code < 400:
                    ok_flag = True
                    break
            except URLError:
                pass
            time.sleep(args.sleep)
        if ok_flag:
            results["ok"].append(f"{name} reachable")
        else:
            results["failures"].append(f"{name} NOT reachable: {url}")

    # Prometheus targets
    try:
        code, data, _ = http_json(f"{prom}/api/v1/targets", timeout=args.timeout)
        if code != 200 or data.get("status") != "success":
            results["failures"].append("Prometheus /api/v1/targets not OK")
        else:
            active = data.get("data", {}).get("activeTargets", [])
            expected_jobs = {"prometheus", "node_exporter", "cadvisor", "blackbox_http", "blackbox_icmp"}
            jobs_seen = set(t.get("labels", {}).get("job") for t in active)
            missing_jobs = expected_jobs - jobs_seen
            if missing_jobs:
                results["failures"].append(f"Missing scrape jobs: {', '.join(sorted(missing_jobs))}")
            up_count = sum(1 for t in active if t.get("health") == "up")
            total = len(active)
            if up_count == 0:
                results["failures"].append("No Prometheus targets are UP")
            else:
                results["ok"].append(f"Targets UP: {up_count}/{total}")
    except Exception as e:
        results["failures"].append(f"Failed to query Prometheus targets: {e}")

    # Prometheus metric spot-checks
    queries = {
        "up>0": 'sum(up)>0',
        "node_cpu_seconds_total": 'count(node_cpu_seconds_total)',
        "probe_success": 'count(probe_success)',
    }
    for label, q in queries.items():
        try:
            code, data, _ = http_json(f"{prom}/api/v1/query?query={q}", timeout=args.timeout)
            if code == 200 and data.get("status") == "success":
                result = data.get("data", {}).get("result", [])
                if result and any(float(v[1]) > 0 for v in (r.get("value") for r in result)):
                    results["ok"].append(f"Query OK: {label}")
                else:
                    results["warnings"].append(f"Query returned 0 or empty: {label}")
            else:
                results["warnings"].append(f"Query failed: {label} (HTTP {code})")
        except Exception as e:
            results["warnings"].append(f"Query error: {label}: {e}")

    # Grafana API checks
    if not args.skip_grafana:
        try:
            headers = {"User-Agent": "stack-smoke/1.0"}
            if args.grafana_user and args.grafana_pass:
                headers.update(b64basic(args.grafana_user, args.grafana_pass))
            code, data, _ = http_json(f"{graf}/api/health", timeout=args.timeout, headers=headers)
            if code == 200 and data.get("database") == "ok":
                results["ok"].append("Grafana /api/health OK")
            else:
                results["warnings"].append(f"Grafana health not OK (HTTP {code})")
        except Exception as e:
            results["warnings"].append(f"Grafana API check error: {e}")

    # Alertmanager status
    try:
        code, data, _ = http_json(f"{alrt}/api/v2/status", timeout=args.timeout)
        if code == 200 and "versionInfo" in data:
            results["ok"].append("Alertmanager /api/v2/status OK")
        else:
            results["warnings"].append(f"Alertmanager status not OK (HTTP {code})")
    except Exception as e:
        results["warnings"].append(f"Alertmanager status error: {e}")

    # Output handling
    if args.json:
        print(json.dumps(results, indent=2))
    else:
        if not args.short:
            for msg in results["ok"]:
                print(f"✅ {msg}")
        for msg in results["warnings"]:
            print(f"⚠️  {msg}")
        for msg in results["failures"]:
            print(f"❌ {msg}")

        print("\n== Summary ==")
        print(f"OK: {len(results['ok'])} | Warnings: {len(results['warnings'])} | Failures: {len(results['failures'])}")

    sys.exit(0 if len(results["failures"]) == 0 else 2)

if __name__ == "__main__":
    main()

