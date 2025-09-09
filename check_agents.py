#!/usr/bin/env python3
import subprocess

hosts = ["192.168.2.60", "192.168.2.51"]
user = "tim"

def check_agent(host):
    try:
        # Run systemctl is-active remotely
        cmd = ["ssh", f"{user}@{host}", "systemctl is-active pizza-ops-agent"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        status = result.stdout.strip()
        if status == "active":
            print(f"[{host}] ✅ pizza-ops-agent is active")
        else:
            print(f"[{host}] ❌ pizza-ops-agent is {status}")
    except Exception as e:
        print(f"[{host}] ⚠️ error: {e}")

for h in hosts:
    check_agent(h)
