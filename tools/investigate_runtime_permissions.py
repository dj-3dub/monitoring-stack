#!/usr/bin/env python3
import os
import pwd
import grp
import subprocess
from pathlib import Path

PATHS = {
    "grafana": "/opt/monitoring/config/grafana/data",
    "prometheus": "/opt/monitoring/config/prometheus/data",
    "alertmanager": "/opt/monitoring/config/alertmanager/data",
    "n8n": "/opt/monitoring/config/n8n/data",
    "tempo": "/opt/monitoring/config/tempo/data",
}

EXPECTED = {
    "grafana": (472, 472),
    "prometheus": (65534, 65534),
    "alertmanager": (65534, 65534),
    "n8n": (1000, 1000),
    "tempo": (10001, 10001),
}

SEARCH_ROOTS = [
    "/home/tim/monitoring-stack/ansible",
    "/home/tim/monitoring-stack/scripts",
    "/home/tim/monitoring-stack/tools",
    "/opt/monitoring/scripts",
    "/opt/monitoring/tools",
]

PATTERNS = [
    "recurse: true",
    "chown",
    "config/prometheus/data",
    "config/grafana/data",
    "config/tempo/data",
    "/opt/monitoring",
]

def name(uid, is_user=True):
    try:
        return pwd.getpwuid(uid).pw_name if is_user else grp.getgrgid(uid).gr_name
    except KeyError:
        return "UNKNOWN"

def run(cmd):
    return subprocess.run(cmd, shell=True, text=True, capture_output=True)

def inspect_path(service, path):
    expected_uid, expected_gid = EXPECTED[service]
    p = Path(path)
    print(f"\n[{service}] {path}")

    if not p.exists():
        print("  MISSING")
        return

    for item in [p] + list(p.iterdir())[:20]:
        st = item.stat()
        status = "OK" if st.st_uid == expected_uid and st.st_gid == expected_gid else "DRIFT"
        print(
            f"  {status:5} "
            f"{st.st_uid}:{st.st_gid} "
            f"({name(st.st_uid)}:{name(st.st_gid, False)}) "
            f"{item}"
        )

def search_culprits():
    print("\n[Potential ownership-changing references]")
    for root in SEARCH_ROOTS:
        if not Path(root).exists():
            continue
        for pattern in PATTERNS:
            result = run(f"grep -RIn --exclude-dir=.git {pattern!r} {root} 2>/dev/null")
            if result.stdout.strip():
                print(f"\nPattern: {pattern}")
                print(result.stdout.strip())

def docker_status():
    print("\n[Docker status]")
    result = run("docker ps --format 'table {{.Names}}\t{{.Status}}'")
    print(result.stdout.strip())

def compose_origin():
    print("\n[Compose working dirs]")
    containers = ["grafana", "prometheus", "alertmanager", "blackbox-exporter", "n8n", "otel-collector", "tempo"]
    for c in containers:
        result = run(f"docker inspect {c} --format '{{{{ index .Config.Labels \"com.docker.compose.project.working_dir\" }}}}' 2>/dev/null")
        value = result.stdout.strip() or "NOT FOUND"
        print(f"  {c}: {value}")

def main():
    docker_status()
    compose_origin()

    print("\n[Runtime data ownership]")
    for service, path in PATHS.items():
        inspect_path(service, path)

    search_culprits()

if __name__ == "__main__":
    main()
