# CNDM IA-2: Containerization & Kubernetes Deployment

A small Flask application ("Pod Info App") that is containerized with Docker and deployed on
Kubernetes (minikube) running on a single AWS EC2 instance. The page shows which pod served the
request, so refreshing the browser demonstrates Kubernetes load balancing across 3 replicas.

## Architecture

```
Browser --> EC2 public IP:30080
              |  (security group allows TCP 30080)
              v
        socat forwarder  --> minikube node (container, private IP)
                                  |
                          Service: pod-info-service (NodePort 30080 -> 80 -> 5000)
                                  |
                  +---------------+---------------+
                  v               v               v
               Pod 1           Pod 2           Pod 3      (Deployment, 3 replicas)
              Flask+gunicorn in a Docker image built with a multi-stage Dockerfile
```

## Repository layout

| Path | Purpose |
|---|---|
| `app.py`, `requirements.txt` | Flask application (`/`, `/info`, `/health`) |
| `Dockerfile`, `.dockerignore` | Multi-stage, non-root, health-checked image |
| `k8s/deployment.yaml` | 3 replicas, resource requests/limits, probes, rolling update |
| `k8s/service.yaml` | NodePort Service (30080 -> 80 -> 5000) |
| `scripts/setup-ec2.sh` | Installs Docker, kubectl, minikube, socat |
| `scripts/run-container.sh` | Builds the image and runs a plain Docker container |
| `scripts/deploy.sh` | Starts minikube, builds the image inside it, applies the manifests |
| `scripts/expose.sh` | Makes the NodePort reachable on the EC2 public IP |
| `scripts/capture-evidence.sh` | Saves command outputs into `evidence/` |
| `scripts/cleanup.sh` | Removes everything |
| `DEMO_SCRIPT.md` | Timed narration for the recorded demo |

## Step-by-step on AWS

### 1. Launch the EC2 instance (AWS console)
- AMI: Ubuntu Server 22.04 LTS. Instance type: `t3.medium` (2 vCPU, 4 GB). Storage: 20 GB gp3.
- Create or choose a key pair (`.pem`) so you can SSH in.
- Security group inbound rules:
  - SSH, TCP 22, source: My IP
  - Custom TCP 30080, source: 0.0.0.0/0 (the application port)

### 2. Connect and get the code
```bash
chmod 400 your-key.pem
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>

git clone https://github.com/<your-username>/<your-repo>.git pod-info-app
cd pod-info-app
```

### 3. Install tools
```bash
bash scripts/setup-ec2.sh
exit            # log out so the docker group takes effect, then SSH in again
cd pod-info-app
```

### 4. Docker: build and run the container
```bash
bash scripts/run-container.sh
```
Shows `docker build`, the image, `docker run`, `docker ps`, the `/health` and `/info` responses and the
container logs. Optional: open `http://<EC2-PUBLIC-IP>:5000` after temporarily allowing port 5000.
Stop it afterwards with `docker rm -f pod-info-test`.

### 5. Kubernetes: deploy
```bash
bash scripts/deploy.sh
```

### 6. Expose and test the Service
```bash
bash scripts/expose.sh
```
Open `http://<EC2-PUBLIC-IP>:30080` and refresh several times: the pod name changes.

### 7. Capture evidence
```bash
bash scripts/capture-evidence.sh
```
Creates `evidence/01-docker.txt` ... `06-scaling.txt`. Add browser and AWS console screenshots to `evidence/`.

### 8. Clean up
```bash
bash scripts/cleanup.sh
```
Then terminate the EC2 instance in the console to stop billing.

## Cloud-native concepts (for the demo)

**Containers and Docker**
- A container packages an app with its dependencies and shares the host kernel, so it is lighter and starts faster than a VM.
- An image is the read-only template. A container is a running instance of it.
- Images are built from layers. Copying `requirements.txt` before the code means dependency layers are cached.
- Multi-stage build: dependencies are installed in a builder stage and only the results are copied to the final image, which keeps it small.
- Security: the app runs as a non-root user. `HEALTHCHECK` lets Docker report container health.

**Kubernetes**
- Pod: the smallest deployable unit (one or more containers).
- Deployment: declares the desired state (3 replicas). It manages ReplicaSets, which keep that many pods running.
- Service: a stable virtual IP and DNS name that load balances across pods selected by labels. Types: ClusterIP (internal), NodePort (a port on every node), LoadBalancer (cloud load balancer such as AWS ELB).
- Labels and selectors tie the Service to the pods (`app: pod-info-app`).
- Requests and limits: requests guide scheduling, limits cap CPU and memory so one pod cannot starve others.
- Probes: readiness decides whether a pod receives traffic, liveness decides whether it gets restarted.
- Self-healing: delete a pod and the Deployment recreates it (see `evidence/05-self-healing.txt`).
- Scaling: `kubectl scale` changes replicas instantly (see `evidence/06-scaling.txt`).
- Rolling updates: new pods replace old ones gradually (`maxUnavailable: 1`, `maxSurge: 1`) for zero-downtime releases.
- Declarative configuration: YAML in Git describes the desired state, and Kubernetes reconciles toward it.

**Cloud-native principles used**: containerized services, declarative infrastructure, health checks, horizontal
scaling, immutable images, configuration through environment variables (Downward API).

**Why minikube on EC2 instead of EKS:** a single-node cluster is enough to demonstrate every Kubernetes object
required here at far lower cost. In production the same manifests run unchanged on EKS, with the image pulled from
ECR and the Service type changed to LoadBalancer.

## Troubleshooting
| Symptom | Fix |
|---|---|
| `permission denied` on `/var/run/docker.sock` | Log out and SSH back in after `setup-ec2.sh` |
| Pods stuck in `ErrImagePull` | Image was built outside minikube. Re-run `bash scripts/deploy.sh` |
| Browser cannot connect on 30080 | Check the security group rule, and run `bash scripts/expose.sh` again |
| minikube refuses to start as root | Run as the `ubuntu` user, not with `sudo` |
| minikube out of memory | Use a `t3.medium` or larger |
