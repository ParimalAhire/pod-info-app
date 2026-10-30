# Demo recording script (about 8 minutes)

Record the screen with your SSH terminal and a browser visible. Say your name and roll number at the start.
Lines in quotes are narration. Lines starting with `$` are commands to run.

## 0:00 Introduction (30 s)
"Hello, I'm <name>, roll number <roll>. This is my CNDM IA-2 submission: containerizing a Flask app with Docker and
deploying it on Kubernetes. Everything runs on one AWS EC2 instance, a t3.medium running Ubuntu, with Docker and a
minikube Kubernetes cluster."

Show: the EC2 console with the running instance and the security group (ports 22 and 30080).

## 0:30 The application and Dockerfile (1 min)
$ cat app.py | head -40
$ cat Dockerfile

"The app is a small Flask service with three routes: the home page, `/info` returning JSON, and `/health` for health
checks. The Dockerfile is multi-stage. The builder stage installs dependencies, and the final stage copies only the
installed packages, which keeps the image small. It runs as a non-root user, has a HEALTHCHECK, and uses gunicorn as a
production server instead of Flask's development server. Copying requirements first lets Docker cache that layer."

## 1:30 Build and run the container (1.5 min)
$ bash scripts/run-container.sh

"First `docker build` creates the image. `docker images` shows its size. `docker run` starts it in the background,
mapping port 5000. `docker ps` shows it running, and curl on `/health` and `/info` shows the app answering from inside
the container. The logs show gunicorn handling those requests."

$ docker rm -f pod-info-test

## 3:00 Kubernetes manifests (1 min)
$ cat k8s/deployment.yaml
$ cat k8s/service.yaml

"The Deployment asks for 3 replicas of the image. Each container has CPU and memory requests and limits, readiness and
liveness probes on `/health`, and a rolling update strategy. The pod name and IP are passed to the app through the
Downward API. The Service is a NodePort. It selects pods by the label `app: pod-info-app` and forwards port 80 to the
container's port 5000, exposed on node port 30080."

## 4:00 Deploy (1 min)
$ bash scripts/deploy.sh

"This starts minikube and builds the image inside minikube's Docker daemon, so no registry is needed. Then `kubectl apply`
creates the Deployment and Service. `kubectl get pods -o wide` shows three pods running on the node, and
`kubectl get svc` shows the NodePort service."

## 5:00 Access the service (1 min)
$ bash scripts/expose.sh

Switch to the browser: open `http://<EC2-PUBLIC-IP>:30080` and refresh 4 to 5 times.

"The page shows which pod answered. As I refresh, the pod name changes. The Service is load balancing across the three
replicas."

## 6:00 Self-healing and scaling (1.5 min)
$ kubectl get pods
$ kubectl delete pod <one-pod-name>
$ kubectl get pods
"I deleted a pod and the Deployment immediately created a replacement, because it keeps the desired state of 3."

$ kubectl scale deployment pod-info-app --replicas=5
$ kubectl get pods
$ kubectl scale deployment pod-info-app --replicas=3
"Scaling is one command."

$ kubectl logs <pod-name> --tail=10
$ kubectl describe deployment pod-info-app | head -30

## 7:30 Concepts and wrap-up (30 s)
"The cloud-native ideas shown here are: containers for portable packaging, declarative YAML for desired state,
self-healing, horizontal scaling, health probes, resource limits and service-based load balancing. On EKS the same
manifests would work with the image in ECR and a LoadBalancer Service. The code, manifests and evidence are in my GitHub
repository. Thank you."

$ bash scripts/capture-evidence.sh   (optional: run before recording so the files are ready)

## Before you hit record
- [ ] `bash scripts/deploy.sh` and `bash scripts/expose.sh` have run once successfully (a dry run saves time)
- [ ] Security group has TCP 30080 open
- [ ] Terminal font size is large enough to read
- [ ] Browser tab ready on `http://<EC2-PUBLIC-IP>:30080`
- [ ] Your name or roll number visible (terminal prompt or the first slide)
