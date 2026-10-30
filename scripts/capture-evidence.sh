#!/usr/bin/env bash
# Step 8: collect execution evidence into evidence/ (submit these files + screenshots).
# Run from the project root AFTER deploy.sh and expose.sh:  bash scripts/capture-evidence.sh
set -uo pipefail
cd "$(dirname "$0")/.."

OUT="evidence"
mkdir -p "$OUT"
NODE_PORT=30080

section() { echo; echo "######## $* ########"; }

{
  echo "Evidence captured: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
  echo "Host: $(hostname)"

  section "docker version"
  docker --version

  section "kubectl / minikube versions"
  kubectl version --client
  minikube version

  section "Dockerfile"
  cat Dockerfile

  section "docker images (inside minikube daemon)"
  eval "$(minikube docker-env)"
  docker images pod-info-app
  eval "$(minikube docker-env -u)"

  section "docker ps (plain container from run-container.sh, if still running)"
  docker ps -a --filter name=pod-info-test
} > "$OUT/01-docker.txt" 2>&1

{
  section "kubectl get nodes"
  kubectl get nodes -o wide

  section "kubectl get deployments"
  kubectl get deployments -o wide

  section "kubectl get pods -o wide"
  kubectl get pods -o wide

  section "kubectl get svc"
  kubectl get svc -o wide

  section "kubectl get endpoints"
  kubectl get endpoints pod-info-service

  section "kubectl describe deployment"
  kubectl describe deployment pod-info-app

  section "kubectl describe service"
  kubectl describe service pod-info-service
} > "$OUT/02-kubernetes.txt" 2>&1

{
  for pod in $(kubectl get pods -l app=pod-info-app -o name); do
    section "kubectl logs $pod"
    kubectl logs "$pod" --tail=30
  done
} > "$OUT/03-pod-logs.txt" 2>&1

{
  section "10 requests to the Service (watch the pod name change = load balancing)"
  for i in $(seq 1 10); do
    printf "request %02d -> " "$i"
    curl -s "http://localhost:${NODE_PORT}/info" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['pod_name'], d['pod_ip'])"
  done
} > "$OUT/04-service-access.txt" 2>&1

{
  section "Self-healing test: delete one pod, Kubernetes recreates it"
  VICTIM="$(kubectl get pods -l app=pod-info-app -o jsonpath='{.items[0].metadata.name}')"
  echo "Deleting $VICTIM"
  kubectl delete pod "$VICTIM" --wait=false
  sleep 8
  kubectl get pods -o wide
} > "$OUT/05-self-healing.txt" 2>&1

{
  section "Scaling test: 3 -> 5 -> 3 replicas"
  kubectl scale deployment pod-info-app --replicas=5
  kubectl rollout status deployment/pod-info-app --timeout=90s
  kubectl get pods
  kubectl scale deployment pod-info-app --replicas=3
  kubectl rollout status deployment/pod-info-app --timeout=90s
  kubectl get pods
} > "$OUT/06-scaling.txt" 2>&1

echo "Evidence saved in ./$OUT:"
ls -1 "$OUT"
echo
echo "Also take browser screenshots of http://<EC2-PUBLIC-IP>:${NODE_PORT} (refresh a few times)"
echo "and of the EC2 console showing the running instance + security group."
