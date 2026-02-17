# Examples

Common scenarios and workflows for abd-infra cluster management.

---

## Table of Contents

- [Quick Start Examples](#quick-start-examples)
- [K3s Scenarios](#k3s-scenarios)
- [Docker Swarm Scenarios](#docker-swarm-scenarios)
- [Multi-Cluster Scenarios](#multi-cluster-scenarios)
- [Development Workflows](#development-workflows)
- [Training Lab Setups](#training-lab-setups)

---

## Quick Start Examples

Install the following tools and utilities;

- Helm
- skaffold (for live reload)
- kubectx for easy switching

``` bash
brew install helm skaffold kubectx # MacOS
```

### Scenario 1: Local K3s Development Cluster

**Goal:** Create a K3s cluster for local Kubernetes development.

```bash
# Create and initialize cluster
export NODE_PREFIX=k3s MANAGER_COUNT=1 WORKER_COUNT=2
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

# Use cluster
export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config
kubectl get nodes

# Deploy application
kubectl create deployment hello --image=nginxdemos/hello
kubectl expose deployment hello --port=80 --type=NodePort

# Access application
NODE_PORT=$(kubectl get svc hello -o jsonpath='{.spec.ports[0].nodePort}')
MANAGER_IP=$(multipass info ${NODE_PREFIX}-manager-1 | grep IPv4 | awk '{print $2}')
echo http://$MANAGER_IP:$NODE_PORT
```

**Cleanup:**

```bash

./scripts/multipass.sh delete
```

---

### Scenario 2: Docker Swarm for Container Training

**Goal:** Create Docker Swarm cluster for learning container orchestration.

```bash
# Create Swarm cluster
export NODE_PREFIX=dck CLUSTER_TYPE=docker MANAGER_COUNT=3 WORKER_COUNT=3
./scripts/multipass.sh create

# Initialize Swarm
MANAGER_IP=$(multipass info ${NODE_PREFIX}-manager-1 | grep IPv4 | awk '{print $2}')
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker swarm init --advertise-addr ${MANAGER_IP}"

# Get join tokens
MANAGER_TOKEN=$(./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker swarm join-token manager -q")
WORKER_TOKEN=$(./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker swarm join-token worker -q")

# Join additional managers
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-2 "sudo docker swarm join --token $MANAGER_TOKEN $MANAGER_IP:2377"
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-3 "sudo docker swarm join --token $MANAGER_TOKEN $MANAGER_IP:2377"

# Join workers
./scripts/multipass.sh exec ${NODE_PREFIX}-worker-1 "sudo docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377"
./scripts/multipass.sh exec ${NODE_PREFIX}-worker-2 "sudo docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377"

# Verify cluster
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker node ls"

# Deploy service
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker service create --name web --replicas 5 -p 8080:80 nginx"

# Access service
echo http://$MANAGER_IP:8080
```

**Cleanup:**

```bash
./scripts/multipass.sh delete
```

---

## K3s Scenarios

### Scenario 3: Minimal K3s Cluster (Resource Constrained)

**Goal:** Create smallest possible K3s cluster for testing.

```bash
# Single node cluster
export NODE_PREFIX=k3s MANAGER_COUNT=1 WORKER_COUNT=0 CPUS_PER_NODE=2 RAM_PER_NODE=4G
./scripts/multipass.sh create

./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config
kubectl get nodes
```

**Resources Used:** 2 CPUs, 4GB RAM

---

### Scenario 4: High-Availability K3s Production Simulation

**Goal:** Create production-like HA K3s cluster.

```bash
# 5 servers, 5 agents, high resources
export NODE_PREFIX=k3s MANAGER_COUNT=5 WORKER_COUNT=5 CPUS_PER_NODE=4 RAM_PER_NODE=8G DISK_PER_NODE=100G
./scripts/multipass.sh create

./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config

# Verify HA etcd cluster
kubectl -n kube-system get pods | grep etcd

# Test node failure tolerance
multipass stop ${NODE_PREFIX}-manager-1

# Cluster should still be functional with 4/5 servers
kubectl get nodes
```

**Resources Used:** 40 CPUs, 80GB RAM

---

### Scenario 5: Deploy Helm Chart on K3s

**Goal:** Use Helm to deploy applications.

```bash
# Create cluster
export NODE_PREFIX=k3s
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config

# Add repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install application
helm install my-release bitnami/nginx

# Check deployment
kubectl get all

# Access application
kubectl port-forward svc/my-release-nginx 8080:80
# Open http://localhost:8080
```

---

## Docker Swarm Scenarios

### Scenario 6: Docker Swarm with Visualizer

**Goal:** Deploy Swarm cluster with visualization tool.

```bash
# Create cluster
export NODE_PREFIX=dck CLUSTER_TYPE=docker
./scripts/multipass.sh create

# Initialize Swarm (abbreviated - see Scenario 2 for full steps)
# ... swarm init and join ...

# Deploy visualizer
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo docker service create \
  --name viz \
  --publish 8080:8080 \
  --constraint node.role==manager \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  dockersamples/visualizer"

# Access visualizer
MANAGER_IP=$(multipass info ${NODE_PREFIX}-manager-1 | grep IPv4 | awk '{print $2}')
open http://$MANAGER_IP:8080
```

---

## Multi-Cluster Scenarios

### Scenario 7: K3s Development + Staging Environments

**Goal:** Run separate dev and staging K3s clusters.

```bash
# Development cluster (lightweight)
export NODE_PREFIX=dev
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

# Staging cluster (production-like)
export NODE_PREFIX=stage CPUS_PER_NODE=4 RAM_PER_NODE=8G
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

# List all clusters
multipass list

# Use development cluster
export KUBECONFIG=~/.kube/dev-k3s-multipass-config
kubectl get nodes

# Use staging cluster
export KUBECONFIG=~/.kube/staging-k3s-multipass-config
kubectl get nodes
```

---

### Scenario 8: K3s + Docker Swarm Side-by-Side

**Goal:** Learn both orchestrators simultaneously.

```bash
# Create K3s cluster
export NODE_PREFIX=k3s MANAGER_COUNT=1 WORKER_COUNT=2
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

# Create Docker Swarm cluster
export NODE_PREFIX=swarm CLUSTER_TYPE=docker MANAGER_COUNT=3 WORKER_COUNT=3
./scripts/multipass.sh create
# ... initialize swarm ...

# List everything
multipass list
# Shows: k3s-manager-1, k3s-manager-2, ..., swarm-manager-1, swarm-manager-2, ...

# Work with K3s
export KUBECONFIG=~/.kube/k3s-k3s-multipass-config
kubectl get nodes

# Work with Swarm
./scripts/multipass.sh shell swarm-manager-1
sudo docker node ls
```

**Total Resources:** 30 CPUs, 60GB RAM (5 nodes × 2 clusters)

---

## Development Workflows

### Scenario 9: Application Development with Live Reload

**Goal:** Develop application with automatic deployment to K3s.

```bash
# Create cluster
export NODE_PREFIX=k3s MANAGER_COUNT=1 WORKER_COUNT=2
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config

# In your app directory with skaffold.yaml
skaffold dev
# Now changes to code automatically redeploy to cluster
```

---

### Scenario 10: CI/CD Pipeline Testing

**Goal:** Test CI/CD pipelines locally before cloud deployment.

```bash
# Create production-like cluster
export NODE_PREFIX=k3s CPUS_PER_NODE=4 RAM_PER_NODE=8G
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config

# Deploy GitLab Runner
kubectl create namespace gitlab-runner
helm repo add gitlab https://charts.gitlab.io
helm install --namespace gitlab-runner gitlab-runner gitlab/gitlab-runner \
  --set gitlabUrl=https://gitlab.com/ \
  --set runnerRegistrationToken="YOUR_TOKEN"

# Test pipeline locally
git push
# Watch pipeline run on local cluster
```

---

## Training Lab Setups

### Scenario 11: Kubernetes Fundamentals Course

**Goal:** Setup for teaching Kubernetes basics.

```bash
# Create simple cluster
export NODE_PREFIX=k3s
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config

# Pre-load common images
kubectl create deployment nginx --image=nginx
kubectl create deployment redis --image=redis

# Setup is ready for students
kubectl get nodes

# Cleanup
kubectl delete deployment nginx redis
```

---

### Scenario 12: High-Availability Training

**Goal:** Demonstrate HA concepts with failover.

```bash
# Create HA cluster
export NODE_PREFIX=k3s MANAGER_COUNT=3 WORKER_COUNT=2
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config

# Deploy demo application
kubectl create deployment demo --image=nginx --replicas=5
kubectl expose deployment demo --port=80 --type=NodePort

# Simulate node failure
multipass stop ${NODE_PREFIX}-manager-1

# Show cluster still operational
kubectl get nodes
kubectl get pods

# Recover node
multipass start ${NODE_PREFIX}-manager-1

# Show node rejoins
watch kubectl get nodes
```

---

### Scenario 13: Multi-Cluster Training Environment

**Goal:** Setup for teaching multi-cluster management.

```bash
# Cluster 1 - Production
export NODE_PREFIX=prod CPUS_PER_NODE=4 RAM_PER_NODE=8G 
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

# Cluster 2 - Staging
export NODE_PREFIX=staging CPUS_PER_NODE=3 RAM_PER_NODE=8G 
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

# Cluster 3 - Development
export NODE_PREFIX=dev CPUS_PER_NODE=2 RAM_PER_NODE=4G 
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

# Rename contexts for clarity
kubectl config rename-context default prod --kubeconfig ~/.kube/prod-k3s-multipass-config
kubectl config rename-context default staging --kubeconfig ~/.kube/staging-k3s-multipass-config
kubectl config rename-context default dev --kubeconfig ~/.kube/dev-k3s-multipass-config

# Merge configs
KUBECONFIG=~/.kube/prod-k3s-multipass-config:~/.kube/staging-k3s-multipass-config:~/.kube/dev-k3s-multipass-config \
kubectl config view --flatten > ~/.kube/merged-config

export KUBECONFIG=~/.kube/merged-config

# Switch between clusters
kubectx prod
kubectl get nodes

kubectx staging
kubectl get nodes

kubectx dev
kubectl get nodes
```

---

## Advanced Scenarios

### Scenario 14: Cluster Upgrade Testing

**Goal:** Test K3s upgrade procedure.

```bash
# Create cluster
export NODE_PREFIX=k3s
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config

# Check current version
kubectl version --short

# Upgrade ${NODE_PREFIX}-manager-1
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo systemctl stop k3s && \
  curl -sfL https://get.k3s.io | sh -s - server --cluster-init && \
  sudo systemctl restart k3s"

# Wait and check
sleep 30
kubectl get nodes -o wide

# Upgrade remaining nodes one by one...
```

---

### Scenario 15: Disaster Recovery Simulation

**Goal:** Practice backup and restore.

```bash
# Create cluster
export NODE_PREFIX=k3s
./scripts/multipass.sh create
./scripts/k3s.sh setup
./scripts/k3s.sh kubeconfig

export KUBECONFIG=~/.kube/${NODE_PREFIX}-k3s-multipass-config

# Deploy applications
kubectl create namespace production
kubectl create deployment app -n production --image=nginx

# Create etcd snapshot
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo k3s etcd-snapshot save --name disaster-recovery"

# List snapshots
./scripts/multipass.sh exec ${NODE_PREFIX}-manager-1 "sudo k3s etcd-snapshot ls"

# Simulate disaster - delete everything
./scripts/multipass.sh delete

# Recreate cluster
./scripts/multipass.sh create

# Restore from snapshot
# (copy snapshot to new cluster and restore)
# ... restore procedure ...
```

---

## Cleanup Commands

### Clean Up Specific Cluster

```bash
# With prefix
NODE_PREFIX=dev ./scripts/multipass.sh delete
NODE_PREFIX=staging ./scripts/multipass.sh delete
```

### Clean Up Everything

```bash
# Reset all env variables
unset NODE_PREFIX MANAGER_COUNT WORKER_COUNT CLUSTER_TYPE CPUS_PER_NODE RAM_PER_NODE DISK_PER_NODE KUBECONFIG

# All clusters created by script
./scripts/multipass.sh delete

# Nuclear option (all multipass VMs)
multipass delete --all --purge
```

---

For detailed usage instructions, see [USAGE.md](USAGE.md)

For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
