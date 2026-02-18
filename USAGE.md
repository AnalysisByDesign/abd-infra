# Usage Guide

Comprehensive guide to using the abd-infra multipass cluster management system.

---

## Table of Contents

- [Basic Commands](#basic-commands)
- [Environment Variables](#environment-variables)
- [K3s Clusters](#k3s-clusters)
- [Docker Swarm Clusters](#docker-swarm-clusters)
- [Node Prefixing (Running Multiple Clusters)](#node-prefixing-running-multiple-clusters)
- [Node Management](#node-management)
- [Resource Configuration](#resource-configuration)

---

## Basic Commands

### Create Cluster

```bash
# Default: K3s cluster with 3 managers, 3 workers
NODE_PREFIX=k3s
./scripts/multipass.sh create
```

### Initialize K3s Cluster

```bash
# After creating K3s nodes
./scripts/k3s.sh setup
```

### Export Kubeconfig

```bash
# Get kubeconfig for kubectl access
./scripts/k3s.sh kubeconfig

# Use it
export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config
kubectl get nodes
```

### List Nodes

```bash
./scripts/multipass.sh list
```

### Get Node IPs

```bash
./scripts/multipass.sh ips
```

### SSH to Node

```bash
./scripts/multipass.sh shell ${NODE_PREFIX}-manager-1
```

### Execute Command on Node

```bash
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "kubectl get nodes"
```

### Destroy Cluster

```bash
./scripts/multipass.sh delete
```

### Get Help

```bash
./scripts/multipass.sh help
```

---

## Environment Variables

All environment variables can be set before running the script:

### NODE_PREFIX

Prefix for node names. Allows running multiple clusters simultaneously.

```bash
# No prefix (default)
./scripts/multipass.sh create
# Creates: manager-1, worker-1, worker-2

# With prefix (hyphen separator added automatically)
NODE_PREFIX=k3s ./scripts/multipass.sh create
# Creates: k3s-manager-1, k3s-manager-2, k3s-manager-3, k3s-worker-1, k3s-worker-2
```

### CLUSTER_TYPE

Type of cluster to create.

```bash
# K3s (default)
CLUSTER_TYPE=k3s ./scripts/multipass.sh create

# Docker Swarm
CLUSTER_TYPE=docker ./scripts/multipass.sh create

# Minikube
CLUSTER_TYPE=minikube ./scripts/multipass.sh create
```

### MANAGER_COUNT

Number of manager/server nodes (default: 1)

```bash
# Single node cluster
MANAGER_COUNT=1 WORKER_COUNT=0 ./scripts/multipass.sh create

# 5 manager HA cluster
MANAGER_COUNT=5 ./scripts/multipass.sh create
```

### WORKER_COUNT

Number of worker/agent nodes (default: 2)

```bash
# No workers (managers only)
MANAGER_COUNT=3 WORKER_COUNT=0 ./scripts/multipass.sh create

# 5 workers
WORKER_COUNT=5 ./scripts/multipass.sh create
```

### CPUS_PER_NODE

CPU cores per node (default: 3)

```bash
# Lightweight (testing)
CPUS_PER_NODE=2 ./scripts/multipass.sh create

# Performance (production-like)
CPUS_PER_NODE=4 ./scripts/multipass.sh create
```

### RAM_PER_NODE

RAM per node (default: 6G). Applies to all nodes unless overridden by `MANAGER_RAM` or `WORKER_RAM`.

```bash
# Minimal
RAM_PER_NODE=4G ./scripts/multipass.sh create

# Comfortable
RAM_PER_NODE=8G ./scripts/multipass.sh create
```

### MANAGER_CPUS / MANAGER_RAM

CPU cores and RAM for manager nodes only. Falls back to `CPUS_PER_NODE` / `RAM_PER_NODE` when not set.

Use this to keep control-plane nodes small while giving workers more resources.

```bash
# Small managers (control plane only), large workers (workloads)
MANAGER_CPUS=2 MANAGER_RAM=4G \
WORKER_CPUS=4  WORKER_RAM=16G \
./scripts/multipass.sh create
```

### WORKER_CPUS / WORKER_RAM

CPU cores and RAM for worker nodes only. Falls back to `CPUS_PER_NODE` / `RAM_PER_NODE` when not set.

```bash
# Workers with extra RAM for Ollama or other memory-heavy workloads
WORKER_CPUS=4 WORKER_RAM=16G ./scripts/multipass.sh create
```

### DISK_PER_NODE

Disk size per node (default: 40G)

```bash
# Minimal
DISK_PER_NODE=20G ./scripts/multipass.sh create

# Large workloads
DISK_PER_NODE=100G ./scripts/multipass.sh create
```

### IMAGE

Ubuntu version (default: 24.04)

```bash
# LTS release
IMAGE=24.04 ./scripts/multipass.sh create

# Older LTS
IMAGE=22.04 ./scripts/multipass.sh create
```

---

## K3s Clusters

### Create and Initialize K3s Cluster

```bash
# 1. Create nodes
./scripts/multipass.sh create

# 2. Initialize K3s with embedded etcd HA
./scripts/k3s.sh setup

# 3. Export kubeconfig
./scripts/k3s.sh kubeconfig

# 4. Use cluster
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes
kubectl get pods -A
```

### K3s Cluster Architecture

- **3 Server Nodes** (manager-1, ${NODE_PREFIX}-manager-2, ${NODE_PREFIX}-manager-3)
  - Run K3s server with `--cluster-init`
  - Embedded etcd for HA
  - API server, scheduler, controller-manager
  - Can tolerate 1 node failure

- **2 Agent Nodes** (worker-1, ${NODE_PREFIX}-worker-2)
  - Run K3s agent (kubelet only)
  - Execute workloads
  - Connect to server API

### Access K3s API

```bash
# Via kubeconfig
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes

# Or directly on nodes
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo k3s kubectl get nodes"
```

### Deploy to K3s

```bash
# Apply manifests
kubectl apply -f your-app.yaml

# Create deployment
kubectl create deployment nginx --image=nginx

# Expose service
kubectl expose deployment nginx --port=80 --type=NodePort
```

---

## Docker Swarm Clusters

### Create Docker Swarm Cluster

```bash

# Create nodes with Docker pre-installed
CLUSTER_TYPE=docker ./scripts/multipass.sh create

# Get manager-1 IP (from Mac host)
MANAGER_IP=$(multipass info ${NODE_PREFIX}-manager-1 | grep IPv4 | awk '{print $2}')

# Initialize Swarm
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker swarm init --advertise-addr $MANAGER_IP"

# Get join tokens
MANAGER_TOKEN=$(./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker swarm join-token manager -q")
WORKER_TOKEN=$(./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker swarm join-token worker -q")

# Join other managers
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-2 "sudo docker swarm join --token $MANAGER_TOKEN $MANAGER_IP:2377"
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-3 "sudo docker swarm join --token $MANAGER_TOKEN $MANAGER_IP:2377"

# Join workers
./scripts/multipass.sh exec ${NODE_PREFIX}-worker-1 "sudo docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377"
./scripts/multipass.sh exec ${NODE_PREFIX}-worker-2 "sudo docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377"
```

### Docker Swarm Architecture

- **3 Manager Nodes**
  - Raft consensus (quorum: 2/3 nodes)
  - Can tolerate 1 failure
  - Run services and management tasks

- **2 Worker Nodes**
  - Execute services
  - Do not participate in Raft consensus

### Deploy to Swarm

```bash
# Create service
docker service create --name web --replicas 3 -p 8080:80 nginx

# List services
docker service ls

# Scale service
docker service scale web=5
```

---

## Node Prefixing (Running Multiple Clusters)

Use `NODE_PREFIX` to run K3s and Docker Swarm clusters simultaneously:

### Example: K3s + Docker Swarm

```bash

# Create K3s cluster with prefix
NODE_PREFIX=k3s CLUSTER_TYPE=k3s ./scripts/multipass.sh create
NODE_PREFIX=k3s ./scripts/k3s.sh setup
NODE_PREFIX=k3s ./scripts/k3s.sh kubeconfig

# Create Docker Swarm cluster with different prefix
NODE_PREFIX=docker CLUSTER_TYPE=docker ./scripts/multipass.sh create

# List all nodes
multipass list
# Shows: k3s-manager-1, k3s-manager-2, ..., docker-manager-1, docker-manager-2, ...

# Access K3s cluster
export KUBECONFIG=~/.kube/k3s-k3s-multipass-config
kubectl get nodes

# Access Swarm cluster
./scripts/multipass.sh shell docker-manager-1
sudo docker node ls
```

### Destroy Specific Cluster

```bash
# Destroy K3s cluster only
NODE_PREFIX=k3s ./scripts/multipass.sh delete

# Destroy Docker cluster only
NODE_PREFIX=docker ./scripts/multipass.sh delete
```

---

## Node Management

### Start/Stop Nodes

```bash
# Start all nodes
./scripts/multipass.sh start all

# Start only managers
./scripts/multipass.sh start managers

# Start only workers
./scripts/multipass.sh start workers

# Start specific node
./scripts/multipass.sh start ${NODE_PREFIX}-manager-1

# Stop nodes (same pattern)
./scripts/multipass.sh stop all
./scripts/multipass.sh stop managers
./scripts/multipass.sh stop workers
./scripts/multipass.sh stop ${NODE_PREFIX}-worker-1
```

### Node Information

```bash
# Get detailed info for a node
./scripts/multipass.sh info ${NODE_PREFIX}-manager-1

# List all nodes with status
./scripts/multipass.sh list

# Get IP addresses
./scripts/multipass.sh ips
```

### Shell Access

```bash
# SSH to node
./scripts/multipass.sh shell ${NODE_PREFIX}-manager-1

# Run single command
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo systemctl status k3s"

# Run command with multipass directly
multipass exec ${NODE_PREFIX}-manager-1 -- kubectl get nodes
```

---

## Resource Configuration

### Minimal Cluster (Testing)

```bash
# 1 manager, 1 worker, minimal resources
MANAGER_COUNT=1 \
WORKER_COUNT=1 \
CPUS_PER_NODE=2 \
RAM_PER_NODE=4G \
./scripts/multipass.sh create
```

**Resource Total:** 4 CPUs, 8GB RAM

### Standard Cluster (Development)

```bash
# 3 managers, 2 workers, uniform resources
MANAGER_COUNT=3 \
WORKER_COUNT=2 \
CPUS_PER_NODE=3 \
RAM_PER_NODE=6G \
./scripts/multipass.sh create
```

**Resource Total:** 15 CPUs, 30GB RAM

### HA Cluster with Split Resources (Recommended)

Keeps manager nodes small (control plane only) and gives workers the RAM they need for workloads like Ollama.

```bash
# 3 managers (small), 2 workers (large)
MANAGER_COUNT=3 \
WORKER_COUNT=2 \
MANAGER_CPUS=2 MANAGER_RAM=4G \
WORKER_CPUS=4  WORKER_RAM=16G \
./scripts/multipass.sh create
```

**Resource Total:** 6 CPUs + 8 CPUs = 14 CPUs, 12GB + 32GB = 44GB RAM

### High-Performance Cluster (Uniform)

```bash
# 3 managers, 3 workers, uniform high resources
MANAGER_COUNT=3 \
WORKER_COUNT=3 \
CPUS_PER_NODE=4 \
RAM_PER_NODE=8G \
./scripts/multipass.sh create
```

**Resource Total:** 24 CPUs, 48GB RAM

### Production-Like HA Cluster

```bash
# 5 managers, 5 workers, production resources
MANAGER_COUNT=5 \
WORKER_COUNT=5 \
CPUS_PER_NODE=4 \
RAM_PER_NODE=8G \
DISK_PER_NODE=100G \
./scripts/multipass.sh create
```

**Resource Total:** 40 CPUs, 80GB RAM

---

## Advanced Usage

### Combining Environment Variables

```bash
# Custom K3s cluster with prefix and custom resources
NODE_PREFIX=prod \
CLUSTER_TYPE=k3s \
MANAGER_COUNT=3 \
WORKER_COUNT=5 \
CPUS_PER_NODE=4 \
RAM_PER_NODE=8G \
./scripts/multipass.sh create && \
NODE_PREFIX=prod ./scripts/k3s.sh setup && \
NODE_PREFIX=prod ./scripts/k3s.sh kubeconfig
```

### Multiple Clusters Workflow

```bash
# Development K3s cluster
NODE_PREFIX=dev CPUS_PER_NODE=2 RAM_PER_NODE=4G ./scripts/multipass.sh create
NODE_PREFIX=dev ./scripts/k3s.sh setup

# Staging K3s cluster
NODE_PREFIX=staging CPUS_PER_NODE=3 RAM_PER_NODE=6G ./scripts/multipass.sh create
NODE_PREFIX=staging ./scripts/k3s.sh setup

# Production simulation
NODE_PREFIX=prod CPUS_PER_NODE=4 RAM_PER_NODE=8G ./scripts/multipass.sh create
NODE_PREFIX=prod ./scripts/k3s.sh setup

# List all
multipass list
# Shows: dev-manager-1, staging-manager-1, prod-manager-1, etc.
```

---

## Quick Reference

### Complete K3s Workflow

```bash
# Create, initialize, and use K3s cluster
./scripts/multipass.sh create && \
./scripts/k3s.sh setup && \
./scripts/k3s.sh kubeconfig && \
export KUBECONFIG=~/.kube/k3s-multipass-config && \
kubectl get nodes
```

### Complete Docker Swarm Workflow

```bash
# Create Docker cluster
CLUSTER_TYPE=docker ./scripts/multipass.sh create

# Initialize Swarm on ${NODE_PREFIX}-manager-1
MANAGER_IP=$(multipass info ${NODE_PREFIX}-manager-1 | grep IPv4 | awk '{print $2}')
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker swarm init --advertise-addr $MANAGER_IP"

# List nodes
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker node ls"
```

### Cleanup

```bash
# Destroy cluster (no prefix)
./scripts/multipass.sh delete

# Destroy specific cluster by prefix
NODE_PREFIX=k3s ./scripts/multipass.sh delete
NODE_PREFIX=docker ./scripts/multipass.sh delete

# Nuclear option: delete ALL multipass VMs
multipass delete --all --purge
```

---

For more examples, see [EXAMPLES.md](EXAMPLES.md)

For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
