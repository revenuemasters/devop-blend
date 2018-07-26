#!/usr/bin/env bash

WRITEDOWN_FILE=/encrypted/client_data/wrmc/outgoing/`date +%m%d%Y`_write_down_report.txt
REVERSAL_FILE=/encrypted/client_data/wrmc/outgoing/`date +%m%d%Y`_reversal_report.txt
NON_ADJUSTMENT_FILE=/encrypted/client_data/wrmc/outgoing/`date +%m%d%Y`_non_adjustment_report.txt
NOTES_REPORT_FILE=/encrypted/client_data/wrmc/outgoing/`date --date="1 day ago" +%m%d%Y`RMRANotesReport.txt

cd /var/www/
./run_wrmc.sh wrmc/current/application/cmd/exportWriteDown.php > /encrypted/client_data/wrmc/applogs/`date +%m%d%Y`-writedown-report-generation.txt

export SSHPASS=<%= @sftp_password %>

if [ -e "$WRITEDOWN_FILE" ]
then
  sshpass -e sftp -oBatchMode=no -b - wrmc@sftp-prod-1.revenuemasters.com << !
     cd /outgoing/ar-write-down-and-reversal
     put $WRITEDOWN_FILE
     cd /outgoing/wrmc-daily
     put $WRITEDOWN_FILE
     bye
!
fi

if [ -e "$REVERSAL_FILE" ]
then
  sshpass -e sftp -oBatchMode=no -b - wrmc@sftp-prod-1.revenuemasters.com << !
     cd /outgoing/ar-write-down-and-reversal
     put $REVERSAL_FILE
     cd /outgoing/wrmc-daily
     put $REVERSAL_FILE
     bye
!
fi

if [ -e "$NON_ADJUSTMENT_FILE" ]
then
  sshpass -e sftp -oBatchMode=no -b - wrmc@sftp-prod-1.revenuemasters.com << !
     cd /outgoing/ar-write-down-and-reversal
     put $NON_ADJUSTMENT_FILE
     cd /outgoing/wrmc-daily
     put $NON_ADJUSTMENT_FILE
     bye
!
fi

./run_wrmc.sh wrmc/current/application/cmd/exportNotes.php /encrypted/client_data/wrmc/outgoing/

if [ -e "$NOTES_REPORT_FILE" ]
then
  sshpass -e sftp -oBatchMode=no -b - wrmc@sftp-prod-1.revenuemasters.com << !
     cd /outgoing/ar-write-down-and-reversal
     put $NOTES_REPORT_FILE
     cd /outgoing/wrmc-daily
     put $NOTES_REPORT_FILE
     bye
!
fi
