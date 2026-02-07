#!/bin/bash

# Multipass Docker Swarm Node Manager
# Manage a cluster of multipass instances configured for Docker Swarm
# Usage: ./multipass.sh [command] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config/multipass"
MANAGER_COUNT=${MANAGER_COUNT:-3}
WORKER_COUNT=${WORKER_COUNT:-3}
CLUSTER_TYPE=${CLUSTER_TYPE:-docker}
IMAGE="24.04"
CPUS_PER_NODE=${CPUS_PER_NODE:-2}
RAM_PER_NODE=${RAM_PER_NODE:-4G}
DISK_PER_NODE=${DISK_PER_NODE:-40G}

# Set cloud-init file based on cluster type
case "$CLUSTER_TYPE" in
    docker)
        CLOUD_INIT_FILE="${CONFIG_DIR}/cloud-init.docker.yaml"
        ;;
    minikube|k8s|kubernetes)
        CLOUD_INIT_FILE="${CONFIG_DIR}/cloud-init.minikube.yaml"
        CLUSTER_TYPE="minikube"
        ;;
    *)
        printf "${RED}✗ Unknown cluster type: %s${NC}\n" "$CLUSTER_TYPE"
        printf "Valid options: docker, minikube\n"
        exit 1
        ;;
esac

# Colors for output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color

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
        echo "manager-$i"
    done
}

get_worker_names() {
    for i in $(seq 1 $WORKER_COUNT); do
        echo "worker-$i"
    done
}

get_all_names() {
    get_manager_names
    get_worker_names
}


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
            --cloud-init "$CLOUD_INIT_FILE" \
            "$IMAGE"

        print_success "Created $node"
    done

    print_success "All nodes created and ready for Docker Swarm"
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

# Get node IP
get_node_ip() {
    local node=$1

    if [ -z "$node" ]; then
        print_error "Please specify a node name"
        return 1
    fi

    multipass info "$node" | grep "IPv4" | awk '{print $2}'
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
${BLUE}Multipass Docker Swarm Manager${NC}

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
    nfs-setup           Configure NFS + worker labels + demo service
    help                Display this help message

${GREEN}Environment Variables:${NC}
    CLUSTER_TYPE        Type of cluster to create (default: docker)
                        Options: docker, minikube
    MANAGER_COUNT       Number of manager nodes (default: 3)
    WORKER_COUNT        Number of worker nodes (default: 2)
    CPUS_PER_NODE       CPU cores per node (default: 2)
    RAM_PER_NODE        RAM per node (default: 4G)
    DISK_PER_NODE       Disk size per node (default: 40G)
    IMAGE               Ubuntu image to use (default: 24.04)

${GREEN}Examples:${NC}
    # Create Docker Swarm cluster (3 managers, 2 workers)
    ./multipass.sh create

    # Create Kubernetes/Minikube cluster (3 managers, 2 workers)
    CLUSTER_TYPE=minikube ./multipass.sh create

    # Create custom Docker cluster (1 manager, 1 worker)
    MANAGER_COUNT=1 WORKER_COUNT=1 CLUSTER_TYPE=docker ./multipass.sh create

    # Start all nodes
    ./multipass.sh start all

    # Stop only worker nodes
    ./multipass.sh stop workers

    # Connect to a specific node
    ./multipass.sh shell manager-1

    # Get IP addresses
    ./multipass.sh ips

    # Configure NFS + labels + demo service
    ./multipass.sh nfs-setup

${GREEN}Node Naming:${NC}
    Manager nodes: manager-1, manager-2, ...
    Worker nodes:  worker-1, worker-2, ...

EOF
}

# Configure NFS on manager, label workers, and deploy demo service
nfs_setup() {
    local manager=${1:-manager-1}
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
