# Target Repo Structure

What is this repo going to contain - remove entries as they are created

```
abd-infra/
├── config/                            # Configuration files
│   ├── k3s/
│   │   ├── config.yaml                # K3s configuration
│   │   └── registries.yaml            # Private registry config
│   └── network/
│       └── network-config.yaml        # Network settings
│
├── docs/                              # Detailed documentation
│   ├── architecture.md                # System architecture diagrams
│   ├── setup-guide.md                 # Step-by-step setup instructions
│   ├── troubleshooting.md             # Common issues and solutions
│   └── networking.md                  # Network configuration details
│
├── examples/                          # Example deployments
│   ├── hello-world/                   # Simple test deployment
│   └── multi-tier/                    # Example multi-tier app
│
├── helm/                              # Helm charts (if needed)
│   └── values/
│       ├── dev.yaml
│       └── local.yaml
│
├── manifests/                         # Kubernetes manifests
│   ├── namespaces/                    # Namespace definitions
│   ├── storage/                       # PV, PVC, StorageClass
│   └── ingress/                       # Ingress controllers
│
├── scripts/                           # Automation scripts
│   ├── setup/
│   │   ├── install-multipass.sh       # Multipass installation
│   │   ├── create-cluster.sh          # Create k3s cluster
│   │   └── configure-networking.sh    # Network setup
│   ├── teardown/
│   │   ├── destroy-cluster.sh         # Clean removal
│   │   └── cleanup.sh                 # Remove artifacts
│   └── utils/
│       ├── check-prerequisites.sh     # Verify system requirements
│       └── backup-config.sh           # Backup configurations
```