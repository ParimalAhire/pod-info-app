#!/usr/bin/env bash
# Step 4-5: build the Docker image and run it as a plain container (no Kubernetes yet).
# Run from the project root:  bash scripts/run-container.sh
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="pod-info-app:1.0"
NAME="pod-info-test"
HOST_PORT=5000

echo "==> docker build"
docker build -t "$IMAGE" .

echo
echo "==> Image details"
docker images pod-info-app

echo
echo "==> docker run"
docker rm -f "$NAME" >/dev/null 2>&1 || true
docker run -d --name "$NAME" -p "${HOST_PORT}:5000" "$IMAGE"

echo "Waiting for the app to start..."
for i in $(seq 1 20); do
  if curl -fs "http://localhost:${HOST_PORT}/health" >/dev/null; then break; fi
  sleep 1
done

echo
echo "==> docker ps"
docker ps --filter "name=$NAME"

echo
echo "==> curl /health"
curl -s "http://localhost:${HOST_PORT}/health"; echo

echo
echo "==> curl /info"
curl -s "http://localhost:${HOST_PORT}/info"; echo

echo
echo "==> Container logs"
docker logs "$NAME"

echo
echo "Container is running. Stop it with:  docker rm -f $NAME"
