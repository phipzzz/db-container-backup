#!/bin/bash

keep_days=30
backupdir=/volume2/backup/container/

mysql_containers=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'mysql\|mariadb' | cut -d":" -f1)

for container_name in $mysql_containers; do
    if [ ! -d $backupdir/$container_name ]; then
        mkdir $backupdir/$container_name
    fi

    MYSQL_DATABASE=$(docker exec $container_name env | grep MYSQL_DATABASE | cut -d"=" -f2)
    MYSQL_PWD=$(docker exec $container_name env | grep MYSQL_ROOT_PASSWORD | cut -d"=" -f2)
    timestamp=$(date +%Y-%m-%d-%H%M)

    if [[ $MYSQL_DATABASE && $MYSQL_PWD ]]; then

        docker exec -e MYSQL_DATABASE=$MYSQL_DATABASE -e MYSQL_PWD=$MYSQL_PWD $container_name /usr/bin/mysqldump -u root $MYSQL_DATABASE > $backupdir/$container_name/$timestamp-$(echo $container_name)_backup.sql
  
        if [[ $(find $backupdir/$container_name/$timestamp*.sql | cut -d"/" -f7 | cut -d"-" -f1,2,3,4) == $timestamp ]]; then
            echo "$timestamp $container_name - backup successful!"
        else
            echo "Backup failed!"
        fi

        backups_old=$($echo find $backupdir/$container_name/*.sql -mtime +$keep_days | wc -l)
        
        if [[ $backups_old > 0 ]]; then
            find $backupdir/$container_name/*.sql -mtime +$keep_days -delete
            echo "$timestamp $container_name - $backups_old backups older than $keep_days days were deleted."
        fi
    fi
done