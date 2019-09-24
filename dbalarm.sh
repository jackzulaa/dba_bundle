# #####################################################################################################################################################
# Database Server Monitoring Script [dbalarm].
VER="[6.6]"
SCRIPT_NAME="dbalarm${VER}"
# Features:
# Report ERRORS in DB, ASM Instance, GRID INFRASTRUCTURE, GOLDENGATE and LISTENERS ALERTLOG plus dmesg DEVICE DRIVER OS log.
# Report TABLESPACES, ASM DISKGROUPS and FRA when reach %USED THRESHOLD.
# Report OFFLINE databases.
# Report CPU, FILESYSTEM, TABLESPACES When hit the THRESHOLD.
# Report LONG RUNNING operations/Active SESSIONS on DB when the CPU hits the THRESHOLD.
# Report BLOCKING SESSIONS in the database.
# Report Failed RMAN Backup Jobs.
# Report User Defined DATABASE SERVICES when they go OFFLINE.
# Notes:
# Most of THRESHOLD and CONTROLS in this script located under THRESHOLDS section. Please adjust them to meet your needs.
# #####################################################################################################################################################
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      22-12-13            #   #   # #   #  
#
# Modified:     23-12-13 Handled non exist logs 1run
#               14-05-14 Handled non existance of LOG_DIR directory.
#               18-05-14 Add Filsystem monitoring.
#               19-05-14 Add CPU monitoring.
#               03-12-14 Add Tablespaces monitoring
#               08-09-15 mpstat output change in Linux 6
#               02-04-16 Using dba_tablespace_usage_metrics To calculate MAXSIZE (11g onwards) Recommended by Satyajit Mohapatra.
#               10-04-16 Add Flash Recovery Area monitoring.
#               10-04-16 Add ASM Disk Groups monitoring.
#               15-09-16 Add "DIG MORE" feature to report.long running operations, queries
#                        and active sessions on DB side when CPU hits the pre-defined threshold.
#               29-12-16 Enhanced ORACLE_HOME search criteria.
#               02-01-17 Added EXL_DB parameter to allow the user to exclude DBs from having dbalarm script run against.
#               04-05-17 Added the ability to disable Database Down Alert through CHKOFFLINEDB variable.
#               11-05-17 Added the option to exclude tablespace/ASM Diskgroup from monitoring.
#               11-05-17 Tuned the method of reporting OFFLINE databases & checking listener log.
#               20-07-17 Modified COLUMNS env variable to fully display top command output.
#                        Neutralize login.sql if found in Oracle user home directory due to bugs.
#               19-10-17 Added the function of checking goldengate logfile.
#               11-04-18 Added the feature of monitoring the availability of specific service.
#		28-04-18 Added the function of printing the script progress.
#		30-04-18 Added Paranoid mode, to report EXPORT/IMPORT, ALTER SYSTEM, ALTER DATABASE 
#			 instance STARTUP/SHUTDOWN, other DB Major activities.
#		05-09-18 Modified the wait in seconds column (Blocking Sessions section) for 11gr2 compatibility,
#			 Added WAIT_FOR_LOCK_THRES threshold to control reporting of sessions blocked for more than N mintes.
#		09-10-18 Enclosing OS Network Failure Statistics (Dropped Packets) whenever TIMOUT error get reported by DB or Listener.
#		15-10-18 Added RMAN Backup Failure Check. [Recommended by: Rahul Malode]
#		22-10-18 Added the Checking of Running RMAN Backup when CPU hit the threshold.
#		01-11-18 Fixing a bug in Monitored Services section.
#		08-11-18 Show the exist restore points if FRA hits the threshold.
#		27-12-18 Checking if another session is running dbalarm script [to avoid performance degradation].
#		14-01-19 Avoid Monitoring the Services if more than one DB instance is running.
#		15-01-19 Added the feature of monitoring the ASM instance ALERTLOG.
#		15-01-18 Added the feature of monitoring the GRID INFRASTRUCTURE ALERTLOG.
#		16-01-19 Added the feature of monitoring Device Driver OS log "dmesg".
#		04-02-19 Added HTML feature to send the alert in HTML format [If sendmail installed, otherwise will use TEXT format automatically].
#		24-03-19 Enhanced the DB Service Monitoring Feature to monitor service availability on RAC setup Locally wise.
#		26-03-19 Listing the Master Blocking Sessions When a Blocking Lock get detected.
#		27-03-19 Used RULE Based Optimizer against all "checking locks" queries for a better performance on RAC instances.
#		15-05-19 Replacement of "bc" function for CPU utilization calculation with "awk".
#		20-05-19 When "unable to extend temp segment" error get detected the Email alert will show the top temp space consumers in the DB.
#
#
#
#
#
#
#
# ######################################################################################################################################################
EMAIL="youremail@yourcompany.com"
export SRV_NAME="`uname -n`"

	# Check if MAIL_LIST parameter is not set notify the user and exit:
        case ${EMAIL} in "youremail@yourcompany.com")
         echo
         echo "******************************************************************"
         echo "Buddy! You forgot to edit line# 70 in dbalarm.sh script."
         echo "Please replace youremail@yourcompany.com with your E-mail address."
         echo "******************************************************************"
         echo
         echo "Script Terminated !"
         echo 
         exit;;
        esac

	# Check if there is another session of dbalarm is running: [Avoid performance impact]
	DBALARMCNT=`ps -ef|grep -v grep|grep -v vi|grep dbalarm|wc -l`
	if [ ${DBALARMCNT} -gt 2 ]
   	 then
	 echo -e "\033[32;5mdbalarm.sh script is currently running by another session.\033[0m"
	 echo ""
	 echo "Please make sure the following sessions are completed before running dbalarm script: [ps -ef|grep -v grep|grep -v vi|grep dbalarm]"
	 ps -ef|grep -v grep|grep -v vi|grep dbalarm.sh
	 echo "Script Terminated !"
	 echo
	 exit
	fi
	
# In case your company Emails go through specific SMTP server. Specify it in the below line and UN-HASH it:
#export smtp="mailrelay.mycompany.com:25"	#This is an example, you have to check with your Network Admin for the SMTP NAME/PORT to use.

export MAIL_LIST="${EMAIL}"
#export MAIL_LIST="-r ${SRV_NAME} ${EMAIL}"

echo
echo "[dbalarm Script Started ...]"

# #########################
# THRESHOLDS:
# #########################
# Modify the THRESHOLDS to the value you prefer:

HTMLENABLE=Y		# Enable HTML Email Format 												   [DB]
FSTHRESHOLD=95 		# THRESHOLD FOR FILESYSTEM 	%USED 											   [OS]
CPUTHRESHOLD=95 	# THRESHOLD FOR CPU 		%BUSY 											   [OS]
TBSTHRESHOLD=95 	# THRESHOLD FOR TABLESPACE 	%USED 											   [DB]
FRATHRESHOLD=95 	# THRESHOLD FOR FRA 		%USED											   [DB]
ASMTHRESHOLD=95 	# THRESHOLD FOR ASM DISK GROUPS %USED  											   [DB]
BLOCKTHRESHOLD=1 	# THRESHOLD FOR THE NUMBER OF BLOCKED SESSIONS										   [DB]
WAIT_FOR_LOCK_THRES=1 	# THRESHOLD FOR THE LOCK TIME OF BLOCKED SESSIONS IN MINUTES								   [DB]
LAST_MIN_BKP_CHK=5 	# REPORT RMAN Backup FAILURE in the last N MINUTES. Should be same interval as the interval of dbalarm script execution in crontab.[DB]
CHKRMANBKP=Y 		# Enable/Disable Checking of RMAN Backup FAILURE.		[Default Enabled]					   [DB]
CHKLISTENER=Y 		# Enable/Disable Checking Listeners:  				[Default Enabled]					   [DB]
CHKOFFLINEDB=Y 		# Enable/Disable Database Down Alert: 				[Default Enabled]					   [DB]
CHKGOLDENGATE=Y 	# Enable/Disable Goldengate Alert:    				[Default Enabled]					   [GG]
CPUDIGMORE=Y 		# Break down to DB Active sessions when CPU hit the threshold: [RECOMMENDED TO SET =N on VERY BUSY environments]. [Default Enabled][DB]
TIMEOUTDIGMORE=Y 	# Enable/Disable the display of Network Errors when TIMEOUT error get detected. 		      [Default Enabled]	   [OS]
TEMPSPACEDIGMORE=Y      # Enable/Disable the display of TOP Temporary space consumers when ORA-1652 get detected.             [Default Enabled]    [DB]
SERVICEMON="" 		# Monitor Specific Named DB Services. e.g. SERVICEMON="'ORCL_RO','ERP_SRVC','SAP_SERVICE'"			   	   [DB]
PARANOIDMODE=N 		# Enable/Disable Paranoid mode will report more events like export/import, instance shutdown/startup. [Default Disabled]   [DB]
CHKASMALERTLOG=Y 	# Enable/Disable Monitoring ASM instance ALERTLOG.		[Default Enabled]					   [DB]
CHKCLSALERTLOG=Y 	# Enable/Disable Monitoring GRID INFRASTRUCTURE ALERTLOG.	[Default Enabled]					   [GI]
DEVICEDRIVERLOG=Y 	# Enable/Disable Check "dmesg" Device Driver log for errors. 	[Default Enabled]					   [OS]

SQLLINESIZE=200 	# The LINE SIZE for SQLPLUS outputs.											   [DB]
OSLINESIZE=300 		# The LINE SIZE for OS Commands outputs. [Default is 167]								   [OS]


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances dbalarm will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:
EXL_DB="\-MGMTDB|ASM|APX"                   #Excluded INSTANCES [Will not get reported offline].


# #########################
# Excluded TABLESPACES:
# #########################
# Here you can exclude one or more tablespace if you don't want to be alerted when they hit the threshold:
# e.g. to exclude "UNDOTBS1" modify the following variable in this fashion without removing "donotremove" value:
# EXL_TBS="donotremove|UNDOTBS1"
EXL_TBS="donotremove"			#Exclude TABLESPACES from being checked.


# #########################
# Excluded ASM Diskgroups:
# #########################
# Here you can exclude one or more ASM Disk Groups if you do NOT want to be alerted when they hit the threshold:
# e.g. to exclude "FRA" DISKGROUP modify the following variable in this fashion without removing "donotremove" value:
# EXL_DISK_GROUP="donotremove|FRA" Please DO NOT REMOVE/REPLACE the value "dontremove". Good boy ;-)
EXL_DISK_GROUP="donotremove"		#Exclude ASM DISKGROUPS from being checked.


# #########################
# Excluded ERRORS:
# #########################
# Here you will tell the script to ignore the ERRORS you don't want to be alerted when they come in the logs:
# Use pipe "|" between each error.

EXL_DB_ALERT_ERR="ORA-2396|TNS-00507|TNS-12502|TNS-12560|TNS-12537|TNS-00505"              #Excluded ALERTLOG ERRORS   		[Will not get reported].
EXL_LSNR_ERR="TNS-00507|TNS-12502|TNS-12560|TNS-12537|TNS-00505"                           #Excluded LISTENER ERRORS   		[Will not get reported].
EXL_GRID_ALERT_ERR="donotremove"							   #Excluded GRID INFRA ERRORS 		[Will not get reported].
EXL_GG_ERR="donotremove"                                                                   #Excluded GoldenGate ERRORS 		[Will not get reported].
EXL_DMESG_ERR=="donotremove|scsmd"							   #Excluded OS DEVICE DRIVERS ERRORS	[Will not get reported].


# #################################
# Excluded FILESYSTEM/MOUNT POINTS:
# #################################
# Here you can exclude specific filesystems/mount points from being reported by dbalarm:
# e.g. Excluding: /dev/mapper, /dev/asm mount points: Remember to put a forward Slash / before each Backslash \

EXL_FS="\/dev\/mapper\/|\/dev\/asm\/"                                                      #Excluded mount points [Will be skipped during the check].


# ###########################
# Check the Linux OS version:
# ###########################
export PATH=${PATH}:/usr/local/bin
FILE_NAME=/etc/redhat-release
export FILE_NAME
	if [ -f ${FILE_NAME} ]
	then
LNXVER=`cat /etc/redhat-release | grep -o '[0-9]'|head -1`
export LNXVER
# Workaround df command output bug "`/root/.gvfs': Permission denied"
DF='df -hPx fuse.gvfs-fuse-daemon'
export DF
	else
export DF='df -h'
	fi


# #########################
# Checking The FILESYSTEM:
# #########################
echo ""
echo "Checking FILESYSTEM Utilization ..."

# Report Partitions that reach the threshold of Used Space:

FSLOG=/tmp/filesystem_DBA_BUNDLE.log
echo "[Reported By ${SCRIPT_NAME} Script]"      >  ${FSLOG}
echo ""                                         >> ${FSLOG}
${DF}                                           >> ${FSLOG}
${DF} | grep -v "^Filesystem" |awk '{print substr($0, index($0, $2))}'| egrep -v "${EXL_FS}"|awk '{print $(NF-1)" "$NF}'| while read OUTPUT
   do
        PRCUSED=`echo ${OUTPUT}|awk '{print $1}'|cut -d'%' -f1`
        FILESYS=`echo ${OUTPUT}|awk '{print $2}'`
                if [ ${PRCUSED} -ge ${FSTHRESHOLD} ]
                 then
echo "Filesystem [${FILESYS}] has reached ${PRCUSED}% of USED space. Reporting the problem."
mail -s "ALARM: Filesystem [${FILESYS}] on Server [${SRV_NAME}] has reached ${PRCUSED}% of USED space" ${MAIL_LIST} < ${FSLOG}
                fi
   done

rm -f ${FSLOG}


# #############################
# Checking The CPU Utilization:
# #############################

# LOGFILE PATH:
# ############
export PATH=${PATH}:${ORACLE_HOME}/bin
export LOG_DIR=/tmp

export LOGFILE=${LOG_DIR}/dbalarm.part.log
export CPULOG=${LOG_DIR}/CPU_DBA_BUNDLE.log
export MPSTATLOG=${LOG_DIR}/mpstat_DBA_BUNDLE.log
export VMSTATLOG=${LOG_DIR}/vmstat_DBA_BUNDLE.log
export TOPLOG=${LOG_DIR}/top_DBA_BUNDLE.log
export UPTIMELOG=${LOG_DIR}/uptime_DBA_BUNDLE.log
export CPULOGCONV=${LOG_DIR}/top_processes_DBA_BUNDLE_CONV.log
export CPULOGHTML=${LOG_DIR}/top_processes_DBA_BUNDLE_HTML.log

if [ -f ${CPULOGHTML} ]
then
rm ${CPULOGHTML}
fi

# #########################
# HTML Preparation:
# #########################
   case ${HTMLENABLE} in
   y|Y|yes|YES|Yes|ON|On|on)
        if [ -x /usr/sbin/sendmail ]
        then
export SENDMAIL="/usr/sbin/sendmail -t"
export MAILEXEC="echo #"
export HASHHTML=""
export HASHHTMLOS=""
export ENDHASHHTMLOS=""
export HASHNONHTML="--"
SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)
export SENDMAILARGS
        else
export SENDMAIL="echo #"
export MAILEXEC="mail -s"
export HASHHTML="--"
export HASHHTMLOS="echo #"
export ENDHASHHTMLOS=""
export HASHNONHTML=""
        fi
   ;;
   *)
export SENDMAIL="echo #"
export HASHHTML="--"
export HASHHTMLOS="echo #"
export ENDHASHHTMLOS=""
export HASHNONHTML=""
export MAILEXEC="mail -s"
   ;;
   esac

# SQLPLUS HTML SETTINGS:
#export HTMLTITLE="SET MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type=\"text/css\"> table { background: #eee; } -th { font:bold 10pt Arial,Helvetica,sans-serif; color:#b7ceec; background:#151b54; padding: 5px; align:center; } td { font:10pt Arial,Helvetica,sans-serif; color:Blue; background:#f7f7e7; padding: 5px; align:center; } </style>' TABLE \"border='3' align='left'\" ENTMAP OFF"

#export HTMLTABLE="SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type=\"text/css\"> table { background: #eee; } -th { font:bold 10pt Arial,Helvetica,sans-serif; color:#b7ceec; background:#151b54; padding: 5px; align:center; } td { font:10pt Arial,Helvetica,sans-serif; color:Blue; background:#f7f7e7; padding: 5px; align:center; } </style>' TABLE \"border='2' align='left'\" ENTMAP OFF"

echo "Checking CPU Utilization ..."

# Report CPU Utilization if reach >= CPUTHRESHOLD:
OS_TYPE=`uname -s`
CPUUTLLOG=/tmp/CPULOG_DBA_BUNDLE.log

# Getting CPU utilization in last 5 seconds:
case `uname` in
        Linux ) CPU_REPORT_SECTIONS=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1 | grep ';' -o | wc -l`
                CPU_COUNT=`cat /proc/cpuinfo|grep processor|wc -l`
                        if [ ${CPU_REPORT_SECTIONS} -ge 6 ]; then
                           CPU_IDLE=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1| cut -d ";" -f 7`
                        else
                           CPU_IDLE=`iostat -c 1 5 | sed -e 's/,/./g' | tr -s ' ' ';' | sed '/^$/d' | tail -1| cut -d ";" -f 6`
                        fi
        ;;
        AIX )   CPU_IDLE=`iostat -t $INTERVAL_SEC $NUM_REPORT | sed -e 's/,/./g'|tr -s ' ' ';' | tail -1 | cut -d ";" -f 6`
                CPU_COUNT=`lsdev -C|grep Process|wc -l`
        ;;
        SunOS ) CPU_IDLE=`iostat -c $INTERVAL_SEC $NUM_REPORT | tail -1 | awk '{ print $4 }'`
                CPU_COUNT=`psrinfo -v|grep "Status of processor"|wc -l`
        ;;
        HP-UX)  SAR="/usr/bin/sar"
                CPU_COUNT=`lsdev -C|grep Process|wc -l`
                	if [ ! -x $SAR ]; then
                 	   echo "sar command is not supported on your environment | CPU Check ignored"; CPU_IDLE=99
                	else
                 	   CPU_IDLE=`/usr/bin/sar 1 5 | grep Average | awk '{ print $5 }'`
                	fi
        ;;
        *) echo "uname command is not supported on your environment | CPU Check ignored"; CPU_IDLE=99
        ;;
        esac

# Getting Utilized CPU (100-%IDLE):
#CPU_UTL_FLOAT=`echo "scale=2; 100-($CPU_IDLE)"|bc`
CPU_UTL_FLOAT=`awk "BEGIN {print 100-($CPU_IDLE)}"`

# Convert the average from float number to integer:
CPU_UTL=${CPU_UTL_FLOAT%.*}

echo "CPU utilizations is: $CPU_UTL"
        if [ -z ${CPU_UTL} ]
         then
          CPU_UTL=1
        fi

# Compare the current CPU utilization with the Threshold:

        if [ ${CPU_UTL} -ge ${CPUTHRESHOLD} ]
         then
                export COLUMNS=${OSLINESIZE}           #Increase the COLUMNS width to display the full output [Default is 167]
                echo "*******"            >  ${MPSTATLOG}
                echo "mpstat"             >> ${MPSTATLOG}
                echo "*******"            >> ${MPSTATLOG}
                mpstat 1 5|tail -7        >> ${MPSTATLOG}

		echo ""                   >  ${VMSTATLOG}
                echo "******"             >> ${VMSTATLOG}
                echo "vmstat"             >> ${VMSTATLOG}
                echo "******"             >> ${VMSTATLOG}
                #echo "[If_the_runqueue_number_in_the_(r)_column_exceeds_the_number_of_CPUs_[${CPU_COUNT}]_this_indicates_a_CPU_bottleneck_on_the_system]." >> ${VMSTATLOG}
                vmstat 2 5                >> ${VMSTATLOG}

		echo ""			  >  ${TOPLOG}
                echo "****************"   >> ${TOPLOG}
		echo "Top10Processes"     >> ${TOPLOG}
		echo "****************"   >> ${TOPLOG}
                top -c -b -n 1|head -17|tail -11   >> ${TOPLOG}

                echo ""                   >  ${UPTIMELOG}
                echo "**********"         >> ${UPTIMELOG}
                echo "Load_Avg"		  >> ${UPTIMELOG}
		echo "**********"	  >> ${UPTIMELOG}
		uptime			  >> ${UPTIMELOG}
                echo ""                   >> ${UPTIMELOG}
                unset COLUMNS                #Set COLUMNS width back to the default value
                #ps -eo pcpu,pid,user,args | sort -k 1 -r | head -11 >> ${CPULOG}

cat ${MPSTATLOG} >  ${LOGFILE}
cat ${VMSTATLOG} >> ${LOGFILE}
cat ${TOPLOG}    >> ${LOGFILE}
cat ${UPTIMELOG} >> ${LOGFILE}

# Convert OS commands output into HTML format:
export FONTSIZE=4
export FONT=Arial
export FONTCOLOR=BLUE
#${HASHHTMLOS} awk 'BEGIN { print "<table borader=1>"} {print "<tr>"; for(i=1;i<=NF;i++)print "<td><FONT COLOR=BLACK FACE="Times New Roman" SIZE=${FONTSIZE}>" $i"</FONT></td>"; print "</tr>"} END{print "</table>" }' ${MPSTATLOG} > ${CPULOGCONV} ${ENDHASHHTMLOS}
${HASHHTMLOS} awk 'BEGIN { print "<table borader=1>"} {print "<tr>"; for(i=1;i<=NF;i++)print "<td><FONT COLOR=BROWN FACE="Times New Roman" SIZE=${FONTSIZE}>" $i"</FONT></td>"; print "</tr>"} END{print "</table>" }' ${MPSTATLOG} > ${CPULOGCONV} ${ENDHASHHTMLOS}
${HASHHTMLOS} awk 'BEGIN { print "<table borader=1>"} {print "<tr>"; for(i=1;i<=NF;i++)print "<td><FONT COLOR=BROWN FACE="Times New Roman" SIZE=${FONTSIZE}>" $i"</FONT></td>"; print "</tr>"} END{print "</table>" }' ${VMSTATLOG} >> ${CPULOGCONV} ${ENDHASHHTMLOS}
${HASHHTMLOS} awk 'BEGIN { print "<table borader=1>"} {print "<tr>"; for(i=1;i<=NF;i++)print "<td><FONT COLOR=BROWN FACE="Times New Roman" SIZE=${FONTSIZE}>" $i"</FONT></td>"; print "</tr>"} END{print "</table>" }' ${TOPLOG}    >> ${CPULOGCONV} ${ENDHASHHTMLOS}
${HASHHTMLOS} awk 'BEGIN { print "<table borader=1>"} {print "<tr>"; for(i=1;i<=NF;i++)print "<td><FONT COLOR=BROWN FACE="Times New Roman" SIZE=${FONTSIZE}>" $i"</FONT></td>"; print "</tr>"} END{print "</table>" }' ${UPTIMELOG} >> ${CPULOGCONV} ${ENDHASHHTMLOS}

#${HASHHTMLOS} cat /dev/null > ${CPULOGHTML} ${ENDHASHHTMLOS}
${HASHHTMLOS} cp ${CPULOGCONV} ${LOGFILE}

# Check ACTIVE SESSIONS on DB side:
echo "[CPU Utilization Crossed The Threshold [${CPU_UTL}%]. Sending Email Alert ...]"
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

# Getting ORACLE_HOME:
# ###################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|grep -v "\-MGMTDB"|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep -i "^${ORA_USER}:" /etc/passwd| cut -f6 -d ':'|tail -1`

# SETTING ORATAB:
if [ -f /etc/oratab ]
  then
ORATAB=/etc/oratab
export ORATAB
## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
ORATAB=/var/opt/oracle/oratab
export ORATAB
fi

# ATTEMPT1: Get ORACLE_HOME using pwdx command:
PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
export PMON_PID
ORACLE_HOME=`pwdx ${PMON_PID}|awk '{print $NF}'|sed -e 's/\/dbs//g'`
export ORACLE_HOME

# ATTEMPT2: If ORACLE_HOME not found get it from oratab file:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## If OS is Linux:
if [ -f /etc/oratab ]
  then
ORATAB=/etc/oratab
ORACLE_HOME=`grep -v '^\#' ${ORATAB} | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
export ORACLE_HOME

## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
ORATAB=/var/opt/oracle/oratab
ORACLE_HOME=`grep -v '^\#' ${ORATAB} | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
export ORACLE_HOME
fi
fi

# ATTEMPT3: If ORACLE_HOME is in /etc/oratab, use dbhome command:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
ORACLE_HOME=`dbhome "${ORACLE_SID}"`
export ORACLE_HOME
fi

# ATTEMPT4: If ORACLE_HOME is still not found, search for the environment variable: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
export ORACLE_HOME
fi

# ATTEMPT5: If ORACLE_HOME is not found in the environment search user's profile: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' ${USR_ORA_HOME}/.bash_profile ${USR_ORA_HOME}/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
export ORACLE_HOME
fi

# ATTEMPT6: If ORACLE_HOME is still not found, search for orapipe: [Least accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
	if [ -x /usr/bin/locate ]
 	 then
ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
export ORACLE_HOME
	fi
fi

# TERMINATE: If all above attempts failed to get ORACLE_HOME location, EXIT the script:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  echo "Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory in order to get this script to run properly"
  echo "e.g."
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
exit
fi


# Check Long Running Transactions if CPUDIGMORE=Y:
                 case ${CPUDIGMORE} in
                 y|Y|yes|YES|Yes|ON|On|on)
DBCPUDIGMORE=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize ${SQLLINESIZE}

-- Enable HTML color format:
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF

SPOOL ${CPULOGHTML} APPEND
prompt

${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='27%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT SESSIONS STATUS: [Local Instance | ${ORACLE_SID}]
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

${HASHNONHTML} PROMPT *************** 

${HASHNONHTML} PROMPT SESSIONS STATUS: [Local Instance | ${ORACLE_SID}]
${HASHNONHTML} PROMPT *************** 

set pages 0
select 'ACTIVE:     '||count(*)         from v\$session where USERNAME is not null and status='ACTIVE';
select 'INACTIVE:   '||count(*)         from v\$session where USERNAME is not null and status='INACTIVE';
select 'BACKGROUND: '||count(*)         from v\$session where USERNAME is null;
select 'ALL:        '||count(*)         from v\$session;

${HASHNONHTML} PROMPT

${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} SET PAGES 0
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='25%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT ACTIVE SESSIONS ON INSTANCE: [${ORACLE_SID}]
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='2' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} SET PAGES 1000

--${HASHHTML} PROMPT

${HASHNONHTML} PROMPT *************************** 

${HASHNONHTML} PROMPT ACTIVE SESSIONS ON INSTANCE: [${ORACLE_SID}]
${HASHNONHTML} PROMPT *************************** 

set feedback off linesize ${SQLLINESIZE} pages 1000
col event                               for a24
col "STATUS|WAIT_STATE|TIME_WAITED"     for a31
col "USER|OSID|SID,SER|MACHN|MODULE"    for a65
col "ST|WA_ST|WAITD|ACT_SINC|LOGIN"     for a44
col "SQLID | FULL_SQL_TEXT"             for a75
col "CURR_SQLID"                        for a35
col "I|BLKD_BY"                         for a9
select
substr(s.USERNAME||'| '||p.spid||'|'||s.sid||','||s.serial#||' |'||substr(s.MACHINE,1,22)||'|'||substr(s.MODULE,1,18),1,65)"USER|OSID|SID,SER|MACHN|MODULE"
,substr(s.status||'|'||w.state||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||to_char(LOGON_TIME,'ddMon'),1,44) "ST|WA_ST|WAITD|ACT_SINC|LOGIN"
,substr(w.event,1,24) "EVENT"
--,substr(w.event,1,30)"EVENT",s.SQL_ID ||' | '|| Q.SQL_FULLTEXT "SQLID | FULL_SQL_TEXT"
,s.SQL_ID "CURRENT SQLID"
,s.FINAL_BLOCKING_INSTANCE||'|'||s.FINAL_BLOCKING_SESSION "I|BLKD_BY"
from    v\$session s, v\$session_wait w, v\$process p
where   s.USERNAME is not null
and     s.sid=w.sid
and     p.addr = s.paddr
and     s.STATUS='ACTIVE'
and     w.EVENT NOT IN ('SQL*Net message from client','class slave wait','Streams AQ: waiting for messages in the queue','Streams capture: waiting for archive log'
        ,'Streams AQ: waiting for time management or cleanup tasks','PL/SQL lock timer','rdbms ipc message')
order by "I|BLKD_BY" desc,w.event,"USER|OSID|SID,SER|MACHN|MODULE","ST|WA_ST|WAITD|ACT_SINC|LOGIN" desc,"CURRENT SQLID";

--${HASHHTML} PROMPT <br>
${HASHNONHTML} PROMPT
${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='40%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT Long Running Operations On Database: [${ORACLE_SID}]
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='2' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

${HASHNONHTML} PROMPT ***********************************

${HASHNONHTML} PROMPT Long Running Operations On Instance: [${ORACLE_SID}]
${HASHNONHTML} PROMPT ***********************************

set linesize ${SQLLINESIZE} pages 1000
col OPERATION                           for a21
col "%DONE"                             for 999.999
col "STARTED|MIN_ELAPSED|REMAIN"        for a30
col MESSAGE                             for a80
col "USERNAME| SID,SERIAL#"             for a26
        select USERNAME||'| '||SID||','||SERIAL# "USERNAME| SID,SERIAL#",SQL_ID
        --,OPNAME OPERATION
        ,round(SOFAR/TOTALWORK*100,2) "%DONE"
        ,to_char(START_TIME,'DD-Mon HH24:MI')||'| '||trunc(ELAPSED_SECONDS/60)||'|'||trunc(TIME_REMAINING/60) "STARTED|MIN_ELAPSED|REMAIN" ,MESSAGE
        from v\$session_longops
        where SOFAR/TOTALWORK*100 <>'100'
        and TOTALWORK <> '0'
        order by "STARTED|MIN_ELAPSED|REMAIN" desc, "USERNAME| SID,SERIAL#";

PROMPT
${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='42%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT Sessions Active Since More Than 1 Hour On Database: [${ORACLE_SID}]
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='2' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

${HASHNONHTML} PROMPT ************************************************** 

${HASHNONHTML} PROMPT Sessions Active Since More Than 1 Hour On Instance: [${ORACLE_SID}]
${HASHNONHTML} PROMPT ************************************************** 

set lines ${SQLLINESIZE}
col module                      for a30
col DURATION_HOURS              for 99999.9
col STARTED_AT                  for a13
col "USERNAME| SID,SERIAL#"     for a30
col "SQL_ID | SQL_TEXT"         for a120
select username||'| '||sid ||','|| serial# "USERNAME| SID,SERIAL#",substr(MODULE,1,30) "MODULE", to_char(sysdate-last_call_et/24/60/60,'DD-MON HH24:MI') STARTED_AT,
last_call_et/60/60 "DURATION_HOURS"
--,SQL_ID ||' | '|| (select SQL_FULLTEXT from v\$sql where address=sql_address) "SQL_ID | SQL_TEXT"
,SQL_ID
from v\$session where
username is not null 
and module is not null
-- 1 is the number of hours
and last_call_et > 60*60*1
and status = 'ACTIVE';

PROMPT
${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='27%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT RUNNING JOBS On Database: [${ORACLE_SID}]
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='2' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

${HASHNONHTML} PROMPT ************************ 

${HASHNONHTML} PROMPT RUNNING JOBS On Instance: [${ORACLE_SID}]
${HASHNONHTML} PROMPT ************************ 

col INS                         for 999
col "JOB_NAME|OWNER|SPID|SID"   for a55
col ELAPSED_TIME                for a17
col CPU_USED                    for a17
col "WAIT_SEC"                  for 9999999999
col WAIT_CLASS                  for a15
col "BLKD_BY"                   for 9999999
col "WAITED|WCLASS|EVENT"       for a45
select j.RUNNING_INSTANCE INS,j.JOB_NAME ||' | '|| j.OWNER||' |'||SLAVE_OS_PROCESS_ID||'|'||j.SESSION_ID"JOB_NAME|OWNER|SPID|SID"
,s.FINAL_BLOCKING_SESSION "BLKD_BY",ELAPSED_TIME,CPU_USED
,substr(s.SECONDS_IN_WAIT||'|'||s.WAIT_CLASS||'|'||s.EVENT,1,45) "WAITED|WCLASS|EVENT",S.SQL_ID
from dba_scheduler_running_jobs j, gv\$session s
where   j.RUNNING_INSTANCE=S.INST_ID(+)
and     j.SESSION_ID=S.SID(+)
order by INS,"JOB_NAME|OWNER|SPID|SID",ELAPSED_TIME;

SPOOL OFF
EOF
)

BACKUPJOBCOUNTRAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT count(*) FROM v\$rman_backup_job_details WHERE status like 'RUNNING%';
exit;
EOF
)
BACKUPJOBCOUNT=`echo ${BACKUPJOBCOUNTRAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

  if [ ${BACKUPJOBCOUNT} -gt 0 ]
   then
BACKUPJOBOUTPUT=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off linesize ${SQLLINESIZE}
col name for A40
EXEC DBMS_SESSION.set_identifier('${SCRIPT_NAME}');
set feedback off

-- Enable HTML color format:
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF

SPOOL ${CPULOGHTML} APPEND

prompt
${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='20%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT Running Backups: [${ORACLE_SID}]
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='2' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

${HASHNONHTML} prompt *************** 

${HASHNONHTML} Prompt Running Backups: [${ORACLE_SID}]
${HASHNONHTML} prompt *************** 

set feedback off linesize ${SQLLINESIZE} pages 1000
col START_TIME for a15
col END_TIME for a15
col TIME_TAKEN_DISPLAY for a10
col INPUT_BYTES_DISPLAY heading "DATA SIZE" for a10
col OUTPUT_BYTES_DISPLAY heading "Backup Size" for a11
col OUTPUT_BYTES_PER_SEC_DISPLAY heading "Speed/s" for a10
col output_device_type heading "Device_TYPE" for a11
SELECT to_char (start_time,'DD-MON-YY HH24:MI') START_TIME, to_char(end_time,'DD-MON-YY HH24:MI') END_TIME, time_taken_display, status,
input_type, output_device_type,input_bytes_display, output_bytes_display, output_bytes_per_sec_display,COMPRESSION_RATIO COMPRESS_RATIO
FROM v\$rman_backup_job_details
WHERE status like 'RUNNING%';

SPOOL OFF
exit;
EOF
)
  fi
		echo ""
                ;;
                esac
  done
echo "CPU utilization has hit the threshold. Reporting the problem."

cat ${CPULOGHTML} >> ${LOGFILE}
export SRV_NAME="`uname -n`"

export MSGSUBJECT="ALERT: CPU Utilization on Server [${SRV_NAME}] has reached [${CPU_UTL}%]"
echo ${MSGSUBJECT}

SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${LOGFILE}
echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}
        fi

rm -f ${CPUUTLLOG}
rm -f ${CPULOG}

echo "CPU CHECK Completed."


# #########################
# Getting ORACLE_SID:
# #########################
# Exit with sending Alert mail if No DBs are running:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )
        if [ ${INS_COUNT} -eq 0 ]
         then
         echo "[Reported By ${SCRIPT_NAME} Script]"                                             >  /tmp/oracle_processes_DBA_BUNDLE.log
         echo " "                                                                               >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "Current running INSTANCES on server [${SRV_NAME}]:"                              >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "***************************************************"                             >> /tmp/oracle_processes_DBA_BUNDLE.log
         ps -ef|grep -v grep|grep pmon                                                          >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo " "                                                                               >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "Current running LISTENERS on server [${SRV_NAME}]:"                              >> /tmp/oracle_processes_DBA_BUNDLE.log
         echo "***************************************************"                             >> /tmp/oracle_processes_DBA_BUNDLE.log
         ps -ef|grep -v grep|grep tnslsnr                                                       >> /tmp/oracle_processes_DBA_BUNDLE.log
mail -s "ALARM: No Databases Are Running on Server: ${SRV_NAME} !!!" ${MAIL_LIST}               <  /tmp/oracle_processes_DBA_BUNDLE.log
         rm -f /tmp/oracle_processes_DBA_BUNDLE.log
         exit
        fi

# Avoid Monitoring Running Services if more than one DB instance is running:
        if [ ${INS_COUNT} -gt 1 ]
         then
          export SERVICEMON=""
        fi


# #########################
# Setting ORACLE_SID:
# #########################
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID
    echo ""
    echo "[Checking ${ORACLE_SID} Database ...]"


# #########################
# Getting ORACLE_HOME
# #########################
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|grep -v "\-MGMTDB"|awk '{print $1}'|tail -1`
  USR_ORA_HOME=`grep -i "^${ORA_USER}:" /etc/passwd| cut -f6 -d ':'|tail -1`

# SETTING ORATAB:
if [ -f /etc/oratab ]
  then
ORATAB=/etc/oratab
export ORATAB
## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
ORATAB=/var/opt/oracle/oratab
export ORATAB
fi

# ATTEMPT1: Get ORACLE_HOME using pwdx command:
PMON_PID=`pgrep  -lf _pmon_${ORACLE_SID}|awk '{print $1}'`
export PMON_PID
ORACLE_HOME=`pwdx ${PMON_PID}|awk '{print $NF}'|sed -e 's/\/dbs//g'`
export ORACLE_HOME

# ATTEMPT2: If ORACLE_HOME not found get it from oratab file:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## If OS is Linux:
if [ -f /etc/oratab ]
  then
ORATAB=/etc/oratab
ORACLE_HOME=`grep -v '^\#' ${ORATAB} | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
export ORACLE_HOME

## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
ORATAB=/var/opt/oracle/oratab
ORACLE_HOME=`grep -v '^\#' ${ORATAB} | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
export ORACLE_HOME
fi
fi

# ATTEMPT3: If ORACLE_HOME is in /etc/oratab, use dbhome command:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
ORACLE_HOME=`dbhome "${ORACLE_SID}"`
export ORACLE_HOME
fi

# ATTEMPT4: If ORACLE_HOME is still not found, search for the environment variable: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
export ORACLE_HOME
fi

# ATTEMPT5: If ORACLE_HOME is not found in the environment search user's profile: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' ${USR_ORA_HOME}/.bash_profile ${USR_ORA_HOME}/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
export ORACLE_HOME
fi

# ATTEMPT6: If ORACLE_HOME is still not found, search for orapipe: [Least accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
	if [ -x /usr/bin/locate ]
 	 then
ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
export ORACLE_HOME
	fi
fi

# TERMINATE: If all above attempts failed to get ORACLE_HOME location, EXIT the script:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  echo "Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory in order to get this script to run properly"
  echo "e.g."
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
mail -s "dbalarm script on Server [${SRV_NAME}] failed to locate ORACLE_HOME for SID [${ORACLE_SID}], Please export ORACLE_HOME variable in your .bash_profile file under oracle user home directory" ${MAIL_LIST} < /dev/null
exit
fi


# #############################
# Getting hostname in lowercase:
# #############################
HOSTNAMELOWER=$( echo "`hostname --short`"| tr '[A-Z]' '[a-z]' )
export HOSTNAMELOWER


# ########################
# Getting GRID_HOME:
# ########################

CHECK_OCSSD=`ps -ef|grep 'ocssd.bin'|grep -v grep|wc -l`
CHECK_CRSD=`ps -ef|grep 'crsd.bin'|grep -v grep|wc -l`

 if [ ${CHECK_OCSSD} -gt 0 ]
  then
GRID_HOME=`ps -ef|grep 'ocssd.bin'|grep -v grep|awk '{print $NF}'|sed -e 's/\/bin\/ocssd.bin//g'|grep -v sed|grep -v "//g"|tail -1`
export GRID_HOME

        if [ ! -d ${GRID_HOME} ]
         then
ASM_INSTANCE_NAME=`ps -ef|grep pmon|grep -v grep|grep asm_pmon_|awk '{print $NF}'|sed -e 's/asm_pmon_//g'|grep -v sed|grep -v "s///g"|tail -1`
GRID_HOME=`dbhome ${ASM_INSTANCE_NAME}`
export GRID_HOME
        fi


# ########################
# Getting GRID_BASE:
# ########################

# Locating GRID_BASE:

GRID_BASE=`cat ${GRID_HOME}/crs/install/crsconfig_params|grep ^ORACLE_BASE|tail -1|awk '{print $NF}'|sed -e 's/ORACLE_BASE=//g'`
export GRID_BASE

        if [ ! -d ${GRID_BASE} ]
         then
GRID_BASE=`cat ${GRID_HOME}/crs/utl/appvipcfg|grep ^ORACLE_BASE|tail -1|awk '{print $NF}'|sed -e 's/ORACLE_BASE=//g'`
export GRID_BASE
        fi

        if [ ! -d ${GRID_BASE} ]
         then
GRID_BASE=`cat ${GRID_HOME}/install/envVars.properties|grep ^ORACLE_BASE|tail -1|awk '{print $NF}'|sed -e 's/ORACLE_BASE=//g'`
export GRID_BASE
        fi
 fi


# #########################
# Variables:
# #########################
export PATH=${PATH}:${ORACLE_HOME}/bin
export LOG_DIR=${USR_ORA_HOME}/BUNDLE_Logs
mkdir -p ${LOG_DIR}
chown -R ${ORA_USER} ${LOG_DIR}
chmod -R go-rwx ${LOG_DIR}

        if [ ! -d ${LOG_DIR} ]
         then
          mkdir -p /tmp/BUNDLE_Logs
          export LOG_DIR=/tmp/BUNDLE_Logs
          chown -R ${ORA_USER} ${LOG_DIR}
          chmod -R go-rwx ${LOG_DIR}
        fi

touch ${LOG_DIR}/dbalarm.part.log
export LOGFILE=${LOG_DIR}/dbalarm.part.log


# #########################
# HTML Preparation:
# #########################
   case ${HTMLENABLE} in
   y|Y|yes|YES|Yes|ON|On|on)
        if [ -x /usr/sbin/sendmail ]
        then
export SENDMAIL="/usr/sbin/sendmail -t"
export MAILEXEC="echo #"
export HASHHTML=""
export HASHNONHTML="--"
SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)
export SENDMAILARGS
        else
export SENDMAIL="echo #"
export MAILEXEC="mail -s"
export HASHHTML="--"
export HASHNONHTML=""
        fi
   ;;
   *)
export SENDMAIL="echo #"
export HASHHTML="--"
export HASHNONHTML=""
export MAILEXEC="mail -s"
   ;;
   esac


#export HTMLTITLE="SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type=\"text/css\"> table { background: #eee; } -th { font:bold 10pt Arial,Helvetica,sans-serif; color:#b7ceec; background:#151b54; padding: 5px; align:center; } td { font:10pt Arial,Helvetica,sans-serif; color:Blue; background:#f7f7e7; padding: 5px; align:center; } </style>' TABLE \"border='3' align='left'\" ENTMAP OFF"

#export HTMLTABLE="SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type=\"text/css\"> table { background: #eee; } -th { font:bold 10pt Arial,Helvetica,sans-serif; color:#b7ceec; background:#151b54; padding: 5px; align:center; } td { font:10pt Arial,Helvetica,sans-serif; color:Blue; background:#f7f7e7; padding: 5px; align:center; } </style>' TABLE \"border='2' align='left'\" ENTMAP OFF"

# ##########################
# Neutralize login.sql file: [Bug Fix]
# ##########################
# Existance of login.sql file under Oracle user Linux home directory eliminates many functions during the execution of this script via crontab:

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
echo "login.sql file found and will be neutralized."
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi


# ########################
# Getting ORACLE_BASE:
# ########################
# Get ORACLE_BASE from user's profile if it EMPTY:

if [ ! -d "${ORACLE_BASE}" ]
 then
ORACLE_BASE=`cat ${ORACLE_HOME}/install/envVars.properties|grep ^ORACLE_BASE|tail -1|awk '{print $NF}'|sed -e 's/ORACLE_BASE=//g'`
export ORACLE_BASE
fi

if [ ! -d "${ORACLE_BASE}" ]
 then
ORACLE_BASE=`grep -h 'ORACLE_BASE=\/' ${USR_ORA_HOME}/.bash* ${USR_ORA_HOME}/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
export ORACLE_BASE
fi


# #########################
# Getting DB_NAME:
# #########################
DB_NAME_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
SELECT name from v\$database;
exit;
EOF
)
# Getting DB_NAME in Uppercase & Lowercase:
DB_NAME_UPPER=`echo ${DB_NAME_RAW}| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
DB_NAME_LOWER=$( echo "${DB_NAME_UPPER}" | tr -s  '[:upper:]' '[:lower:]' )
export DB_NAME_UPPER
export DB_NAME_LOWER


# #########################
# Getting DB_UNQ_NAME:
# #########################
VAL121=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select value from v\$parameter where name='db_unique_name';
exit;
EOF
)
# Getting DB_NAME in Uppercase & Lowercase:
DB_UNQ_NAME=`echo ${VAL121}| perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
export DB_UNQ_NAME

# In case DB_UNQ_NAME variable is empty then use DB_NAME instead:
case ${DB_UNQ_NAME} in
'') DB_UNQ_NAME=${DB_NAME}; export DB_UNQ_NAME;;
esac


        if [ -d ${ORACLE_BASE}/diag/rdbms/${DB_NAME_UPPER} ]
        then
                DB_NAME=${DB_NAME_UPPER}
        fi

        if [ -d ${ORACLE_BASE}/diag/rdbms/${DB_NAME_LOWER} ]
        then
                DB_NAME=${DB_NAME_LOWER}
        fi

        if [ -d ${ORACLE_BASE}/diag/rdbms/${DB_UNQ_NAME} ]
        then
                DB_NAME=${DB_UNQ_NAME}
        fi

export DB_NAME


# ###################
# Getting DB Version:
# ###################
echo "Checking DB Version"
VAL311=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select version from v\$instance;
exit;
EOF
)
DB_VER=`echo ${VAL311}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# #####################
# Getting DB Block Size:
# #####################
echo "Checking DB Block Size"
VAL302=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select value from v\$parameter where name='db_block_size';
exit;
EOF
)
blksize=`echo ${VAL302}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# #####################
# Getting DB ROLE:
# #####################
echo "Checking DB Role"
VAL312=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select DATABASE_ROLE from v\$database;
exit;
EOF
)
DB_ROLE=`echo ${VAL312}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

        case ${DB_ROLE} in
         PRIMARY)
export DB_ROLE_ID=0
	;;
               *)
export DB_ROLE_ID=1
# Disable the reporting of BLOCKED Sessions if the DB Role is not PRIMARY:
export BLOCKTHRESHOLD=100000
	;;
        esac


# ######################################
# Check Flash Recovery Area Utilization:
# ######################################
VAL318=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select value from v\$parameter where name='db_recovery_file_dest';
exit;
EOF
)
FRA_LOC=`echo ${VAL318}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# If FRA is configured, check the its utilization:
  if [ ! -z ${FRA_LOC} ]
   then

FRACHK1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off linesize ${SQLLINESIZE}
col name for A40
SELECT ROUND((SPACE_USED - SPACE_RECLAIMABLE)/SPACE_LIMIT * 100, 1) FROM V\$RECOVERY_FILE_DEST;
exit;
EOF
)

FRAPRCUSED=`echo ${FRACHK1}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# Convert FRAPRCUSED from float number to integer:
FRAPRCUSED=${FRAPRCUSED%.*}
        if [ -z ${FRAPRCUSED} ]
         then
          FRAPRCUSED=1
        fi

# If FRA %USED >= the defined threshold then send an email alert:
INTEG='^[0-9]+$'
        # Verify that FRAPRCUSED value is a valid number:
        if [[ ${FRAPRCUSED} =~ ${INTEG} ]]
         then
echo "Checking FRA For [${ORACLE_SID}] ..."
               if [ ${FRAPRCUSED} -ge ${FRATHRESHOLD} ]
                 then
FRA_RPT=${LOG_DIR}/FRA_REPORT.log

FRACHK2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize ${SQLLINESIZE}
${HASHHTML} set linesize 300
${HASHNONHTML} col name for a100
${HASHNONHTML} col TOTAL_MB   for 99999999999999999
${HASHNONHTML} col FREE_MB    for 99999999999999999

-- Enable HTML color format:
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF

SPOOL ${FRA_RPT}
${HASHHTML} set pages 0
${HASHHTML} select '<b>'||'Reported By ${SCRIPT_NAME} Script'||'</b>' from dual;
${HASHHTML} set pages 1000


${HASHNONHTML} PROMPT [Reported By ${SCRIPT_NAME} Script]
${HASHNONHTML} PROMPT
${HASHNONHTML} PROMPT [FLASH RECOVERY AREA Utilization]
${HASHNONHTML} PROMPT

${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <p> <table border='3' bordercolor='#E67E22' width='30%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT FLASH RECOVERY AREA Utilization
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

col NAME for a30
SELECT NAME,SPACE_LIMIT/1024/1024 AS TOTAL_MB,(SPACE_LIMIT - SPACE_USED + SPACE_RECLAIMABLE)/1024/1024 AS FREE_MB,
ROUND((SPACE_USED - SPACE_RECLAIMABLE)/SPACE_LIMIT * 100, 1) AS "%FULL"
FROM V\$RECOVERY_FILE_DEST;

${HASHNONHTML} PROMPT

${HASHNONHTML} PROMPT [FRA COMPONENTS]
${HASHNONHTML} PROMPT

${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='22%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT FRA COMPONENTS
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

select * from v\$flash_recovery_area_usage;

${HASHNONHTML} PROMPT

${HASHNONHTML} PROMPT [Exist Restore Points: <You may need to drop>]
${HASHNONHTML} PROMPT

${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='22%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT Exist Restore Points
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

col SCN                for 999999999999999999
col time               for a35 
col RESTORE_POINT_TIME for a35
col name               for a40
select NAME,SCN,TIME,STORAGE_SIZE/1024/1024 STORAGE_SIZE_MB from v\$restore_point;
spool off
exit;
EOF
)

echo "FRA has reached ${FRAPRCUSED}%. Reporting the problem."
cat ${FRA_RPT} > ${LOGFILE}
export MSGSUBJECT="ALERT: FRA has reached ${FRAPRCUSED}% on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]"

SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${FRA_RPT}
echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}
               fi
        fi

rm -f ${FRAFULL}
rm -f ${FRA_RPT}
  fi


# ################################
# Check ASM Diskgroup Utilization:
# ################################
echo "Checking ASM Diskgroup Utilization ..."
VAL314=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from v\$asm_diskgroup;
exit;
EOF
)
ASM_GROUP_COUNT=`echo ${VAL314}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# If ASM DISKS Are Exist, Check the size utilization:
  if [ ${ASM_GROUP_COUNT} -gt 0 ]
   then
echo "Checking ASM on [${ORACLE_SID}] ..."

ASM_UTL=${LOG_DIR}/ASM_UTILIZATION.log

ASMCHK1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off linesize ${SQLLINESIZE}
col name for A40
spool ${ASM_UTL}
select name,ROUND((1-(free_mb / total_mb))*100, 2) "%FULL" from v\$asm_diskgroup;
spool off
exit;
EOF
)

ASMFULL=${LOG_DIR}/asm_full.log
#cat ${ASM_UTL}|awk '{ print $1" "$NF }'| while read OUTPUT3
cat ${ASM_UTL}|egrep -v ${EXL_DISK_GROUP}|awk '{ print $1" "$NF }'| while read OUTPUT3
   do
        ASMPRCUSED=`echo ${OUTPUT3}|awk '{print $NF}'`
        ASMDGNAME=`echo ${OUTPUT3}|awk '{print $1}'`
        echo "[Reported By ${SCRIPT_NAME} Script]"                      >  ${ASMFULL}
        echo " "                                                        >> ${ASMFULL}
        echo "ASM_DISK_GROUP            %USED"                          >> ${ASMFULL}
        echo "----------------------          --------------"           >> ${ASMFULL}
        echo "${ASMDGNAME}                        ${ASMPRCUSED}%"       >> ${ASMFULL}

# Convert ASMPRCUSED from float number to integer:
ASMPRCUSED=${ASMPRCUSED%.*}
        if [ -z ${ASMPRCUSED} ]
         then
          ASMPRCUSED=1
        fi
# If ASM %USED >= the defined threshold send an email for each DISKGROUP:
               if [ ${ASMPRCUSED} -ge ${ASMTHRESHOLD} ]
                 then
ASM_RPT=${LOG_DIR}/ASM_REPORT.log

ASMCHK2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize ${SQLLINESIZE} pages 1000
col name for a35

-- Enable HTML color format:
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF

SPOOL ${ASM_RPT}

${HASHHTML} set pages 0
${HASHHTML} select '<b>'||'Reported By ${SCRIPT_NAME} Script'||'</b>' from dual;
${HASHHTML} set pages 1000

${HASHNONHTML} PROMPT [Reported By ${SCRIPT_NAME} Script]
${HASHNONHTML} PROMPT
${HASHNONHTML} prompt ASM DISK GROUPS:
${HASHNONHTML} PROMPT ***************

${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <p> <table border='3' bordercolor='#E67E22' color='#FFFFFF' width='25%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT ASM DISK GROUPS
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

select name,total_mb,free_mb,ROUND((1-(free_mb / total_mb))*100, 2) "%FULL" from v\$asm_diskgroup where name='${ASMDGNAME}';
spool off
exit;
EOF
)

echo "ASM DISK GROUP [${ASMDGNAME}] has reached ${ASMPRCUSED}%. Reporting the problem."
export MSGSUBJECT="ALERT: ASM DISK GROUP [${ASMDGNAME}] has reached ${ASMPRCUSED}% on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]"
cat ${ASM_RPT} > ${LOGFILE}

SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${LOGFILE}
echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}
               fi
   done

rm -f ${ASMFULL}
rm -f ${ASM_RPT}
  fi


# #########################
# Tablespaces Size Check:
# #########################

echo "Checking TABLESPACES on [${ORACLE_SID}] ..."

        if [ ${DB_VER} -gt 10 ]
         then
# If The Database Version is 11g Onwards:

TBSCHK=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF

set pages 0 termout off echo off feedback off 
col tablespace_name for A25
col y for 999999999 heading 'Total_MB'
col z for 999999999 heading 'Used_MB'
col bused for 999.99 heading '%Used'

spool ${LOG_DIR}/tablespaces_DBA_BUNDLE.log

select tablespace_name,
       (used_space*$blksize)/(1024*1024) Used_MB,
       (tablespace_size*$blksize)/(1024*1024) Total_MB,
       used_percent "%Used"
from dba_tablespace_usage_metrics;

spool off
exit;
EOF
)

         else

# If The Database Version is 10g Backwards:
# Check if AUTOEXTEND OFF (MAXSIZE=0) is set for any of the datafiles divide by ALLOCATED size else divide by MAXSIZE:
VAL33=$(${ORACLE_HOME}/bin/sqlplus -S '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_DATA_FILES WHERE MAXBYTES=0;
exit;
EOF
)
VAL44=`echo ${VAL33}| awk '{print $NF}'`
                case ${VAL44} in
                "0") CALCPERCENTAGE1="((sbytes - fbytes)*100 / MAXSIZE) bused " ;;
                  *) CALCPERCENTAGE1="round(((sbytes - fbytes) / sbytes) * 100,2) bused " ;;
                esac

VAL55=$(${ORACLE_HOME}/bin/sqlplus -S '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_TEMP_FILES WHERE MAXBYTES=0;
exit;
EOF
)
VAL66=`echo ${VAL55}| awk '{print $NF}'`
                case ${VAL66} in
                "0") CALCPERCENTAGE2="((sbytes - fbytes)*100 / MAXSIZE) bused " ;;
                  *) CALCPERCENTAGE2="round(((sbytes - fbytes) / sbytes) * 100,2) bused " ;;
                esac

TBSCHK=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 termout off echo off feedback off 
col tablespace for A25
col "MAXSIZE MB" format 9999999
col x for 999999999 heading 'Allocated MB'
col y for 999999999 heading 'Free MB'
col z for 999999999 heading 'Used MB'
col bused for 999.99 heading '%Used'
--bre on report
spool ${LOG_DIR}/tablespaces_DBA_BUNDLE.log
select a.tablespace_name tablespace,bb.MAXSIZE/1024/1024 "MAXSIZE MB",sbytes/1024/1024 x,fbytes/1024/1024 y,
(sbytes - fbytes)/1024/1024 z,
$CALCPERCENTAGE1
--round(((sbytes - fbytes) / sbytes) * 100,2) bused
--((sbytes - fbytes)*100 / MAXSIZE) bused
from (select tablespace_name,sum(bytes) sbytes from dba_data_files group by tablespace_name ) a,
     (select tablespace_name,sum(bytes) fbytes,count(*) ext from dba_free_space group by tablespace_name) b,
     (select tablespace_name,sum(MAXBYTES) MAXSIZE from dba_data_files group by tablespace_name) bb
--where a.tablespace_name in (select tablespace_name from dba_tablespaces)
where a.tablespace_name = b.tablespace_name (+)
and a.tablespace_name = bb.tablespace_name
and round(((sbytes - fbytes) / sbytes) * 100,2) > 0
UNION ALL
select c.tablespace_name tablespace,dd.MAXSIZE/1024/1024 MAXSIZE_GB,sbytes/1024/1024 x,fbytes/1024/1024 y,
(sbytes - fbytes)/1024/1024 obytes,
$CALCPERCENTAGE2
from (select tablespace_name,sum(bytes) sbytes
      from dba_temp_files group by tablespace_name having tablespace_name in (select tablespace_name from dba_tablespaces)) c,
     (select tablespace_name,sum(bytes_free) fbytes,count(*) ext from v\$temp_space_header group by tablespace_name) d,
     (select tablespace_name,sum(MAXBYTES) MAXSIZE from dba_temp_files group by tablespace_name) dd
--where c.tablespace_name in (select tablespace_name from dba_tablespaces)
where c.tablespace_name = d.tablespace_name (+)
and c.tablespace_name = dd.tablespace_name
order by tablespace;
select tablespace_name,null,null,null,null,null||'100.00' from dba_data_files minus select tablespace_name,null,null,null,null,null||'100.00'  from dba_free_space;
spool off
exit;
EOF
)
        fi
TBSLOG=${LOG_DIR}/tablespaces_DBA_BUNDLE.log
TBSFULL=${LOG_DIR}/full_tbs.log
#cat ${TBSLOG}|awk '{ print $1" "$NF }'| while read OUTPUT2
cat ${TBSLOG}|egrep -v ${EXL_TBS} |awk '{ print $1" "$NF }'| while read OUTPUT2
   do
        PRCUSED=`echo ${OUTPUT2}|awk '{print $NF}'`
        TBSNAME=`echo ${OUTPUT2}|awk '{print $1}'`
        echo "[Reported By ${SCRIPT_NAME} Script]"              >  ${TBSFULL}
        echo " "                                                >> ${TBSFULL}
        echo "Tablespace_name          %USED"                   >> ${TBSFULL}
        echo "----------------------          --------------"   >> ${TBSFULL}
#       echo ${OUTPUT2}|awk '{print $1"                              "$NF}' >> ${TBSFULL}
        echo "${TBSNAME}                        ${PRCUSED}%"    >> ${TBSFULL}

# Convert PRCUSED from float number to integer:
PRCUSED=${PRCUSED%.*}
        if [ -z ${PRCUSED} ]
         then
          PRCUSED=1
        fi
# If the tablespace %USED >= the defined threshold send an email for each tablespace:
               if [ ${PRCUSED} -ge ${TBSTHRESHOLD} ]
                 then
echo "TABLESPACE [${TBSNAME}] reached ${PRCUSED}%. Reporting the problem."
mail -s "ALERT: TABLESPACE [${TBSNAME}] reached ${PRCUSED}% on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]" ${MAIL_LIST} < ${TBSFULL}
               fi
   done

rm -f ${LOG_DIR}/tablespaces_DBA_BUNDLE.log
rm -f ${LOG_DIR}/full_tbs.log


# ############################################
# Checking Monitored Services:
# ############################################

#case ${DB_NAME} in
#ORCL)

if [ ! -x ${SERVICEMON} ]
then
echo "Checking Monitored Services on [${ORACLE_SID}] ..."
VAL_SRVMON_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off;
prompt
select count(*) from V\$ACTIVE_SERVICES where lower(NAME) in (${SERVICEMON}) or upper(NAME) in (${SERVICEMON});
exit;
EOF
) 

ONLINE_SERVICES_COUNT=`echo ${VAL_SRVMON_RAW}| awk '{print $NF}'`
#echo "Number of ONLINE Services is: $ONLINE_SERVICES_COUNT"

MONITORED_SERVICES_COUNT=`echo "${SERVICEMON}" | awk -F "," '{print NF}'`
#echo "Number of MONITORED Services is: $MONITORED_SERVICES_COUNT"

DOWN_SERVICES_COUNT=`expr ${MONITORED_SERVICES_COUNT} - ${ONLINE_SERVICES_COUNT}`
#echo "Number of OFFLINE Services is: $DOWN_SERVICES_COUNT"

               if [ ${DOWN_SERVICES_COUNT} -gt 0 ]
                 then
VAL_SRVNAME_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off;
prompt
select name from dba_services minus select name from v\$ACTIVE_SERVICES;
exit;
EOF
) 

OFFLINE_SRVNAME=`echo ${VAL_SRVNAME_RAW}| awk '{print $NF}'`

VAL_SRVMON_EMAIL=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize 160 pages 1000 echo off feedback off

-- Enable HTML color format:
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF

spool ${LOG_DIR}/current_running_services.log

${HASHHTML} set pages 0
${HASHHTML} select '<b>'||'Reported By ${SCRIPT_NAME} Script'||'</b>' from dual;
${HASHHTML} set pages 1000

${HASHNONHTML} PROMPT [Reported By ${SCRIPT_NAME} Script]
${HASHNONHTML} PROMPT

${HASHNONHTML} PROMPT
${HASHNONHTML} PROMPT SERVICE [${OFFLINE_SRVNAME}] REPORTED OFFLINE.
${HASHNONHTML} PROMPT

${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <p> <table border='3' width='30%' bordercolor='#E67E22' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT SERVICE [${OFFLINE_SRVNAME}] REPORTED OFFLINE
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

select name OFFLINE_SERVICES from dba_services minus select name from v\$active_services;

${HASHHTML} PROMPT <br>
select INST_ID,NAME ONLINE_SERVICE_NAME from GV\$ACTIVE_SERVICES where NAME not in ('SYS\$BACKGROUND','SYS\$USERS') order by ONLINE_SERVICE_NAME;
spool off
exit;
EOF
)

echo "Service Down detected [${OFFLINE_SRVNAME}]. Reporting the problem."
export MSGSUBJECT="ALERT: SERVICE [${OFFLINE_SRVNAME}] Detected OFFLINE on Instance [${ORACLE_SID}] on Server [${SRV_NAME}]"
cat ${LOG_DIR}/current_running_services.log > ${LOGFILE}

SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${LOG_DIR}/current_running_services.log
echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL} 

rm -f ${LOG_DIR}/current_running_services.log
                fi
fi

#;;
#esac


# ######################################
# Checking RMAN In-Complete Backup Jobs:
# ######################################

                case ${CHKRMANBKP} in
                 y|Y|yes|YES|Yes|ON|On|on)

echo "Checking FAILED RMAN Backup Jobs In The Last ${LAST_MIN_BKP_CHK} Minutes ..."
RMANBKPCNTRAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from v\$rman_backup_job_details where end_time > sysdate - (${LAST_MIN_BKP_CHK}/1440) and status in ('FAILED','COMPLETED WITH ERRORS');
exit;
EOF
)
RMANBKPCNT=`echo ${RMANBKPCNTRAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

  			if [ ${RMANBKPCNT} -gt 0 ]
   			then
echo "FAILED RMAN Backup Jobs Detected."
RMANBKPFAILLOG=${LOG_DIR}/RMANBKPFAILREPORT.log

RMANBKPCHK=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 1000 termout off echo off feedback off linesize ${SQLLINESIZE}

-- Enable HTML color format:
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF

spool ${RMANBKPFAILLOG}

${HASHNONHTML} PROMPT [FAILED BACKUP REPORT IN THE LAST ${LAST_MIN_BKP_CHK} Minutes]
${HASHNONHTML} PROMPT

${HASHHTML} set pages 0
${HASHHTML} select '<b>'||'Reported By ${SCRIPT_NAME} Script'||'</b>' from dual;
${HASHHTML} set pages 1000


${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <p> <table border='3' bordercolor='#E67E22' width='35%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT FAILED BACKUP REPORT IN THE LAST ${LAST_MIN_BKP_CHK} Minutes
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

col START_TIME for a15
col END_TIME for a15
col TIME_TAKEN_DISPLAY for a10
col INPUT_BYTES_DISPLAY heading "DATA SIZE" for a10
col OUTPUT_BYTES_DISPLAY heading "Backup Size" for a11
col OUTPUT_BYTES_PER_SEC_DISPLAY heading "Speed/s" for a10
col output_device_type heading "Device_TYPE" for a11
SELECT to_char (start_time,'DD-MON-YY HH24:MI') START_TIME, to_char(end_time,'DD-MON-YY HH24:MI') END_TIME, time_taken_display, status,
input_type, output_device_type,input_bytes_display, output_bytes_display, output_bytes_per_sec_display,COMPRESSION_RATIO COMPRESS_RATIO
FROM v\$rman_backup_job_details
WHERE end_time > sysdate - (${LAST_MIN_BKP_CHK}/1440)
and status in ('FAILED','COMPLETED WITH ERRORS');

spool off
exit;
EOF
)
echo "FAILED RMAN Backup Detected. Reporting the problem."
cat ${RMANBKPFAILLOG} > ${LOGFILE}
export MSGSUBJECT="Info: FAILED RMAN Backup Detected on Database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]"

SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${RMANBKPFAILLOG}
echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}
			fi
		esac


# ############################################
# Checking BLOCKING SESSIONS ON THE DATABASE:
# ############################################

echo "Checking Blocking Sessions on [${ORACLE_SID}] With Wait > 1min..."

                        if [ ${DB_VER} -gt 10 ]
                         then
                          export WAIT_COL="s2.WAIT_TIME_MICRO"
                          export WAIT_DISPLAY="round(${WAIT_COL}/1000000/60,0)"
                         else
                          export WAIT_COL="s2.SECONDS_IN_WAIT"
                          export WAIT_DISPLAY="round(${WAIT_COL}/60)"
                        fi

VAL77=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off;
select /*+RULE*/ count(*) from gv\$LOCK l1, gv\$SESSION s1, gv\$LOCK l2, gv\$SESSION s2
where s1.sid=l1.sid and s2.sid=l2.sid and l1.BLOCK=1 and l2.request > 0 and l1.id1=l2.id1 and l2.id2=l2.id2 and ${WAIT_DISPLAY} > ${WAIT_FOR_LOCK_THRES};
exit;
EOF
) 
VAL88=`echo ${VAL77}| awk '{print $NF}'`

               if [ ${VAL88} -ge ${BLOCKTHRESHOLD} ]
                 then
		  echo "BLOCKING SESSIONS detected. Reporting the problem."

VAL99=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set linesize ${SQLLINESIZE} pages 1000 echo off feedback off
col BLOCKING_STATUS for a90

-- Enable HTML color format:
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; font-size: 80%; } th { background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF

spool ${LOG_DIR}/blocking_sessions.log

${HASHHTML} set pages 0
${HASHHTML} select '<b>'||'Reported By ${SCRIPT_NAME} Script'||'</b>' from dual;
${HASHHTML} set pages 1000

${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <p> <table border='3' bordercolor='#E67E22' width='27%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT MASTER BLOCKING SESSIONS ON DATABASE [${ORACLE_SID}]
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

${HASHNONHTML} prompt ************************************ 
${HASHNONHTML} PROMPT MASTER BLOCKING SESSIONS ON DATABASE: [${ORACLE_SID}]
${HASHNONHTML} PROMPT ************************************ 

set feedback off linesize ${SQLLINESIZE} pages 1000
col "I|OS/DB USER|SID,SER|MACHN|MOD"    for a75
col "PREV|CURRENT_SQL|REMAIN_SEC"       for a30
col "ST|WAITD|ACT_SINC|LOGIN"           for a34
col event                               for a24
select  /*+RULE*/
substr(s.INST_ID||'|'||s.OSUSER||'/'||s.USERNAME||'| '||s.sid||','||s.serial#||' |'||substr(s.MACHINE,1,22)||'|'||substr(s.MODULE,1,18),1,75)"I|OS/DB USER|SID,SER|MACHN|MOD"
,substr(s.status||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||to_char(LOGON_TIME,'ddMon HH24:MI'),1,34) "ST|WAITD|ACT_SINC|LOGIN"
,substr(w.event,1,24) "EVENT"
,s.PREV_SQL_ID||'|'||s.SQL_ID||'|'||round(w.TIME_REMAINING_MICRO/1000000) "PREV|CURRENT_SQL|REMAIN_SEC"
from    gv\$session s, gv\$session_wait w
where   s.sid in (select distinct FINAL_BLOCKING_SESSION from gv\$session where FINAL_BLOCKING_SESSION is not null)
and     s.USERNAME is not null
and     s.sid=w.sid
and     s.FINAL_BLOCKING_SESSION is null
/

col "KILL MASTER BLOCKING SESSION"      for a75
select  /*+RULE*/ 'ALTER SYSTEM DISCONNECT SESSION '''||s.sid||','||s.serial#||''' IMMEDIATE;' "KILL MASTER BLOCKING SESSION"
from    gv\$session s
where   s.sid in (select distinct FINAL_BLOCKING_SESSION from gv\$session where FINAL_BLOCKING_SESSION is not null)
and     s.USERNAME is not null
and     s.FINAL_BLOCKING_SESSION is null
/


${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='27%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT List of LOCKED SESSIONS
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

${HASHNONHTML} prompt 
${HASHNONHTML} prompt ******************************

${HASHNONHTML} prompt [List of Victim LOCKED SESSIONS]
${HASHNONHTML} prompt ******************************

set linesize ${SQLLINESIZE} pages 1000 echo off feedback off
col module for a27
col event for a24
col MACHINE for a27
col "WA_ST|WAITD|ACT_SINC|LOG_T" for a38
col "INST|USER|SID,SERIAL#" for a30
col "INS|USER|SID,SER|MACHIN|MODUL" for a65
col "PREV|CURR SQLID" for a27
col "I|BLKD_BY" for a12
col "${WAIT_DISPLAY}" for 99999999.9
select /*+RULE*/
substr(s.INST_ID||'|'||s.USERNAME||'| '||s.sid||','||s.serial#||' |'||substr(s.MACHINE,1,22)||'|'||substr(s.MODULE,1,18),1,65)"INS|USER|SID,SER|MACHIN|MODUL"
,substr(w.state||'|'||round(w.WAIT_TIME_MICRO/1000000)||'|'||LAST_CALL_ET||'|'||to_char(LOGON_TIME,'ddMon'),1,38) "WA_ST|WAITD|ACT_SINC|LOG_T"
,substr(w.event,1,24) "EVENT"
,s.FINAL_BLOCKING_INSTANCE||'|'||s.FINAL_BLOCKING_SESSION "I|BLKD_BY"
from    gv\$session s, gv\$session_wait w
where   s.USERNAME is not null
and     s.FINAL_BLOCKING_SESSION is not null
and     s.sid=w.sid
and     s.STATUS='ACTIVE'
order by "I|BLKD_BY" desc,w.event,"INS|USER|SID,SER|MACHIN|MODUL","WA_ST|WAITD|ACT_SINC|LOG_T" desc;

${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='27%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT Blocking Locks On Objects Level
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

${HASHNONHTML} prompt
${HASHNONHTML} prompt ****************************

${HASHNONHTML} Prompt [Blocking Locks On Objects Level]
${HASHNONHTML} prompt ****************************

--${HASHNONHTML} PROMPT
${HASHHTML} set linesize ${SQLLINESIZE} pages 1000 echo off feedback off
${HASHNONHTML} set linesize ${SQLLINESIZE} pages 100 echo on feedback on

column OS_PID format A15 Heading "OS_PID"
column ORACLE_USER format A15 Heading "ORACLE_USER"
column LOCK_TYPE format A15 Heading "LOCK_TYPE"
column LOCK_HELD format A11 Heading "LOCK_HELD"
column LOCK_REQUESTED format A11 Heading "LOCK_REQUESTED"
column STATUS format A13 Heading "STATUS"
column OWNER format A15 Heading "OWNER"
column OBJECT_NAME format A35 Heading "OBJECT_NAME"
select  /*+RULE*/ l.sid,
        ORACLE_USERNAME oracle_user,
        decode(TYPE,
                'MR', 'Media Recovery',
                'RT', 'Redo Thread',
                'UN', 'User Name',
                'TX', 'Transaction',
                'TM', 'DML',
                'UL', 'PL/SQL User Lock',
                'DX', 'Distributed Xaction',
                'CF', 'Control File',
                'IS', 'Instance State',
                'FS', 'File Set',
                'IR', 'Instance Recovery',
                'ST', 'Disk Space Transaction',
                'TS', 'Temp Segment',
                'IV', 'Library Cache Invalidation',
                'LS', 'Log Start or Switch',
                'RW', 'Row Wait',
                'SQ', 'Sequence Number',
                'TE', 'Extend Table',
                'TT', 'Temp Table', type) lock_type,
        decode(LMODE,
                0, 'None',
                1, 'Null',
                2, 'Row-S (SS)',
                3, 'Row-X (SX)',
                4, 'Share',
                5, 'S/Row-X (SSX)',
                6, 'Exclusive', lmode) lock_held,
        decode(REQUEST,
                0, 'None',
                1, 'Null',
                2, 'Row-S (SS)',
                3, 'Row-X (SX)',
                4, 'Share',
                5, 'S/Row-X (SSX)',
                6, 'Exclusive', request) lock_requested,
        decode(BLOCK,
                0, 'Not Blocking',
                1, 'Blocking',
                2, 'Global', block) status,
        OWNER,
        OBJECT_NAME
from    v\$locked_object lo,
        dba_objects do,
        v\$lock l
where   lo.OBJECT_ID = do.OBJECT_ID
AND     l.SID = lo.SESSION_ID
AND l.BLOCK='1';

${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='35%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT Long Running Operations On DATABASE [${ORACLE_SID}]
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 1000

${HASHNONHTML} prompt
${HASHNONHTML} prompt ******************************************

${HASHNONHTML} Prompt [Long Running Operations On DATABASE $ORACLE_SID]
${HASHNONHTML} prompt ******************************************

set linesize ${SQLLINESIZE} pages 1000
col "USERNAME| SID,SERIAL#" for a40
col MESSAGE for a80
col "%COMPLETE" for 999.999
col "SID|SERIAL#" for a12
col "STARTED|MIN_ELAPSED|REMAIN" for a30
        select USERNAME||'| '||SID||','||SERIAL# "USERNAME| SID,SERIAL#",SQL_ID
        --,OPNAME OPERATION
        ,round(SOFAR/TOTALWORK*100,2) "%DONE"
        ,to_char(START_TIME,'DD-Mon HH24:MI')||'| '||trunc(ELAPSED_SECONDS/60)||'|'||trunc(TIME_REMAINING/60) "STARTED|MIN_ELAPSED|REMAIN" ,MESSAGE
        from v\$session_longops
        where SOFAR/TOTALWORK*100 <>'100'
        and TOTALWORK <> '0'
        order by "STARTED|MIN_ELAPSED|REMAIN" desc, "USERNAME| SID,SERIAL#";


${HASHHTML} SET PAGES 0
${HASHHTML} SET MARKUP HTML OFF SPOOL OFF
${HASHHTML} PROMPT <br> <p> <table border='3' bordercolor='#E67E22' width='27%' align='left' summary='Script output'> <tr> <th scope="col">
${HASHHTML} PROMPT LOCKING ANALYSIS
${HASHHTML} PROMPT </td> </tr> </table> <p> <br>
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { background: #E67E22; bordercolor: #E67E22; font-size: 80%; } th { color: #FFFFFF; background: #AF601A; } td { background: #E67E22; padding: 0px; } </style>' TABLE "border='1' bordercolor='#E67E22'" ENTMAP OFF
${HASHHTML} set pages 0 lines 300
${HASHHTML} col blocking_status for a300

${HASHNONHTML} set linesize ${SQLLINESIZE} pages 0
${HASHNONHTML} PROMPT
${HASHNONHTML} PROMPT ******************

${HASHNONHTML} PROMPT [LOCKING ANALYSIS]
${HASHNONHTML} PROMPT ******************

select /*+RULE*/ 'User: '||s1.username || '@' || s1.machine || '(SID=' || s1.sid ||' ) running SQL_ID:'||s1.sql_id||'  is blocking
User: '|| s2.username || '@' || s2.machine || '(SID=' || s2.sid || ') running SQL_ID:'||s2.sql_id||' For '||${WAIT_DISPLAY}||' Minutes
[Inform user '||s1.username||' Or Kill his session using:]
ALTER SYSTEM KILL SESSION '''||s1.sid||','||s1.serial#||''' immediate;' AS blocking_status
from gv\$LOCK l1, gv\$SESSION s1, gv\$LOCK l2, gv\$SESSION s2
 where s1.sid=l1.sid and s2.sid=l2.sid 
 and l1.BLOCK=1 and l2.request > 0
 and l1.id1 = l2.id1
 and l2.id2 = l2.id2
 order by ${WAIT_COL} desc;

spool off
exit;
EOF
)
cat ${LOG_DIR}/blocking_sessions.log > ${LOGFILE}
export MSGSUBJECT="ALERT: BLOCKING SESSIONS detected on database [${DB_NAME_UPPER}] on Server [${SRV_NAME}]"

SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${LOG_DIR}/blocking_sessions.log
echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}
rm -f ${LOG_DIR}/blocking_sessions.log
                fi
  

# #########################
# Locating DB ALERTLOG path:
# #########################
echo "Locating DB Instance ALERTLOG ..."
# First Attempt:
DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 30000;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
ALERTZ=`echo ${DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log
export ALERTDB

# Second Attempt:
        if [ ! -f ${ALERTDB} ]
         then
DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 30000;
prompt
SELECT VALUE from V\$DIAG_INFO where name='Diag Trace';
exit;
EOF
)
ALERTZ=`echo ${DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log
export ALERTDB
        fi

# Third Attempt:
        if [ ! -f ${ALERTDB} ]
         then
DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 30000;
prompt
SELECT value from v\$parameter where NAME='core_dump_dest';
exit;
EOF
)
ALERTZ=`echo ${DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|sed -e 's/\/cdump/\/trace/g'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log
export ALERTDB
	fi

# Forth Attempt:
	if [ ! -f ${ALERTDB} ]
	 then
ALERTDB=${ORACLE_BASE}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log
export ALERTDB
	fi

# Fifth Attempt: [Expensive search with locate command]
        if [ ! -f ${ALERTDB} ]
         then
                if [ -x /usr/bin/locate ]
                then
ALERTDB=`ls -rtl \`locate alert_${ORACLE_SID}\`|tail -1|awk '{print $NF}'`
export ALERTDB
                fi
	fi


# ###########################
# Checking Database Errors:
# ###########################

# ALERTLOG errors to be send in text format:
export MAILEXEC="mail -s"

# Final check of ALERTLOG path:
        if [ -f ${ALERTDB} ]
         then
          ALERTLOG=${ALERTDB}
        elif [ -f ${ORACLE_BASE}/admin/${ORACLE_SID}/bdump/alert_${ORACLE_SID}.log ]
         then
          ALERTLOG=${ORACLE_BASE}/admin/${ORACLE_SID}/bdump/alert_${ORACLE_SID}.log
        elif [ -f ${ORACLE_HOME}/diagnostics/${DB_NAME}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log ]
         then
          ALERTLOG=${ORACLE_HOME}/diagnostics/${DB_NAME}/diag/rdbms/${DB_NAME}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log
        else
          ALERTLOG=`/usr/bin/find ${ORACLE_BASE} -iname alert_${ORACLE_SID}.log  -print 2>/dev/null|sort|tail -1`
        fi

	# If HTML OPTION Enabled:
	#case ${SENDMAIL} in
   	#'/usr/sbin/sendmail -t')
	#if [ -f ${ALERTLOG} ]
	#then
	#ALERTXML=`echo ${ALERTLOG} |awk '{print $NF}'|sed -e 's/\/trace\/alert.*/\/alert\/log.xml/g'`
	#echo ALERTXML is: $ALERTXML
        #	if [ -f ${ALERTXML} ]
	#	then
	#	export ALERTLOG=${ALERTXML}
	#	fi
	#export ALERTLOG
	#echo ALERTLOG is: $ALERTLOG
	#fi
	#;;
	#esac

if [ -f ${ALERTLOG} ]
 then
 echo "Checking DB ALERTLOG ..."
# Rename the old log generated by the script (if exists):
 if [ -f ${LOG_DIR}/alert_${ORACLE_SID}_new.log ]
  then
   mv ${LOG_DIR}/alert_${ORACLE_SID}_new.log ${LOG_DIR}/alert_${ORACLE_SID}_old.log
   # Create new log:
   tail -1000 ${ALERTLOG} > ${LOG_DIR}/alert_${ORACLE_SID}_new.log
   # Extract new entries by comparing old & new logs:
   echo "[Reported By ${SCRIPT_NAME} Script]"   >  ${LOG_DIR}/diff_${ORACLE_SID}.log
   echo " "                                     >> ${LOG_DIR}/diff_${ORACLE_SID}.log
   diff ${LOG_DIR}/alert_${ORACLE_SID}_old.log ${LOG_DIR}/alert_${ORACLE_SID}_new.log |grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_${ORACLE_SID}.log

   # Search for errors:

   ERRORS=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log       | grep 'ORA-\|TNS-' |egrep -v ${EXL_DB_ALERT_ERR}| tail -1`
   EXPFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log      | grep 'DM00 '                      | tail -1`
   ALTERSFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log   | grep 'ALTER SYSTEM '              | tail -1`
   ALTERDFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log   | grep 'Completed: '                | tail -1`
   STARTUPFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log  | grep 'Starting ORACLE instance'   | tail -1`
   SHUTDOWNFLAG=`cat ${LOG_DIR}/diff_${ORACLE_SID}.log | grep 'Instance shutdown complete' | tail -1`

   FILE_ATTACH=${LOG_DIR}/diff_${ORACLE_SID}.log

 else
   # Create new log:
   echo "[Reported By ${SCRIPT_NAME} Script]"   >  ${LOG_DIR}/alert_${ORACLE_SID}_new.log
   echo " "                                     >> ${LOG_DIR}/alert_${ORACLE_SID}_new.log
   tail -1000 ${ALERTLOG}                       >> ${LOG_DIR}/alert_${ORACLE_SID}_new.log

   # Search for errors:
   ERRORS=`cat ${LOG_DIR}/alert_${ORACLE_SID}_new.log | grep 'ORA-\|TNS-' |egrep -v ${EXL_DB_ALERT_ERR}| tail -1`
   FILE_ATTACH=${LOG_DIR}/alert_${ORACLE_SID}_new.log
 fi


# Send mail in case error exist:

        case "${ERRORS}" in
        *ORA-*|*TNS-*)
                # In case time out errors reported enclose the Network Failure Staticits in the same E-mail:
		case ${TIMEOUTDIGMORE} in
		y|Y|yes|YES|Yes|true|TRUE|True|on|ON|On)
                        case "${ERRORS}" in
                        *'timed out'*)
                                case `uname` in
                                Linux )
					if [ -x /usr/bin/sar ]
					then
echo "Alertlog TIMEOUT errors reported, Checking OS Network Failure Statistics for the last 15 minutes ..."
echo -e "Netowrk Statistics are shown at the bottom of this E-mail\n$(cat ${FILE_ATTACH})"                      >  ${FILE_ATTACH}
echo ""                                                                                                 	>> ${FILE_ATTACH}
echo ""                                                                                                 	>> ${FILE_ATTACH}
echo "NIC Statistics in the last 15 minutes:"                                                           	>> ${FILE_ATTACH}
echo "*************************************"                                                           	        >> ${FILE_ATTACH}
echo "sar -n EDEV -s `date "+%H:%M:%S" -d "20 min ago"` | grep -Ev lo"                                  	>> ${FILE_ATTACH}
sar -n EDEV -s `date "+%H:%M:%S" -d "20 min ago"` | grep -Ev lo                                         	>> ${FILE_ATTACH}
					fi
                                esac
                        esac
		esac

                case ${TEMPSPACEDIGMORE} in
                y|Y|yes|YES|Yes|true|TRUE|True|on|ON|On)
                        case "${ERRORS}" in
                        *'ORA-1652'*|*'ORA-01652'*)
echo -e "TOP TEMP SPACE CONSUMERS are shown at the bottom of this E-mail\n$(cat ${FILE_ATTACH})"                >  ${FILE_ATTACH}
TOP_TEMP_CONSUMERS=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 1000 feedback off lines ${SQLLINESIZE}
SPOOL ${FILE_ATTACH} APPEND
col "USER|SID,SER|MACHIN|MODUL" for a65
COL TABLESPACE FOR A15
PROMPT
PROMPT TOP TEMP SPACE CONSUMERS:
PROMPT *************************

select substr(s.USERNAME||'|'||s.sid||','||s.serial#||'|'||substr(s.MACHINE,1,20)||'|'||substr(s.MODULE,1,20),1,65)"USER|SID,SER|MACHINE|MODULE"
,SUM (O.BLOCKS) * T.BLOCK_SIZE/1024/1024 USED_MB ,COUNT(*) SORTS#, S.SQL_ID,O.TABLESPACE
FROM V\$SORT_USAGE O, V\$SESSION S, DBA_TABLESPACES T
WHERE O.SESSION_ADDR = S.SADDR AND O.TABLESPACE = T.TABLESPACE_NAME
GROUP BY S.SID, S.SERIAL#, S.USERNAME, S.OSUSER, S.MODULE,S.MACHINE, T.BLOCK_SIZE,S.SQL_ID, O.TABLESPACE
ORDER BY USED_MB desc,S.USERNAME;
spool off
exit;
EOF
)
                        esac
                esac

cat ${FILE_ATTACH} > ${LOGFILE}
export MSGSUBJECT="ALERT: Instance [${ORACLE_SID}] on Server [${SRV_NAME}] reporting errors: ${ERRORS}"
echo ${MSGSUBJECT}
SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${LOGFILE}
#echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}

	;;
        esac

                case ${PARANOIDMODE} in
                y|Y|yes|YES|Yes|true|TRUE|True|on|ON|On)

        case "${EXPFLAG}" in
        *'DM00'*)
cat ${FILE_ATTACH} > ${LOGFILE}
export MSGSUBJECT="INFO: EXPORT/IMPORT Operation Initiated on Instance [${ORACLE_SID}] on Server [${SRV_NAME}]"
SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${LOGFILE}
#echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}
        ;;
        esac

        case "${ALTERSFLAG}" in
        *'ALTER SYSTEM'*)
cat ${FILE_ATTACH} > ${LOGFILE}
export MSGSUBJECT="INFO: ALTER SYSTEM Command Executed Against Instance [${ORACLE_SID}] on Server [${SRV_NAME}]"
echo ${MSGSUBJECT}
SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${LOGFILE}
#echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}
        ;;
        esac

        case "${ALTERDFLAG}" in
        *'Completed:'*)
cat ${FILE_ATTACH} > ${LOGFILE}
export MSGSUBJECT="INFO: MAJOR DB ACTIVITY Completed on Instance [${ORACLE_SID}] on Server [${SRV_NAME}]"
echo ${MSGSUBJECT}
SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${LOGFILE}
#echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}
        ;;
        esac

        case "${STARTUPFLAG}" in
        *'Starting ORACLE instance'*)
cat ${FILE_ATTACH} > ${LOGFILE}
export MSGSUBJECT="ALERT: Startup Event of Instance [${ORACLE_SID}] Triggered on Server [${SRV_NAME}]"
echo ${MSGSUBJECT}
SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${LOGFILE}
#echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}
        ;;
        esac

        case "${SHUTDOWNFLAG}" in
        *'Instance shutdown complete'*)
cat ${FILE_ATTACH} > ${LOGFILE}
export MSGSUBJECT="ALARM: Shutdown Event of Instance [${ORACLE_SID}] Triggered on Server [${SRV_NAME}]"
echo ${MSGSUBJECT}
SENDMAILARGS=$(
echo "To:           ${EMAIL};"
echo "Subject:      ${MSGSUBJECT} ;"
echo "Content-Type: text/html;"
echo "MIME-Version: 1.0;"
cat ${LOGFILE}
)

${MAILEXEC} "${MSGSUBJECT}" ${MAIL_LIST} < ${LOGFILE}
#echo ${SENDMAILARGS} | tr \; '\n' |awk 'length == 1 || NR == 1 {print $0} length && NR > 1 { print substr($0,2) }'| ${SENDMAIL}
        ;;
        esac

                ;;
                esac
fi


# #####################
# Reporting Offline DBs:
# #####################
# Populate ${LOG_DIR}/alldb_DBA_BUNDLE.log from ORATAB:
# put all running instances in one variable:
ALL_RUNNING_INSTANCES=`ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g"`
# Exclude all running instances/DB names from getting checked when reading ORATAB file:
grep -v '^\#' ${ORATAB} |egrep -v "${EXL_DB}"|egrep -v "${ALL_RUNNING_INSTANCES}"|grep -v "${DB_NAME_LOWER}:"| grep -v "${DB_NAME_UPPER}:"|  grep -v '^$' | grep "^" | cut -f1 -d':' > ${LOG_DIR}/alldb_DBA_BUNDLE.log

# Populate ${LOG_DIR}/updb_DBA_BUNDLE.log:
  echo ${ORACLE_SID}    >> ${LOG_DIR}/updb_DBA_BUNDLE.log
  echo ${DB_NAME}       >> ${LOG_DIR}/updb_DBA_BUNDLE.log

# End looping for databases:
echo ""
done

# Continue Reporting Offline DBs...
        case ${CHKOFFLINEDB} in
        y|Y|yes|YES|Yes|ON|On|on)
echo "Checking Offline Databases ..."
# Sort the lines alphabetically with removing duplicates:
sort ${LOG_DIR}/updb_DBA_BUNDLE.log  | uniq -d                                  >  ${LOG_DIR}/updb_DBA_BUNDLE.log.sort
sort ${LOG_DIR}/alldb_DBA_BUNDLE.log                                            >  ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort
diff ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort ${LOG_DIR}/updb_DBA_BUNDLE.log.sort   >  ${LOG_DIR}/diff_DBA_BUNDLE.sort
echo "The Following Instances are POSSIBLY Down/Hanged on [${SRV_NAME}]:"       >  ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"       >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
grep "^< " ${LOG_DIR}/diff_DBA_BUNDLE.sort | cut -f2 -d'<'                      >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo " "                                                                        >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "If above instances are permanently offline, please add their names to 'EXL_DB' parameter at line# 90 or hash their entries in ${ORATAB} to let the script ignore them in the next run." >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
OFFLINE_DBS_NUM=`cat ${LOG_DIR}/offdb_DBA_BUNDLE.log| wc -l`
  
# If OFFLINE_DBS is not null:
        if [ ${OFFLINE_DBS_NUM} -gt 4 ]
         then
echo ""                           >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "Current Running Instances:" >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo "************************"   >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
ps -ef|grep pmon|grep -v grep     >> ${LOG_DIR}/offdb_DBA_BUNDLE.log
echo ""                           >> ${LOG_DIR}/offdb_DBA_BUNDLE.log

VALX1=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 100;
spool ${LOG_DIR}/running_instances.log
set linesize ${SQLLINESIZE}
col BLOCKED for a7
col STARTUP_TIME for a19 
select instance_name INS_NAME,STATUS,DATABASE_STATUS DB_STATUS,LOGINS,BLOCKED,to_char(STARTUP_TIME,'DD-MON-YY HH24:MI:SS') STARTUP_TIME from v\$instance;
spool off
exit;
EOF
)
cat ${LOG_DIR}/running_instances.log >> ${LOG_DIR}/offdb_DBA_BUNDLE.log

echo "Offline Database Detected. Reporting the problem."
mail -s "ALARM: Database Inaccessible on Server: [${SRV_NAME}]" ${MAIL_LIST} < ${LOG_DIR}/offdb_DBA_BUNDLE.log
        fi

# Wiping Logs:
#cat /dev/null >  ${LOG_DIR}/updb_DBA_BUNDLE.log
#cat /dev/null >  ${LOG_DIR}/alldb_DBA_BUNDLE.log
#cat /dev/null >  ${LOG_DIR}/updb_DBA_BUNDLE.log.sort
#cat /dev/null >  ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort
#cat /dev/null >  ${LOG_DIR}/diff_DBA_BUNDLE.sort

rm -f ${LOG_DIR}/updb_DBA_BUNDLE.log
rm -f ${LOG_DIR}/alldb_DBA_BUNDLE.log
rm -f ${LOG_DIR}/updb_DBA_BUNDLE.log.sort
rm -f ${LOG_DIR}/alldb_DBA_BUNDLE.log.sort
rm -f ${LOG_DIR}/diff_DBA_BUNDLE.sort

        ;;
        esac


# ###########################
# Checking Listeners log:
# ###########################
# Check if the LISTENER CHECK flag is Y:

                case ${CHKLISTENER} in
                 y|Y|yes|YES|Yes|ON|On|on)
echo "Checking Listener Log ..."
# In case there is NO Listeners are running send an (Alarm):
LSN_COUNT=$( ps -ef|grep -v grep|grep tnslsnr|wc -l )

 if [ ${LSN_COUNT} -eq 0 ]
  then
   echo "The following are the LISTENERS running by user ${ORA_USER} on server ${SRV_NAME}:"    >  ${LOG_DIR}/listener_processes.log
   echo "************************************************************************************"  >> ${LOG_DIR}/listener_processes.log
   ps -ef|grep -v grep|grep tnslsnr                                                             >> ${LOG_DIR}/listener_processes.log
mail -s "ALARM: No Listeners Are Running on Server: ${SRV_NAME} !!!" ${MAIL_LIST}               <  ${LOG_DIR}/listener_processes.log
  
  # In case there is listener running analyze its log:
  else
#        for LISTENER_NAME in $( ps -ef|grep -v grep|grep tnslsnr|awk '{print $(NF-1)}' )
         for LISTENER_NAME in $( ps -ef|grep -v grep|grep tnslsnr|awk '{print $(9)}' )
         do
#         LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep "${LISTENER_NAME} "|awk '{print $(NF-2)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"`
          LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep "${LISTENER_NAME} "|awk '{print $(8)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"`
          export LISTENER_HOME
          TNS_ADMIN=${LISTENER_HOME}/network/admin; export TNS_ADMIN
          export TNS_ADMIN
          LISTENER_LOGDIR=`${LISTENER_HOME}/bin/lsnrctl status ${LISTENER_NAME} |grep "Listener Log File"| awk '{print $NF}'| sed -e 's/\/alert\/log.xml//g'`
          export LISTENER_LOGDIR
          LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
          export LISTENER_LOG

          # Determine if the listener name is in Upper/Lower case:
                if [ ! -f  ${LISTENER_LOG} ]
                 then
                  # Listner_name is Uppercase:
                  LISTENER_NAME=$( echo ${LISTENER_NAME} | awk '{print toupper($0)}' )
                  export LISTENER_NAME
                  LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
                  export LISTENER_LOG
                fi
                if [ ! -f  ${LISTENER_LOG} ]
                 then
                  # Listener_name is Lowercase:
                  LISTENER_NAME=$( echo "${LISTENER_NAME}" | awk '{print tolower($0)}' )
                  export LISTENER_NAME
                  LISTENER_LOG=${LISTENER_LOGDIR}/trace/${LISTENER_NAME}.log
                  export LISTENER_LOG
                fi

    if [ -f  ${LISTENER_LOG} ]
        then
          # Rename the old log (If exists):
          if [ -f ${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log ]
           then
              mv ${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log    ${LOG_DIR}/alert_lis_${LISTENER_NAME}_old.log
            # Create a new log:
              tail -1000 ${LISTENER_LOG}                       >  ${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log
            # Get the new entries:
              echo "[Reported By ${SCRIPT_NAME} Script]"       >  ${LOG_DIR}/diff_lis_${LISTENER_NAME}.log
              echo " "                                         >> ${LOG_DIR}/diff_lis_${LISTENER_NAME}.log
              diff ${LOG_DIR}/alert_lis_${LISTENER_NAME}_old.log  ${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log | grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_lis_${LISTENER_NAME}.log
            # Search for errors:
             #ERRORS=`cat ${LOG_DIR}/diff_lis_${LISTENER_NAME}.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
             ERRORS=`cat ${LOG_DIR}/diff_lis_${LISTENER_NAME}.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
             SRVC_REG=`cat ${LOG_DIR}/diff_lis_${LISTENER_NAME}.log| grep "service_register" `
             FILE_ATTACH=${LOG_DIR}/diff_lis_${LISTENER_NAME}.log

         # If no old logs exist:
         else
            # Just create a new log without doing any comparison:
             echo "[Reported By ${SCRIPT_NAME} Script]"         >  ${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log
             echo " "                                   	>> ${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log
             tail -1000 ${LISTENER_LOG}                 	>> ${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log

            # Search for errors:
              #ERRORS=`cat ${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log|grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
              ERRORS=`cat ${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log   | grep "TNS-"|egrep -v "${EXL_LSNR_ERR}"|tail -1`
              SRVC_REG=`cat ${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log | grep "service_register" `
              FILE_ATTACH=${LOG_DIR}/alert_lis_${LISTENER_NAME}_new.log
         fi


          # Report TNS Errors (Alert)
            case "${ERRORS}" in
            *TNS-*)
                        # In case timeout errors reported enclose the Network Failure Staticits in the same E-mail:
                case ${TIMEOUTDIGMORE} in
                y|Y|yes|YES|Yes|true|TRUE|True|on|ON|On)
                        case "${ERRORS}" in
                        *timeout*)
                                case `uname` in
                                Linux )
echo "Listener TIMEOUT errors reported, Checking OS Network Failure Statistics for the last 15 minutes ..."
echo -e "Network Statistics are shown at the bottom of this E-mail\n$(cat ${FILE_ATTACH})"              >  ${FILE_ATTACH}
echo ""                                                                                                 >> ${FILE_ATTACH}
echo ""                                                                                                 >> ${FILE_ATTACH}
echo "NIC Statistics in the last 15 minutes:"                                                           >> ${FILE_ATTACH}
echo "*************************************"                                                            >> ${FILE_ATTACH}
echo "sar -n EDEV -s `date "+%H:%M:%S" -d "20 min ago"` | grep -Ev lo"                                  >> ${FILE_ATTACH}
sar -n EDEV -s `date "+%H:%M:%S" -d "20 min ago"` | grep -Ev lo                                         >> ${FILE_ATTACH}
                                esac
                        esac
		esac
mail -s "ALERT: Listener [${LISTENER_NAME}] on Server [${SRV_NAME}] reporting errors: ${ERRORS}" ${MAIL_LIST} < ${FILE_ATTACH}
            esac


          # Report Registered Services to the listener (Info)
            case "${SRVC_REG}" in
            *service_register*)
mail -s "INFO: Service Registered on Listener [${LISTENER_NAME}] on Server [${SRV_NAME}] | TNS poisoning possibility" ${MAIL_LIST} < ${FILE_ATTACH}
            esac
        else
         echo "Cannot find the listener log: <${LISTENER_LOG}> for listener ${LISTENER_NAME} !"
    fi
        done
 fi

                esac


# ###############################
# Checking ASM Instance ALERTLOG:
# ###############################
# Manually Specify ASM Instance alertlog file location: [In case the script failed to find its location]
ASMALERT=
export ASMALERT

# Check if the CHKASMALERTLOG is enabled:
 case ${CHKASMALERTLOG} in
 y|Y|yes|YES|Yes|ON|On|on)

ASMCOUNT=`ps -ef|grep -v grep|grep asm_pmon_|wc -l`
  if [ ${ASMCOUNT} -gt 0 ]
   then
echo "[ASM Instance Found] Locating ASM Instance ALERTLOG ..."

# Fetching ASM Instance name:
ASM_INSTANCE_NAME=`ps -ef|grep pmon|grep -v grep|grep asm_pmon_|awk '{print $NF}'|sed -e 's/asm_pmon_//g'|grep -v sed|grep -v "s///g"|tail -1`
export ASM_INSTANCE_NAME

# Locating GRID_HOME:
GRID_HOME=`ps -ef|grep ocssd|grep -v grep|awk '{print $NF}'|sed -e 's/\/bin\/ocssd.bin//g'|grep -v "ocssd.bin"|tail -1`
export GRID_HOME

	if [ ! -d ${GRID_HOME} ]
	 then
GRID_HOME=`dbhome ${ASM_INSTANCE_NAME}`
export GRID_HOME
	fi

# Locating GRID_BASE:
GRID_BASE=`cat ${GRID_HOME}/crs/install/crsconfig_params|grep ^ORACLE_BASE|tail -1|awk '{print $NF}'|sed -e 's/ORACLE_BASE=//g'`
export GRID_BASE

	if [ ! -d ${GRID_BASE} ]
	 then
GRID_BASE=`cat ${GRID_HOME}/crs/utl/appvipcfg|grep ^ORACLE_BASE|tail -1|awk '{print $NF}'|sed -e 's/ORACLE_BASE=//g'`
export GRID_BASE
	fi

	if [ ! -d ${GRID_BASE} ]
	 then
GRID_BASE=`cat ${GRID_HOME}/install/envVars.properties|grep ^ORACLE_BASE|tail -1|awk '{print $NF}'|sed -e 's/ORACLE_BASE=//g'`
export GRID_BASE
	fi

# Locating ASM ALERTLOG:
ASMALERT=`ls -rtl ${GRID_BASE}/diag/asm/+asm/${ASM_INSTANCE_NAME}/trace/alert_+ASM*.log|tail -1|awk '{print $NF}'`
export ASMALERT

	if [ ! -f ${ASMALERT} ]
	then
        	if [ -x /usr/bin/locate ]
         	then
ASMALERT=`ls -rtl \`/usr/bin/locate alert_+ASM\`|tail -1|awk '{print $NF}'`
export ASMALERT
		fi
	fi

	if [ ! -d ${GRID_BASE} ]
  	 then
        	if [ -f ${ASMALERT} ]
		 then
GRID_BASE=`grep 'ORACLE_BASE from environment' ${ASMALERT} | awk '{print $(5)}'|tail -1`
export GRID_BASE
		fi
 	fi

		if [ -f ${ASMALERT} ]
		 then
		 # ASM ALERTLOG Inspection:
		 echo "Checking ASM ALERTLOG ..."
 				if [ -f ${LOG_DIR}/alertASM_new.log ]
				  then

				   mv ${LOG_DIR}/alertASM_new.log ${LOG_DIR}/alertASM_old.log
				   # Create new log:
				   tail -1000 ${ASMALERT} > ${LOG_DIR}/alertASM_new.log
				   # Extract new entries by comparing old & new logs:
				   echo "[Reported By ${SCRIPT_NAME} Script]"                                             >  ${LOG_DIR}/diff_ASMALERT.log
				   echo " "                                                                               >> ${LOG_DIR}/diff_ASMALERT.log
				   diff ${LOG_DIR}/alertASM_old.log ${LOG_DIR}/alertASM_new.log |grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_ASMALERT.log

				   # Search for errors:

				   ERRORS=`cat ${LOG_DIR}/diff_ASMALERT.log       | grep 'ORA-\|TNS-' |egrep -v ${EXL_DB_ALERT_ERR}| tail -1`
				   STARTUPFLAG=`cat ${LOG_DIR}/diff_ASMALERT.log  | grep 'Starting ORACLE instance' | tail -1`
				   SHUTDOWNFLAG=`cat ${LOG_DIR}/diff_ASMALERT.log | grep 'Instance shutdown complete' | tail -1`

				   FILE_ATTACH=${LOG_DIR}/diff_ASMALERT.log

				  else
				   # If dbalarm is running for the first time against ASM ALERTLOG, Create a new staging log:
				   echo "[Reported By ${SCRIPT_NAME} Script]"   >  ${LOG_DIR}/alertASM_new.log
				   echo " "                                     >> ${LOG_DIR}/alertASM_new.log
				   tail -1000 ${ASMALERT}                       >> ${LOG_DIR}/alertASM_new.log

				   # Search for errors:
				   ERRORS=`cat ${LOG_DIR}/alertASM_new.log | grep 'ORA-\|TNS-' |egrep -v ${EXL_DB_ALERT_ERR}| tail -1`
				   FILE_ATTACH=${LOG_DIR}/alertASM_new.log
 				fi

		 # Send E-mail alert in case any of the following errors detected:

        	case "${ERRORS}" in
	        *ORA-*|*TNS-*)
mail -s "ALERT: ASM Instance on Server [${SRV_NAME}] reporting errors: ${ERRORS}" ${MAIL_LIST} < ${FILE_ATTACH} 
echo    "ALERT: ASM Instance on Server [${SRV_NAME}] reporting errors: ${ERRORS}"
		esac

        	case "${STARTUPFLAG}" in
	        *'Starting ORACLE instance'*)
mail -s "ALERT: Startup Event of ASM Instance Triggered on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo    "ALERT: Startup Event of ASM Instance Triggered on Server [${SRV_NAME}]"
        	esac

        	case "${SHUTDOWNFLAG}" in
	        *'Instance shutdown complete'*)
mail -s "ALARM: Shutdown Event of ASM Instance Triggered on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo    "ALARM: Shutdown Event of ASM Instance Triggered on Server [${SRV_NAME}]"
        	esac

                else
                echo "Cannot find ASM ALERTLOG, locate utility is not installed on this system."
                echo "Please manually export the ASM ALERTLOG full path inside dbalarm.sh: e.g. ASMALERT=/u01/app/grid/diag/asm/+asm/+ASM/trace/alert_+ASM.log"
                fi
  fi
 esac


# ######################################
# Checking GRID INFRASTRUCTURE ALERTLOG:
# ######################################
# Manually Specify GRID INFRASTRUCTURE alertlog file location: [In case the script failed to find its location]
GRIDLOGFILE=
export GRIDLOGFILE

# Check if the CHKCLSALERTLOG flag is enabled:
 case ${CHKCLSALERTLOG} in
 y|Y|yes|YES|Yes|ON|On|on)

# Locate ADR BASE:
VAL_ADR_BASE=$(${ORACLE_HOME}/bin/adrci <<EOF
exit;
EOF
)
ADR_BASE=`echo ${VAL_ADR_BASE}|awk '{print $(NF-1)}'|sed -e 's/"//g'`
export ADR_BASE

# Check for ocssd process:
CHECK_OCSSD=`ps -ef|grep 'ocssd.bin'|grep -v grep|wc -l`
  if [ ${CHECK_OCSSD} -gt 0 ]
   then
echo "[Grid Infrastructure Setup Detected] Locating Grid Infrastructure ALERTLOG ..."
# Hashed the following line to avoid slowing down the script execution:
#GRIDLOGFILE=`locate -i crs/${HOSTNAMELOWER}/crs/trace/alert.log`

# Locate Clusterware log location:
GRIDLOGFILE="${GRID_BASE}/diag/crs/${HOSTNAMELOWER}/crs/trace/alert.log"

        if [ ! -f ${GRIDLOGFILE} ]
         then
GRIDLOGFILE="${GRID_BASE}/diag/crs/${HOSTNAMELOWER}/crs/trace/alert${HOSTNAMELOWER}.log"
        fi

        if [ ! -f ${GRIDLOGFILE} ]
         then
GRIDLOGFILE="${GRID_HOME}/log/${HOSTNAMELOWER}/alert${HOSTNAMELOWER}.log"
        fi

        if [ ! -f ${GRIDLOGFILE} ]
         then
GRIDLOGFILE="${GRID_HOME}/log/${HOSTNAMELOWER}/alert.log"
        fi

        if [ ! -f ${GRIDLOGFILE} ]
         then
GRIDLOGFILE="${ADR_BASE}/diag/crs/${HOSTNAMELOWER}/crs/trace/alert.log"
        fi

        if [ ! -f ${GRIDLOGFILE} ]
         then
GRIDLOGFILE="${ADR_BASE}/diag/crs/${HOSTNAMELOWER}/crs/trace/alert${HOSTNAMELOWER}.log"
        fi

export GRIDLOGFILE

    if [ -f ${GRIDLOGFILE} ]
    then
    # CLUSTERWARE ALERTLOG Inspection:
    echo "Checking GRID INFRASTRUCTURE ALERTLOG ..."
         if [ -f ${LOG_DIR}/alertGRID_new.log ]
          then
          mv ${LOG_DIR}/alertGRID_new.log ${LOG_DIR}/alertGRID_old.log
          # Create new logfile:
          tail -1000 ${GRIDLOGFILE} > ${LOG_DIR}/alertGRID_new.log
          # Extract the new entries by comparing old & new logs:
          echo "[Reported By ${SCRIPT_NAME} Script]"                                               >  ${LOG_DIR}/diff_GRIDALERT.log
          echo " "                                                                                 >> ${LOG_DIR}/diff_GRIDALERT.log
          diff ${LOG_DIR}/alertGRID_old.log ${LOG_DIR}/alertGRID_new.log |grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_GRIDALERT.log

          # Search for errors:

          ERRORS=`cat ${LOG_DIR}/diff_GRIDALERT.log | grep 'ORA-\|TNS-\| error \|error:\|errors with\|Errors\|failed\|fatal error\|Unable to failover\|disconnected from server\|Maximum restart attempts' |egrep -v ${EXL_GRID_ALERT_ERR}| tail -1`
	  STARTUPFLAG=`cat ${LOG_DIR}/diff_GRIDALERT.log     | grep 'is starting'                       | tail -1`
	  SHUTDOWNFLAG=`cat ${LOG_DIR}/diff_GRIDALERT.log    | grep 'is exiting'                        | tail -1`
          NODEEVECTFLAG=`cat ${LOG_DIR}/diff_GRIDALERT.log   | grep 'Node down event'                   | tail -1`
          IPCONFLICTFLAG=`cat ${LOG_DIR}/diff_GRIDALERT.log  | grep 'is already in use in the network'  | tail -1`
          HEARTBEATFLAG=`cat ${LOG_DIR}/diff_GRIDALERT.log   | grep 'not scheduled for'                 | tail -1`
          SERVICEFAILFLAG=`cat ${LOG_DIR}/diff_GRIDALERT.log | grep 'has been removed from pool'        | tail -1`


          FILE_ATTACH=${LOG_DIR}/diff_GRIDALERT.log

          else
          # If dbalarm is running for the first time against GRID ALERTLOG, Create a new staging log:
          echo "[Reported By ${SCRIPT_NAME} Script]"    >  ${LOG_DIR}/alertGRID_new.log
          echo " "                                      >> ${LOG_DIR}/alertGRID_new.log
          tail -1000 ${GRIDALERT}                       >> ${LOG_DIR}/alertGRID_new.log

          # Search for errors:
          ERRORS=`cat ${LOG_DIR}/alertGRID_new.log | grep 'ORA-\|TNS-' |egrep -v ${EXL_DB_ALERT_ERR}| tail -1`
          FILE_ATTACH=${LOG_DIR}/alertGRID_new.log
         fi

              # Send E-mail alert in case any of the following errors detected:

              case "${ERRORS}" in
              *'ORA-'*|*'TNS-'*|*' error '*|*'error:'*|*'errors with'*|*'Errors'*|*'failed'*|*'fatal error'*|*'Unable to failover'*|*'disconnected from server'*|*'Maximum restart attempts'*)
mail -s "ALERT: GRID on Server [${SRV_NAME}] reporting errors: ${ERRORS}" ${MAIL_LIST} < ${FILE_ATTACH}
echo    "ALERT: GRID on Server [${SRV_NAME}] reporting errors: ${ERRORS}"
              esac

              case "${STARTUPFLAG}" in
	      *'is starting'*)
mail -s "ALARM: GRID Startup Event Detected on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo    "ALARM: GRID Startup Event Detected."
	      esac

              case "${SHUTDOWNFLAG}" in
              *'is exiting'*)
mail -s "ALARM: GRID SHUTDOWN Event Detected on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo    "ALARM: GRID SHUTDOWN Event Detected."
              esac

              case "${NODEEVECTFLAG}" in
              *'Node down event'*)
mail -s "ALARM: GRID Node Eviction Event Detected on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo    "ALARM: GRID Node Eviction Event Detected."
              esac

              case "${IPCONFLICTFLAG}" in
              *'is already in use in the network'*)
mail -s "ALARM: IP CONFLICT Detected In The Network Impacting The GRID On Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo    "ALARM: IP CONFLICT Detected In The Network Impacting The GRID."
              esac

              case "${HEARTBEATFLAG}" in
              *'not scheduled for'*)
mail -s "ALARM: GRID HEARTBEAT Failure Detected on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo    "ALARM: GRID HEARTBEAT Failure Detected."
              esac

              case "${SERVICEFAILFLAG}" in
              *'has been removed from pool'*)
mail -s "ALARM: GRID SERVICE Down Event Detected on Server [${SRV_NAME}]" ${MAIL_LIST} < ${FILE_ATTACH}
echo    "ALARM: GRID SERVICE Down Event Detected."
              esac

    else
    echo "Unable to locate the GRID INFRASTRUCTURE ALERTLOG."
    echo "Please export it manually inside dbalarm script. e.g. GRIDLOGFILE=/u01/app/grid/diag/crs/databasemachinename/crs/trace/alert.log"
    fi
  fi
 esac


# ###########################
# Checking Goldengate Errors:
# ###########################
# Manually Specify goldengate logfile location: [In case the script failed to find its location]
ALERTGGPATH=
export ALERTGGPATH

# Check if the Goldengate CHECK flag is Y:

 case ${CHKGOLDENGATE} in
 y|Y|yes|YES|Yes|ON|On|on)
 echo "Checking GoldenGate log ..."

# Determine goldengate log path:
        if [ ! -z ${ALERTGGPATH} ]
         then
          GGLOG=${ALERTGGPATH}
	  export GGLOG
        else
          GGLOG=`/bin/ps -ef|grep ggserr.log|grep -v grep|tail -1|awk '{print $NF}'`
	  export GGLOG
        fi

# Second Attempt: [Expensive search with locate command]
        if [ -z ${GGLOG} ]
         then
                if [ -x /usr/bin/locate ]
                then
GGLOG=`ls -rtl \`/usr/bin/locate ggserr.log\`|tail -1|awk '{print $NF}'`
export GGLOG
                fi
	fi

  if [ ! -z ${GGLOG} ]
  then
# Rename the old log generated by the script (if exists):
 	if [ -f ${LOG_DIR}/ggserr_new.log ]
  	then
   	mv ${LOG_DIR}/ggserr_new.log ${LOG_DIR}/ggserr_old.log
   	# Create new staging log in case it's the first run of dbalarm.sh:
   	tail -1000 ${GGLOG}                          >  ${LOG_DIR}/ggserr_new.log

   	# Extract new entries by comparing old & new logs:
   	echo "[Reported By ${SCRIPT_NAME} Script]"   >  ${LOG_DIR}/diff_ggserr.log
   	echo " "                                     >> ${LOG_DIR}/diff_ggserr.log
   	diff ${LOG_DIR}/ggserr_old.log  ${LOG_DIR}/ggserr_new.log |grep ">" | cut -f2 -d'>' >> ${LOG_DIR}/diff_ggserr.log

   	# Search for errors:
   	#ERRORS=`cat ${LOG_DIR}/diff_ggserr.log | grep 'ERROR' |egrep -v ${EXL_GG_ERR}| tail -1`
   	ERRORS=`cat ${LOG_DIR}/diff_ggserr.log | grep 'ERROR' | tail -1`

   	FILE_ATTACH=${LOG_DIR}/diff_ggserr.log

 	else
   	# Create new log:
   	echo "[Reported By ${SCRIPT_NAME} Script]"   >  ${LOG_DIR}/ggserr_new.log
   	echo " "                                     >> ${LOG_DIR}/ggserr_new.log
   	tail -1000 ${GGLOG}                          >> ${LOG_DIR}/ggserr_new.log

   	# Search for errors:
   	#ERRORS=`cat ${LOG_DIR}/ggserr_new.log | grep 'ERROR' |egrep -v ${EXL_GG_ERR}| tail -1`
   	ERRORS=`cat ${LOG_DIR}/ggserr_new.log | grep 'ERROR' | tail -1`
   	FILE_ATTACH=${LOG_DIR}/ggserr_new.log
 	fi

# Send mail in case error exist:
        case ${ERRORS} in
        *' ERROR '*)
echo "Goldengate Error Detected. Reporting the problem."
mail -s "Goldengate Error on Server [${SRV_NAME}]: ${ERRORS}" ${MAIL_LIST} < ${FILE_ATTACH}
        esac
  fi
 esac


# #############################
# Check Device Driver Messages: [dmesg]
# #############################

 case ${DEVICEDRIVERLOG} in
 y|Y|yes|YES|Yes|ON|On|on)
 echo "Checking Device Driver [dmesg] ..."

	if [ -f ${LOG_DIR}/dmesg_new.log ]
	 then
	 mv ${LOG_DIR}/dmesg_new.log ${LOG_DIR}/dmesg_old.log
	 # Generate a new log to compare the old with:
	 dmesg > ${LOG_DIR}/dmesg_new.log
	 # Extract new entries by comparing old & new logs:
	 echo "[Reported By ${SCRIPT_NAME} Script]"                                             >  ${LOG_DIR}/diff_dmesg.log
	 echo " "                                                                               >> ${LOG_DIR}/diff_dmesg.log
	 diff ${LOG_DIR}/dmesg_old.log ${LOG_DIR}/dmesg_new.log |grep ">" | cut -f2 -d'>'       >> ${LOG_DIR}/diff_dmesg.log

	 # Search for Errors:
	 ERRORS=`cat ${LOG_DIR}/diff_dmesg.log | grep 'error' |egrep -v ${EXL_DMESG_ERR}| tail -1`
	 FILE_ATTACH=${LOG_DIR}/diff_dmesg.log

	 else
	 # If dbalarm is running for the first time against dmesg log, create a new staging log and use it for the next execution:
	 dmesg > ${LOG_DIR}/dmesg_new.log
	fi

        			case "${ERRORS}" in
			        *error*)
mail -s "ALERT: OS DEVICE DRIVER Error Detected on Server [${SRV_NAME}] | ${ERRORS}" ${MAIL_LIST} < ${FILE_ATTACH} 
echo    "ALERT: OS DEVICE DRIVER Error Detected | ${ERRORS}"
				esac
 esac


# ###############################
# De-Neutralize login.sql file:
# ###############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
	 mv ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}  ${USR_ORA_HOME}/login.sql
        fi

echo ""
echo "[dbalarm Script Completed]"
echo ""


# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
