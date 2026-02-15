# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Infrastructure-as-code for local multi-node clusters using Canonical Multipass VMs on macOS. Supports three cluster types: K3s (default), Docker Swarm, and Minikube. Part of the AbD Training ecosystem, with a goal of building AI-agent-managed infrastructure (see PROJECT_CONTEXT.md).

## Key Commands

All cluster operations go through the single entry point `./scripts/multipass.sh`:

```bash
# Full K3s workflow (create VMs, install K3s, export kubeconfig)
./scripts/multipass.sh create && ./scripts/multipass.sh k3s-setup && ./scripts/multipass.sh k3s-kubeconfig

# Lifecycle
./scripts/multipass.sh create          # Provision VMs with cloud-init
./scripts/multipass.sh delete          # Teardown (interactive confirmation)
./scripts/multipass.sh start [target]  # target: all|managers|workers|<node-name>
./scripts/multipass.sh stop [target]

# Cluster-specific
./scripts/multipass.sh k3s-setup       # Install K3s across nodes (HA with embedded etcd)
./scripts/multipass.sh k3s-kubeconfig  # Export to ~/.kube/k3s-multipass-config
./scripts/multipass.sh nfs-setup       # Docker Swarm: NFS + labels + demo service

# Node access
./scripts/multipass.sh shell <node>    # SSH into node
./scripts/multipass.sh exec <node> <cmd>
./scripts/multipass.sh ips             # List all node IPs
```

Switch cluster type and tune resources via env vars:

```bash
CLUSTER_TYPE=docker|minikube|k3s  MANAGER_COUNT=3  WORKER_COUNT=3
CPUS_PER_NODE=2  RAM_PER_NODE=4G  DISK_PER_NODE=40G
```

## Architecture

`scripts/multipass.sh` is a single bash script (~575 lines) that orchestrates everything. It:

1. Reads `CLUSTER_TYPE` to select the corresponding cloud-init file from `config/multipass/`
2. Creates Multipass VMs named `manager-{1..N}` and `worker-{1..N}`
3. For K3s: installs K3s on manager-1 first, then joins additional managers (HA server mode) and workers (agent mode) using the node token from manager-1
4. For Docker Swarm: VMs come pre-configured with Docker+Portainer via cloud-init; swarm init is manual
5. For Minikube: VMs come with Docker+kubectl+minikube; startup is manual

Cloud-init files (`config/multipass/cloud-init.*.yaml`) handle per-VM provisioning: package installation, Docker setup, network forwarding config. K3s installation itself is NOT in cloud-init — it's done by the `k3s_setup()` function so it can coordinate the multi-node join sequence.

Node naming convention is fixed: `manager-{N}` and `worker-{N}`. The script uses `multipass list | grep` to check node existence before operations.

## Placeholder Directories

`examples/`, `helm/`, and `manifests/` are currently empty placeholders for future K8s manifests, Helm charts, and example deployments.

## Coding Conventions

- Use comments sparingly. Only comment complex code.

## Related Repositories

This repo is the infrastructure layer. Other abd-training repos handle databases (abd-databases), monitoring (abd-monitoring), AI agents (abd-ai-agents), and services (abd-go-services, abd-python-services).
