#!/usr/bin/env bash

NAME=$1
ROOT=$2

if [ -z $ROOT ];
then
    echo "Usage: $0 NAME BACKUP_ROOT"
fi

# Get container
echo "Preparing backup for $NAME"
id=$(docker ps --filter "name=$NAME" --format "{{.ID}}")
mkdir -p $ROOT/$NAME/

# Get MySQL credentials
username=root
password=$(docker exec $id bash -c 'echo $MYSQL_ROOT_PASSWORD')

# Might be using MYSQL_RANDOM_ROOT_PASSWORD, try to find it in logs
if [ -z "$password" ]; then
    password=$(docker logs $id 2>&1 | grep 'GENERATED ROOT PASSWORD' | awk '{print $NF}')
fi

# Worst case we use MYSQL_USERNAME and MYSQL_PASSWORD
if [ -z "$password" ]; then
    username=$(docker exec $id bash -c 'echo $MYSQL_USERNAME')
    password=$(docker exec $id bash -c 'echo $MYSQL_PASSWORD')
fi

# Retrieve list of databases
databases=$(docker exec $id mysql -uroot -p$password -e "SHOW DATABASES;" | grep -v Database)
for database in $databases; do
    if [[ "$database" != "information_schema" ]] && [[ "$database" != "performance_schema" ]] && [[ "$database" != "mysql" ]] && [[ "$database" != _* ]] ; then
        echo "Dumping database: $database"
        docker exec $id mysqldump -uroot -p$password --databases $database > $ROOT/$NAME/`date +%Y%m%d`.$database.sql
    fi
done
