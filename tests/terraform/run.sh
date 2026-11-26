#!/usr/bin/env bash
# Terraform end-to-end test: deploys the stack with Terraform (running in its
# container, as a user without Terraform would) to a throwaway SSH host, checks
# it works, checks a second apply changes nothing, then destroys it.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
terraform_image=$(sed -n 's/^TERRAFORM_IMAGE *:= *//p' "$repo/Makefile")

name=monitoring-stack-tf-test
network=$name
work=$(mktemp -d)

cleanup() {
  status=$?
  if ((status != 0)) && docker ps -q -f "name=^${name}$" | grep -q .; then
    echo "--- test failed; stack status on the test host ---"
    docker exec "$name" sh -c 'cd /opt/monitoring-stack 2>/dev/null && docker compose ps' || true
  fi
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker network rm "$network" >/dev/null 2>&1 || true
  rm -rf "$work"
  exit "$status"
}
trap cleanup EXIT

pass() { printf '  \033[32mok\033[0m    %s\n' "$*"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; exit 1; }

on_host() { docker exec "$name" "$@"; }

terraform() {
  docker run --rm --network "$network" --user "$(id -u):$(id -g)" -e HOME=/tmp \
    -e TF_IN_AUTOMATION=1 -e TF_INPUT=0 \
    -v "$work/repo:/workspace" -v "$work/keys:/keys:ro" -w /workspace/terraform \
    "$terraform_image" "$@"
}

echo "Preparing a throwaway SSH host"
mkdir -p "$work/keys"
ssh-keygen -q -t ed25519 -N '' -f "$work/keys/id_ed25519"
chmod 644 "$work/keys/id_ed25519"   # readable by the Terraform container's user
docker build -q -t "$name" "$here" >/dev/null
docker network create "$network" >/dev/null
docker run -d --privileged --name "$name" --hostname tf-test-host --network "$network" \
  -v "$work/keys/id_ed25519.pub:/test-key.pub:ro" "$name" >/dev/null
for _ in $(seq 60); do on_host docker info >/dev/null 2>&1 && break; sleep 2; done
on_host docker info >/dev/null 2>&1 || fail "Docker did not start on the test host"
pass "test host is up with SSH and Docker"

# Work on a clean copy so the test never touches your real Terraform state.
mkdir -p "$work/repo"
(cd "$repo" && tar --exclude=.git --exclude=terraform/.terraform --exclude='*.tfstate*' \
  --exclude=terraform/terraform.tfvars --exclude=.env -cf - .) | tar -xf - -C "$work/repo"
cat > "$work/repo/terraform/terraform.tfvars" <<TFVARS
host                 = "$name"
ssh_user             = "deploy"
ssh_private_key_path = "/keys/id_ed25519"
host_name            = "tf-test-host"
install_docker       = false
ntfy_topic           = "tf-test"
TFVARS

echo "Deploying with Terraform ($terraform_image)"
terraform init >/dev/null
terraform apply -auto-approve >"$work/apply.log" 2>&1 || { tail -40 "$work/apply.log"; fail "terraform apply"; }
pass "terraform apply succeeded"

# shellcheck disable=SC2016  # expands on the test host, not here
on_host sh -c 'cd /opt/monitoring-stack && test "$(stat -c %a .env)" = 600' || fail ".env is not mode 600"
pass ".env on the host is private (mode 600)"

expected=$(cd "$repo" && GRAFANA_ADMIN_PASSWORD=x NTFY_TOPIC=x docker compose config --services | wc -l)
running=$(on_host sh -c 'cd /opt/monitoring-stack && docker compose ps --status running --services | wc -l')
[[ $running -eq $expected ]] || fail "only $running of $expected services are running"
pass "all $expected services are running on the host"

password=$(terraform output -raw grafana_admin_password)
on_host curl -sf -u "admin:$password" http://localhost:3000/api/datasources >/dev/null || fail "Grafana login with the Terraform output password"
pass "Grafana accepts the generated admin password"

targets_ok=false
for _ in $(seq 24); do
  if on_host curl -sf http://localhost:9090/api/v1/targets |
      jq -e '[.data.activeTargets[] | select(.health != "up")] | length == 0' >/dev/null 2>&1; then
    targets_ok=true; break
  fi
  sleep 5
done
$targets_ok || fail "not all Prometheus targets are up on the host"
pass "every Prometheus target is up on the host"

terraform plan -detailed-exitcode >/dev/null 2>&1 || fail "a second plan wants to change something"
pass "a second plan shows no changes"

terraform destroy -auto-approve >"$work/destroy.log" 2>&1 || { tail -40 "$work/destroy.log"; fail "terraform destroy"; }
left=$(on_host sh -c 'docker ps -q | wc -l')
[[ $left -eq 0 ]] || fail "$left containers still running after destroy"
on_host sh -c 'docker volume ls -q | grep -q prometheus-data' || fail "data volumes were deleted (remove_data_on_destroy is false)"
pass "terraform destroy stopped the stack and kept its data"

echo "All Terraform checks passed."
