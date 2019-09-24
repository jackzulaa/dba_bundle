# ###################################################################################
# This script Backup & Cleanup the database logs.
# To be run by ORACLE user
# [Ver 1.8]
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      03-06-2013          #   #   # #   # 
# Modified:     02-07-2013
#               14-01-2014 Customized the script to run on various environments.
#               14-06-2017 Increased the script accuracy and elimiated tar bug.
#		15-05-2018 Added the option of archiving Audit log files.
#		27-12-2018 Verify the trace/log locations are valid before cleaning.
#		23-01-2019 Added the option of Skipping backing up the trace/logs.
#
#
#
# ###################################################################################
SCRIPT_NAME="oracle_cleanup"

# ###########
# Description:
# ###########
echo
echo "=================================================================="
echo "This script will Back up & Delete the database logs and Audit logs ..."
echo "=================================================================="
echo
sleep 1

# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM|APX"                           #Excluded INSTANCES [Will not get reported offline].

# ###########################
# Listing Available Instances:
# ###########################

# Count Instance Numbers:
INS_COUNT=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|wc -l )

# Exit if No DBs are running:
if [ $INS_COUNT -eq 0 ]
 then
   echo No Database Running !
   exit
fi

# If there is ONLY one DB set it as default without prompt for selection:
if [ $INS_COUNT -eq 1 ]
 then
   export ORACLE_SID=$( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )

# If there is more than one DB ASK the user to select:
elif [ $INS_COUNT -gt 1 ]
 then
    echo
    echo "Select the Instance You Want To Backup & Delete It's Logs: [Enter the Number]"
    echo "----------------------------------------------------------"
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
        if [ -z "${REPLY##[0-9]*}" ]
         then
          export ORACLE_SID=$DB_ID
          echo Selected Instance:
          echo "********"
          echo $DB_ID
          echo "********"
          break
         else
          export ORACLE_SID=${REPLY}
          break
        fi
     done

fi
# Exit if the user selected a Non Listed Number:
        if [ -z "${ORACLE_SID}" ]
         then
          echo "You've Entered An INVALID ORACLE_SID"
          exit
        fi

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
exit
fi

# ########################################
# Exit if the user is not the Oracle Owner:
# ########################################
CURR_USER=`whoami`
        if [ ${ORA_USER} != ${CURR_USER} ]; then
          echo ""
          echo "You're Running This Sctipt with User: \"${CURR_USER}\" !!!"
          echo "Please Run This Script With The Right OS User: \"${ORA_USER}\""
          echo "Script Terminated!"
          exit
        fi

# ########################
# Getting ORACLE_BASE:
# ########################
echo "Setting ORACLE_BASE ..."
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


# Neutralize login.sql file:
# #########################
# Existance of login.sql file under current working directory eliminates many functions during the execution of this script:

        if [ -f ./login.sql ]
         then
mv ./login.sql   ./login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi

# #########################
# Getting DB_NAME:
# #########################
echo "Getting DB NAME ..."
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


# #########################
# Getting ALERTLOG path:
# #########################

# First Attempt:
VAL_DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 30000;
prompt
SELECT value from v\$parameter where NAME='background_dump_dest';
exit;
EOF
)
ALERTZ=`echo ${VAL_DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log
export ALERTDB

# Second Attempt:
        if [ ! -f ${ALERTDB} ]
         then
VAL_DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 30000;
prompt
SELECT VALUE from V\$DIAG_INFO where name='Diag Trace';
exit;
EOF
)
ALERTZ=`echo ${VAL_DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
ALERTDB=${ALERTZ}/alert_${ORACLE_SID}.log
export ALERTDB
        fi

# Third Attempt:
        if [ ! -f ${ALERTDB} ]
         then
VAL_DUMP=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 30000;
prompt
SELECT value from v\$parameter where NAME='core_dump_dest';
exit;
EOF
)
ALERTZ=`echo ${VAL_DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|sed -e 's/\/cdump/\/trace/g'`
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

   	if [ -f ${ALERTDB} ]
         then
BDUMP=`echo ${VAL_DUMP} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`
DUMP=`echo ${BDUMP} | sed 's/\/trace//g'`
CDUMP=${DUMP}/cdump
export BDUMP
export DUMP
export CDUMP

        fi

echo DUMP location is: ${DUMP}
echo BDUMP location is: ${BDUMP}

# #########
# Variables: 
# #########

echo ""
echo "Do you want to BACK UP the LOGFILES before Cleaning them up? [Y|N] Y"
echo "============================================================"
while read ANS
  do
        case $ANS in
        ""|y|Y|yes|YES|Yes) export BACKUP_FLAG="ON"; break ;;
        n|N|NO|no|No)   echo; export BACKUP_FLAG=""; break ;;
        *)              echo; echo "Please enter a VALID answer [Y|N]" ;;
        esac
  done

        case $BACKUP_FLAG in
	ON)
export HASH_BKP=""
echo ""
echo "Please Enter The Full Path of Backup Location: [/tmp]"
echo "============================================="
read LOC1
# Check if No location provided:
        if [ -z ${LOC1} ]; then
          LOC1=/tmp
          export LOC1
          echo "Database Logs Backup Will Be Saved Under: ${LOC1}"
         else
          export LOC1
          echo "Database Logs Backup Will Be Saved Under: ${LOC1}"
        fi

	if [ -d ${LOC1} ]; then
# Creating folder holds the logs:
mkdir -p ${BKP_LOC_DB}
	fi

# Check if provided location path is not exist:
        if [ ! -d ${LOC1} ]; then
          echo ""
          echo "Location Path \"${LOC1}\" is NOT EXIST!"
          echo "Script Terminated!"
          exit
        fi
	;;
	*) export HASH_BKP="echo #"
	;;
	esac


# Setting a Verifier:
echo ""
echo "Shall we go ahead with CLEANING UP LOGS and TRACES of Database \"${ORACLE_SID}\" and its Listener: [Y|N] Y"
echo "=============================================================================================="
while read ANS
  do
        case $ANS in
        ""|y|Y|yes|YES|Yes) break ;;
        n|N|NO|no|No) 	echo; echo "Script Terminated !";echo; exit; break ;;
        *) 		echo; echo "Please enter a VALID answer [Y|N]" ;;
        esac
  done


echo ""
echo "Do you want to Cleanup Database Audit files: [Y|N] Y"
echo "============================================"
while read ANS
  do
        case $ANS in
        ""|y|Y|yes|YES|Yes)     echo;export AUDIT_FILES_CLEANUP=Y ;break ;;
        n|N|NO|no|No)           echo;export AUDIT_FILES_CLEANUP=N ;break ;;
        *) 			echo;echo "Please enter a VALID answer [Y|N]" ;;
        esac
  done


BKP_BASE=${LOC1}
export BKP_BASE
BKP_LOC_DB=${BKP_BASE}/${ORACLE_SID}_logs/`uname -n`/`date '+%b_%Y'`
export BKP_LOC_DB
DB=${DB_NAME}
export DB
INS=${ORACLE_SID}
export INS

# ######################
# Getting Listener name:
# ######################
LSNR_COUNT=$( ps -ef|grep tnslsnr|grep -v grep|wc -l )

        if [ ${LSNR_COUNT} -eq 1 ]
         then
           LSNR_NAME=$( ps -ef|grep tnslsnr|grep -v grep|awk '{print $(9)}' )
         else
           LSNR_NAME=$( ps -ef|grep tnslsnr|grep -i "${ORACLE_SID} "|grep -v grep|awk '{print $(9)}' )
        fi

        if [ -z "${LSNR_NAME}" ]
         then
           LSNR_NAME=LISTENER
        fi

LISTENER_NAME=${LSNR_NAME}


# #######################
# Backup & Delete DB logs:
# #######################
	# Exit if DUMP/BDUMP/CDUMP variables are NULL:
	if [ -z "${DUMP}" ]
	then
         echo "DUMP variable is NULL."
         echo "Script Terminated."
	 exit
	fi

        if [ -z "${BDUMP}" ]
        then
         echo "BDUMP variable is NULL."
         echo "Script Terminated."
	 exit
        fi

        if [ -z "${CDUMP}" ]
        then
         echo "CDUMP variable is NULL."
         echo "Script Terminated."
	 exit
        fi

	# Exit if DUMP/BDUMP/CDUMP locations are not ACCESSIBLE:
        if [ ! -d ${DUMP} ]
         then
          echo "The Parent Log DUMP location cannot be Located!"
          exit
        fi

        if [ ! -d ${BDUMP} ]
         then
          echo "The Log BDUMP location cannot be Located!"
          exit
        fi

        if [ ! -d ${CDUMP} ]
         then
          echo "The Log CDUMP location cannot be Located!"
          exit
        fi

echo "Backing up & removing DB & Listener Logs ..."
sleep 1
tail -1000 ${ALERTDB} > ${BDUMP}/alert_${INS}.log.keep
echo "Zipping the Alertlog ..."
gzip -f9 ${BDUMP}/alert_${INS}.log 
${HASH_BKP} echo "Backing up the Alertlog ..."
${HASH_BKP} mv -f ${BDUMP}/alert_${INS}.log.gz            ${BKP_LOC_DB}
echo "Rotating the Alertlog ..."
mv -f ${BDUMP}/alert_${INS}.log.keep                      ${BDUMP}/alert_${INS}.log
#tar zcvfP ${BKP_LOC_DB}/${INS}-dump-logs.tar.gz ${DUMP}
${HASH_BKP} echo "Backing up ${DUMP} ..."
#find ${DUMP} -name '*' -print >                                ${BKP_LOC_DB}/dump_files_list.txt
#tar zcfP ${BKP_LOC_DB}/${INS}-dump-logs.tar.gz --files-from    ${BKP_LOC_DB}/dump_files_list.txt
cd ${DUMP}
${HASH_BKP} tar zcfP ${BKP_LOC_DB}/${INS}-dump-logs.tar.gz *


# Delete DB logs older than 5 days:
echo "Deleting DB logs older than 5 days under ${BDUMP} ..."
find ${BDUMP}         -type f -name '*.trc' -mtime +5 -exec rm -f {} \;
find ${BDUMP}         -type f -name '*.trm' -mtime +5 -exec rm -f {} \;
find ${BDUMP}         -type f -name '*.log' -mtime +5 -exec rm -f {} \;
echo "Deleting DB logs older than 5 days under ${DUMP}/alert ..."
find ${DUMP}/alert    -type f -name '*.xml' -mtime +5 -exec rm -f {} \;
echo "Deleting DB logs older than 5 days under ${DUMP}/incident ..."
find ${DUMP}/incident -type f -name '*.trc' -mtime +5 -exec rm -f {} \;
find ${DUMP}/incident -type f -name '*.trm' -mtime +5 -exec rm -f {} \;
find ${DUMP}/incident -type f -name '*.log' -mtime +5 -exec rm -f {} \;
echo "Deleting DB logs older than 5 days under ${CDUMP} ..."
find ${CDUMP}         -type f -name '*.trc' -mtime +5 -exec rm -f {} \;
find ${CDUMP}         -type f -name '*.trm' -mtime +5 -exec rm -f {} \;
find ${CDUMP}         -type f -name '*.log' -mtime +5 -exec rm -f {} \;

# Backup & Delete listener's logs:
# ################################
#LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep -i ${LSNR_NAME}|awk '{print $(NF-2)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"|head -1`
LISTENER_HOME=`ps -ef|grep -v grep|grep tnslsnr|grep "${LSNR_NAME} "|awk '{print $(8)}' |sed -e 's/\/bin\/tnslsnr//g'|grep -v sed|grep -v "s///g"|head -1`
TNS_ADMIN=${LISTENER_HOME}/network/admin
export TNS_ADMIN
LSNLOGDR=`${LISTENER_HOME}/bin/lsnrctl status ${LISTENER_NAME}|grep "Listener Log File"| awk '{print $NF}'| sed -e 's/\/alert\/log.xml//g'`
LISTENER_LOG=${LSNLOGDR}/trace/${LISTENER_NAME}.log
echo LISTENER_NAME: $LISTENER_NAME
echo LISTENER_HOME: $LISTENER_HOME
echo TNS_ADMIN: $TNS_ADMIN
echo LISTENER_LOG: $LISTENER_LOG

# Determine if the listener name is in Upper/Lower case:
        if [ -f ${LISTENER_LOG} ]
         then
          # Listner_name is Uppercase:
          LISTENER_NAME=$( echo ${LISTENER_NAME} | perl -lpe'$_ = reverse' |perl -lpe'$_ = reverse' )
          LISTENER_LOG=${LSNLOGDR}/trace/${LISTENER_NAME}.log
         else
          # Listener_name is Lowercase:
          LISTENER_NAME=$( echo "${LISTENER_NAME}" | tr -s  '[:upper:]' '[:lower:]' )
          LISTENER_LOG=${LSNLOGDR}/trace/${LISTENER_NAME}.log
        fi

	# Exit if LISTENER LOG directory is NULL:
	if [ -z "${LSNLOGDR}" ]
        then
         echo "LSNLOGDR variable is NULL."
         echo "Script Terminated."
         exit
        fi

	# Exit if LISTENER LOG directory is IN-ACCESSIBLE:
        if [ ! -d ${LSNLOGDR} ]
         then
          echo 'Listener Logs Location Cannot be Found!'
	  echo "Script Terminated."
	  exit
        fi

${HASH_BKP} echo "Backing up listener logs under: ${LSNLOGDR}/trace ..."
${HASH_BKP} cd ${LSNLOGDR}/trace
${HASH_BKP} tar zcfP ${BKP_LOC_DB}/${LISTENER_NAME}_trace.tar.gz *
${HASH_BKP} echo "Backing up listener logs under: ${LSNLOGDR}/alert ..."
${HASH_BKP} cd ${LSNLOGDR}/alert
${HASH_BKP} tar zcfP ${BKP_LOC_DB}/${LISTENER_NAME}_alert.tar.gz *
tail -10000 ${LSNLOGDR}/trace/${LISTENER_NAME}.log > ${LSNLOGDR}/${LISTENER_NAME}.log.keep
echo "Deleting listener logs older than 5 days under: ${LSNLOGDR}/trace ..."
find ${LSNLOGDR}/trace -type f -name '*.trc' -mtime +5 -exec rm -f {} \;
find ${LSNLOGDR}/trace -type f -name '*.trm' -mtime +5 -exec rm -f {} \;
find ${LSNLOGDR}/trace -type f -name '*.log' -mtime +5 -exec rm -f {} \;
echo "Deleting listener logs older than 5 days under: ${LSNLOGDR}/alert ..."
find ${LSNLOGDR}/alert -type f -name '*.xml' -mtime +5 -exec rm -f {} \;
echo "Rotating listener log ${LSNLOGDR}/trace/${LISTENER_NAME}.log ..."
mv -f ${LSNLOGDR}/${LISTENER_NAME}.log.keep   ${LSNLOGDR}/trace/${LISTENER_NAME}.log

# ############################
# Backup & Delete AUDIT logs:
# ############################
# Getting Audit Files Location:
# ############################

        case ${AUDIT_FILES_CLEANUP} in
        Y)

VAL_AUD=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
SELECT value from v\$parameter where NAME='audit_file_dest';
exit;
EOF
)
AUD_LOC=`echo ${VAL_AUD} | perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'`

        # Exit if AUDIT LOG variable is NULL:
        if [ -z "${AUD_LOC}" ]
        then
         echo "AUD_LOC variable is NULL."
         echo "Script Terminated."
         exit
        fi

        if [ -d ${AUD_LOC} ]
         then

#tar zcvfP ${BKP_LOC_DB}/audit_files.tar.gz ${AUD_LOC}/${ORACLE_SID}_*
#find ${AUD_LOC} -type f -name '${ORACLE_SID}_*.aud' -print >           ${BKP_LOC_DB}/audit_files_list.txt
#tar zcvfP ${BKP_LOC_DB}/${INS}-audit-logs.tar.gz --files-from          ${BKP_LOC_DB}/audit_files_list.txt
${HASH_BKP} echo "Backing up Audit files under: ${AUD_LOC} ..."
${HASH_BKP} cd ${AUD_LOC}
${HASH_BKP} tar zcfP ${BKP_LOC_DB}/${INS}-audit-logs.tar.gz ${ORACLE_SID}_*.aud

# Delete Audit logs older than 5 days
echo "Deleting Audit files older than 5 days under: ${AUD_LOC} ..."
find ${AUD_LOC} -type f -name "${ORACLE_SID}_*.aud" -mtime +5 -exec rm -f {} \;

         else
	 # Exit if AUDIT LOG directory is IN-ACCESSIBLE:
         echo "Audit Files Location Cannot be Found!"
	 exit
        fi

        ;;
        esac

echo ""
echo "------------------------------------"
echo "Old logs are backed up under: ${BKP_LOC_DB}"
echo "The Last 5 Days Logs are KEPT."
echo "CLEANUP COMPLETED."
echo "------------------------------------"
echo

# De-Neutralize login.sql file:
# ############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ./login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ./login.sql_NeutralizedBy${SCRIPT_NAME}  ./login.sql
        fi

        if [ -f ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}  ${USR_ORA_HOME}/login.sql
        fi

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: <mahmmoudadel@hotmail.com>.
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: 
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
