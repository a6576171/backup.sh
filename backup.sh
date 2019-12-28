#!/bin/bash

# script for backing up server folders AND sql data
# It has a LOT of room for improvement, but it currently does meet my needs.
# I'll update it as I go.
# By Isaac Candido

#sets up time variables
ntime=`date +%Y%m%d_%H%M%S`
time="" 
time2="" 
time3=""

#function to update time vars as needed throughout the routine for recording and logging purposes (backups take time!)
timestamp()
{
	time=`date +%Y%m%d_%H%M%S` 
	time2=`date +%F` 
	time3=`date +%T`
	return 0
}

# final file vars
home=/home/
www=/var/www/
mysql=/etc/mysql
timestamp
bkpfolder=/var/backups/full_server_backup #defines the backup path, no file name attached
lock=/var/backups/lo.ck #session lock file path
nbkp=svrbkp_$ntime.tar.gz #defines the file name
bkpfile=$bkpfolder/$nbkp #defines the backup path, with file name attached
logfile=$bkpfolder/log.log #defines log file name and path

# database vars
db_name='db_name'
db_user='db_user'
db_pass='db_pass'
# backup_parameters='--add-drop-table --add-locks --extended-insert --single-transaction -quick' >>>>>>> I don't use parameters, myself.
backup_command=mysqldump
sql_bkpname=$db_name_mysql-$ntime.sql
mysql_created_file_full_path=$bkpfolder/$sql_bkpname

# statuses, for logging purposes.
s0="START"
s1="END"
s2="WARNING"
s3="SUCCESS"
s4="FAILED"
s5="NOTICE"

if [ "$(id -u)" -ne 0 ]; then
	# Since the script accesses root-owned folders, it MUST be run as root.  
	echo This script must be run as superuser. >&2
	echo [$time2 $time3] [$s4] User [$USER] has no permissions to run script. Will exit now. >&2 >> ./errorlog.txt
	exit 1
else
	if [ -f "$logfile" ]; then 
		timestamp
		echo [$time2 $time3] [$s4] Script still running. Wait until it finishes before running it again. >&2
			if [ -f "$lock" ]; then
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
		echo 'As long as this file exists, full backup of this server cannot be done via this backup.sh script.' >> $lock
		echo 'Once this file is removed, another instance can be launched.' >> $lock
		echo 'The backup routine automatically removes this file at the end of runtime in order to allow further backups to be run.' >> $lock
		echo 'If this file still exists and no backup is running, probably the backup sequence was interrupted for some reason.' >> $lock
		echo 'If that is the case, you should check the logfile for errors and will have to remove the lo.ck file manually.' >> $lock
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
		echo [$time2 $time3] [$s3] Created folder [$bkpfolder/]. Moving on. >> $logfile
	else
		timestamp
		echo [$time2 $time3] [$s0] Booting up backup routine. Started by user [$USER]. >> $logfile
		timestamp
		echo [$time2 $time3] [$s5] Session locked to this instance via [$lock] file. >> $logfile
		timestamp
		echo [$time2 $time3] [$s2] Backup folder at [$bkpfolder/] already exists. Moving on. >> $logfile
	fi
	
	#Run SQL backup
	timestamp 
	echo [$time2 $time3] [$s0] Running MYSQL dump for database [$db_name] at [$bkpfolder/$sql_bkpname]... >> $logfile 
	$backup_command -u $db_user -p$db_pass $db_name > $mysql_created_file_full_path
	if [[ $? -ne 1 ]]
	then
		timestamp
		echo [$time2 $time3] [$s3] Backup from database [$db_name] created. >> $logfile
	else
		timestamp
		echo [$time2 $time3] [$s4] Could not create backup file due to some unknown reason. Will proceed without it. >> $logfile
	fi
		
	# enumerate sources and make tarball of them all.
	timestamp
	echo [$time2 $time3] [$s5] Backing up [$home]... >> $logfile
	timestamp
	echo [$time2 $time3] [$s5] Backing up [$www]... >> $logfile
	timestamp
	echo [$time2 $time3] [$s5] Backing up database [$db_name]... >> $logfile
	timestamp
	echo [$time2 $time3] [$s5] Will create file [$nbkp]. Tarballing... >> $logfile

	# tarbal!
	tar -cpzf $bkpfile $home $www $mysql_created_file_full_path > /dev/null 2>&1 >> $logfile 
	if [[ $? -ne 1 ]]
		then
			# remove .sql file created upon backup routine since it's already tarballed - hopefully!
			# Yes, this script "hopes" stuff will work. So do I.
			timestamp
			echo [$time2 $time3] [$s5] Attempting to remove SQL backup file at [$mysql_created_file_full_path]... >> $logfile
			rm -rf $mysql_created_file_full_path
			if [[ $? -ne 1 ]]
			then 
				timestamp
				echo [$time2 $time3] [$s3] SQL dump file at [$mysql_created_file_full_path] removed successfully. >> $logfile
			else
				timestamp
				echo [$time2 $time3] [$s4] Could not remove SQL dump file at [$mysql_created_file_full_path]. >> $logfile
			fi	
			timestamp
			echo [$time2 $time3] [$s3] Backup [$nbkp] file created. >> $logfile
		else
			timestamp
			echo [$time2 $time3] [$s4] Could not create backup file due to some unknown reason. >> $logfile
	fi

	#running removal of backup files found which are older than 7 days.
	timestamp
	echo [$time2 $time3] [$s5] Running old backup removal... >> $logfile
	find $bkpfolder/*.gz -ctime +7 | xargs rm -f | sh -x >> $logfile
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
