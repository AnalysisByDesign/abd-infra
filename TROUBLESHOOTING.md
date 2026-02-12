# Troubleshooting Guide

Common issues and solutions for abd-infra cluster management.

---

## Table of Contents

- [Installation Issues](#installation-issues)
- [Node Creation Issues](#node-creation-issues)
- [K3s Cluster Issues](#k3s-cluster-issues)
- [Docker Swarm Issues](#docker-swarm-issues)
- [Resource Issues](#resource-issues)
- [Network Issues](#network-issues)
- [General Issues](#general-issues)

---

## Installation Issues

### Multipass Not Found

**Problem:** `multipass: command not found`

**Solution:**

```bash
# macOS
brew install multipass

# Linux
sudo snap install multipass

# Verify installation
multipass version
```

---

### Script Permission Denied

**Problem:** `Permission denied: ./multipass.sh`

**Solution:**

```bash
chmod +x scripts/multipass.sh
```

---

## Node Creation Issues

### Insufficient Resources

**Problem:** `Not enough memory/CPU available`

**Solution:**

Reduce cluster size or node resources:

```bash
# Minimal cluster
MANAGER_COUNT=1 \
WORKER_COUNT=1 \
CPUS_PER_NODE=2 \
RAM_PER_NODE=4G \
./multipass.sh create
```

Or close other applications to free resources.

---

### Cloud-Init File Not Found

**Problem:** `Cloud-init file does not exist`

**Solution:**

Ensure you're running from correct directory:

```bash
cd /path/to/abd-infra/scripts
./multipass.sh create
```

Cloud-init files should be in `../config/multipass/`

---

### Node Already Exists

**Problem:** `Node manager-1 already exists, skipping...`

**Solution:**

Destroy existing nodes first:

```bash
./multipass.sh --destroy
# Then recreate
./multipass.sh create
```

---

### Wrong Resources Applied

**Problem:** Nodes have 1 CPU and 1GB RAM instead of configured values

**Cause:** Bug fixed in latest version - `multipass launch` wasn't using CPU/RAM parameters

**Solution:**

Update to latest version of multipass.sh, then recreate:

```bash
./multipass.sh --destroy
./multipass.sh create
```

Verify resources:

```bash
multipass info manager-1 | grep -E "CPU|Memory"
```

---

## K3s Cluster Issues

### K3s Setup Hangs

**Problem:** `k3s-setup` command hangs indefinitely

**Symptoms:**

- Script prints "Waiting for K3s to start..." and never continues
- Process stuck for >5 minutes

**Common Causes:**

1. **Output redirection issue** (fixed in latest version)
   - `multipass exec ... > /dev/null` causes SSH hang on macOS

2. **Insufficient resources**
   - K3s needs minimum 2 CPU, 4GB RAM per server node

**Solution:**

Kill hung process:

```bash
# Find hung process
ps -ef | grep "multipass exec"

# Kill it
kill <PID>

# Update to latest script (has fix)
# Then destroy and recreate
./multipass.sh --destroy
./multipass.sh create
./multipass.sh k3s-setup
```

---

### K3s Service Failed

**Problem:** `K3s service is not active`

**Diagnosis:**

```bash
# Check service status
./multipass.sh exec manager-1 "sudo systemctl status k3s"

# Check logs
./multipass.sh exec manager-1 "sudo journalctl -xeu k3s.service -n 50"
```

**Common Errors:**

#### Error: "etcd disabled"

**Cause:** First server installed without `--cluster-init` flag

**Solution:**

Update to latest script (includes `--cluster-init`), destroy and recreate:

```bash
./multipass.sh --destroy
./multipass.sh create
./multipass.sh k3s-setup
```

#### Error: "Failed to connect to manager-1:6443"

**Cause:** API server not ready or network issue

**Solution:**

Wait longer, or check connectivity:

```bash
# Get manager-1 IP
MANAGER_IP=$(multipass info manager-1 | grep IPv4 | awk '{print $2}')

# Test connectivity
curl -k https://$MANAGER_IP:6443/ping
```

---

### Additional Servers Won't Join

**Problem:** manager-2 or manager-3 fails to join cluster

**Diagnosis:**

```bash
# Check logs on failing node
./multipass.sh exec manager-2 "sudo journalctl -xeu k3s.service -n 50"
```

**Common Issues:**

1. **Token not retrieved**
   - Ensure manager-1 is fully initialized before joining others

2. **Network connectivity**
   - Test: `./multipass.sh exec manager-2 "ping manager-1"`

3. **Wrong join command**
   - Should use: `K3S_URL=https://MANAGER_IP:6443 K3S_TOKEN=xxx sh -s - server`

---

### Kubeconfig Export Fails

**Problem:** `k3s-kubeconfig` fails or kubectl doesn't work

**Solution:**

```bash
# Manually export kubeconfig
multipass exec manager-1 -- sudo cat /etc/rancher/k3s/k3s.yaml > ~/.kube/k3s-multipass-config

# Get manager-1 IP
MANAGER_IP=$(multipass info manager-1 | grep IPv4 | awk '{print $2}')

# Update kubeconfig server address
sed -i '' "s/127.0.0.1/$MANAGER_IP/g" ~/.kube/k3s-multipass-config

# Use it
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes
```

---

## Docker Swarm Issues

### Swarm Init Fails

**Problem:** `docker swarm init` returns error

**Common Issues:**

1. **Multiple network interfaces**

```bash
# Specify advertise address explicitly
sudo docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
```

2. **Docker not running**

```bash
sudo systemctl status docker
sudo systemctl start docker
```

---

### Workers Can't Join

**Problem:** Worker nodes fail to join swarm

**Solution:**

```bash
# On manager-1, get correct join command
sudo docker swarm join-token worker

# Ensure you're using manager-1's IP (not localhost)
MANAGER_IP=$(multipass info manager-1 | grep IPv4 | awk '{print $2}')

# On worker, join with correct IP
sudo docker swarm join --token <TOKEN> $MANAGER_IP:2377
```

---

## Resource Issues

### Out of Memory

**Problem:** Host system runs out of RAM

**Symptoms:**

- VMs become unresponsive
- Multipass commands hang
- System slowdown

**Solution:**

Reduce cluster size:

```bash
# Stop unused clusters
NODE_PREFIX=old- ./multipass.sh stop all

# Or destroy
NODE_PREFIX=old- ./multipass.sh --destroy

# Create smaller cluster
MANAGER_COUNT=1 \
WORKER_COUNT=1 \
RAM_PER_NODE=4G \
./multipass.sh create
```

---

### Out of Disk Space

**Problem:** Not enough disk space for VM images

**Solution:**

```bash
# Check VM disk usage
multipass exec manager-1 -- df -h

# Clean up Docker images (if using Docker Swarm)
./multipass.sh exec manager-1 "sudo docker system prune -af"

# Destroy unused clusters
multipass list
NODE_PREFIX=unused- ./multipass.sh --destroy

# Or reduce disk per node
DISK_PER_NODE=20G ./multipass.sh create
```

---

### High CPU Usage

**Problem:** Multipass VMs consuming too much CPU

**Solution:**

```bash
# Reduce CPU allocation
CPUS_PER_NODE=2 ./multipass.sh create

# Or limit running clusters
./multipass.sh stop workers  # Stop workers, keep managers
```

---

## Network Issues

### Can't Access Services

**Problem:** Can't reach services deployed in cluster

**Diagnosis:**

```bash
# Get service NodePort
kubectl get svc

# Get node IP
MANAGER_IP=$(multipass info manager-1 | grep IPv4 | awk '{print $2}')

# Test connectivity
curl http://$MANAGER_IP:<NODE_PORT>
```

**Common Issues:**

1. **Wrong IP** - Use multipass node IP, not localhost
2. **Wrong port** - Use NodePort, not ClusterIP port
3. **Firewall** - Check host firewall rules

---

### Nodes Can't Communicate

**Problem:** Nodes can't ping each other

**Solution:**

```bash
# Verify multipass network
multipass list  # Check IPs are in same subnet

# Test from one node to another
./multipass.sh exec manager-1 "ping worker-1"

# Restart multipass if needed
sudo systemctl restart snap.multipass.multipassd  # Linux
```

---

## General Issues

### Multipass Commands Hang

**Problem:** `multipass exec` hangs indefinitely

**Cause:** Known issue with output redirection or unresponsive VM

**Solution:**

```bash
# Check VM is running
multipass list

# Restart VM
multipass restart manager-1

# If still hangs, stop and start
multipass stop manager-1
multipass start manager-1

# Last resort: delete and recreate
./multipass.sh --destroy
./multipass.sh create
```

**Prevention:**

Latest script version avoids problematic `> /dev/null` redirections.

---

### Node Becomes Unresponsive

**Problem:** VM stops responding to commands

**Symptoms:**

- `multipass exec` hangs
- High CPU usage on node
- K3s installation stuck

**Solution:**

```bash
# Restart node
multipass restart manager-1

# Check if it's a resource issue
multipass info manager-1

# If 1 CPU / 1GB RAM, recreate with more resources
./multipass.sh --destroy
CPUS_PER_NODE=4 RAM_PER_NODE=8G ./multipass.sh create
```

---

### Script Returns Wrong Exit Code

**Problem:** Script fails but doesn't show error

**Solution:**

Run with verbose logging:

```bash
bash -x ./multipass.sh create
```

Check specific step manually:

```bash
# Test node creation manually
multipass launch --name test --cpus 3 --memory 6G --disk 40G --cloud-init ../config/multipass/cloud-init.k3s.yaml 24.04
```

---

### Multiple Clusters Conflict

**Problem:** Commands affect wrong cluster

**Cause:** Not using NODE_PREFIX correctly

**Solution:**

Always specify prefix when managing specific cluster:

```bash
# Create
NODE_PREFIX=k3s- ./multipass.sh create

# Setup
NODE_PREFIX=k3s- ./multipass.sh k3s-setup

# Destroy
NODE_PREFIX=k3s- ./multipass.sh --destroy

# List what exists
multipass list
```

---

## Diagnostic Commands

### Check System Resources

```bash
# Available RAM
free -h  # Linux
vm_stat  # macOS

# Available disk
df -h

# CPU cores
nproc  # Linux
sysctl -n hw.ncpu  # macOS
```

---

### Check Multipass Status

```bash
# List all VMs
multipass list

# Detailed info
multipass info manager-1

# Get all IPs
multipass list | grep -E "manager|worker" | awk '{print $1, $3}'
```

---

### Check K3s Status

```bash
# Service status
./multipass.sh exec manager-1 "sudo systemctl status k3s"

# Logs
./multipass.sh exec manager-1 "sudo journalctl -xeu k3s.service -n 100"

# Cluster status
./multipass.sh exec manager-1 "sudo k3s kubectl get nodes"
./multipass.sh exec manager-1 "sudo k3s kubectl get pods -A"
```

---

### Check Docker Swarm Status

```bash
# Node list
./multipass.sh exec manager-1 "sudo docker node ls"

# Service list
./multipass.sh exec manager-1 "sudo docker service ls"

# Inspect node
./multipass.sh exec manager-1 "sudo docker node inspect manager-1"
```

---

## Getting Help

If you're still stuck:

1. Check script version is latest
2. Review [USAGE.md](USAGE.md) for correct syntax
3. Check [EXAMPLES.md](EXAMPLES.md) for similar scenario
4. Check logs: `./multipass.sh exec <node> "sudo journalctl -xeu <service>"`
5. Try minimal cluster to isolate issue
6. Destroy and recreate with verbose logging: `bash -x ./multipass.sh create`

---

## Common Error Messages

### "First server node does not exist"

**Cause:** Trying to run k3s-setup before creating nodes

**Solution:**

```bash
./multipass.sh create
./multipass.sh k3s-setup
```

---

### "Node token is empty"

**Cause:** K3s not fully initialized on manager-1

**Solution:**

Wait longer, or check manager-1 status:

```bash
./multipass.sh exec manager-1 "sudo systemctl status k3s"
./multipass.sh exec manager-1 "sudo cat /var/lib/rancher/k3s/server/node-token"
```

---

### "Cloud-init file does not exist"

**Cause:** Running script from wrong directory

**Solution:**

```bash
cd /path/to/abd-infra/scripts
./multipass.sh create
```

---

## Reset Everything

When all else fails:

```bash
# Nuclear option - delete ALL multipass VMs
multipass delete --all
multipass purge

# Verify clean state
multipass list

# Start fresh
cd /path/to/abd-infra/scripts
./multipass.sh create
./multipass.sh k3s-setup
```

---

For usage instructions, see [USAGE.md](USAGE.md)

For examples, see [EXAMPLES.md](EXAMPLES.md)
