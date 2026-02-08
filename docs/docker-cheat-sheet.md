# MySQL Docker Cheat Sheet

What are the useful commands we need to run MySQL in Docker.

This assumes we have used a Docker compose file to start up the service.

## Installation

- Install Docker Desktop for Mac
- Insatll Docker credential helper

  ``` bash
  brew install docker-credential-helper
  docker-credential-osxkeychain version
  ```

- Update `~/.docker/config.json`

  ``` bash
  {
    "auths": {
        "https://index.docker.io/v1/": {}
    },
    "credsStore": "osxkeychain",
    "currentContext": "desktop-linux",
      :
    ```

- Login to Docker

  ``` bash
  docker login -u $USER
  ```



## Start / Stop / Recreate (Compose)

``` bash
# start services in background (detached)
docker compose up -d

# stop and remove containers, networks (preserves volumes)
docker compose down

# stop and remove containers AND volumes (data loss)
docker compose down -v

# rebuild images and recreate containers
docker compose build --no-cache && docker compose up -d
```

## Useful Container Commands

``` bash
# list running containers
docker ps

# list all containers (including stopped)
docker ps -a

# inspect container metadata (config, env, networks)
docker inspect some-mysql

# get container IP (useful when not using host ports)
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' some-mysql

# show published ports for a container
docker port some-mysql

# show processes running in container
docker top some-mysql

# remove stopped containers (interactive prompt)
docker container prune
```

## Container Shell Access

``` bash
docker exec -it some-mysql bash
```

## Docker Container Logs

``` bash
# show all logs
docker logs some-mysql

# follow logs (live)
docker logs -f some-mysql

# show only last 100 lines
docker logs --tail 100 some-mysql
```

## Running the MySQL Client

``` bash
# run a throwaway MySQL client container on the same network
docker run -it --network some-network --rm mysql mysql -hsome-mysql -uexample-user -p

# run the mysql client inside a running container
docker exec -it some-mysql mysql -uroot -p
```

## Backup and Restore

``` bash
# backup all databases to a file on the host
docker exec some-mysql sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases' > all-databases.sql

# backup and gzip on the fly
docker exec some-mysql sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases' | gzip > all-databases.sql.gz

# restore from a dump on the host
cat all-databases.sql | docker exec -i some-mysql sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD"'
```

## File Copying

``` bash
# copy a file from host into container
docker cp dump.sql some-mysql:/tmp/dump.sql

# copy a file from container to host
docker cp some-mysql:/tmp/dump.sql ./dump.sql
```

## Volumes & Data

- Use named volumes in `docker-compose.yml` for persistent MySQL data (do not rely on the container filesystem).
- To remove volumes created by compose: `docker compose down -v` (this deletes data).

## Tips & Notes

- Use `--rm` for ephemeral one-off containers so stopped containers don't accumulate (cannot be used with `-d`).
- `-d` (or `--detach`) runs containers in the background and returns immediately; use with `docker logs -f` to follow output.
- Prefer `docker compose` (space) over legacy `docker-compose` where available.
- When exposing MySQL to the host, consider binding to `127.0.0.1` to avoid exposing it publicly.

---

# Quick reference summary

| Action | Command example |
|---|---|
| Start services | `docker compose up -d` |
| Stop & remove | `docker compose down` |
| Logs (follow) | `docker logs -f some-mysql` |
| Backup | `docker exec some-mysql mysqldump ... > dump.sql` |
| Restore | `cat dump.sql | docker exec -i some-mysql mysql ...` |
