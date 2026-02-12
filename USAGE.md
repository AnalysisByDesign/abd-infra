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
cd scripts

# Default: K3s cluster with 3 managers, 3 workers
./multipass.sh create
```

### Initialize K3s Cluster

```bash
# After creating K3s nodes
./multipass.sh k3s-setup
```

### Export Kubeconfig

```bash
# Get kubeconfig for kubectl access
./multipass.sh k3s-kubeconfig

# Use it
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes
```

### List Nodes

```bash
./multipass.sh list
```

### Get Node IPs

```bash
./multipass.sh ips
```

### SSH to Node

```bash
./multipass.sh shell manager-1
```

### Execute Command on Node

```bash
./multipass.sh exec manager-1 "kubectl get nodes"
```

### Destroy Cluster

```bash
./multipass.sh --destroy
```

### Get Help

```bash
./multipass.sh help
```

---

## Environment Variables

All environment variables can be set before running the script:

### NODE_PREFIX

Prefix for node names. Allows running multiple clusters simultaneously.

```bash
# No prefix (default)
./multipass.sh create
# Creates: manager-1, manager-2, manager-3, worker-1, worker-2

# With prefix
NODE_PREFIX=k3s- ./multipass.sh create
# Creates: k3s-manager-1, k3s-manager-2, k3s-manager-3, k3s-worker-1, k3s-worker-2
```

### CLUSTER_TYPE

Type of cluster to create.

```bash
# K3s (default)
CLUSTER_TYPE=k3s ./multipass.sh create

# Docker Swarm
CLUSTER_TYPE=docker ./multipass.sh create

# Minikube
CLUSTER_TYPE=minikube ./multipass.sh create
```

### MANAGER_COUNT

Number of manager/server nodes (default: 3)

```bash
# Single node cluster
MANAGER_COUNT=1 WORKER_COUNT=0 ./multipass.sh create

# 5 manager HA cluster
MANAGER_COUNT=5 ./multipass.sh create
```

### WORKER_COUNT

Number of worker/agent nodes (default: 3)

```bash
# No workers (managers only)
MANAGER_COUNT=3 WORKER_COUNT=0 ./multipass.sh create

# 5 workers
WORKER_COUNT=5 ./multipass.sh create
```

### CPUS_PER_NODE

CPU cores per node (default: 3)

```bash
# Lightweight (testing)
CPUS_PER_NODE=2 ./multipass.sh create

# Performance (production-like)
CPUS_PER_NODE=4 ./multipass.sh create
```

### RAM_PER_NODE

RAM per node (default: 6G)

```bash
# Minimal
RAM_PER_NODE=4G ./multipass.sh create

# Comfortable
RAM_PER_NODE=8G ./multipass.sh create
```

### DISK_PER_NODE

Disk size per node (default: 40G)

```bash
# Minimal
DISK_PER_NODE=20G ./multipass.sh create

# Large workloads
DISK_PER_NODE=100G ./multipass.sh create
```

### IMAGE

Ubuntu version (default: 24.04)

```bash
# LTS release
IMAGE=24.04 ./multipass.sh create

# Older LTS
IMAGE=22.04 ./multipass.sh create
```

---

## K3s Clusters

### Create and Initialize K3s Cluster

```bash
cd scripts

# 1. Create nodes
./multipass.sh create

# 2. Initialize K3s with embedded etcd HA
./multipass.sh k3s-setup

# 3. Export kubeconfig
./multipass.sh k3s-kubeconfig

# 4. Use cluster
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes
kubectl get pods -A
```

### K3s Cluster Architecture

- **3 Server Nodes** (manager-1, manager-2, manager-3)
  - Run K3s server with `--cluster-init`
  - Embedded etcd for HA
  - API server, scheduler, controller-manager
  - Can tolerate 1 node failure

- **2 Agent Nodes** (worker-1, worker-2)
  - Run K3s agent (kubelet only)
  - Execute workloads
  - Connect to server API

### Access K3s API

```bash
# Via kubeconfig
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes

# Or directly on nodes
./multipass.sh exec manager-1 "sudo k3s kubectl get nodes"
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
cd scripts

# Create nodes with Docker pre-installed
CLUSTER_TYPE=docker ./multipass.sh create

# Initialize Swarm (manual for now)
./multipass.sh shell manager-1
sudo docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')

# Get join tokens
MANAGER_TOKEN=$(sudo docker swarm join-token manager -q)
WORKER_TOKEN=$(sudo docker swarm join-token worker -q)

# Join other managers (from manager-2, manager-3)
sudo docker swarm join --token $MANAGER_TOKEN manager-1:2377

# Join workers (from worker-1, worker-2)
sudo docker swarm join --token $WORKER_TOKEN manager-1:2377
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
cd scripts

# Create K3s cluster with prefix
NODE_PREFIX=k3s- CLUSTER_TYPE=k3s ./multipass.sh create
NODE_PREFIX=k3s- ./multipass.sh k3s-setup
NODE_PREFIX=k3s- ./multipass.sh k3s-kubeconfig

# Create Docker Swarm cluster with different prefix
NODE_PREFIX=docker- CLUSTER_TYPE=docker ./multipass.sh create

# List all nodes
multipass list
# Shows: k3s-manager-1, k3s-manager-2, ..., docker-manager-1, docker-manager-2, ...

# Access K3s cluster
export KUBECONFIG=~/.kube/k3s-k3s-multipass-config
kubectl get nodes

# Access Swarm cluster
./multipass.sh shell docker-manager-1
sudo docker node ls
```

### Destroy Specific Cluster

```bash
# Destroy K3s cluster only
NODE_PREFIX=k3s- ./multipass.sh --destroy

# Destroy Docker cluster only
NODE_PREFIX=docker- ./multipass.sh --destroy
```

---

## Node Management

### Start/Stop Nodes

```bash
# Start all nodes
./multipass.sh start all

# Start only managers
./multipass.sh start managers

# Start only workers
./multipass.sh start workers

# Start specific node
./multipass.sh start manager-1

# Stop nodes (same pattern)
./multipass.sh stop all
./multipass.sh stop managers
./multipass.sh stop workers
./multipass.sh stop worker-1
```

### Node Information

```bash
# Get detailed info for a node
./multipass.sh info manager-1

# List all nodes with status
./multipass.sh list

# Get IP addresses
./multipass.sh ips
```

### Shell Access

```bash
# SSH to node
./multipass.sh shell manager-1

# Run single command
./multipass.sh exec manager-1 "sudo systemctl status k3s"

# Run command with multipass directly
multipass exec manager-1 -- kubectl get nodes
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
./multipass.sh create
```

**Resource Total:** 4 CPUs, 8GB RAM

### Standard Cluster (Development)

```bash
# 3 managers, 2 workers, standard resources (DEFAULT)
MANAGER_COUNT=3 \
WORKER_COUNT=2 \
CPUS_PER_NODE=3 \
RAM_PER_NODE=6G \
./multipass.sh create
```

**Resource Total:** 15 CPUs, 30GB RAM

### High-Performance Cluster

```bash
# 3 managers, 3 workers, high resources
MANAGER_COUNT=3 \
WORKER_COUNT=3 \
CPUS_PER_NODE=4 \
RAM_PER_NODE=8G \
./multipass.sh create
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
./multipass.sh create
```

**Resource Total:** 40 CPUs, 80GB RAM

---

## Advanced Usage

### Combining Environment Variables

```bash
# Custom K3s cluster with prefix and custom resources
NODE_PREFIX=prod- \
CLUSTER_TYPE=k3s \
MANAGER_COUNT=3 \
WORKER_COUNT=5 \
CPUS_PER_NODE=4 \
RAM_PER_NODE=8G \
./multipass.sh create && \
NODE_PREFIX=prod- ./multipass.sh k3s-setup && \
NODE_PREFIX=prod- ./multipass.sh k3s-kubeconfig
```

### Multiple Clusters Workflow

```bash
# Development K3s cluster
NODE_PREFIX=dev- CPUS_PER_NODE=2 RAM_PER_NODE=4G ./multipass.sh create
NODE_PREFIX=dev- ./multipass.sh k3s-setup

# Staging K3s cluster
NODE_PREFIX=staging- CPUS_PER_NODE=3 RAM_PER_NODE=6G ./multipass.sh create
NODE_PREFIX=staging- ./multipass.sh k3s-setup

# Production simulation
NODE_PREFIX=prod- CPUS_PER_NODE=4 RAM_PER_NODE=8G ./multipass.sh create
NODE_PREFIX=prod- ./multipass.sh k3s-setup

# List all
multipass list
# Shows: dev-manager-1, staging-manager-1, prod-manager-1, etc.
```

---

## Quick Reference

### Complete K3s Workflow

```bash
# Create, initialize, and use K3s cluster
./multipass.sh create && \
./multipass.sh k3s-setup && \
./multipass.sh k3s-kubeconfig && \
export KUBECONFIG=~/.kube/k3s-multipass-config && \
kubectl get nodes
```

### Complete Docker Swarm Workflow

```bash
# Create Docker cluster
CLUSTER_TYPE=docker ./multipass.sh create

# Initialize Swarm on manager-1
./multipass.sh shell manager-1
# Inside VM:
sudo docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
exit

# List nodes
./multipass.sh exec manager-1 "sudo docker node ls"
```

### Cleanup Everything

```bash
# Destroy all clusters (without prefix)
./multipass.sh --destroy

# With specific prefix
NODE_PREFIX=k3s- ./multipass.sh --destroy
NODE_PREFIX=docker- ./multipass.sh --destroy

# Nuclear option: delete ALL multipass VMs
multipass delete --all --purge
```

---

For more examples, see [EXAMPLES.md](EXAMPLES.md)

For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
