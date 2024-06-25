#!/bin/bash

keep_days=30
backupdir=/volume2/backup/container/

psql_containers=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'postgres' | cut -d":" -f1)

for container_name in $psql_containers; do
    if [ ! -d $backupdir/$container_name ]; then
        mkdir $backupdir/$container_name
    fi

    POSTGRES_DB=$(docker exec $container_name env | grep POSTGRES_DB | cut -d"=" -f2)
    POSTGRES_USER=$(docker exec $container_name env | grep POSTGRES_USER | cut -d"=" -f2)
    timestamp=$(date +%Y-%m-%d-%H%M)

    if [[ $POSTGRES_DB && $POSTGRES_USER ]]; then

        docker exec $container_name pg_dump $POSTGRES_DB -U $POSTGRES_USER -Fc > $backupdir/$container_name/$timestamp-$(echo $container_name)_backup-Fc.dump

        if [[ $(find $backupdir/$container_name/$timestamp*.dump | cut -d"/" -f7 | cut -d"-" -f1,2,3,4) == $timestamp ]]; then
            echo "$timestamp $container_name - backup successful!"
        else
            echo "Backup failed!"
        fi

        backups_old=$($echo find $backupdir/$container_name/*.dump -mtime +$keep_days | wc -l)
        
        if [[ $backups_old > 0 ]]; then
            find $backupdir/$container_name/*.dump -mtime +$keep_days -delete
            echo "$timestamp $container_name - $backups_old backups older than $keep_days days were deleted."
        fi
    fi
done