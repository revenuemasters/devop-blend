#!/bin/bash

php_root=/usr/bin/php
fix_repetitive_files=/root/scripts/fix-repetitive-files.php

now=$(date +"%m-%d-%Y %H:%M %Z")
logFile=$(date +"%Y-%m-%d-%H-%M")_rsync.log
logFile=/root/scripts/logs/$logFile
incoming=/encrypted/sftp/
archive=/encrypted/sftp_automated_backup/
start_dir=$(dirname $(readlink -f $0))
echo Current directory is $start_dir

fixup_dirs=("$incoming/mhermann/incoming/remits" "$incoming/revworkscm/incoming/remits" "$incoming/tyroneinstitutional/incoming/remits")
echo checking folders for perl PR transform
for dir in ${fixup_dirs[@]}; do
  c=$(find $dir -maxdepth 1 -type f | wc -l)
  if [ ! -d "$dir/orig/" ]; then
    echo creating missing orig subdirectory in $dir
    mkdir $dir/orig
  fi
  if [ $c -gt 0 ]; then
    echo running CAS*PR fixup and GS08 fixup on $c files in $dir

    ## perl pie needs you to be in the working directory
    cd $dir

    ## back up only the new files to orig.  Do not overwrite existing files.  Orig should have pristine originals.
    cp -n *.* orig/

    ## replace pipe with * in some files
    sed -i "s/|/*/g" S835_*

    ## fix GS08 to be std 835 instead of HIPAA.
    perl -pi -e 's/(GS.*?005010)X221A1/$1/g' *.*

    ## fix GS08 to be std 835 instead of HIPAA in BCBS with caret ^ separator.
    ## perl -pi -e 's/(005010)X221A1~/$1~/g' BCBS-B*

    for i in *; do perl /root/scripts/rawfilepreprocessor.pl $i; done

    echo Done transform
  else
    echo No files to fix up in $dir
  fi
done
cd $start_dir

echo Fix problem with repetitive files
$php_root $fix_repetitive_files
echo Done fix problem with repetitive files

echo Starting rsync to archive
rsync -a --exclude='rmedi' --exclude='sftptest' --exclude='wrmcstaging' --exclude='*.filepart' --log-file=$logFile $incoming $archive
echo Done rsync incoming to archive folder

## Make all files available to rmedi user
chown rmedi:rmedi $archive/* -R

for dir in /encrypted/sftp/*; do
  client=$(basename $dir)
  targetDir=/encrypted/rmedi/incoming/$client
  if [ ! -d "$targetDir" ]; then
    mkdir $targetDir
  fi

  if [ ! -d "$dir/incoming/" ]; then
    echo Source directory $dir/incoming/ not found ... skipping
    continue
  fi
  echo -e "\nsyncing $client"

  rsync -av --blocking-io --exclude='*.filepart' --remove-source-files $dir/incoming/ $targetDir/
  chown rmedi:rmedi $targetDir -R
  chmod 0770 $targetDir -R
done

echo script completed
