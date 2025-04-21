#!/usr/bin/env bash
# Backup a MariaDB container using logical backup (mariadb-dump)

NAME=$1
ROOT=$2

if [ -z "$ROOT" ];
then
    echo "Usage: $0 NAME BACKUP_ROOT"
    echo ""
    echo "ARGUMENTS"
    echo "  NAME        Name of the container to backup"
    echo "  BACKUP_ROOT Path to the backup directory"
    echo ""
    exit 1
fi

set -eou pipefail

now=$(date +%Y%m%d)

# Get container
echo "Preparing backup for container '$NAME'"
id=$(docker ps --filter "name=$NAME" --format "{{.ID}}")
echo "Found container with ID '$id'"
mkdir -p "$ROOT/$NAME/"

# Get MariaDB credentials
username=root
password=$(docker exec "$id" bash -c \
    'env | grep -E "(MARIADB|MYSQL)_ROOT_PASSWORD" | cut -d"=" -f2')

# Might be using MARIADB_RANDOM_ROOT_PASSWORD, try to find it in logs
if [ -z "$password" ]
then
    password=$(docker logs "$id" 2>&1 \
        | grep 'GENERATED ROOT PASSWORD' \
        | awk '{print $NF}')
fi

# Worst case we use MariaDB_USERNAME and MariaDB_PASSWORD
if [ -z "$password" ]
then
    username=$(docker exec "$id" bash -c \
        'env | grep -E "(MARIADB|MYSQL)_USERNAME" | cut -d"=" -f2')
    password=$(docker exec "$id" bash -c \
        'env | grep -E "(MARIADB|MYSQL)_PASSWORD" | cut -d"=" -f2')
fi

# Retrieve list of databases
databases=$(docker exec "$id" mariadb \
    -u"$username" \
    -p"$password" \
    -e "SHOW DATABASES;" \
    | grep -v Database)
for database in $databases
do
    if [[ "$database" != "information_schema" ]] \
    && [[ "$database" != "performance_schema" ]] \
    && [[ "$database" != "mysql" ]] \
    && [[ "$database" != "sys" ]] \
    && [[ "$database" != _* ]]
    then
        echo "Dumping database: $database"
        docker exec "$id" mariadb-dump \
            -u"$username" \
            -p"$password" \
            --databases "$database" \
            --single-transaction \
            > "$ROOT/$NAME/$now.$database.sql"
    fi
done
