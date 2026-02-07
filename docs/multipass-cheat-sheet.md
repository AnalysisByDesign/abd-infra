# Canonical Multipass Cheat Sheet

Useful commands for running virtual machines with Canonical Multipass.

Multipass provides lightweight VM management, useful for testing multi-machine setups without Docker.

## Installation

- Install Multipass for Mac

  ``` bash
  brew install multipass
  multipass version
  ```

- Alternatively, download from [multipass.run](https://multipass.run)

- Go to `Settings > Privacy & Security > Local Network` and make sure iTerm2 is enabled

## Instance Management

``` bash
# launch a new instance
multipass launch --name my-vm

# launch with specific image
multipass launch --name my-vm 22.04

# launch with custom resources (cpus, memory, disk)
multipass launch --name my-vm --cpus 2 --memory 2G --disk 10G

# list all instances
multipass list

# get detailed info about an instance
multipass info my-vm

# start an instance
multipass start my-vm

# stop an instance
multipass stop my-vm

# restart an instance
multipass restart my-vm

# suspend an instance (lighter than stop)
multipass suspend my-vm

# resume a suspended instance
multipass resume my-vm

# delete an instance
multipass delete my-vm

# permanently remove deleted instances
multipass purge
```

## Shell Access

``` bash
# open a shell in an instance
multipass shell my-vm

# run a command in an instance without entering shell
multipass exec my-vm -- command arg1 arg2

# run multiple commands
multipass exec my-vm -- bash -c 'cd /home && pwd && ls -la'
```

## File Transfer

``` bash
# copy a file from host to instance
multipass transfer /path/to/local/file my-vm:/path/in/instance/

# copy a file from instance to host
multipass transfer my-vm:/path/in/instance/file /path/to/local/

# copy directory recursively
multipass transfer -r /local/dir my-vm:/remote/dir
```

## Networking

``` bash
# get instance IP address
multipass info my-vm

# mount a directory from host into instance
multipass mount /path/on/host my-vm:/path/in/instance

# unmount a directory
multipass unmount my-vm:/path/in/instance

# list all mounts
multipass info my-vm
```

## Instance Logs & Troubleshooting

``` bash
# view cloud-init logs
multipass exec my-vm -- cat /var/log/cloud-init-output.log

# check instance status
multipass list

# check primary instance
multipass info primary

# recover an instance that won't start
multipass delete my-vm
multipass purge
multipass launch --name my-vm
```

## Useful Cloud-Init Setup

``` bash
# launch instance with cloud-init script
multipass launch --name my-vm --cloud-init init.yaml

# example init.yaml with package installation and user setup
cat > init.yaml << 'EOF'
#cloud-config
packages:
  - build-essential
  - git
  - curl

runcmd:
  - echo "Setup complete"
EOF
```

## Working with Primary Instance

``` bash
# the "primary" instance is special (can be used without --name)
multipass launch primary

# work with primary directly
multipass shell primary

multipass exec primary -- some-command

multipass transfer file.txt primary:
```

## Tips & Notes

- Multipass uses QEMU (on Mac) for lightweight virtualization without Docker overhead.
- The "primary" instance is created automatically or used as the default when no name is specified.
- Use `multipass mount` to share directories between host and VMs for development workflows.
- Cloud-init scripts run on first boot; use them to customize instances at launch time.
- `multipass stop` is faster for temporary pause;
- `multipass delete` + `multipass purge` fully removes instances.
- Use `--cpus`, `--memory`, and `--disk` when launching to control resource allocation.
- For multi-machine clusters, launch multiple instances and use `multipass exec` to run commands across them.

---

# Quick reference summary

| Action | Command example |
|---|---|
| Launch instance | `multipass launch --name my-vm --cpus 2 --memory 2G` |
| Open shell | `multipass shell my-vm` |
| Run command | `multipass exec my-vm -- command` |
| Copy file to VM | `multipass transfer file.txt my-vm:/path/` |
| Copy file from VM | `multipass transfer my-vm:/path/file.txt ./` |
| List instances | `multipass list` |
| Stop instance | `multipass stop my-vm` |
| Delete instance | `multipass delete my-vm && multipass purge` |
| Mount directory | `multipass mount /local/path my-vm:/remote/path` |
| View logs | `multipass exec my-vm -- cat /var/log/cloud-init-output.log` |
