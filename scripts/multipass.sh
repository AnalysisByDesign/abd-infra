#!/bin/bash

# Multipass Infrastructure Manager
# Manage the lifecycle of multipass VMs for cluster nodes
# Usage: ./multipass.sh [command] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config/multipass"

# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

# Set cloud-init file based on cluster type
case "$CLUSTER_TYPE" in
    docker)
        CLOUD_INIT_FILE="${CONFIG_DIR}/cloud-init.docker.yaml"
        ;;
    minikube|kubernetes)
        CLOUD_INIT_FILE="${CONFIG_DIR}/cloud-init.minikube.yaml"
        CLUSTER_TYPE="minikube"
        ;;
    k3s)
        CLOUD_INIT_FILE="${CONFIG_DIR}/cloud-init.k3s.yaml"
        ;;
    *)
        printf "${RED}✗ Unknown cluster type: %s${NC}\n" "$CLUSTER_TYPE"
        printf "Valid options: docker, minikube, k3s\n"
        exit 1
        ;;
esac

# Create nodes
create_nodes() {
    print_header "Creating Multipass Nodes (${CLUSTER_TYPE} Cluster)"

    local nodes=$(get_all_names)

    for node in $nodes; do
        if multipass list | grep -q "^$node "; then
            print_warning "Node $node already exists, skipping..."
            continue
        fi

        print_info "Creating $node..."
        multipass launch \
            --name "$node" \
            --cpus "$CPUS_PER_NODE" \
            --memory "$RAM_PER_NODE" \
            --disk "$DISK_PER_NODE" \
            --cloud-init "$CLOUD_INIT_FILE" \
            "$IMAGE"

        print_success "Created $node"
    done

    print_success "All nodes created and ready for ${CLUSTER_TYPE} cluster"
}

# Delete nodes
delete_nodes() {
    print_header "Deleting Multipass Nodes"

    local nodes=$(get_all_names)

    for node in $nodes; do
        if multipass list | grep -q "^$node "; then
            print_info "Deleting $node..."
            multipass delete "$node" --purge
            print_success "Deleted $node"
        fi
    done

    print_success "All nodes deleted"
}

# Start nodes
start_nodes() {
    local target=${1:-all}

    if [ "$target" = "all" ]; then
        print_header "Starting All Nodes"
        local nodes=$(get_all_names)
    elif [ "$target" = "managers" ]; then
        print_header "Starting Manager Nodes"
        local nodes=$(get_manager_names)
    elif [ "$target" = "workers" ]; then
        print_header "Starting Worker Nodes"
        local nodes=$(get_worker_names)
    else
        print_header "Starting Node: $target"
        local nodes=$target
    fi

    for node in $nodes; do
        if multipass list | grep -q "^$node "; then
            print_info "Starting $node..."
            multipass start "$node"
            print_success "Started $node"
        else
            print_error "Node $node does not exist"
        fi
    done
}

# Stop nodes
stop_nodes() {
    local target=${1:-all}

    if [ "$target" = "all" ]; then
        print_header "Stopping All Nodes"
        local nodes=$(get_all_names)
    elif [ "$target" = "managers" ]; then
        print_header "Stopping Manager Nodes"
        local nodes=$(get_manager_names)
    elif [ "$target" = "workers" ]; then
        print_header "Stopping Worker Nodes"
        local nodes=$(get_worker_names)
    else
        print_header "Stopping Node: $target"
        local nodes=$target
    fi

    for node in $nodes; do
        if multipass list | grep -q "^$node "; then
            print_info "Stopping $node..."
            multipass stop "$node"
            print_success "Stopped $node"
        else
            print_error "Node $node does not exist"
        fi
    done
}

# List nodes
list_nodes() {
    print_header "Multipass Nodes Status"
    multipass list

    print_header "Manager Nodes"
    echo "Expected: $MANAGER_COUNT"
    get_manager_names

    print_header "Worker Nodes"
    echo "Expected: $WORKER_COUNT"
    get_worker_names
}

# Get node info
node_info() {
    local node=$1

    if [ -z "$node" ]; then
        print_error "Please specify a node name"
        return 1
    fi

    print_header "Node Information: $node"
    multipass info "$node"
}

# SSH into node
shell_node() {
    local node=$1

    if [ -z "$node" ]; then
        print_error "Please specify a node name"
        return 1
    fi

    print_info "Connecting to $node..."
    multipass shell "$node"
}

# Execute command on node
exec_node() {
    local node=$1
    shift
    local cmd=$@

    if [ -z "$node" ]; then
        print_error "Please specify a node name"
        return 1
    fi

    if [ -z "$cmd" ]; then
        print_error "Please specify a command"
        return 1
    fi

    multipass exec "$node" -- $cmd
}

# List node IPs
list_ips() {
    print_header "Node IP Addresses"

    local nodes=$(get_all_names)
    for node in $nodes; do
        local ip=$(get_node_ip "$node" 2>/dev/null || echo "N/A")
        printf "%-15s %s\n" "$node" "$ip"
    done
}

# Display help
show_help() {
    cat << EOF
${BLUE}Multipass Infrastructure Manager${NC}
Manages the lifecycle of multipass VMs for cluster nodes.

${GREEN}Usage:${NC}
    ./multipass.sh [command] [options]

${GREEN}Commands:${NC}
    create              Create all manager and worker nodes
    delete              Delete all nodes
    start [target]      Start nodes (all|managers|workers|node-name)
    stop [target]       Stop nodes (all|managers|workers|node-name)
    list                List all nodes and their status
    info <node>         Show detailed info for a specific node
    shell <node>        SSH into a specific node
    exec <node> <cmd>   Execute a command on a node
    ips                 Show IP addresses of all nodes
    help                Display this help message

${GREEN}Environment Variables:${NC}
    NODE_PREFIX         Prefix for node names (default: none)
                        Use to run multiple clusters simultaneously
                        Example: k3s creates k3s-manager-1, k3s-worker-1
                        Note: Hyphen separator is added automatically
    CLUSTER_TYPE        Type of cluster to create (default: k3s)
                        Options: docker, minikube, k3s
    MANAGER_COUNT       Number of manager nodes (default: 1)
    WORKER_COUNT        Number of worker nodes (default: 2)
    CPUS_PER_NODE       CPU cores per node (default: 2)
    RAM_PER_NODE        RAM per node (default: 4G)
    DISK_PER_NODE       Disk size per node (default: 20G)
    IMAGE               Ubuntu image to use (default: 24.04)

${GREEN}Examples:${NC}
    # Create K3s cluster (default)
    ./multipass.sh create

    # Create Docker Swarm cluster
    CLUSTER_TYPE=docker ./multipass.sh create

    # Create Minikube cluster
    CLUSTER_TYPE=minikube ./multipass.sh create

    # Create custom cluster (1 manager, 2 workers)
    MANAGER_COUNT=1 WORKER_COUNT=2 ./multipass.sh create

    # Run two clusters simultaneously with prefixes
    NODE_PREFIX=k3s CLUSTER_TYPE=k3s ./multipass.sh create
    NODE_PREFIX=docker CLUSTER_TYPE=docker ./multipass.sh create

    # Start/stop/list nodes
    ./multipass.sh start all
    ./multipass.sh stop workers
    ./multipass.sh list

    # Connect to a node
    ./multipass.sh shell manager-1

    # Get IP addresses
    ./multipass.sh ips

${GREEN}Node Naming:${NC}
    Manager nodes: [prefix-]manager-1, [prefix-]manager-2, ...
    Worker nodes:  [prefix-]worker-1, [prefix-]worker-2, ...

    Without prefix: manager-1, worker-1, etc.
    With NODE_PREFIX=k3s: k3s-manager-1, k3s-worker-1, etc.
    (Hyphen separator is added automatically)

${GREEN}Technology-Specific Setup:${NC}
    After creating nodes, use the appropriate script for cluster setup:

    K3s:          ./k3s.sh help
    Docker Swarm: ./docker-swarm.sh help
    Minikube:     ./minikube.sh help

EOF
}

# Main command handler
main() {
    local command=${1:-help}

    case "$command" in
        create)
            create_nodes
            ;;
        delete)
            print_warning "This will delete all nodes!"
            read -p "Are you sure? (yes/no): " -r
            if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                delete_nodes
            else
                print_info "Cancelled"
            fi
            ;;
        start)
            start_nodes "${2:-all}"
            ;;
        stop)
            stop_nodes "${2:-all}"
            ;;
        list)
            list_nodes
            ;;
        info)
            node_info "$2"
            ;;
        shell)
            shell_node "$2"
            ;;
        exec)
            shift
            exec_node "$@"
            ;;
        ips)
            list_ips
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
