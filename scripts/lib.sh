#!/bin/bash

# Shared library for multipass cluster management scripts
# Source this file at the top of each script:
#   source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Colors for output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color

# Shared environment variable defaults
NODE_PREFIX=${NODE_PREFIX:-}
# Automatically add hyphen separator when NODE_PREFIX is set
PREFIX_WITH_SEP="${NODE_PREFIX:+${NODE_PREFIX}-}"
MANAGER_COUNT=${MANAGER_COUNT:-1}
WORKER_COUNT=${WORKER_COUNT:-2}
CLUSTER_TYPE=${CLUSTER_TYPE:-k3s}
IMAGE="24.04"
CPUS_PER_NODE=${CPUS_PER_NODE:-2}
RAM_PER_NODE=${RAM_PER_NODE:-4G}
DISK_PER_NODE=${DISK_PER_NODE:-20G}
# Per-role overrides — fall back to CPUS_PER_NODE/RAM_PER_NODE when not set
MANAGER_CPUS=${MANAGER_CPUS:-$CPUS_PER_NODE}
MANAGER_RAM=${MANAGER_RAM:-$RAM_PER_NODE}
WORKER_CPUS=${WORKER_CPUS:-$CPUS_PER_NODE}
WORKER_RAM=${WORKER_RAM:-$RAM_PER_NODE}

# Helper functions
print_header() {
    printf "${BLUE}=== %s ===${NC}\n" "$1"
}

print_success() {
    printf "${GREEN}✓ %s${NC}\n" "$1"
}

print_info() {
    printf "${BLUE}ℹ %s${NC}\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠ %s${NC}\n" "$1"
}

print_error() {
    printf "${RED}✗ %s${NC}\n" "$1"
}

# Generate node names
get_manager_names() {
    for i in $(seq 1 $MANAGER_COUNT); do
        echo "${PREFIX_WITH_SEP}manager-$i"
    done
}

get_worker_names() {
    for i in $(seq 1 $WORKER_COUNT); do
        echo "${PREFIX_WITH_SEP}worker-$i"
    done
}

get_all_names() {
    get_manager_names
    get_worker_names
}

# Get node IP
get_node_ip() {
    local node=$1

    if [ -z "$node" ]; then
        print_error "Please specify a node name"
        return 1
    fi

    multipass info "$node" | grep "IPv4" | awk '{print $2}'
}
