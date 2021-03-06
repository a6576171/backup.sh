#!/bin/bash

# Script for backing up server directories AND sql data
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
db_name='database_name'
db_user='database_username'
db_pass='database_password'

home=/home/
www=/var/www/
mysql=/etc/mysql/$db_name-backup
timestamp
bkpfolder=/var/backups/full_server_backup #defines the backup path, no file name attached
lock=/var/backups/lo.ck #session lock file path
nbkp=svrbkp_$ntime.tar.gz #defines the file name
bkpfile=$bkpfolder/$nbkp #defines the backup path, with file name attached
logfile=$bkpfolder/log.log #defines log file name and path
include_sql=yes

backup_parameters='--add-drop-table --complete-insert --extended-insert --single-transaction --quick --lock-tables=false'
backup_command=mysqldump
sql_bkpname=$db_name-$ntime.sql
mysql_created_file_full_path=$mysql/$sql_bkpname

# statuses, for logging purposes.
s0="START"
s1="END"
s2="WARNING"
s3="SUCCESS"
s4="FAILED"
s5="NOTICE"

if [ "$(id -u)" -ne 0 ]; then
	# Since the script accesses root-owned directories, it MUST be run as root.  
	echo This script must be run as superuser. >&2
	echo [$time2 $time3] [$s4] User [$USER] has no permissions to run script. Will exit now. >&2 >> ./errorlog.txt
	exit 1
else
	if [ -f "$lock" ]; then 
		timestamp
		echo [$time2 $time3] [$s4] Script still running. Wait until it finishes before running it again. >&2
			if [ -f "$logfile" ]; then
				echo [$time2 $time3] [$s4] Another instance is running. Wait until it finishes before running it again. >> $logfile
				timestamp
				echo [$time2 $time3] [$s4] If you are sure it is not running, see if [$lock] exists and delete it. >> $logfile
				exit 1
			else
				echo [$time2 $time3] [$s4] Another instance is running. Wait until it finishes before running it again. >> ./errorlog.txt
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
	
	timestamp
	echo [$time2 $time3] [$s0] Booting up backup routine. Started by user [$USER].
		
	if [ ! -d "$bkpfolder" ]
	then
		# create backup directory if it doesn't already exists; else, proceed.
		mkdir $bkpfolder > /dev/null 2>&1
		if [[ $? -eq 0 ]]
		then
			timestamp
			echo [$time2 $time3] [$s0] Booting up backup routine. Started by user [$USER].	>> $logfile
			timestamp
			echo [$time2 $time3] [$s5] Session locked to this instance via [$lock] file. >> $logfile
			timestamp
			echo [$time2 $time3] [$s3] Backup directory does not seem to exist. Created directory at [$bkpfolder/]. Proceeding to backup. >> $logfile
		fi
	else
		timestamp
		echo [$time2 $time3] [$s2] Backup directory at [$bkpfolder/] already exists. Proceeding to backup. >> $logfile
	fi
	
	# Run packages list export.
	# Read below.
	echo 'Installed packages exported.' > /home/READ.ME
	echo 'Very important!' >> /home/READ.ME
	echo 'The list can be used to install the same packages in the next OS installation, to be a clone of this one.'>> /home/READ.ME
	echo 'In order to install the packages in the new installation, run:'>> /home/READ.ME
	echo 'sudo xargs -a packages_list.txt apt install' >> /home/READ.ME
	echo 'But, before you restore your packages, you gotta restore apt directory AND update apt.' >> /home/READ.ME
	# for user information, I will leave this info in a readme file.
			
	# so...
	# Make a copy of the whole apt directory to /home.
	/bin/cp -rf /etc/apt/ /home/apt_backup/
	
	dpkg-query -f '${binary:Package}\n' -W > /home/packages_list.txt
	if [ -f "/home/packages_list.txt" ]
	then 
		timestamp 
		echo [$time2 $time3] [$s3] Exported installed packages list to "/home/packages_list.txt"... >> $logfile 
	else
		timestamp 
		echo [$time2 $time3] [$s3] Could not create packages list in "/home/packages_list.txt". >> $logfile 
	fi
	
	# Make a copy of the whole apt directory to /home.
	/bin/cp -rf /etc/apt/ /home/apt_backup/
	
	if [ -d "/home/apt_backup/" ]
	then 
		timestamp 
		echo [$time2 $time3] [$s3] Created a copy of your /etc/apt/ directory... >> $logfile 
	else
		timestamp 
		echo [$time2 $time3] [$s3] Could not create a copy of your /etc/apt/ directory. >> $logfile 
	fi
	
	# Run SQL backup
	timestamp 
	echo [$time2 $time3] [$s0] Running MYSQL dump for database [$db_name] at [$mysql_created_file_full_path]... >> $logfile 
	
	timestamp
	echo [$time2 $time3] [$s5] Creating temporary directory for MYSQL dump at [$mysql]. >> $logfile
	# COMMAND
	mkdir $mysql > /dev/null 2>&1
	
	# if sql backup directory was created, proceed to backing up stuff.
	if [[ -d "$mysql" ]]
	then
		timestamp
		echo [$time2 $time3] [$s3] Directory [$mysql] created. >> $logfile
		# COMMAND	
		$backup_command -u $db_user -p$db_pass $db_name $backup_parameters > $mysql_created_file_full_path
		
		# if backup succeeds, include sql in final backup. Else, don't.
		if [[ $? -ne 1 ]]
		then
			timestamp
			echo [$time2 $time3] [$s3] Backup from database [$db_name] created. >> $logfile
			include_sql=yes
			timestamp
			echo [$time2 $time3] [$s5] Backup will include MYSQL dump in final file. >> $logfile
		else
			timestamp
			echo [$time2 $time3] [$s4] Could not create backup file at [$mysql_created_file_full_path]. Skipping MYSQL backup. >> $logfile
			rm -rf $mysql
			include_sql=no
			timestamp
			echo [$time2 $time3] [$s2] Will not backup MYSQL database due to errors. >> $logfile
			timestamp
			echo [$time2 $time3] [$s2] Will not backup MYSQL database due to errors. See log file for details.
		fi
	else
		timestamp
		echo [$time2 $time3] [$s4] Could not create directory at [$mysql]. Skipping MYSQL backup. >> $logfile
		include_sql=no
		timestamp
		echo [$time2 $time3] [$s2] Will not backup MYSQL database due to errors. >> $logfile
		timestamp
		echo [$time2 $time3] [$s2] Will not backup MYSQL database due to errors. See log file for details.
	fi
		
	# Enumerate sources and make tarball of them all.
	timestamp
	echo [$time2 $time3] [$s5] Adding to backup list: [$home]... >> $logfile
	timestamp                            
	echo [$time2 $time3] [$s5] Adding to backup list: [$www]... >> $logfile
	
	if [[ $include_sql -eq no ]]
	then
		timestamp
		echo [$time2 $time3] [$s5] Adding to backup list: backup for database [$db_name]... >> $logfile
	fi
	
	timestamp
	echo [$time2 $time3] [$s5] Will create file [$nbkp]. Tarballing... >> $logfile

	# tarball!
	if [[ $include_sql -eq no ]]
	then 
		tar -cpzf $bkpfile $home $www $mysql_created_file_full_path > /dev/null 2>&1
	else
		tar -cpzf $bkpfile $home > /dev/null 2>&1
	fi
		
	if [[ $? -ne 1 ]]
		then
			timestamp
			echo [$time2 $time3] [$s5] Tarball created successfully at [$bkpfile]. >> $logfile
		
			if [[ $include_sql -eq no ]]
				then
				# if sql is included in final file:
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
				echo [$time2 $time3] [$s5] Attempting to remove SQL backup directory at [$mysql]... >> $logfile
				rm -rf $mysql
				if [[ $? -ne 1 ]]
				then 
					timestamp
					echo [$time2 $time3] [$s3] SQL backup directory at [$mysql] removed successfully. >> $logfile
				else
					timestamp
					echo [$time2 $time3] [$s4] Could not remove SQL backup directory at [$mysql]. >> $logfile
				fi					
				timestamp
				echo [$time2 $time3] [$s3] Backup file [$nbkp] created. >> $logfile
			fi
		else
			timestamp
			echo [$time2 $time3] [$s4] Could not create backup due to some unknown reason. >> $logfile
	fi

	#running removal of backup files found which are older than 7 days.
	timestamp
	echo [$time2 $time3] [$s5] Running old backup removal... >> $logfile
	find $bkpfolder/*.gz -ctime +7 | xargs rm -f | sh -x >> $logfile
	if [[ $? -ne 1 ]]
	then 
		timestamp
		echo [$time2 $time3] [$s3] Removed old backup files. >> $logfile
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
