#!/bin/bash

help="Usage: restore-letsencrypt.sh -s <source bucket> -r <role>"

while getopts "hs:r:" opt; do
  case $opt in
    s)
      source_bucket=$OPTARG
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

if [[ $source_bucket == "" ]] || [[ $role == "" ]]; then
  echo "$help"
  exit 1
fi

echo "$(date) Downloading tarball from S3..."
aws s3 cp s3://$source_bucket/letsencrypt/$role.tar /tmp/
echo "$(date) Extracting tarball..."
# --dereference preserves symlinks, which is critical here because certbot will error if it finds a file where it expects a symlink.
tar --directory /etc/letsencrypt --dereference --extract --file=/tmp/$role.tar
echo "$(date) Removing local copy of tarball..."
rm /tmp/$role.tar
