#!/usr/bin/env python3
import subprocess

# homelab hosts
build_host = "192.168.2.60"   # where Rust & the binary are built
binary_path = "/home/tim/pizza-ops-agent/target/release/pizza-ops-agent"
hosts = ["192.168.2.60", "192.168.2.51"]
user = "tim"

def run(cmd, check=True):
    print(f"$ {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.stdout:
        print(result.stdout.strip())
    if result.stderr:
        print(result.stderr.strip())
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}")
    return result

def deploy_binary(host):
    target = f"{user}@{host}"
    print(f"\n=== Deploying to {host} ===")

    # always copy fresh binary from build host
    if host != build_host:
        print(f"[{host}] Copying fresh binary from build host {build_host} …")
        run([
            "scp",
            f"{build_host}:{binary_path}",
            f"{target}:/tmp/pizza-ops-agent"
        ])
        run(["ssh", target, "sudo install -m755 /tmp/pizza-ops-agent /usr/local/bin/pizza-ops-agent"])
    else:
        print(f"[{host}] Skipping copy (this is the build host).")
        run(["sudo", "install", "-m755", binary_path, "/usr/local/bin/pizza-ops-agent"])

    # reload + restart service
    run(["ssh", target, "sudo systemctl daemon-reload"])
    run(["ssh", target, "sudo systemctl restart pizza-ops-agent"])
    status = run(["ssh", target, "systemctl is-active pizza-ops-agent"])
    print(f"[{host}] Service status: {status.stdout.strip()}")

for h in hosts:
    deploy_binary(h)
