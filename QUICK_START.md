# K3s Cluster Quick Start

## Delete Existing Cluster (if any)

```bash
cd /Users/dave/Documents/Projects/abd-training/abd-infra/scripts
./multipass.sh --destroy
```

## Create K3s Cluster with Proper Resources

### Option 1: Use Script Defaults (3 CPU, 6GB RAM)

```bash
./multipass.sh --type k3s --managers 3 --workers 2
```

### Option 2: Increase Resources for Better Performance (RECOMMENDED)

```bash
CPUS_PER_NODE=4 RAM_PER_NODE=8G ./multipass.sh --type k3s --managers 3 --workers 2
```

## Verify Node Resources

After creation, verify each node has correct resources:

```bash
# Check all nodes
for node in manager-1 manager-2 manager-3 worker-1 worker-2; do
  echo "=== $node ==="
  multipass info $node | grep -E "CPU|Memory"
done
```

Expected output:

```
=== manager-1 ===
CPU(s):         4
Memory usage:   XXX.XMiB out of 7.7GiB
```

## Why These Resources?

**Minimum for K3s:**

- Server nodes (managers): 2 CPU, 4GB RAM
- Agent nodes (workers): 1 CPU, 2GB RAM

**Recommended (to avoid hangs):**

- All nodes: 4 CPU, 8GB RAM
- Provides headroom for K3s, etcd, and workloads

## Troubleshooting

### Problem: Nodes have only 1 CPU and 1GB RAM

**Cause:** Nodes were created without proper resource parameters

**Solution:** Delete and recreate with correct parameters:

```bash
./multipass.sh --destroy
CPUS_PER_NODE=4 RAM_PER_NODE=8G ./multipass.sh --type k3s --managers 3 --workers 2
```

### Problem: K3s installation hangs or fails

**Cause:** Insufficient resources (CPU/RAM)

**Solution:** Increase CPUS_PER_NODE and RAM_PER_NODE before creation

## Access Cluster

After successful creation:

```bash
# Get kubeconfig
export KUBECONFIG=~/.kube/k3s-cluster-config

# Verify cluster
kubectl get nodes
kubectl get pods -A
```

## Next Steps

1. Verify cluster health: `kubectl get nodes`
2. Deploy workloads: `kubectl apply -f your-app.yaml`
3. Monitor: `kubectl top nodes` (requires metrics-server)
