#!/bin/bash

# Docker Swarm Setup
# Configure Docker Swarm-specific features on multipass nodes
# Usage: ./docker-swarm.sh [command] [options]
# Prerequisites: CLUSTER_TYPE=docker ./multipass.sh create

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# Configure NFS on manager, label workers, and deploy demo service
nfs_setup() {
    local manager=${1:-${PREFIX_WITH_SEP}manager-1}
    local export_dir=${2:-/srv/swarm-shared}
    local volume_name=${3:-swarm_shared}
    local service_name=${4:-demo}

    print_header "Configuring NFS on $manager"

    multipass exec "$manager" -- sudo apt-get update
    multipass exec "$manager" -- sudo apt-get install -y nfs-kernel-server
    multipass exec "$manager" -- sudo mkdir -p "$export_dir"
    multipass exec "$manager" -- sudo bash -c "echo \"$export_dir *(rw,sync,no_subtree_check,no_root_squash)\" >> /etc/exports"
    multipass exec "$manager" -- sudo exportfs -ra

    print_header "Installing NFS client on workers"
    local workers=$(get_worker_names)
    for node in $workers; do
        multipass exec "$node" -- sudo apt-get update
        multipass exec "$node" -- sudo apt-get install -y nfs-common
    done

    print_header "Labeling workers"
    for node in $workers; do
        multipass exec "$manager" -- docker node update --label-add role=worker "$node"
    done

    local manager_ip
    manager_ip=$(get_node_ip "$manager")

    print_header "Deploying demo service"
    multipass exec "$manager" -- docker service create \
        --name "$service_name" \
        --constraint 'node.labels.role==worker' \
        --mount type=volume,source="$volume_name",target=/data,volume-driver=local,volume-opt=type=nfs,volume-opt=o=addr="$manager_ip"\\,nfsvers=4\\,rw,volume-opt=device=:"$export_dir" \
        nginx:alpine

    print_success "NFS, labels, and demo service configured"
}

# Display help
show_help() {
    cat << EOF
${BLUE}Docker Swarm Setup${NC}
Configure Docker Swarm-specific features on multipass nodes.
Prerequisite: CLUSTER_TYPE=docker ./multipass.sh create

${GREEN}Usage:${NC}
    ./docker-swarm.sh [command] [options]

${GREEN}Commands:${NC}
    nfs-setup [manager] [export-dir] [volume] [service]
                        Configure NFS on manager, label workers, deploy demo service
    help                Display this help message

${GREEN}Environment Variables:${NC}
    NODE_PREFIX         Prefix for node names — must match what was used with multipass.sh
    MANAGER_COUNT       Number of manager nodes (default: 1)
    WORKER_COUNT        Number of worker nodes (default: 2)

${GREEN}Examples:${NC}
    # Full Docker Swarm workflow
    CLUSTER_TYPE=docker ./multipass.sh create
    ./docker-swarm.sh nfs-setup

    # With custom NFS settings
    ./docker-swarm.sh nfs-setup manager-1 /srv/data myvolume myservice

    # With node prefix (multi-cluster)
    NODE_PREFIX=swarm CLUSTER_TYPE=docker ./multipass.sh create
    NODE_PREFIX=swarm ./docker-swarm.sh nfs-setup

${GREEN}High Availability Notes:${NC}
    - Requires ODD number of managers for Raft consensus (1, 3, 5, 7)
    - 3 managers = tolerate 1 failure (recommended minimum for HA)
    - 5 managers = tolerate 2 failures (production recommended)
    - NEVER use 2 or 4 managers (no benefit, worse than 1 or 3)

EOF
}

# Main command handler
main() {
    local command=${1:-help}

    case "$command" in
        nfs-setup)
            nfs_setup "$2" "$3" "$4" "$5"
            ;;
        help)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
