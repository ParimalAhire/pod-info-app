#!/usr/bin/env bash
# Step 6: start minikube, build the image inside it, and deploy to Kubernetes.
# Run from the project root:  bash scripts/deploy.sh
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="pod-info-app:1.0"

echo "==> Starting minikube (Docker driver) if it is not already running"
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker --cpus=2 --memory=3072
fi

echo
echo "==> Nodes"
kubectl get nodes

echo
echo "==> Building the image inside minikube's Docker daemon (no registry needed)"
eval "$(minikube docker-env)"
docker build -t "$IMAGE" .

echo
echo "==> Applying Deployment and Service"
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

echo
echo "==> Waiting for rollout"
kubectl rollout status deployment/pod-info-app --timeout=120s

echo
echo "==> Deployment, pods and service"
kubectl get deployments
kubectl get pods -o wide
kubectl get svc pod-info-service

echo
echo "Next: bash scripts/expose.sh   (makes the NodePort reachable from the internet)"
