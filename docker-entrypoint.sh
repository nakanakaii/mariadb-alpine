#!/bin/sh
set -eu

DATADIR=/var/lib/mysql
SOCKET=/run/mysqld/mysqld.sock

if [ -z "${MARIADB_ROOT_PASSWORD:-}" ] && [ "${MARIADB_ALLOW_EMPTY_ROOT_PASSWORD:-}" != "yes" ]; then
    echo "Set MARIADB_ROOT_PASSWORD or MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=yes" >&2
    exit 1
fi

ROOT_ARGS=""
[ -z "${MARIADB_ROOT_PASSWORD:-}" ] || ROOT_ARGS="--password=$MARIADB_ROOT_PASSWORD"

mkdir -p "$DATADIR" /run/mysqld
chown -R mysql:mysql "$DATADIR" /run/mysqld

if [ ! -d "$DATADIR/mysql" ]; then
    mariadb-install-db \
        --user=mysql \
        --datadir="$DATADIR" \
        --skip-test-db

    mariadbd \
        --user=mysql \
        --datadir="$DATADIR" \
        --skip-networking \
        --socket="$SOCKET" &

    pid=$!

    i=0
    until mariadb-admin --socket="$SOCKET" ping >/dev/null 2>&1; do
        i=$((i + 1))
        [ "$i" -lt 30 ] || exit 1
        sleep 1
    done

    if [ -n "${MARIADB_ROOT_PASSWORD:-}" ]; then
        mariadb --socket="$SOCKET" -uroot <<SQL
ALTER USER 'root'@'localhost'
  IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL
    else
        mariadb --socket="$SOCKET" -uroot <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED BY '';
CREATE USER 'root'@'%' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL
    fi

    if [ -n "${MARIADB_DATABASE:-}" ] && [ -n "${MARIADB_USER:-}" ]; then
        mariadb --socket="$SOCKET" -uroot $ROOT_ARGS <<SQL
CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD:-}';
GRANT ALL PRIVILEGES ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';
FLUSH PRIVILEGES;
SQL
    fi

    mariadb-admin --socket="$SOCKET" $ROOT_ARGS shutdown
    wait "$pid" || true
fi

exec "$@"
