#!/usr/bin/env bash
# Step 2: install Docker, kubectl, minikube and helpers on a fresh Ubuntu 22.04 EC2 instance.
# Run as the normal "ubuntu" user (NOT root):  bash scripts/setup-ec2.sh
set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "Run this as the ubuntu user, not root (minikube's Docker driver refuses root)." >&2
  exit 1
fi

echo "==> Updating apt and installing base packages"
sudo apt-get update -y
sudo apt-get install -y docker.io curl git socat conntrack ca-certificates

echo "==> Enabling Docker and adding $USER to the docker group"
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"

echo "==> Installing kubectl"
KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KVER}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl

echo "==> Installing minikube"
curl -fsSLo /tmp/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install -o root -g root -m 0755 /tmp/minikube /usr/local/bin/minikube

echo
echo "==> Installed versions"
docker --version
kubectl version --client
minikube version

cat <<'EOF'

Setup finished.

IMPORTANT: the docker group only applies to NEW sessions.
Log out and SSH back in (or run:  newgrp docker ) before running the next scripts.
EOF
