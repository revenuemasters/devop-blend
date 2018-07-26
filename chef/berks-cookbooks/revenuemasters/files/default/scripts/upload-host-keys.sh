#!/bin/bash

# This script checks to see if SSH keys for this host exist in S3 and uploads any that are missing.
# This was added to ensure that servers in new environments can self-provision.

help="Usage: upload-host-keys.sh -s <full source local path> -d <full destination s3 path>"

while getopts "hs:d:" opt; do
  case $opt in
    s)
      source_path=$OPTARG
      ;;
    d)
      destination_path=$OPTARG
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

if [[ $source_path == "" ]] || [[ $destination_path == "" ]]; then
  echo "$help"
  exit 1
fi

echo "Checking for ${destination_path}..."
exists=$(aws s3 ls $destination_path 2>&1)
exit_code=$?
echo $exists

if [[ $exit_code == '1' ]] && [[ $exists == '' ]]; then
  echo "$(date) Didn't find ${destination_path}, uploading ours..."
  aws s3 cp --sse AES256 $source_path $destination_path
fi
