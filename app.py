"""CNDM IA-2: Pod Info App.

A tiny Flask service that shows which container/pod answered the request.
Refreshing the page when running 3 replicas behind a Kubernetes Service makes
load balancing visible (the pod name changes).
"""
import os
import socket
import time
from datetime import datetime, timezone

from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

START_TIME = time.time()
REQUEST_COUNT = 0

# POD_NAME / POD_IP / NODE_NAME are injected by Kubernetes (Downward API).
# When running with plain `docker run`, we fall back to the container hostname.
def runtime_info():
    return {
        "app": "pod-info-app",
        "version": os.getenv("APP_VERSION", "1.0"),
        "hostname": socket.gethostname(),
        "pod_name": os.getenv("POD_NAME", socket.gethostname()),
        "pod_ip": os.getenv("POD_IP", "n/a (plain Docker)"),
        "node_name": os.getenv("NODE_NAME", "n/a (plain Docker)"),
        "environment": os.getenv("APP_ENV", "development"),
        "uptime_seconds": int(time.time() - START_TIME),
        "requests_served_by_this_instance": REQUEST_COUNT,
        "time_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }


PAGE = """<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Pod Info App</title>
  <style>
    body { font-family: system-ui, sans-serif; background:#0f172a; color:#e2e8f0;
           display:flex; justify-content:center; padding:40px 16px; margin:0; }
    .card { background:#1e293b; border-radius:12px; padding:28px 32px; max-width:560px; width:100%; }
    h1 { margin:0 0 4px; font-size:1.4rem; }
    p.sub { margin:0 0 20px; color:#94a3b8; }
    table { width:100%; border-collapse:collapse; }
    td { padding:8px 0; border-top:1px solid #334155; }
    td:first-child { color:#94a3b8; width:46%; }
    .pod { color:#38bdf8; font-weight:600; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Pod Info App v{{ i.version }}</h1>
    <p class="sub">Containerized with Docker, deployed on Kubernetes. Refresh to see load balancing.</p>
    <table>
      <tr><td>Served by pod</td><td class="pod">{{ i.pod_name }}</td></tr>
      <tr><td>Pod IP</td><td>{{ i.pod_ip }}</td></tr>
      <tr><td>Node</td><td>{{ i.node_name }}</td></tr>
      <tr><td>Container hostname</td><td>{{ i.hostname }}</td></tr>
      <tr><td>Environment</td><td>{{ i.environment }}</td></tr>
      <tr><td>Uptime (s)</td><td>{{ i.uptime_seconds }}</td></tr>
      <tr><td>Requests on this instance</td><td>{{ i.requests_served_by_this_instance }}</td></tr>
      <tr><td>Time (UTC)</td><td>{{ i.time_utc }}</td></tr>
    </table>
  </div>
</body>
</html>"""


@app.route("/")
def index():
    global REQUEST_COUNT
    REQUEST_COUNT += 1
    return render_template_string(PAGE, i=runtime_info())


@app.route("/info")
def info():
    global REQUEST_COUNT
    REQUEST_COUNT += 1
    return jsonify(runtime_info())


@app.route("/health")
def health():
    # Used by the Docker HEALTHCHECK and Kubernetes liveness/readiness probes.
    return jsonify(status="ok"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
