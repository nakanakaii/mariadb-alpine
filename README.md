# MariaDB Alpine

An Alpine-based MariaDB server image built from Alpine Mini Root Filesystem and published to GHCR for:

- `linux/amd64`
- `linux/arm64`

Replace `ghcr.io/YOUR_GITHUB_USERNAME/YOUR_REPOSITORY:latest` below with the image published by this repository.

## Development

This setup leaves the root account without a password and creates one application database and user on first startup.

```yaml
services:
  mariadb:
    image: ghcr.io/YOUR_GITHUB_USERNAME/YOUR_REPOSITORY:latest
    container_name: mariadb-dev
    restart: unless-stopped
    ports:
      - "3306:3306"
    environment:
      MARIADB_ALLOW_EMPTY_ROOT_PASSWORD: "yes"
      MARIADB_DATABASE: app
      MARIADB_USER: app
      MARIADB_PASSWORD: app
    volumes:
      - mariadb_dev_data:/var/lib/mysql

volumes:
  mariadb_dev_data:
```

Start it:

```sh
docker compose up -d
```

The root password is empty in this development configuration:

```sh
docker compose exec mariadb mariadb -uroot
```

Root is also available without a password over TCP, so TablePlus and other MySQL/MariaDB clients can connect with:

```text
Host: 127.0.0.1
Port: 3306
User: root
Password: leave empty
```

Root has full privileges in this development mode, so databases can be created directly from the client:

```sql
CREATE DATABASE project_a;
CREATE DATABASE project_b;
```

The container listens on TCP port `3306` on all interfaces. Keep this development configuration on a trusted local network only.

Create additional development databases as needed:

```sh
docker compose exec mariadb mariadb -uroot -e \
  "CREATE DATABASE IF NOT EXISTS test; CREATE DATABASE IF NOT EXISTS reporting;"
```

The `app` user only receives access to the `app` database. Grant access to additional databases explicitly when required:

```sh
docker compose exec mariadb mariadb -uroot -e \
  "GRANT ALL PRIVILEGES ON test.* TO 'app'@'%'; GRANT ALL PRIVILEGES ON reporting.* TO 'app'@'%'; FLUSH PRIVILEGES;"
```

## Production

Use a non-empty root password and a separate application user. Do not commit real passwords to the repository; use environment variables or Docker secrets in your deployment system.

```yaml
services:
  mariadb:
    image: ghcr.io/YOUR_GITHUB_USERNAME/YOUR_REPOSITORY:latest
    container_name: mariadb
    restart: unless-stopped
    ports:
      - "3306:3306"
    environment:
      MARIADB_ROOT_PASSWORD: ${MARIADB_ROOT_PASSWORD}
      MARIADB_DATABASE: ${MARIADB_DATABASE:-app}
      MARIADB_USER: ${MARIADB_USER:-app}
      MARIADB_PASSWORD: ${MARIADB_PASSWORD}
    volumes:
      - mariadb_data:/var/lib/mysql

volumes:
  mariadb_data:
```

Create a `.env` file locally or provide these values through your deployment platform:

```dotenv
MARIADB_ROOT_PASSWORD=replace-with-a-long-random-root-password
MARIADB_DATABASE=app
MARIADB_USER=app
MARIADB_PASSWORD=replace-with-a-long-random-app-password
```

Start it:

```sh
docker compose up -d
docker compose logs -f mariadb
```

Connect from the host over TCP:

```sh
mariadb -h 127.0.0.1 -P 3306 -u app -p app
```

## Important behavior

- Database and user environment variables are applied only when `/var/lib/mysql` is initialized for the first time.
- Set exactly one root initialization mode: `MARIADB_ROOT_PASSWORD` for production or `MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=yes` for development.
- In development mode, root has no password and is available over TCP for local client tools.
- In production mode, root is local-only; use the configured application user for remote connections.
- Changing passwords or database variables does not change an existing database volume.
- To reset a disposable development database, remove its volume:

  ```sh
  docker compose down -v
  docker compose up -d
  ```

- Do not use an empty root password in production.
- Do not expose port `3306` publicly unless access is restricted by a firewall or private network.

## Build locally

The normal build happens in GitHub Actions. To build locally for the current architecture:

```sh
docker build -t mariadb-alpine:local .
```

## Publish to GHCR

Push to `main` or create a version tag. GitHub Actions builds and publishes both architectures using the repository's automatic `GITHUB_TOKEN`.

The same workflow also runs weekly on Sunday at `03:17 UTC`. It resolves the latest Alpine stable Mini Root Filesystem release and installs the latest MariaDB packages available in that Alpine repository.

The workflow first publishes one fixed `candidate` tag, compares its multi-architecture manifest digest with `latest`, and promotes it to `latest` only when the digest changes. Identical weekly builds therefore leave `latest` untouched and do not create accumulating update tags.

The scheduled build can also be started manually from the repository's **Actions** tab with **Publish MariaDB Alpine Image** → **Run workflow**.

The published image tags are:

```text
ghcr.io/<owner>/<repository>:latest
ghcr.io/<owner>/<repository>:sha-<commit>
```
