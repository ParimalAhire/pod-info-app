#!/usr/bin/env bash
# Tear everything down after recording the demo.
# Run from the project root:  bash scripts/cleanup.sh
set -uo pipefail
cd "$(dirname "$0")/.."

echo "==> Stopping port forwarder"
if [ -f .socat.pid ]; then kill "$(cat .socat.pid)" 2>/dev/null || true; rm -f .socat.pid; fi

echo "==> Deleting Kubernetes resources"
kubectl delete -f k8s/ --ignore-not-found

echo "==> Removing test container"
docker rm -f pod-info-test 2>/dev/null || true

echo "==> Deleting minikube cluster"
minikube delete

cat <<'EOF'

Cluster removed.

LAST STEP (avoids AWS charges): in the EC2 console, select the instance and choose
Instance state -> Terminate (or Stop if you may need it again).
Also release any Elastic IP you allocated.
EOF
