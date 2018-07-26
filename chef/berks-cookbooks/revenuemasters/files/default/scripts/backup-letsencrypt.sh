#!/bin/bash

help="Usage: backup-letsencrypt.sh -d <destination bucket> -r <role>"

while getopts "hd:r:" opt; do
  case $opt in
    d)
      destination_bucket=$OPTARG
      ;;
    r)
      role=$OPTARG
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

if [[ $destination_bucket == "" ]] || [[ $role == "" ]]; then
  echo "$help"
  exit 1
fi

echo "$(date) Creating tarball..."
tar --directory /etc/letsencrypt --create --file=/tmp/$role.tar .
echo "$(date) Uploading tarball to S3..."
aws s3 cp /tmp/$role.tar s3://$destination_bucket/letsencrypt/ --sse
echo "$(date) Removing local copy of tarball..."
rm /tmp/$role.tar
