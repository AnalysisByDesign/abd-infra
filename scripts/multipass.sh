#!/bin/bash

# Multipass Cluster Manager
# Manage a cluster of multipass instances for Docker Swarm, Kubernetes (Minikube), or K3s
# Usage: ./multipass.sh [command] [options]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config/multipass"
NODE_PREFIX=${NODE_PREFIX:-}
MANAGER_COUNT=${MANAGER_COUNT:-3}
WORKER_COUNT=${WORKER_COUNT:-3}
CLUSTER_TYPE=${CLUSTER_TYPE:-k3s}
IMAGE="24.04"
CPUS_PER_NODE=${CPUS_PER_NODE:-3}
RAM_PER_NODE=${RAM_PER_NODE:-6G}
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
        echo "${NODE_PREFIX}manager-$i"
    done
}

get_worker_names() {
    for i in $(seq 1 $WORKER_COUNT); do
        echo "${NODE_PREFIX}worker-$i"
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
    NODE_PREFIX         Prefix for node names (default: none)
                        Use to run multiple clusters simultaneously
                        Example: k3s- creates k3s-manager-1, k3s-worker-1
    CLUSTER_TYPE        Type of cluster to create (default: k3s)
                        Options: docker, minikube, k3s
    MANAGER_COUNT       Number of manager nodes (default: 3)
    WORKER_COUNT        Number of worker nodes (default: 3)
    CPUS_PER_NODE       CPU cores per node (default: 3)
    RAM_PER_NODE        RAM per node (default: 6G)
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

    # Run K3s and Docker Swarm clusters simultaneously with prefixes
    NODE_PREFIX=k3s- CLUSTER_TYPE=k3s ./multipass.sh create
    NODE_PREFIX=k3s- ./multipass.sh k3s-setup
    NODE_PREFIX=docker- CLUSTER_TYPE=docker ./multipass.sh create

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
    Manager nodes: [prefix]manager-1, [prefix]manager-2, ...
    Worker nodes:  [prefix]worker-1, [prefix]worker-2, ...

    Without prefix: manager-1, worker-1, etc.
    With NODE_PREFIX=k3s-: k3s-manager-1, k3s-worker-1, etc.

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
# Wait for K3s API server to be ready
wait_for_k3s_api() {
    local server_ip=$1
    local max_attempts=15
    local attempt=0

    print_info "Waiting for K3s API server..."

    while [ $attempt -lt $max_attempts ]; do
        if curl -k --silent --fail --max-time 2 "https://$server_ip:6443/ping" > /dev/null 2>&1; then
            print_success "K3s API server is ready"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 3
    done

    print_error "K3s API server did not become ready"
    return 1
}

# Initialize K3s cluster
k3s_setup() {
    local first_server="${NODE_PREFIX}manager-1"

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

    # Install K3s on first server with cluster-init for HA
    print_header "Installing K3s on $first_server (first server with embedded etcd)"

    if ! multipass exec "$first_server" -- bash -c "curl -sfL https://get.k3s.io | sh -s - server --cluster-init"; then
        print_error "Failed to install K3s on $first_server"
        return 1
    fi

    # Wait for K3s to be ready
    print_info "Waiting for K3s to start..."
    sleep 30

    # Wait for API server (this verifies K3s is running)
    if ! wait_for_k3s_api "$server_ip"; then
        print_error "K3s API server did not become ready"
        print_info "Check logs: multipass exec $first_server -- sudo journalctl -xeu k3s.service"
        return 1
    fi

    print_success "K3s is ready"

    # Get node token
    print_info "Retrieving node token..."
    local node_token
    node_token=$(multipass exec "$first_server" -- sudo cat /var/lib/rancher/k3s/server/node-token)

    if [ -z "$node_token" ]; then
        print_error "Failed to retrieve node token"
        return 1
    fi

    print_success "First K3s server initialized successfully"

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

        if ! multipass exec "$node" -- bash -c "curl -sfL https://get.k3s.io | K3S_URL=https://$server_ip:6443 K3S_TOKEN=$node_token sh -s - server"; then
            print_error "Failed to install K3s on $node"
            print_info "Continuing with remaining nodes..."
            continue
        fi

        print_info "Waiting for $node to initialize..."
        sleep 20

        print_success "Server $node installation complete"
    done

    # Install K3s on worker nodes as agents
    local workers=$(get_worker_names)
    for node in $workers; do
        if ! multipass list | grep -q "^$node "; then
            print_warning "Node $node does not exist, skipping..."
            continue
        fi

        print_header "Installing K3s on $node (agent)"

        if ! multipass exec "$node" -- bash -c "curl -sfL https://get.k3s.io | K3S_URL=https://$server_ip:6443 K3S_TOKEN=$node_token sh -"; then
            print_error "Failed to install K3s on $node"
            print_info "Continuing with remaining nodes..."
            continue
        fi

        print_info "Waiting for $node to join..."
        sleep 15

        print_success "Agent $node installation complete"
    done

    # Wait a bit for all nodes to stabilize
    print_info "Waiting for cluster to stabilize..."
    sleep 10

    # Display cluster status
    print_header "K3s Cluster Status"
    if ! multipass exec "$first_server" -- sudo k3s kubectl get nodes; then
        print_error "Failed to get cluster status"
        return 1
    fi

    # Check which nodes are Ready
    print_header "Checking Node Status"
    local ready_count=0
    local total_count=0

    for node in $(get_all_names); do
        total_count=$((total_count + 1))
        if multipass exec "$first_server" -- sudo k3s kubectl get node "$node" 2>/dev/null | grep -q "Ready"; then
            ready_count=$((ready_count + 1))
            print_success "$node is Ready"
        else
            print_warning "$node is not Ready yet (may need more time)"
        fi
    done

    print_header "Cluster Summary"
    print_info "Nodes Ready: $ready_count/$total_count"

    if [ $ready_count -eq $total_count ]; then
        print_success "All nodes joined successfully!"
    elif [ $ready_count -gt 0 ]; then
        print_warning "Some nodes are not ready yet. Wait a few minutes and check again:"
        print_info "  multipass exec $first_server -- sudo k3s kubectl get nodes"
    else
        print_error "No nodes are ready. Check logs for errors."
        return 1
    fi

    print_success "K3s cluster initialization complete!"
    print_info ""
    print_info "Access cluster: multipass exec $first_server -- sudo k3s kubectl get nodes"
    print_info "Get kubeconfig: ./multipass.sh k3s-kubeconfig"
    print_info "Check all pods: multipass exec $first_server -- sudo k3s kubectl get pods -A"
}

# Export K3s kubeconfig for local kubectl access
k3s_kubeconfig() {
    local first_server="${NODE_PREFIX}manager-1"
    local kubeconfig_name="${NODE_PREFIX}k3s-multipass-config"
    local kubeconfig_path="${HOME}/.kube/${kubeconfig_name}"

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
