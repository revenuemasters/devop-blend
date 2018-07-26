#!/bin/bash
# CLIENT : <%= @client %>
now=`date +"%m-%d-%Y %H:%M %Z"`
logFile=`date +"%Y-%m-%d"`_<%= @client %>_sftp.log
mkdir -p /var/log/sftp
logFile=/var/log/sftp/$logFile
rm $logFile
touch $logFile

recipient=appmonitor@revenuemasters.com
client=<%= @client %>
for batchFile in claims remits payments ucrns
do
    batchPath=/home/appproc/$client.$batchFile.txt
    echo checking $client remote $batchFile
    sshpass -p <%= @password %> sftp -oBatchMode=no -b $batchPath <%= @user %>@<%= @host %> >> $logFile 2>&1
done

# read logFile into variable
fileData=`cat $logFile`

# send logFile to recipient
subject="<%= @client %> sftp fetch complete"
echo -e "<%= @client %> sftp fetch completed at $now.\nFiles retrieved are shown below.\n $fileData" | mail -s $subject $recipient
