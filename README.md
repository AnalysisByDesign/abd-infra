# abd-infra

**Local Development Infrastructure for K3s, Docker Swarm, and Kubernetes**

Multi-cluster local development environment using Canonical Multipass VMs. Part of the AbD Training ecosystem for labs, courses, and AI-driven infrastructure management.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
  - [K3s Cluster (Default)](#k3s-cluster-default)
  - [Docker Swarm Cluster](#docker-swarm-cluster)
  - [Minikube Cluster](#minikube-cluster)
- [Commands Reference](#commands-reference)
- [Configuration](#configuration)
- [Architecture](#architecture)
- [Project Status](#project-status)
- [Documentation](#documentation)
- [Related Repositories](#related-repositories)
- [License](#license)

---

## Overview

The `abd-infra` repository provides infrastructure-as-code for creating production-like development environments on your laptop using lightweight VMs. It supports multiple orchestration platforms (K3s, Docker Swarm, Minikube) and is designed for:

- **Local Development**: Fully laptop-contained multi-node clusters
- **Training Labs**: Hands-on infrastructure and database courses
- **AI Agent Development**: Foundation for AI-driven infrastructure management (future)
- **Production Simulation**: HA clusters with proper quorum and failover

### Primary Use Case

Creating a **K3s high-availability cluster** (3 server nodes + 3 agent nodes) with embedded etcd for developing and testing Kubernetes applications locally without cloud resources.

---

## Features

### Core Capabilities

- ✅ **Multi-Cluster Support**: K3s, Docker Swarm, Minikube with single command switching
- ✅ **High Availability**: Configurable manager/worker node counts with proper HA patterns
- ✅ **One-Command Deployment**: Automated cluster initialization and configuration
- ✅ **Kubeconfig Export**: Direct kubectl access from host machine
- ✅ **Resource Customization**: Configure CPUs, RAM, disk per node via environment variables
- ✅ **Full Lifecycle Management**: Create, delete, start, stop individual nodes or entire clusters
- ✅ **Production-Like Topology**: 3-node quorum for Raft/etcd consensus testing

### Cluster Types

| Cluster Type | Best For | Default Config | HA Support |
|--------------|----------|----------------|------------|
| **K3s** (default) | Kubernetes development, lightweight production-like | 3 servers + 3 agents | ✅ Yes (embedded etcd) |
| **Docker Swarm** | Docker-native orchestration, Portainer UI | 3 managers + 3 workers | ✅ Yes (Raft consensus) |
| **Minikube** | Single-node K8s testing, quick experiments | 1 manager + workers | ⚠️ Limited |

---

## Quick Start

### Prerequisites

- **macOS** (Darwin) - tested on macOS 25.2.0+
- **Multipass** installed: `brew install multipass`
- **kubectl** (optional, for K3s): `brew install kubectl`
- **Docker** (for Swarm mode only)

### 30-Second K3s Cluster

```bash
# Clone repository
git clone <repo-url>
cd abd-infra

# Create, initialize, and configure K3s cluster
./scripts/multipass.sh create && \
./scripts/multipass.sh k3s-setup && \
./scripts/multipass.sh k3s-kubeconfig

# Use your cluster
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes
```

Expected output:
```
NAME        STATUS   ROLES                       AGE   VERSION
manager-1   Ready    control-plane,etcd,master   2m    v1.28.x+k3s1
manager-2   Ready    control-plane,etcd,master   1m    v1.28.x+k3s1
manager-3   Ready    control-plane,etcd,master   1m    v1.28.x+k3s1
worker-1    Ready    <none>                      30s   v1.28.x+k3s1
worker-2    Ready    <none>                      30s   v1.28.x+k3s1
worker-3    Ready    <none>                      30s   v1.28.x+k3s1
```

---

## Installation

### Install Multipass

```bash
# macOS
brew install multipass

# Verify installation
multipass version
```

### Clone Repository

```bash
git clone <repo-url>
cd abd-infra
chmod +x scripts/multipass.sh
```

### Verify Prerequisites

```bash
# Check Multipass is running
multipass list

# Check available resources
multipass version
system_profiler SPHardwareDataType | grep -E "Cores|Memory"
```

**Resource Requirements:**
- Default: 6 nodes × 2 CPUs × 4GB RAM = **12 CPUs, 24GB RAM**
- Minimum: 1 server + 2 agents = **3 nodes, 6 CPUs, 12GB RAM**

---

## Usage

### K3s Cluster (Default)

**Full Workflow:**

```bash
# 1. Create VM nodes (3 servers + 3 agents)
./scripts/multipass.sh create

# 2. Install and configure K3s cluster
./scripts/multipass.sh k3s-setup

# 3. Export kubeconfig for local access
./scripts/multipass.sh k3s-kubeconfig

# 4. Verify cluster
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes
kubectl get pods -A
```

**Custom Configuration:**

```bash
# Single-server development cluster (saves resources)
MANAGER_COUNT=1 WORKER_COUNT=2 ./scripts/multipass.sh create
./scripts/multipass.sh k3s-setup

# Custom resources per node
CPUS_PER_NODE=1 RAM_PER_NODE=2G ./scripts/multipass.sh create
```

**Access Cluster:**

```bash
# Via kubectl (from host)
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get all -A

# Via SSH to server node
./scripts/multipass.sh shell manager-1
sudo k3s kubectl get nodes

# Deploy test workload
kubectl create deployment nginx --image=nginx:alpine
kubectl expose deployment nginx --port=80 --type=NodePort
```

---

### Docker Swarm Cluster

**Full Workflow:**

```bash
# 1. Create Swarm cluster (3 managers + 3 workers)
CLUSTER_TYPE=docker ./scripts/multipass.sh create

# 2. Get manager-1 IP for Portainer access
./scripts/multipass.sh info manager-1

# 3. Initialize Docker Swarm (manual step)
./scripts/multipass.sh shell manager-1
docker swarm init --advertise-addr <manager-1-IP>
docker swarm join-token manager  # Run on manager-2, manager-3
docker swarm join-token worker   # Run on worker nodes

# 4. Optional: Configure NFS and labels
./scripts/multipass.sh nfs-setup

# 5. Access Portainer UI
# Browser: https://<manager-1-IP>:9443
```

**Swarm Management:**

```bash
# View cluster status
./scripts/multipass.sh exec manager-1 docker node ls

# Deploy service across workers
./scripts/multipass.sh exec manager-1 docker service create \
  --name web \
  --replicas 3 \
  --publish 8080:80 \
  nginx:alpine

# Scale service
./scripts/multipass.sh exec manager-1 docker service scale web=6
```

---

### Minikube Cluster

```bash
# Create Minikube nodes
CLUSTER_TYPE=minikube ./scripts/multipass.sh create

# Start Minikube on manager-1
./scripts/multipass.sh shell manager-1
minikube start --driver=docker --nodes=3

# Use kubectl
minikube kubectl -- get nodes
```

---

## Commands Reference

### Cluster Lifecycle

```bash
# Create all nodes (managers + workers)
./scripts/multipass.sh create

# Delete all nodes (with confirmation)
./scripts/multipass.sh delete

# Start nodes
./scripts/multipass.sh start all           # All nodes
./scripts/multipass.sh start managers      # Only managers
./scripts/multipass.sh start workers       # Only workers
./scripts/multipass.sh start manager-1     # Specific node

# Stop nodes (same syntax as start)
./scripts/multipass.sh stop all
```

### K3s Operations

```bash
# Initialize K3s cluster (after creating nodes)
./scripts/multipass.sh k3s-setup

# Export kubeconfig for kubectl access
./scripts/multipass.sh k3s-kubeconfig

# Verify cluster status
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes
```

### Docker Swarm Operations

```bash
# Configure NFS + node labels + demo service
./scripts/multipass.sh nfs-setup
```

### Node Management

```bash
# List all nodes and status
./scripts/multipass.sh list

# Show detailed node information
./scripts/multipass.sh info manager-1

# SSH into node
./scripts/multipass.sh shell worker-2

# Execute command on node
./scripts/multipass.sh exec manager-1 hostname

# Show all node IP addresses
./scripts/multipass.sh ips
```

### Help

```bash
# Display full help with examples
./scripts/multipass.sh help
```

---

## Configuration

### Environment Variables

| Variable | Default | Description | Example |
|----------|---------|-------------|---------|
| `CLUSTER_TYPE` | `k3s` | Cluster type: k3s, docker, minikube | `CLUSTER_TYPE=docker` |
| `MANAGER_COUNT` | `3` | Number of manager/server nodes | `MANAGER_COUNT=5` |
| `WORKER_COUNT` | `3` | Number of worker/agent nodes | `WORKER_COUNT=2` |
| `CPUS_PER_NODE` | `2` | CPU cores per node | `CPUS_PER_NODE=4` |
| `RAM_PER_NODE` | `4G` | RAM per node | `RAM_PER_NODE=8G` |
| `DISK_PER_NODE` | `40G` | Disk size per node | `DISK_PER_NODE=100G` |
| `IMAGE` | `24.04` | Ubuntu image version | `IMAGE=22.04` |

### Node Naming Convention

- **Manager/Server nodes**: `manager-1`, `manager-2`, `manager-3`, ...
- **Worker/Agent nodes**: `worker-1`, `worker-2`, `worker-3`, ...

### Cloud-Init Configurations

Cloud-init files located in [`config/multipass/`](config/multipass/):

- [`cloud-init.k3s.yaml`](config/multipass/cloud-init.k3s.yaml) - K3s prerequisites and network configuration
- [`cloud-init.docker.yaml`](config/multipass/cloud-init.docker.yaml) - Docker Engine + Portainer CE
- [`cloud-init.minikube.yaml`](config/multipass/cloud-init.minikube.yaml) - Docker + kubectl + Minikube

---

## Architecture

### High Availability Design

#### K3s Cluster (Default)
```
┌─────────────────────────────────────────────┐
│           K3s HA Cluster (6 nodes)          │
├─────────────────────────────────────────────┤
│  Server Nodes (Control Plane + etcd)        │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│  │manager-1│ │manager-2│ │manager-3│       │
│  │ K3s API │ │ K3s API │ │ K3s API │       │
│  │  etcd   │ │  etcd   │ │  etcd   │       │
│  └─────────┘ └─────────┘ └─────────┘       │
│       ↓           ↓           ↓             │
├─────────────────────────────────────────────┤
│  Agent Nodes (Workloads)                    │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│  │worker-1 │ │worker-2 │ │worker-3 │       │
│  │ Kubelet │ │ Kubelet │ │ Kubelet │       │
│  └─────────┘ └─────────┘ └─────────┘       │
└─────────────────────────────────────────────┘
```

**HA Properties:**
- 3 server nodes = embedded etcd cluster (tolerate 1 failure)
- Load balanced API access across all servers
- Automatic leader election and failover

#### Docker Swarm Cluster
```
┌─────────────────────────────────────────────┐
│      Docker Swarm Cluster (6 nodes)         │
├─────────────────────────────────────────────┤
│  Manager Nodes (Raft consensus)             │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│  │manager-1│ │manager-2│ │manager-3│       │
│  │ Leader  │ │Reachable│ │Reachable│       │
│  │Portainer│ │         │ │         │       │
│  └─────────┘ └─────────┘ └─────────┘       │
│       ↓           ↓           ↓             │
├─────────────────────────────────────────────┤
│  Worker Nodes (Services)                    │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐       │
│  │worker-1 │ │worker-2 │ │worker-3 │       │
│  │ Engine  │ │ Engine  │ │ Engine  │       │
│  └─────────┘ └─────────┘ └─────────┘       │
└─────────────────────────────────────────────┘
```

**HA Properties:**
- 3 manager nodes = Raft quorum (tolerate 1 failure)
- Automatic leader election
- Portainer UI on manager-1 (ports 9443, 9000, 8000)

### Network Topology

- **Host Network**: macOS host machine
- **Multipass Network**: Virtual bridge (192.168.64.0/24 typical)
- **VM-to-VM**: Direct communication within Multipass network
- **Host-to-VM**: Direct access via VM IP addresses
- **External Access**: VMs have internet access via NAT

---

## Project Status

### ✅ Complete (Current Phase)

- Multi-cluster infrastructure management (K3s, Docker Swarm, Minikube)
- K3s HA cluster initialization with embedded etcd
- Kubeconfig export and local kubectl access
- Docker Swarm with Portainer UI
- NFS shared storage for Swarm
- Comprehensive CLI with lifecycle management
- Cloud-init automation for all cluster types

### 🚧 In Progress / Planned

Per [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md), the next phases include:

**Phase 2 - Local Development Environment:**
- [ ] MariaDB deployment in K3s cluster
- [ ] Persistent storage configuration
- [ ] Database initialization scripts
- [ ] Namespace and ingress setup

**Phase 3 - AI Agent Implementation:**
- [ ] LangGraph orchestration framework
- [ ] CrewAI specialized workers
- [ ] Claude API integration
- [ ] Four agent roles: Infrastructure, Website, QA/Security, Supervisor

**Phase 4 - Production Infrastructure:**
- [ ] Terraform for AWS ECS Fargate
- [ ] RDS MariaDB configuration
- [ ] SQS queue setup
- [ ] CI/CD pipeline

### Known Limitations

- **MariaDB**: Not yet integrated (planned for separate deployment repo)
- **Ingress Controller**: Not pre-installed (install manually if needed)
- **Monitoring**: No built-in Prometheus/Grafana (add via manifests)
- **Service Mesh**: No Istio/Linkerd (manual installation required)
- **Registry**: No private registry (use public or add Harbor)

---

## Documentation

### Reference Guides

Comprehensive cheat sheets in the [`docs/`](docs/) folder:

- [**Multipass Cheat Sheet**](docs/multipass-cheat-sheet.md) - VM management, networking, cloud-init
- [**Docker Cheat Sheet**](docs/docker-cheat-sheet.md) - Container and compose operations
- [**Docker Swarm Cheat Sheet**](docs/docker-swarm-cheat-sheet.md) - Swarm cluster management
- [**Ubuntu Cheat Sheet**](docs/ubuntu-cheat-sheet.md) - Linux CLI reference

### Planning Documents

- [**Target Repository Structure**](docs/target-repo-structure.md) - Future directory layout
- [**PROJECT_CONTEXT.md**](PROJECT_CONTEXT.md) - AI agent portfolio project context

### Additional Resources

For specific operations, see the built-in help:
```bash
./scripts/multipass.sh help
```

---

## Related Repositories

This repository is part of the larger **AbD Training** ecosystem:

- **abd-databases** - Database configurations (MySQL, MariaDB, PostgreSQL)
- **abd-monitoring** - Prometheus, Grafana, PMM monitoring stacks
- **abd-web-platforms** - Web platform hosting and applications
- **abd-ai-agents** - LangGraph and CrewAI agent implementations
- **abd-go-services** - Go microservices
- **abd-python-services** - Python microservices
- **local-setup** - Local development tools (MySQL, Portainer, ProxySQL, Vault)

All repos share common patterns for Docker, Kubernetes, and Helm deployments.

---

## Troubleshooting

### Common Issues

**Problem: VMs fail to start**
```bash
# Check Multipass daemon
multipass version

# Restart Multipass service
sudo launchctl unload /Library/LaunchDaemons/com.canonical.multipassd.plist
sudo launchctl load /Library/LaunchDaemons/com.canonical.multipassd.plist
```

**Problem: K3s nodes not joining cluster**
```bash
# Check first server status
./scripts/multipass.sh exec manager-1 sudo systemctl status k3s

# Verify token
./scripts/multipass.sh exec manager-1 sudo cat /var/lib/rancher/k3s/server/node-token

# Check firewall (K3s requires port 6443)
./scripts/multipass.sh exec manager-1 sudo ufw status
```

**Problem: kubectl cannot connect**
```bash
# Verify kubeconfig
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl config view

# Test connectivity
./scripts/multipass.sh ips  # Get manager-1 IP
curl -k https://<manager-1-IP>:6443
```

**Problem: Running out of disk space**
```bash
# Increase disk size (before creation)
DISK_PER_NODE=100G ./scripts/multipass.sh create

# Or resize existing VM
multipass stop manager-1
multipass set local.manager-1.disk=100G
multipass start manager-1
```

### Resource Optimization

For laptops with limited resources:

```bash
# Minimal K3s cluster (1 server + 2 agents)
MANAGER_COUNT=1 WORKER_COUNT=2 \
CPUS_PER_NODE=1 RAM_PER_NODE=2G \
./scripts/multipass.sh create

# Single-node development
MANAGER_COUNT=1 WORKER_COUNT=0 \
./scripts/multipass.sh create
```

---

## Contributing

This is a personal project for the AbD Training platform, but suggestions and improvements are welcome via issues.

---

## License

GPL-3.0 - See [LICENSE](LICENSE) file for details.

---

## Quick Reference Card

### Essential Commands

```bash
# CREATE CLUSTER
./scripts/multipass.sh create
./scripts/multipass.sh k3s-setup
./scripts/multipass.sh k3s-kubeconfig

# USE CLUSTER
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes

# MANAGE CLUSTER
./scripts/multipass.sh list              # Show all nodes
./scripts/multipass.sh ips               # Show IPs
./scripts/multipass.sh stop all          # Stop cluster
./scripts/multipass.sh start all         # Start cluster
./scripts/multipass.sh delete            # Delete cluster

# ACCESS NODES
./scripts/multipass.sh shell manager-1   # SSH to node
./scripts/multipass.sh info worker-1     # Node details

# SWITCH CLUSTER TYPES
CLUSTER_TYPE=docker ./scripts/multipass.sh create   # Swarm
CLUSTER_TYPE=minikube ./scripts/multipass.sh create # K8s
CLUSTER_TYPE=k3s ./scripts/multipass.sh create      # K3s (default)
```

### Resource Tuning

```bash
# Light (3 nodes, 6 CPUs, 6GB RAM)
MANAGER_COUNT=1 WORKER_COUNT=2 CPUS_PER_NODE=1 RAM_PER_NODE=2G

# Default (6 nodes, 12 CPUs, 24GB RAM)
# Uses defaults, no env vars needed

# Heavy (6 nodes, 24 CPUs, 48GB RAM)
CPUS_PER_NODE=4 RAM_PER_NODE=8G DISK_PER_NODE=100G
```

---

**Built with ❤️ for local Kubernetes development and AI-driven infrastructure**

**Website**: https://abd.training/
