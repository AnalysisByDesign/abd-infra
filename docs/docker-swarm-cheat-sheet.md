# Docker Swarm Cheat Sheet

Useful commands for managing Docker Swarm clusters.

Docker Swarm is Docker's native orchestration solution for managing multiple Docker hosts as a single virtual system.

## Installation & Setup

- Install Docker Desktop for Mac (includes Swarm)
  - Using Multipass - `mp launch --name node_name docker`

``` bash
docker --version
docker swarm --help
```

- Enable Docker Swarm mode (one-time setup on the manager node)

``` bash
docker swarm init

# on additional nodes, join the swarm as a worker
docker swarm join --token SWMTKN-xxxxx 192.168.1.100:2377

# get the join token for workers
docker swarm join-token worker

# get the join token for managers
docker swarm join-token manager
```

## Swarm & Node Management

``` bash
# list all nodes in the swarm
docker node ls

# promote a worker to manager
docker node promote worker-node-1

# demote a manager to worker
docker node demote manager-node-1

# leave the swarm (removes node)
docker swarm leave

# force leave the swarm (dangerous on managers)
docker swarm leave --force

# drain a node (stop all services on it)
docker node update --availability drain node-1

# make a node active again
docker node update --availability active node-1

# remove a drained node from the swarm
docker node rm node-1

# inspect a node
docker node inspect node-1

# add labels to a node (for placement constraints)
docker node update --label-add zone=east node-1
```

## Service Management

``` bash
# create a new service
docker service create --name web-app nginx

# create a service with replicas
docker service create --name web-app --replicas 3 nginx

# create a service with resource limits
docker service create --name web-app --limit-cpu 0.5 --limit-memory 512m nginx

# create a service with environment variables
docker service create --name web-app -e NODE_ENV=production nginx

# create a service with port publishing
docker service create --name web-app -p 8080:80 nginx

# list all services
docker service ls

# inspect a service
docker service inspect web-app

# get detailed service status
docker service ps web-app

# update a service
docker service update --replicas 5 web-app

# update service image
docker service update --image nginx:latest web-app

# remove a service
docker service rm web-app

# scale a service
docker service scale web-app=10 db=2
```

## Service Networking

``` bash
# create an overlay network
docker network create --driver overlay my-network

# create an overlay network with options
docker network create --driver overlay --subnet 10.0.9.0/24 my-network

# list networks
docker network ls

# inspect a network
docker network inspect my-network

# connect a service to a network
docker service create --network my-network --name web-app nginx

# remove a network
docker network rm my-network
```

## Service Constraints & Placement

``` bash
# place service only on specific nodes (node ID or hostname)
docker service create --constraint node.hostname==manager-1 --name web-app nginx

# place service only on manager nodes
docker service create --constraint node.role==manager --name web-app nginx

# place service only on nodes with a specific label
docker service create --constraint node.labels.zone==east --name web-app nginx

# place service using node labels for spreading
docker service create --placement-pref spread=node.labels.zone --name web-app nginx
```

## Volumes & Persistent Storage

``` bash
# create a volume
docker volume create my-volume

# use a volume in a service
docker service create --mount type=volume,source=my-volume,target=/data nginx

# use a bind mount
docker service create --mount type=bind,source=/host/path,target=/container/path nginx

# list volumes
docker volume ls

# inspect a volume
docker volume inspect my-volume

# remove a volume
docker volume rm my-volume
```

## Stacks (Compose in Swarm)

``` bash
# deploy a docker-compose file as a stack
docker stack deploy -c docker-compose.yml my-stack

# list all stacks
docker stack ls

# list services in a stack
docker stack services my-stack

# list tasks in a stack
docker stack ps my-stack

# inspect a stack
docker stack inspect my-stack

# update a stack
docker stack deploy -c docker-compose.yml my-stack

# remove a stack (deletes all services)
docker stack rm my-stack
```

## Tasks & Container Management

``` bash
# list all tasks in the swarm
docker service ps web-app

# list tasks on a specific node
docker node ps node-1

# inspect a task
docker inspect task-id

# get logs from a service (all replicas)
docker service logs web-app

# follow service logs
docker service logs -f web-app
```

## Rolling Updates

``` bash
# update a service image with rolling updates
docker service update --image nginx:1.19 web-app

# configure rolling update parallelism and delay
docker service create \
  --update-parallelism 2 \
  --update-delay 10s \
  --name web-app \
  nginx

# monitor rolling update
docker service ps web-app --no-trunc
```

## Secrets & Configs

``` bash
# create a secret (password, token, etc.)
echo "my-secret-value" | docker secret create my-secret -

# create a secret from a file
docker secret create my-secret /path/to/secret/file

# list secrets
docker secret ls

# use a secret in a service
docker service create --secret my-secret --name web-app nginx

# inspect a secret
docker secret inspect my-secret

# remove a secret
docker secret rm my-secret

# create a config object (non-sensitive files)
docker config create my-config /path/to/config/file

# use a config in a service
docker service create --config my-config --name web-app nginx
```

## Monitoring & Troubleshooting

``` bash
# check swarm manager status
docker info | grep Swarm

# view service events in real-time
docker events --filter type=service

# get service logs
docker service logs my-service

# check task history and restart count
docker service ps web-app --no-trunc

# validate a docker-compose.yml for stack deployment
docker stack config -c docker-compose.yml > resolved-compose.yml
```

## Tips & Notes

- Manager nodes run the consensus raft algorithm; maintain an odd number of managers for high availability (1, 3, 5, 7, etc.).
- Services are automatically load-balanced across nodes; no separate load balancer needed.
- Overlay networks handle multi-host networking transparently.
- Use placement constraints (`--constraint`) and preferences (`--placement-pref`) to control service distribution.
- Secrets are encrypted at rest and in transit; use them for sensitive data like passwords and API keys.
- Rolling updates allow zero-downtime deployments; configure with `--update-parallelism` and `--update-delay`.
- Drain a node (`--availability drain`) before maintenance or removal.
- Use `docker stack` for multi-service deployments defined in compose files.
- Service names are automatically DNS resolvable within overlay networks.

---

# Quick reference summary

| Action | Command example |
|---|---|
| Initialize swarm | `docker swarm init` |
| Join swarm | `docker swarm join --token SWMTKN-... 192.168.1.100:2377` |
| List nodes | `docker node ls` |
| Create service | `docker service create --replicas 3 --name web nginx` |
| Scale service | `docker service scale web=5` |
| Update service | `docker service update --image nginx:1.19 web` |
| View logs | `docker service logs web` |
| Deploy stack | `docker stack deploy -c docker-compose.yml my-stack` |
| Remove stack | `docker stack rm my-stack` |
| Drain node | `docker node update --availability drain node-1` |
