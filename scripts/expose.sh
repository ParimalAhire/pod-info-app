#!/usr/bin/env bash
# Step 7: make the Kubernetes NodePort reachable from the EC2 public IP.
#
# Why this is needed: with the Docker driver, minikube's "node" is itself a container
# with a private IP (e.g. 192.168.49.2). The NodePort exists there, not on the EC2 host.
# socat forwards EC2:30080 -> minikube-node:30080, so traffic still goes through the
# Service (kube-proxy) and is load balanced across all pods.
#
# Run from the project root:  bash scripts/expose.sh
set -euo pipefail
cd "$(dirname "$0")/.."

NODE_PORT=30080
PID_FILE=".socat.pid"

MINIKUBE_IP="$(minikube ip)"

# Stop any previous forwarder
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  kill "$(cat "$PID_FILE")" || true
  sleep 1
fi

nohup socat "TCP-LISTEN:${NODE_PORT},fork,reuseaddr" "TCP:${MINIKUBE_IP}:${NODE_PORT}" \
  >/dev/null 2>&1 &
echo $! > "$PID_FILE"
sleep 1

echo "minikube node IP : ${MINIKUBE_IP}"
echo "Forwarder PID    : $(cat "$PID_FILE")"
echo

echo "==> Local test (from the EC2 instance)"
curl -s "http://localhost:${NODE_PORT}/info"; echo

# IMDSv2 token, then public IP (falls back to a placeholder if metadata is unreachable)
TOKEN="$(curl -s -m 2 -X PUT 'http://169.254.169.254/latest/api/token' \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 60' || true)"
PUBLIC_IP="$(curl -s -m 2 -H "X-aws-ec2-metadata-token: ${TOKEN}" \
  http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
PUBLIC_IP="${PUBLIC_IP:-<EC2-PUBLIC-IP>}"

echo
echo "Open in your browser:  http://${PUBLIC_IP}:${NODE_PORT}"
echo "(Security group must allow inbound TCP ${NODE_PORT}. Refresh to see different pod names.)"
