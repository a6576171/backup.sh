#!/bin/bash

#script for backing up server folders 
#By Isaac Candido

#sets folders for backup 
home=/home/
www=/var/www/
mysql=/var/lib/mysql/
minecraft=/opt/minecraft/

#sets up time variables
ntime=`date +%Y%m%d_%H%M%S`
time="" 
time2="" 
time3=""

#function to update time vars as needed throughout the routine for recording purposes (backups take time!)
timestamp()
{
	time=`date +%Y%m%d_%H%M%S` 
	time2=`date +%F` 
	time3=`date +%T`
	return 0
}

#vars
timestamp
lock=/var/backups/lo.ck #session lock file path
nbkp=svbkp_$ntime.tar.gz #defines the file name
bkpfile=/var/backups/server_backup/$nbkp #defines the backup path, with file name attached
bkpfolder=/var/backups/server_backup/ #defines the backup path, no file name attached
logfile=/var/backups/server_backup/log.txt #defines log file name and path

#statuses
s0="START"
s1="END"
s2="WARNING"
s3="SUCCESS"
s4="FAILED"
s5="NOTICE"

if [ "$(id -u)" -ne 0 ]; then
	echo This script must be run as superuser. >&2
	echo [$time2 $time3] [$s4] User [$USER] has no permissions to run script. Will exit now. >&2 >> ./errorlog.txt
	exit 1
else
		
	if [ -f "$lock" ]; then 
		timestamp
		echo [$time2 $time3] [$s4] Script still running. Wait until it finishes before running it again. >&2
			if [ -f "$logfile" ]; then
				echo [$time2 $time3] [$s4] Script still running. Wait until it finishes before running it again. >> $logfile
				timestamp
				echo [$time2 $time3] [$s4] If you are sure it is not running, see if [$lock] exists and delete it. >> $logfile
				exit 1
			else
				echo [$time2 $time3] [$s4] Script still running. Wait until it finishes before running it again. >> ./errorlog.txt
				timestamp
				echo [$time2 $time3] [$s4] If you are sure it is not running, see if [$lock] exists and delete it. >> ./errorlog.txt
				exit 1
			fi
	else
		echo 'Backup routine locked to one - current - session!' > $lock 
		echo 'As long as this file exists, full backup of this server cannot be done via backup.sh script.' >> $lock
		echo 'Once this file is removed, another instance can be launched.' >> $lock
		echo 'The backup routine automatically removes this file at the end of runtime in order to allow further backups to be run.' >> $lock
		echo 'If this file still exists and no backup is running, probably the backup sequence was interrupted for some reason.' >> $lock
		echo 'If that is the case, please remove it manually.' >> $lock
	fi
	
	#create backup folder if it doesn't already exists; else, proceed.
	mkdir $bkpfolder > /dev/null 2>&1
	if [[ $? -eq 0 ]]
	then
		timestamp
		echo [$time2 $time3] [$s0] Booting up backup routine. Started by user [$USER].	>> $logfile
		timestamp
		echo [$time2 $time3] [$s5] Session locked to this instance via [$lock] file. >> $logfile
		timestamp
		echo [$time2 $time3] [$s2] Backup folder does not seem to exist. >> $logfile
		timestamp
		echo [$time2 $time3] [$s3] Created folder [$bkpfolder]. Moving on. >> $logfile
	else
		timestamp
		echo [$time2 $time3] [$s0] Booting up backup routine. Started by user [$USER]. >> $logfile
		timestamp
		echo [$time2 $time3] [$s5] Session locked to this instance via [$lock] file. >> $logfile
		timestamp
		echo [$time2 $time3] [$s2] Backup folder at [$bkpfolder] already exists. Moving on. >> $logfile
	fi
	
	#enumerate sources and make tarball of them all.
	timestamp
	echo [$time2 $time3] [$s5] Backing up [$home]... >> $logfile
	timestamp
	echo [$time2 $time3] [$s5] Backing up [$www]... >> $logfile
	timestamp
	echo [$time2 $time3] [$s5] Backing up [$mysql]... >> $logfile
	timestamp
	echo [$time2 $time3] [$s5] Backing up [$minecraft]... >> $logfile
	timestamp
	echo [$time2 $time3] [$s5] Will create file [$nbkp]. Running backup routine... >> $logfile
		
	timestamp
	echo [$time2 $time3] [$s0] Running backup routine...
	
	#tarbal!
	tar -cpzf $bkpfile $home $www $mysql $minecraft > /dev/null 2>&1 >> $logfile 
	if [[ $? -ne 1 ]]
	then
		timestamp
		echo [$time2 $time3] [$s3] Backup [$nbkp] file created. >> $logfile
	else
		timestamp
		echo [$time2 $time3] [$s4] Could not create backup file due to some unknown reason. >> $logfile
	fi

	#running removal of backup files found which are older than 7 days.
	timestamp
	echo [$time2 $time3] [$s5] Running old backup removal... >> $logfile
	find $bkpfolder*.gz -ctime +7 | xargs rm -f | sh -x >> $logfile
	if [[ $? -ne 1 ]]
	then 
		timestamp
		echo [$time2 $time3] [$s3] Removed old backup files. Maybe none. >> $logfile
	else
		timestamp
		echo [$time2 $time3] [$s4] Could not remove old backup files. >> $logfile
	fi
	
	if [ -f "$lock" ]; then
		rm $lock
		timestamp
		echo [$time2 $time3] [$s1] Backup routine complete. >> $logfile
		timestamp
		echo [$time2 $time3] [$s3] Backup routine complete. 
		timestamp
		echo [$time2 $time3] [$s1] Refer to [$logfile] for details.
	else
		timestamp
		echo [$time2 $time3] [$s4] Could not remove file [$lock]. Was it already removed? >> $logfile
		timestamp
		echo [$time2 $time3] [$s1] Backup routine complete. >> $logfile
		timestamp
		echo [$time2 $time3] [$s2] Could not unlock session. Was it unlocked manually?
		timestamp
		echo [$time2 $time3] [$s3] Backup routine complete.
		timestamp
		echo [$time2 $time3] [$s1] Refer to [$logfile] for details.		
	fi
fi
