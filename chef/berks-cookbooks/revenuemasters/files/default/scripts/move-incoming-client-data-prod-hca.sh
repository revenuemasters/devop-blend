#!/bin/bash

now=`date +"%m-%d-%Y %H:%M %Z"`
logFile=`date +"%Y-%m-%d-%H-%M"`_rsync.log
logFile=/root/scripts/logs/$logFile
incoming=/encrypted/sftp/
archive=/encrypted/sftp_automated_backup/
start_dir=`dirname $(readlink -f $0)`
echo Current directory is $start_dir

cd $start_dir

echo Starting rsync to archive
rsync -a --exclude='atchison' --exclude='atchisoninstitutionalstaging' --exclude='northtexasstaging' --exclude='parflpilot' --exclude='*.filepart' --log-file=$logFile $incoming  $archive
echo Done rsync incoming to archive folder

## Make all files available to rmedi user
chown rmedi:rmedi $archive/* -R;

for dir in /encrypted/sftp/*
do
  client=`basename $dir`;

  if [ $client = 'atchison' ] || [ $client = 'atchisoninstitutionalstaging' ] || [ $client = 'northtexasstaging' ] || [ $client = 'parflpilot' ]; then
        continue
  fi

  targetDir=/encrypted/rmedi/incoming/$client;
  if [ ! -d "$targetDir" ]; then
        mkdir $targetDir ;
  fi

  if [ ! -d "$dir/incoming/" ]; then
        echo Source directory $dir/incoming/ not found ... skipping
        continue
  fi
  echo -e "\nsyncing $client"

  rsync -av --blocking-io --exclude='*.filepart' --remove-source-files $dir/incoming/ $targetDir/
  chown rmedi:rmedi $targetDir -R;
  chmod 0770 $targetDir -R;
done

echo script completed
