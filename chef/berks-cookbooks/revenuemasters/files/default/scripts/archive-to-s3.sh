#!/bin/bash

log_file="/var/log/archive_to_s3.log"
help="Usage: archive-to-s3.sh -s <source path> -b <destination bucket> -k <destination key> -d <retention days>"

while getopts "hs:b:k:d:" opt; do
  case $opt in
    d)
      retention_days=$OPTARG
      ;;
    s)
      source_path=$OPTARG
      ;;
    b)
      destination_bucket=$OPTARG
      ;;
    k)
      destination_key=$OPTARG
      ;;
    h)
      echo "$help"
      exit 0
      ;;
    \?)
      echo "$help"
      exit 1
      ;;
  esac
done

if [[ $source_path == "" ]] || [[ $destination_bucket == "" ]] || [[ $destination_key == "" ]]; then
  echo "$help"
  exit 1
fi

echo "$(date) Syncing..." >> $log_file
aws s3 sync --sse AES256 ${source_path}/ s3://${destination_bucket}/${destination_key}/ >> $log_file 2>&1

if [[ $retention_days != "" ]]; then
  echo "$(date) Deleting files older than $retention_days days from ${source_path}..." >> $log_file
  find $source_path -type f -mtime +$retention_days -delete -print >> $log_file 2>&1
fi
