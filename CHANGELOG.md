# Changelog

## 2026-02-13 - NODE_PREFIX Automatic Hyphen Separator

### ✅ Enhancement

#### NODE_PREFIX Simplified Usage

- **Changed:** NODE_PREFIX now automatically adds hyphen separator
- **Before:** `NODE_PREFIX=k3s-` (user had to include trailing hyphen)
- **After:** `NODE_PREFIX=k3s` (hyphen added automatically)
- **Benefit:** More intuitive usage, less prone to user error
- **Implementation:** Added `PREFIX_WITH_SEP` variable that handles separator logic
- **Updated:** All documentation updated to reflect new usage pattern

**Migration Guide:**

```bash
# Old usage (still works if you forget to update)
NODE_PREFIX=k3s- ./multipass.sh create  # Creates: k3s--manager-1 (double hyphen)

# New usage (recommended)
NODE_PREFIX=k3s ./multipass.sh create   # Creates: k3s-manager-1 (correct)
```

---

## 2026-02-10 - Multi-Cluster Support & Documentation Complete

### ✅ Features Added

#### 1. Node Name Prefixing

- Added `NODE_PREFIX` environment variable
- Enables running multiple clusters simultaneously (K3s + Docker Swarm)
- Example: `NODE_PREFIX=k3s` creates `k3s-manager-1`, `k3s-worker-1`, etc.
- Note: As of 2026-02-13, hyphen separator is added automatically

#### 2. Resource Configuration

- Fixed: Nodes now properly use configured CPU/RAM/Disk values
- Added `--cpus`, `--memory`, `--disk` flags to `multipass launch`
- Default: 3 CPUs, 6GB RAM, 40GB disk per node

### 🐛 Bug Fixes

#### 1. K3s HA Setup

- **Fixed:** First server now installs with `--cluster-init` flag
- **Result:** Embedded etcd cluster initializes correctly
- **Impact:** manager-2 and manager-3 can now join successfully

#### 2. macOS Compatibility

- **Fixed:** Removed `multipass exec ... > /dev/null` patterns
- **Cause:** Output redirection causes SSH connection hangs on macOS
- **Result:** k3s-setup no longer hangs indefinitely

#### 3. Resource Allocation

- **Fixed:** Nodes created with only 1 CPU / 1GB RAM (Multipass defaults)
- **Cause:** `multipass launch` wasn't receiving CPU/RAM parameters
- **Result:** Nodes now created with configured resources

### 📚 Documentation

#### New Documentation Files

1. **USAGE.md** (500+ lines)
   - Comprehensive command reference
   - All environment variables explained
   - K3s and Docker Swarm workflows
   - Node management guide

2. **EXAMPLES.md** (450+ lines)
   - 15 complete scenario examples
   - Multi-cluster setups
   - Development workflows
   - Training lab configurations

3. **TROUBLESHOOTING.md** (450+ lines)
   - Common issues and solutions
   - Diagnostic commands
   - Error message reference
   - Reset procedures

4. **CHANGELOG.md** (this file)
   - Track changes and updates

#### Updated Files

- **scripts/multipass.sh**
  - Added NODE_PREFIX support
  - Fixed resource parameter passing
  - Fixed K3s --cluster-init
  - Removed problematic output redirections
  - Updated help text

### 🎯 Tested & Working

- ✅ K3s cluster creation (3 managers, 2 workers)
- ✅ K3s HA initialization with embedded etcd
- ✅ All 5 nodes join and reach Ready state
- ✅ Multiple build iterations (stable)
- ✅ Node prefixing for parallel clusters
- ✅ Resource configuration (3 CPU, 6GB RAM)

### 📊 Script Statistics

- **Total lines:** 850+
- **Functions:** 15+
- **Cluster types supported:** 3 (K3s, Docker Swarm, Minikube)
- **Documentation:** 1,500+ lines across 4 files

### 🚀 Quick Start

```bash
cd scripts

# Create and initialize K3s cluster
./multipass.sh create
./multipass.sh k3s-setup
./multipass.sh k3s-kubeconfig

# Use cluster
export KUBECONFIG=~/.kube/k3s-multipass-config
kubectl get nodes
```

### 🔄 Migration Guide

If you have existing clusters from older version:

```bash
# Destroy old cluster
./multipass.sh --destroy

# Recreate with new version (gets proper resources and fixes)
./multipass.sh create
./multipass.sh k3s-setup
```

### 🎓 Next Steps

The abd-infra repository is now stable and ready for:

- Training platform development
- Multi-cluster management
- Infrastructure automation
- AI agent integration (abd-ai-agents repo)

### 📝 Notes

- All changes tested on macOS with Multipass
- K3s version: Latest stable (auto-installed)
- Default resources: 3 CPU, 6GB RAM per node
- Recommended host: 16GB+ RAM for full cluster

---

**Repository Status:** ✅ Production Ready for Training Platform
