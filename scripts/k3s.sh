#!/bin/bash

# K3s Cluster Setup
# Install and configure K3s on multipass nodes, including Istio service mesh
# Usage: ./k3s.sh [command] [options]
# Prerequisites: ./multipass.sh create

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

ISTIO_VERSION=${ISTIO_VERSION:-1.29.0}

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
    local first_server="${PREFIX_WITH_SEP}manager-1"

    print_header "Initializing K3s Cluster"

    # Check if first server node exists
    if ! multipass list | grep -q "^$first_server "; then
        print_error "First server node ($first_server) does not exist. Run './multipass.sh create' first."
        return 1
    fi

    # Get first server IP
    local server_ip
    server_ip=$(get_node_ip "$first_server")
    print_info "First server IP: $server_ip"

    # Install K3s on first server with cluster-init for HA
    print_header "Installing K3s on $first_server (first server with embedded etcd)"

    if ! multipass exec "$first_server" -- bash -c "curl -sfL https://get.k3s.io | sh -s - server --cluster-init --disable traefik"; then
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

        if ! multipass exec "$node" -- bash -c "curl -sfL https://get.k3s.io | K3S_URL=https://$server_ip:6443 K3S_TOKEN=$node_token sh -s - server --disable traefik"; then
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
    print_info "Get kubeconfig: ./k3s.sh kubeconfig"
    print_info "Check all pods: multipass exec $first_server -- sudo k3s kubectl get pods -A"
}

# Export K3s kubeconfig for local kubectl access
k3s_kubeconfig() {
    local first_server="${PREFIX_WITH_SEP}manager-1"
    local kubeconfig_name="${PREFIX_WITH_SEP}k3s-multipass-config"
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

# Install Istio service mesh
istio_setup() {
    local first_server="${PREFIX_WITH_SEP}manager-1"
    local istio_version="${ISTIO_VERSION:-1.29.0}"

    print_header "Installing Istio Service Mesh"

    # Check if first server node exists
    if ! multipass list | grep -q "^$first_server "; then
        print_error "First server node ($first_server) does not exist. Run './multipass.sh create' and './k3s.sh setup' first."
        return 1
    fi

    # Check if K3s is running
    print_info "Verifying K3s cluster is ready..."
    local node_check
    node_check=$(multipass exec "$first_server" -- sudo k3s kubectl get nodes 2>&1)
    if [ $? -ne 0 ]; then
        print_error "K3s cluster is not ready. Run './k3s.sh setup' first."
        return 1
    fi

    # Install Gateway API CRDs
    print_header "Installing Gateway API CRDs"
    print_info "Installing Kubernetes Gateway API..."

    if ! multipass exec "$first_server" -- sudo k3s kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml; then
        print_warning "Failed to install Gateway API CRDs, continuing anyway..."
    else
        print_success "Gateway API CRDs installed"
    fi

    # Download and install istioctl
    print_header "Installing istioctl CLI"
    multipass exec "$first_server" -- bash -c "curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$istio_version sh -"

    # Move istioctl to PATH
    multipass exec "$first_server" -- sudo mv "istio-$istio_version/bin/istioctl" /usr/local/bin/istioctl
    multipass exec "$first_server" -- sudo chmod +x /usr/local/bin/istioctl

    print_success "istioctl installed"

    # Install Istio with minimal profile and Gateway API support
    print_header "Installing Istio (minimal profile with Gateway API)"
    print_info "This may take a few minutes..."

    if ! multipass exec "$first_server" -- bash -c "KUBECONFIG=/etc/rancher/k3s/k3s.yaml sudo -E istioctl install --set profile=minimal -y"; then
        print_error "Failed to install Istio"
        return 1
    fi

    print_success "Istio installed successfully"

    # Wait for Istio components to be ready
    print_info "Waiting for Istio components to be ready..."
    sleep 10

    # Verify installation
    print_header "Verifying Istio Installation"

    # Check istiod deployment
    if multipass exec "$first_server" -- sudo k3s kubectl get deployment -n istio-system istiod 2>/dev/null | grep -q "1/1"; then
        print_success "istiod is running"
    else
        print_warning "istiod may still be initializing"
    fi

    # Check ingress gateway
    if multipass exec "$first_server" -- sudo k3s kubectl get service -n istio-system istio-ingressgateway 2>/dev/null; then
        print_success "istio-ingressgateway service is created"
    else
        print_warning "istio-ingressgateway not found"
    fi

    # Verify Gateway API CRDs
    print_header "Verifying Gateway API"
    if multipass exec "$first_server" -- sudo k3s kubectl get crd gateways.gateway.networking.k8s.io 2>/dev/null; then
        print_success "Gateway API CRDs are installed"
    else
        print_warning "Gateway API CRDs not found"
    fi

    # Display cluster status
    print_header "Istio Components Status"
    multipass exec "$first_server" -- sudo k3s kubectl get pods -n istio-system

    print_success "Istio service mesh installation complete!"
    print_info ""
    print_info "Installed components:"
    print_info "  ✓ Istio ${istio_version} (minimal profile)"
    print_info "  ✓ Gateway API v1.2.1"
    print_info ""
    print_info "Next steps:"
    print_info "  1. Enable Istio injection for your namespace:"
    print_info "     multipass exec $first_server -- sudo k3s kubectl label namespace default istio-injection=enabled"
    print_info ""
    print_info "  2. Verify Istio version:"
    print_info "     multipass exec $first_server -- bash -c 'KUBECONFIG=/etc/rancher/k3s/k3s.yaml sudo -E istioctl version'"
    print_info ""
    print_info "  3. Create a Gateway (using Gateway API):"
    print_info "     kubectl apply -f - <<EOF"
    print_info "     apiVersion: gateway.networking.k8s.io/v1"
    print_info "     kind: Gateway"
    print_info "     metadata:"
    print_info "       name: gateway"
    print_info "     spec:"
    print_info "       gatewayClassName: istio"
    print_info "       listeners:"
    print_info "       - name: http"
    print_info "         port: 80"
    print_info "         protocol: HTTP"
    print_info "     EOF"
    print_info ""
    print_info "  4. Deploy a sample application:"
    print_info "     multipass exec $first_server -- sudo k3s kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.29/samples/bookinfo/platform/kube/bookinfo.yaml"
    print_info ""
    print_info "  5. Extend Istio with addons (optional):"
    print_info "     Kiali, Jaeger, Prometheus, Grafana"
    print_info "     See: https://istio.io/latest/docs/setup/getting-started/#dashboard"
}

# Display help
show_help() {
    cat << EOF
${BLUE}K3s Cluster Setup${NC}
Install and configure K3s on multipass nodes, including Istio service mesh.
Prerequisite: ./multipass.sh create

${GREEN}Usage:${NC}
    ./k3s.sh [command]

${GREEN}Commands:${NC}
    setup               Install K3s on all nodes (servers + agents)
    kubeconfig          Export kubeconfig for local kubectl access
    istio-setup         Install Istio service mesh + Gateway API
    help                Display this help message

${GREEN}Environment Variables:${NC}
    NODE_PREFIX         Prefix for node names — must match what was used with multipass.sh
    MANAGER_COUNT       Number of manager nodes (default: 1)
    WORKER_COUNT        Number of worker nodes (default: 2)
    ISTIO_VERSION       Istio version to install (default: 1.29.0)

${GREEN}Examples:${NC}
    # Full K3s + Istio workflow
    ./multipass.sh create
    ./k3s.sh setup
    ./k3s.sh kubeconfig
    ./k3s.sh istio-setup

    # With node prefix (multi-cluster)
    NODE_PREFIX=k3s ./multipass.sh create
    NODE_PREFIX=k3s ./k3s.sh setup
    NODE_PREFIX=k3s ./k3s.sh kubeconfig

    # Enable Istio sidecar injection
    multipass exec manager-1 -- sudo k3s kubectl label namespace default istio-injection=enabled

${GREEN}Istio Service Mesh:${NC}
    - Installed with minimal profile (istiod + istio-ingressgateway)
    - Gateway API v1.2.1 installed for modern ingress management
    - Traefik is disabled on K3s clusters to avoid conflicts
    - Extend with: istioctl install --set profile=demo (adds Kiali, Jaeger, etc.)

${GREEN}Node Naming:${NC}
    Without prefix: manager-1, worker-1, etc.
    With NODE_PREFIX=k3s: k3s-manager-1, k3s-worker-1, etc.

EOF
}

# Main command handler
main() {
    local command=${1:-help}

    case "$command" in
        setup)
            k3s_setup
            ;;
        kubeconfig)
            k3s_kubeconfig
            ;;
        istio-setup)
            istio_setup
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
