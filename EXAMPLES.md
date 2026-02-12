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

### Scenario 1: Local K3s Development Cluster

**Goal:** Create a K3s cluster for local Kubernetes development.

```bash
cd scripts

# Create and initialize cluster
./multipass.sh create
./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

# Use cluster
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes

# Deploy application
kubectl create deployment hello --image=nginxdemos/hello
kubectl expose deployment hello --port=80 --type=NodePort

# Access application
NODE_PORT=$(kubectl get svc hello -o jsonpath='{.spec.ports[0].nodePort}')
MANAGER_IP=$(multipass info manager-1 | grep IPv4 | awk '{print $2}')
curl http://$MANAGER_IP:$NODE_PORT
```

**Cleanup:**

```bash

./multipass.sh --destroy
```

---

### Scenario 2: Docker Swarm for Container Training

**Goal:** Create Docker Swarm cluster for learning container orchestration.

```bash
cd scripts

# Create Swarm cluster
CLUSTER_TYPE=docker ./multipass.sh create

# Initialize Swarm
./multipass.sh exec manager-1 "sudo docker swarm init --advertise-addr \$(hostname -I | awk '{print \$1}')"

# Get join tokens
MANAGER_TOKEN=$(./multipass.sh exec manager-1 "sudo docker swarm join-token manager -q")
WORKER_TOKEN=$(./multipass.sh exec manager-1 "sudo docker swarm join-token worker -q")
MANAGER_IP=$(multipass info manager-1 | grep IPv4 | awk '{print $2}')

# Join additional managers
./multipass.sh exec manager-2 "sudo docker swarm join --token $MANAGER_TOKEN $MANAGER_IP:2377"
./multipass.sh exec manager-3 "sudo docker swarm join --token $MANAGER_TOKEN $MANAGER_IP:2377"

# Join workers
./multipass.sh exec worker-1 "sudo docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377"
./multipass.sh exec worker-2 "sudo docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377"

# Verify cluster
./multipass.sh exec manager-1 "sudo docker node ls"

# Deploy service
./multipass.sh exec manager-1 "sudo docker service create --name web --replicas 5 -p 8080:80 nginx"

# Access service
curl http://$MANAGER_IP:8080
```

**Cleanup:**

```bash
./multipass.sh --destroy
```

---

## K3s Scenarios

### Scenario 3: Minimal K3s Cluster (Resource Constrained)

**Goal:** Create smallest possible K3s cluster for testing.

```bash
cd scripts

# Single node cluster
MANAGER_COUNT=1 \
WORKER_COUNT=0 \
CPUS_PER_NODE=2 \
RAM_PER_NODE=4G \
./multipass.sh create

./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes
```

**Resources Used:** 2 CPUs, 4GB RAM

---

### Scenario 4: High-Availability K3s Production Simulation

**Goal:** Create production-like HA K3s cluster.

```bash
cd scripts

# 5 servers, 5 agents, high resources
MANAGER_COUNT=5 \
WORKER_COUNT=5 \
CPUS_PER_NODE=4 \
RAM_PER_NODE=8G \
DISK_PER_NODE=100G \
./multipass.sh create

./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

export KUBECONFIG=~/.kube/k3s-multipass-config

# Verify HA etcd cluster
kubectl -n kube-system get pods | grep etcd

# Test node failure tolerance
multipass stop manager-1

# Cluster should still be functional with 4/5 servers
kubectl get nodes
```

**Resources Used:** 40 CPUs, 80GB RAM

---

### Scenario 5: Deploy Helm Chart on K3s

**Goal:** Use Helm to deploy applications.

```bash
cd scripts

# Create cluster
./multipass.sh create
./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

export KUBECONFIG=~/.kube/k3s-multipass-config

# Install Helm (if not installed)
brew install helm  # macOS

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
cd scripts

# Create cluster
CLUSTER_TYPE=docker ./multipass.sh create

# Initialize Swarm (abbreviated - see Scenario 2 for full steps)
# ... swarm init and join ...

# Deploy visualizer
./multipass.sh exec manager-1 "sudo docker service create \
  --name viz \
  --publish 8080:8080 \
  --constraint node.role==manager \
  --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
  dockersamples/visualizer"

# Access visualizer
MANAGER_IP=$(multipass info manager-1 | grep IPv4 | awk '{print $2}')
open http://$MANAGER_IP:8080
```

---

## Multi-Cluster Scenarios

### Scenario 7: K3s Development + Staging Environments

**Goal:** Run separate dev and staging K3s clusters.

```bash
cd scripts

# Development cluster (lightweight)
NODE_PREFIX=dev- \
CPUS_PER_NODE=2 \
RAM_PER_NODE=4G \
./multipass.sh create

NODE_PREFIX=dev- ./multipass.sh k3s-setup
NODE_PREFIX=dev- ./multipass.sh k3s-kubeconfig

# Staging cluster (production-like)
NODE_PREFIX=staging- \
CPUS_PER_NODE=4 \
RAM_PER_NODE=8G \
./multipass.sh create

NODE_PREFIX=staging- ./multipass.sh k3s-setup
NODE_PREFIX=staging- ./multipass.sh k3s-kubeconfig

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
cd scripts

# Create K3s cluster
NODE_PREFIX=k3s- CLUSTER_TYPE=k3s ./multipass.sh create
NODE_PREFIX=k3s- ./multipass.sh k3s-setup
NODE_PREFIX=k3s- ./multipass.sh k3s-kubeconfig

# Create Docker Swarm cluster
NODE_PREFIX=swarm- CLUSTER_TYPE=docker ./multipass.sh create
# ... initialize swarm ...

# List everything
multipass list
# Shows: k3s-manager-1, k3s-manager-2, ..., swarm-manager-1, swarm-manager-2, ...

# Work with K3s
export KUBECONFIG=~/.kube/k3s-k3s-multipass-config
kubectl get nodes

# Work with Swarm
./multipass.sh shell swarm-manager-1
sudo docker node ls
```

**Total Resources:** 30 CPUs, 60GB RAM (5 nodes × 2 clusters)

---

## Development Workflows

### Scenario 9: Application Development with Live Reload

**Goal:** Develop application with automatic deployment to K3s.

```bash
cd scripts

# Create cluster
./multipass.sh create
./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

export KUBECONFIG=~/.kube/k3s-multipass-config

# Install skaffold (for live reload)
brew install skaffold  # macOS

# In your app directory with skaffold.yaml
skaffold dev
# Now changes to code automatically redeploy to cluster
```

---

### Scenario 10: CI/CD Pipeline Testing

**Goal:** Test CI/CD pipelines locally before cloud deployment.

```bash
cd scripts

# Create production-like cluster
CPUS_PER_NODE=4 RAM_PER_NODE=8G ./multipass.sh create
./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

export KUBECONFIG=~/.kube/k3s-multipass-config

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
cd scripts

# Create simple cluster
MANAGER_COUNT=1 \
WORKER_COUNT=2 \
./multipass.sh create

./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

export KUBECONFIG=~/.kube/k3s-multipass-config

# Pre-load common images
kubectl create deployment nginx --image=nginx
kubectl create deployment redis --image=redis
kubectl delete deployment nginx redis

# Setup is ready for students
kubectl get nodes
```

---

### Scenario 12: High-Availability Training

**Goal:** Demonstrate HA concepts with failover.

```bash
cd scripts

# Create HA cluster
MANAGER_COUNT=3 WORKER_COUNT=2 ./multipass.sh create
./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

export KUBECONFIG=~/.kube/k3s-multipass-config

# Deploy demo application
kubectl create deployment demo --image=nginx --replicas=5
kubectl expose deployment demo --port=80 --type=NodePort

# Simulate node failure
multipass stop manager-1

# Show cluster still operational
kubectl get nodes
kubectl get pods

# Recover node
multipass start manager-1

# Show node rejoins
watch kubectl get nodes
```

---

### Scenario 13: Multi-Cluster Training Environment

**Goal:** Setup for teaching multi-cluster management.

```bash
cd scripts

# Cluster 1 - Production
NODE_PREFIX=prod- CPUS_PER_NODE=4 RAM_PER_NODE=8G ./multipass.sh create
NODE_PREFIX=prod- ./multipass.sh k3s-setup
NODE_PREFIX=prod- ./multipass.sh k3s-kubeconfig

# Cluster 2 - Staging
NODE_PREFIX=staging- CPUS_PER_NODE=3 RAM_PER_NODE=6G ./multipass.sh create
NODE_PREFIX=staging- ./multipass.sh k3s-setup
NODE_PREFIX=staging- ./multipass.sh k3s-kubeconfig

# Cluster 3 - Development
NODE_PREFIX=dev- CPUS_PER_NODE=2 RAM_PER_NODE=4G ./multipass.sh create
NODE_PREFIX=dev- ./multipass.sh k3s-setup
NODE_PREFIX=dev- ./multipass.sh k3s-kubeconfig

# Setup kubectx for easy switching
brew install kubectx  # macOS

# Rename contexts for clarity
kubectl config rename-context default prod
kubectl config rename-context default staging --kubeconfig ~/.kube/staging-k3s-multipass-config
kubectl config rename-context default dev --kubeconfig ~/.kube/dev-k3s-multipass-config

# Merge configs
KUBECONFIG=~/.kube/k3s-multipass-config:~/.kube/staging-k3s-multipass-config:~/.kube/dev-k3s-multipass-config \
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
cd scripts

# Create cluster
./multipass.sh create
./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

export KUBECONFIG=~/.kube/k3s-multipass-config

# Check current version
kubectl version --short

# Upgrade manager-1
./multipass.sh exec manager-1 "sudo systemctl stop k3s && \
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
cd scripts

# Create cluster
./multipass.sh create
./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

export KUBECONFIG=~/.kube/k3s-multipass-config

# Deploy applications
kubectl create namespace production
kubectl create deployment app -n production --image=nginx

# Create etcd snapshot
./multipass.sh exec manager-1 "sudo k3s etcd-snapshot save --name disaster-recovery"

# List snapshots
./multipass.sh exec manager-1 "sudo k3s etcd-snapshot ls"

# Simulate disaster - delete everything
./multipass.sh --destroy

# Recreate cluster
./multipass.sh create

# Restore from snapshot
# (copy snapshot to new cluster and restore)
# ... restore procedure ...
```

---

## Cleanup Commands

### Clean Up Specific Cluster

```bash
# With prefix
NODE_PREFIX=dev- ./multipass.sh --destroy
NODE_PREFIX=staging- ./multipass.sh --destroy
```

### Clean Up Everything

```bash
# All clusters created by script
./multipass.sh --destroy

# Nuclear option (all multipass VMs)
multipass delete --all --purge
```

---

For detailed usage instructions, see [USAGE.md](USAGE.md)

For troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
