#!/bin/bash

# check for required env variables
: "${MYSQL_DATABASE:?Need to set MYSQL_DATABASE}"
: "${MYSQL_DUMP_DIR:?Need to set MYSQL_DUMP_DIR}"
: "${MYSQL_HOST:?Need to set MYSQL_HOST non-empty}"
: "${MYSQL_PASSWORD:?Need to set MYSQL_PASSWORD}"
: "${MYSQL_USER:?Need to set MYSQL_USER}"

file=$MYSQL_DUMP_DIR/`date +%m-%d-%y`_dump.sql

function log {
    echo "`date` $2"
    logger -p local1.$1 "`date` Mysql Export: $2"
}

function log_info {
    log info "$1"
}

function log_error {
    log error "$1"
}

function error {
    log_error "Backup failed."
    exit 1
}

log_info "Starting mysqldump to $file"
mysqldump -q --single-transaction -u $MYSQL_USER -p$MYSQL_PASSWORD -h $MYSQL_HOST $MYSQL_DATABASE > $file
if [ $? -ne 0 ]; then
    error 'Error creating backup'
fi

log_info "Compressing $file"
gzip --force $file
if [ $? -ne 0 ]; then
    error "Error compressing $file"
fi

log_info "Removing uncompressed backup: $file"
/bin/rm -f $file
if [ $? -ne 0 ]; then
    error "Error removing uncompressed backup: $file"
fi

log_info "Backup Successful."

exit 0
