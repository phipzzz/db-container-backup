#!/bin/bash

keep_days=30 # Number of days to keep the database dumps
backupdir=/volume2/backup/database-container # Path to store the database dumps

function create_backupdir_and_log() {
    if [ ! -d $backupdir ]; then
        mkdir -p -m 660 $backupdir
    fi

    if [ ! -d $backupdir/$container_name ]; then
        mkdir -m 660 $backupdir/$container_name
    fi

    if [ ! -f $backupdir/$container_name.log ]; then
        touch $backupdir/$container_name.log
        chmod 660 $backupdir/$container_name.log
    fi
}

function remove_and_result() {
    filetype=$1

    cd $backupdir/$container_name

    if [[ $(find $timestamp*.$filetype | cut -d"-" -f1,2,3) == $timestamp ]]; then

        function delete_old_backups() {
            find $backupdir/$container_name/*.$filetype -mtime +$keep_days -delete
        }

        old_backups=$($echo find $backupdir/$container_name/*.$filetype -mtime +$keep_days | wc -l)

        if [[ $old_backups = 1 ]]; then
            delete_old_backups
            result="Backup successful! - $old_backups backup older than $keep_days days was deleted."
        elif [[ $old_backups > 1 ]]; then
            delete_old_backups
            result="Backup successful! - $old_backups backups older than $keep_days days were deleted."
        else
            result="Backup successful!"
        fi
    else
        result="Backup failed!"
    fi

    echo -e "$timestamp - $result\n$( < $backupdir/$container_name.log )" > $backupdir/$container_name.log
}

mysql_containers=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'mysql\|mariadb' | cut -d":" -f1)

for container_name in $mysql_containers; do

    create_backupdir_and_log

    MYSQL_DATABASE=$(docker exec $container_name env | grep MYSQL_DATABASE | cut -d"=" -f2)
    MYSQL_PWD=$(docker exec $container_name env | grep MYSQL_ROOT_PASSWORD | cut -d"=" -f2)

    timestamp=$(date +%Y-%m-%d_%H:%M)

    docker exec -e MYSQL_DATABASE=$MYSQL_DATABASE -e MYSQL_PWD=$MYSQL_PWD $container_name /usr/bin/mysqldump -u root $MYSQL_DATABASE > $backupdir/$container_name/$timestamp-$(echo $container_name)_backup.sql

    remove_and_result sql

done

psql_containers=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'postgres' | cut -d":" -f1)

for container_name in $psql_containers; do

    create_backupdir_and_log

    POSTGRES_DB=$(docker exec $container_name env | grep POSTGRES_DB | cut -d"=" -f2)
    POSTGRES_USER=$(docker exec $container_name env | grep POSTGRES_USER | cut -d"=" -f2)

    timestamp=$(date +%Y-%m-%d_%H:%M)

    docker exec $container_name pg_dump $POSTGRES_DB -U $POSTGRES_USER -Fc > $backupdir/$container_name/$timestamp-$(echo $container_name)_backup-Fc.dump

    remove_and_result dump

done