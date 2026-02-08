#!/bin/bash

# Multipass Cluster Manager
# Manage a cluster of multipass instances for Docker Swarm, Kubernetes (Minikube), or K3s
# Usage: ./multipass.sh [command] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config/multipass"
MANAGER_COUNT=${MANAGER_COUNT:-3}
WORKER_COUNT=${WORKER_COUNT:-3}
CLUSTER_TYPE=${CLUSTER_TYPE:-k3s}
IMAGE="24.04"
CPUS_PER_NODE=${CPUS_PER_NODE:-2}
RAM_PER_NODE=${RAM_PER_NODE:-4G}
DISK_PER_NODE=${DISK_PER_NODE:-40G}

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
${BLUE}Multipass Cluster Manager (Docker Swarm / Kubernetes / K3s)${NC}

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
    nfs-setup           Configure NFS + worker labels + demo service (Docker Swarm)
    k3s-setup           Initialize K3s cluster (server + agents)
    k3s-kubeconfig      Export K3s kubeconfig for local kubectl access
    help                Display this help message

${GREEN}Environment Variables:${NC}
    CLUSTER_TYPE        Type of cluster to create (default: k3s)
                        Options: docker, minikube, k3s
    MANAGER_COUNT       Number of manager nodes (default: 3)
    WORKER_COUNT        Number of worker nodes (default: 3)
    CPUS_PER_NODE       CPU cores per node (default: 2)
    RAM_PER_NODE        RAM per node (default: 4G)
    DISK_PER_NODE       Disk size per node (default: 40G)
    IMAGE               Ubuntu image to use (default: 24.04)

${GREEN}Examples:${NC}
    # Create K3s cluster (3 managers, 3 workers) - DEFAULT
    ./multipass.sh create

    # Create Docker Swarm cluster (3 managers, 3 workers)
    CLUSTER_TYPE=docker ./multipass.sh create

    # Create Kubernetes/Minikube cluster (3 managers, 3 workers)
    CLUSTER_TYPE=minikube ./multipass.sh create

    # Create custom K3s cluster (1 manager, 2 workers)
    MANAGER_COUNT=1 WORKER_COUNT=2 ./multipass.sh create

    # Start all nodes
    ./multipass.sh start all

    # Stop only worker nodes
    ./multipass.sh stop workers

    # Connect to a specific node
    ./multipass.sh shell manager-1

    # Get IP addresses
    ./multipass.sh ips

    # Initialize K3s cluster (after creating K3s nodes)
    ./multipass.sh k3s-setup

    # Export kubeconfig for local kubectl access
    ./multipass.sh k3s-kubeconfig

    # Full K3s workflow
    ./multipass.sh create && ./multipass.sh k3s-setup && ./multipass.sh k3s-kubeconfig

    # Configure NFS + labels + demo service (Docker Swarm only)
    ./multipass.sh nfs-setup

${GREEN}Node Naming:${NC}
    Manager nodes: manager-1, manager-2, ...
    Worker nodes:  worker-1, worker-2, ...

${GREEN}High Availability Notes:${NC}
    ${YELLOW}Docker Swarm:${NC}
    - Requires ODD number of managers for Raft consensus (1, 3, 5, 7)
    - 3 managers = tolerate 1 failure (recommended minimum for HA)
    - 5 managers = tolerate 2 failures (production recommended)
    - NEVER use 2 or 4 managers (no benefit, worse than 1 or 3)

    ${YELLOW}K3s:${NC}
    - Single server mode: 1 server node (development, no HA)
    - HA mode: 3+ server nodes with embedded etcd (production-like)
    - For local dev: 1 server + 2 agents = 3 nodes (saves resources)
    - For production-like: 3 servers + 3 agents = 6 nodes (matches Swarm)

    ${YELLOW}Minikube:${NC}
    - Single-node by design (1 manager, workers optional)
    - Multi-node support limited to testing workload distribution

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

# Initialize K3s cluster
k3s_setup() {
    local first_server="manager-1"

    print_header "Initializing K3s Cluster"

    # Check if first server node exists
    if ! multipass list | grep -q "^$first_server "; then
        print_error "First server node ($first_server) does not exist. Run 'create' first."
        return 1
    fi

    # Get first server IP
    local server_ip
    server_ip=$(get_node_ip "$first_server")
    print_info "First server IP: $server_ip"

    # Install K3s on first server
    print_header "Installing K3s on $first_server (first server)"
    multipass exec "$first_server" -- bash -c "curl -sfL https://get.k3s.io | sh -"

    # Wait for K3s to be ready
    print_info "Waiting for K3s to be ready..."
    sleep 10
    multipass exec "$first_server" -- sudo k3s kubectl wait --for=condition=Ready node/$first_server --timeout=60s || true

    # Get node token
    print_info "Retrieving node token..."
    local node_token
    node_token=$(multipass exec "$first_server" -- sudo cat /var/lib/rancher/k3s/server/node-token)

    print_success "First K3s server initialized"

    # Install K3s on additional manager nodes as servers (HA mode)
    local managers=$(get_manager_names)
    for node in $managers; do
        if [ "$node" = "$first_server" ]; then
            continue
        fi

        if ! multipass list | grep -q "^$node "; then
            print_warning "Node $node does not exist, skipping..."
            continue
        fi

        print_header "Installing K3s on $node (additional server)"
        multipass exec "$node" -- bash -c "curl -sfL https://get.k3s.io | K3S_URL=https://$server_ip:6443 K3S_TOKEN=$node_token sh -s - server"

        print_info "Waiting for $node to join..."
        sleep 5
        print_success "Server $node joined cluster"
    done

    # Install K3s on worker nodes as agents
    local workers=$(get_worker_names)
    for node in $workers; do
        if ! multipass list | grep -q "^$node "; then
            print_warning "Node $node does not exist, skipping..."
            continue
        fi

        print_header "Installing K3s on $node (agent)"
        multipass exec "$node" -- bash -c "curl -sfL https://get.k3s.io | K3S_URL=https://$server_ip:6443 K3S_TOKEN=$node_token sh -"

        print_info "Waiting for $node to join..."
        sleep 5
        print_success "Agent $node joined cluster"
    done

    # Display cluster status
    print_header "K3s Cluster Status"
    multipass exec "$first_server" -- sudo k3s kubectl get nodes

    print_success "K3s cluster initialized successfully!"
    print_info "Access cluster: multipass exec $first_server -- sudo k3s kubectl get nodes"
    print_info "Get kubeconfig: ./multipass.sh k3s-kubeconfig"
}

# Export K3s kubeconfig for local kubectl access
k3s_kubeconfig() {
    local first_server="manager-1"
    local kubeconfig_path="${HOME}/.kube/k3s-multipass-config"

    print_header "Exporting K3s Kubeconfig"

    # Check if first server node exists
    if ! multipass list | grep -q "^$first_server "; then
        print_error "First server node ($first_server) does not exist."
        return 1
    fi

    # Get first server IP
    local server_ip
    server_ip=$(get_node_ip "$first_server")

    # Create .kube directory if it doesn't exist
    mkdir -p "${HOME}/.kube"

    # Get kubeconfig from first server and modify server address
    print_info "Retrieving kubeconfig from $first_server..."
    multipass exec "$first_server" -- sudo cat /etc/rancher/k3s/k3s.yaml | \
        sed "s/127.0.0.1/$server_ip/g" > "$kubeconfig_path"

    print_success "Kubeconfig exported to: $kubeconfig_path"
    print_info ""
    print_info "To use this cluster with kubectl:"
    print_info "  export KUBECONFIG=$kubeconfig_path"
    print_info "  kubectl get nodes"
    print_info ""
    print_info "Or merge with your existing kubeconfig:"
    print_info "  KUBECONFIG=~/.kube/config:$kubeconfig_path kubectl config view --flatten > ~/.kube/config.new"
    print_info "  mv ~/.kube/config.new ~/.kube/config"
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
        k3s-setup)
            k3s_setup
            ;;
        k3s-kubeconfig)
            k3s_kubeconfig
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
