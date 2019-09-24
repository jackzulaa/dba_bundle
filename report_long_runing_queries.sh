# ##################################################################################
# Checking long running queries run by specific user
# [Ver 1.2]
#
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      09-03-17            #   #   # #   #  
# Modified:	21-01-19 Enhanced the fetch for ORACLE_HOME
#		19-02-19 Enabled the HTML report version
#
#
#
#
#
#
#
#
#
#
#
# ##################################################################################
EMAIL="youremail@yourcompany.com"

SCRIPT_NAME="report_long_runing_queries"
SRV_NAME=`uname -n`

        case ${EMAIL} in "youremail@yourcompany.com")
         echo
         echo "****************************************************************************************************"
         echo "Buddy! You will not receive an E-mail with the result, because you didn't set EMAIL variable yet"
         echo "Just replace youremail@yourcompany.com with your right email."
         echo "****************************************************************************************************"
         echo 
        esac

export EMAIL

# #########################
# THRESHOLDS:
# #########################
# Modify the THRESHOLDS to the value you prefer:

EXEC_TIME_IN_MINUTES=60		# Report Sessions running longer than N minutes [Default is 60 minutes].
LONG_RUN_SESS_COUNT=0		# CONTROL the number of long running sessions if reached, the report will tirgger. [Default 0 which means report all long running sessions].
HTMLENABLE=Y            	# Enable HTML Email Format

export EXEC_TIME_IN_MINUTES
export LONG_RUN_SESS_COUNT


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM|APX"                           #Excluded INSTANCES [Will not get reported offline].


# #########################
# SQLPLUS Output Format:
# #########################
SQLLINESIZE=160
SQLPAGES=1000
SQLLONG=999999999

export SQLLINESIZE
export SQLPAGES
export SQLLONG


# ##########################
# Neutralize login.sql file: [Bug Fix]
# ##########################
# Existance of login.sql file under Oracle user Linux home directory eliminates many functions during the execution of this script from crontab:

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi


# #########################
# Setting ORACLE_SID:
# #########################
for ORACLE_SID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
   do
    export ORACLE_SID

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
	if [ -f /usr/bin/locate ]
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


# #########################
# Variables:
# #########################
export PATH=$PATH:${ORACLE_HOME}/bin
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

export LOGFILE=${LOG_DIR}/reported_long_running_sessions.log

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


# ##########################
# Neutralize login.sql file: [Bug Fix]
# ##########################
# Existance of login.sql file under Oracle user Linux home directory eliminates many functions during the execution of this script from crontab:

        if [ -f ${USR_ORA_HOME}/login.sql ]
         then
mv ${USR_ORA_HOME}/login.sql   ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}
        fi


# ####################################
# SCRIPT ENGINE:
# ####################################

# Check the Long Running Session Count:
LONG_RUN_COUNT_RAW2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select count(*) from v\$session
where
-- To capture active session for more than defined EXEC_TIME_IN_MINUTES variable in minutes:
last_call_et > 60*${EXEC_TIME_IN_MINUTES}
and username is not null 
and module is not null
and module not like 'backup%'
and status = 'ACTIVE';
exit;
EOF
)

LONG_RUN_COUNT2=`echo ${LONG_RUN_COUNT_RAW2}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

  if [ ${LONG_RUN_COUNT2} -gt ${LONG_RUN_SESS_COUNT} ]
   then
# Long running query output:
LONG_QUERY_DETAIL2=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set linesize ${SQLLINESIZE} pages ${SQLPAGES}
-- Enable HTML color format:
${HASHHTML} SET WRAP OFF ECHO OFF FEEDBACK OFF MARKUP HTML ON SPOOL ON HEAD '<title></title> <style type="text/css"> table { font-size: 90%; } th { background: #AF601A; } </style>' TABLE "border='2' bordercolor='#E67E22'" ENTMAP OFF

set long ${SQLLONG}
col module 			for a30
col DURATION_HOURS 		for 99999.9
col STARTED_AT 			for a13
col "USERNAME| SID,SERIAL#" 	for a30
col "SQL_ID | SQL_TEXT" 	for a${SQLLINESIZE}
spool ${LOGFILE}
select username||'| '||sid ||','|| serial# "USERNAME| SID,SERIAL#",substr(MODULE,1,30) "MODULE", to_char(sysdate-last_call_et/24/60/60,'DD-MON HH24:MI') STARTED_AT,
last_call_et/60/60 "DURATION_HOURS"
,SQL_ID ||' | '|| (select SQL_FULLTEXT from v\$sql where address=sql_address and CHILD_NUMBER=SQL_CHILD_NUMBER) "SQL_ID | SQL_TEXT"
--,SQL_ID ||' | '|| (select SQL_FULLTEXT from v\$sql where address=sql_address) "SQL_ID | SQL_TEXT"
--,SQL_ID
from v\$session
where
-- To capture active session for more than defined EXEC_TIME_IN_MINUTES variable in minutes:
last_call_et > 60*${EXEC_TIME_IN_MINUTES}
and username is not null 
and module is not null
and module not like 'backup%'
and status = 'ACTIVE'
order by "DURATION_HOURS" desc;
spool off
exit;
EOF
)

cat ${LOGFILE}
export MSGSUBJECT="Info: Long Running Queries on DB [${ORACLE_SID}] on Server [${SRV_NAME}]"

${MAILEXEC} "${MSGSUBJECT}" ${EMAIL} < ${LOGFILE}

(
echo "To: ${EMAIL};"
echo "MIME-Version: 1.0"
echo "Content-Type: text/html;"
echo "Subject: ${MSGSUBJECT}"
cat ${LOGFILE}
) | ${SENDMAIL}

  fi


done

# #############################
# De-Neutralize login.sql file:
# #############################
# If login.sql was renamed during the execution of the script revert it back to its original name:
        if [ -f ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME} ]
         then
mv ${USR_ORA_HOME}/login.sql_NeutralizedBy${SCRIPT_NAME}  ${USR_ORA_HOME}/login.sql
        fi


# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
