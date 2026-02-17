#!/bin/bash

# Minikube Cluster Setup
# Configure Minikube-specific features on multipass nodes
# Usage: ./minikube.sh [command] [options]
# Prerequisites: CLUSTER_TYPE=minikube ./multipass.sh create

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# Display help
show_help() {
    cat << EOF
${BLUE}Minikube Cluster Setup${NC}
Configure Minikube-specific features on multipass nodes.
Prerequisite: CLUSTER_TYPE=minikube ./multipass.sh create

${GREEN}Usage:${NC}
    ./minikube.sh [command]

${GREEN}Commands:${NC}
    help                Display this help message

${GREEN}Environment Variables:${NC}
    NODE_PREFIX         Prefix for node names — must match what was used with multipass.sh
    MANAGER_COUNT       Number of nodes (default: 1 for Minikube)
    WORKER_COUNT        Number of worker nodes (default: 0 for single-node Minikube)

${GREEN}Examples:${NC}
    # Single-node Minikube
    CLUSTER_TYPE=minikube MANAGER_COUNT=1 WORKER_COUNT=0 ./multipass.sh create
    # Then SSH in and start Minikube manually
    ./multipass.sh shell manager-1

${GREEN}Minikube Notes:${NC}
    - Single-node by design (1 manager, workers optional)
    - Multi-node support limited to testing workload distribution
    - Minikube-specific setup commands will be added here as needed

EOF
}

# Main command handler
main() {
    local command=${1:-help}

    case "$command" in
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
