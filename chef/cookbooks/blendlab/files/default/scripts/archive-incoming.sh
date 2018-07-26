#/bin/bash

# Move Parallon_FL remits into the proper facility subdirectory
# using the N1*PE COID account number
# Mapping of COID to facilities provided by Ronnie at HCA

src=/ebs/sftp_users/parallon_fl/incoming/remits/all_facilities
for f in `find $src -maxdepth 1 -type f`; do
        #echo $f
        acct=`cat $f | perl -ne '/N1\*PE\*.*\*XX\*([0-9]*)\~/ && print $1."\n"' | sort | uniq`
        case "$acct" in
        "1710931522" | "1255602876")
                #kendall
                mv $f $src/kendall
                echo "$f moved to kendall"
                ;;
        "1760429880" | "1891741849")
                #trinity
                mv $f $src/trinity
                echo "$f moved to trinity"
                ;;
        *)
                # do nothing
                ;;
        esac
done

## Run any custom EDI fixup functions on incoming files before they are archived and moved to 1EDISource
start_dir=`dirname $(readlink -f $0)`
echo Current directory is $start_dir
fixup_dirs=( "/ebs/sftp_users/parallon_fl/incoming/remits/all_facilities/kendall" "/ebs/sftp_users/parallon_fl/incoming/remits/all_facilities/trinity" "/ebs/sftp_users/parallon_rcps/incoming/remits/atchison" "/ebs/sftp_users/parallon_rcps/incoming/remits/north_texas" )

for dir in ${fixup_dirs[@]}
do
    c=`find $dir -maxdepth 1 -type f | wc -l`
    if [ ! -d "$dir/orig/" ]; then
        echo creating missing orig subdirectory in $dir
        mkdir $dir/orig
    fi
    if [ $c -gt 0 ]; then
        echo running CAS*PR and GS08 fixups on $c files in $dir

        ## perl pie needs you to be in the working directory
        cd $dir

        ## back up only the new files to orig.  Do not overwrite existing files.  Orig should have pristine originals.
        cp -n *.dat orig/
        cp -n *.835 orig/

        ## fix GS08 to be std 835 instead of HIPAA.  
        perl -pi -e 's/(GS\*.*?\*005010)X221A1~/$1~/g' *.*

        ## fix GS08 to be std 835 instead of HIPAA in BCBS with caret ^ separator.
        perl -pi -e 's/(GS\^*.*?\^005010)X221A1~/$1~/g' BCBS-B*

        for i in *; do perl /root/scripts/rawfilepreprocessor.pl $i ; done

        ## fix CAS*XX multi-item replace ** with *XX*.  Originals not backed up since they're already in orig/ from above fix
        ## perl -pi -e '@a=split("~",$_); for $i (0..$#a) { $a[$i]=~s/\*\*/\*PR\*/g if $a[$i] =~ /^CAS\*PR/; } $_=join("~",@a)' *.*
        ## perl -pi -e '@a=split("~",$_); for $i (0..$#a) { $a[$i]=~s/\*\*/\*CO\*/g if $a[$i] =~ /^CAS\*CO/; } $_=join("~",@a)' *.*
        ## perl -pi -e '@a=split("~",$_); for $i (0..$#a) { $a[$i]=~s/\*\*/\*OA\*/g if $a[$i] =~ /^CAS\*OA/; } $_=join("~",@a)' *.*
        ## perl -pi -e '@a=split("~",$_); for $i (0..$#a) { $a[$i]=~s/\*\*/\*PI\*/g if $a[$i] =~ /^CAS\*PI/; } $_=join("~",@a)' *.*
        ## perl -pi -e '@a=split("~",$_); for $i (0..$#a) { $a[$i]=~s/\*\*/\*CR\*/g if $a[$i] =~ /^CAS\*CR/; } $_=join("~",@a)' *.*

        ## Apply ^PR^ fix to BCBS remit files that use ^ separator.  Cannot use tr to globally replace since we need ^ in the ISA header
        ## perl -pi -e '@a=split("~",$_); for $i (0..$#a) { $a[$i]=~s/\^\^/\^PR\^/g if $a[$i] =~ /^CAS\^PR/; } $_=join("~",@a)' BCBS-B*
        ## perl -pi -e '@a=split("~",$_); for $i (0..$#a) { $a[$i]=~s/\^\^/\^CO\^/g if $a[$i] =~ /^CAS\^CO/; } $_=join("~",@a)' BCBS-B*
        ## perl -pi -e '@a=split("~",$_); for $i (0..$#a) { $a[$i]=~s/\^\^/\^OA\^/g if $a[$i] =~ /^CAS\^OA/; } $_=join("~",@a)' BCBS-B*
        ## perl -pi -e '@a=split("~",$_); for $i (0..$#a) { $a[$i]=~s/\^\^/\^PI\^/g if $a[$i] =~ /^CAS\^PI/; } $_=join("~",@a)' BCBS-B*
        ## perl -pi -e '@a=split("~",$_); for $i (0..$#a) { $a[$i]=~s/\^\^/\^CR\^/g if $a[$i] =~ /^CAS\^CR/; } $_=join("~",@a)' BCBS-B*

        echo Done transform
    else
        echo No remits to transform for CAS*PR in $dir
    fi
done
cd $start_dir
echo restored `pwd`

## do the archive
#cp -pR /ebs/sftp_users/* /ebs/sftp_archive/
archive=/ebs/sftp_archive/
logDir=/root/scripts/logs
logFile=$logDir/`date +"%Y-%m-%d-%H-%M"`_rsync.log

echo Starting rsync to backup
rsync -a --log-file=$logFile /ebs/sftp_users/* $archive
echo Done rsync incoming to archive folder

chgrp -R sftp_parallon_archive /ebs/sftp_archive/parallon_fl/incoming/*
chgrp -R sftp_parallon_archive /ebs/sftp_archive/parallon_rcps/incoming/*
chmod -R 755 /ebs/sftp_archive/parallon_fl/*
chmod -R 755 /ebs/sftp_archive/parallon_rcps/*

## Remove the late charges from pickup directory.  They're not used.
## Already copied to archive above for safekeeping
dir=/ebs/sftp_users/parallon_rcps/incoming/files/atchison
c=`find $dir -maxdepth 1 -name ATCH_TOG_latechgs\* -type f | wc -l`
if [ $c -gt 0 ]; then
    echo removing latechgs files
    rm $dir/ATCH_TOG_latechgs*
fi

## add group to allow edisource to delete files
chgrp -R sftp_parallon_fl /ebs/sftp_users/parallon_fl/incoming/*
chgrp -R sftp_parallon_rcps /ebs/sftp_users/parallon_rcps/incoming/*
chmod -R 775 /ebs/sftp_users/parallon_fl/incoming/*
chmod -R 775 /ebs/sftp_users/parallon_rcps/incoming/*
