# ###########################################################################
# This script shows all held locks on an object
# To be run by ORACLE user		
# Ver 1.0
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	01-08-2019	    #   #   # #   # 
# Modified:	
#		
#		
# ###########################################################################

# ###########
# Description:
# ###########
echo
echo "============================================="
echo "This script shows all held lock on an object."
echo "============================================="
echo
sleep 1


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM|APX"                           #Excluded INSTANCES [Will not get reported offline].


# ##############################
# SCRIPT ENGINE STARTS FROM HERE ............................................
# ##############################

# ###########################
# Listing Available Databases:
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
    echo "Select the ORACLE_SID:[Enter the number]"
    echo ---------------------
    select DB_ID in $( ps -ef|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g" )
     do
        if [ -z "${REPLY##[0-9]*}" ]
         then
          export ORACLE_SID=$DB_ID
          echo Selected Instance: $DB_ID
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
  USR_ORA_HOME=`grep ${ORA_USER} /etc/passwd| cut -f6 -d ':'|tail -1`

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
#echo "ORACLE_HOME from PWDX is ${ORACLE_HOME}"

# ATTEMPT2: If ORACLE_HOME not found get it from oratab file:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
## If OS is Linux:
if [ -f /etc/oratab ]
  then
  ORATAB=/etc/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME

## If OS is Solaris:
elif [ -f /var/opt/oracle/oratab ]
  then
  ORATAB=/var/opt/oracle/oratab
  ORACLE_HOME=`grep -v '^\#' $ORATAB | grep -v '^$'| grep -i "^${ORACLE_SID}:" | perl -lpe'$_ = reverse' | cut -f3 | perl -lpe'$_ = reverse' |cut -f2 -d':'`
  export ORACLE_HOME
fi
#echo "ORACLE_HOME from oratab is ${ORACLE_HOME}"
fi

# ATTEMPT3: If ORACLE_HOME is still not found, search for the environment variable: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`env|grep -i ORACLE_HOME|sed -e 's/ORACLE_HOME=//g'`
  export ORACLE_HOME
#echo "ORACLE_HOME from environment  is ${ORACLE_HOME}"
fi

# ATTEMPT4: If ORACLE_HOME is not found in the environment search user's profile: [Less accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`grep -h 'ORACLE_HOME=\/' $USR_ORA_HOME/.bash_profile $USR_ORA_HOME/.*profile | perl -lpe'$_ = reverse' |cut -f1 -d'=' | perl -lpe'$_ = reverse'|tail -1`
  export ORACLE_HOME
#echo "ORACLE_HOME from User Profile is ${ORACLE_HOME}"
fi

# ATTEMPT5: If ORACLE_HOME is still not found, search for orapipe: [Least accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
        if [ -x /usr/bin/locate ]
         then
ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
export ORACLE_HOME
        fi
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


# #########################
# SQLPLUS Section:
# #########################
# PROMPT FOR VARIABLES:
# ####################
echo
echo "Please Enter the OBJECT NAME:"
echo "============================"
while read OBJECT_NAME
 do
        if [ -z ${OBJECT_NAME} ]
         then
          echo
          echo "Enter the OBJECT NAME:"
          echo "====================="
         else
OBJECT_COUNT_RAW=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_OBJECTS WHERE OBJECT_TYPE in ('TABLE','MATERIALIZED VIEW') and OBJECT_NAME=UPPER('${OBJECT_NAME}');
EOF
)
OBJECT_COUNT=`echo ${OBJECT_COUNT_RAW}| awk '{print $NF}'`

                if [ ${OBJECT_COUNT} -eq 0 ]
                 then
                  echo
                  echo "INFO: OBJECT [${OBJECT_NAME}] IS NOT EXIST !"
                  echo; echo "Searching the database for objects having similar name ..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
col OBJECT_NAME for a45
col OBJECT_TYPE for a45
select OWNER,OBJECT_NAME,OBJECT_TYPE FROM DBA_OBJECTS WHERE OBJECT_TYPE in ('TABLE','MATERIALIZED VIEW') and OBJECT_NAME like UPPER('%${OBJECT_NAME}%') order by OWNER;
EOF
                  echo; echo "Enter a VALID OBJECT NAME:"
                        echo "========================="
                 else
                  break
                fi
        fi
 done

                if [ ${OBJECT_COUNT} -eq 1 ]
		then
OBJECT_OWNER_RAW=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT OWNER FROM DBA_OBJECTS WHERE OBJECT_TYPE in ('TABLE','MATERIALIZED VIEW') and OBJECT_NAME=UPPER('${OBJECT_NAME}');
EOF
)
export OBJECT_OWNER=`echo ${OBJECT_OWNER_RAW}| awk '{print $NF}'`
		fi

		if [ ${OBJECT_COUNT} -gt 1 ]
		then
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
col OBJECT_NAME for a45
col OBJECT_TYPE for a45
select OWNER,OBJECT_NAME,OBJECT_TYPE FROM DBA_OBJECTS WHERE OBJECT_TYPE in ('TABLE','MATERIALIZED VIEW') and OBJECT_NAME like UPPER('%${OBJECT_NAME}%') order by OWNER;
EOF

echo ""
echo "Please Enter the OBJECT OWNER:"
echo "============================="
while read OBJECT_OWNER
 do
        if [ -z ${OBJECT_OWNER} ]
         then
          echo
          echo "Enter the OBJECT OWNER:"
          echo "======================"
         else
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 0 feedback off;
SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME=upper('${OBJECT_OWNER}');
EOF
)
VAL22=`echo ${VAL11}| awk '{print $NF}'`
                if [ ${VAL22} -eq 0 ]
                 then
                  echo
                  echo "INFO: SCHEMA [${OBJECT_OWNER}] IS NOT EXIST ON DATABASE [${ORACLE_SID}] !"
                  echo; echo "Searching for existing SCHEMAS matching the provided string ..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
select username "Users match provided string" from dba_users where username like upper ('%${OBJECT_OWNER}%');
EOF
                  echo; echo "Enter a VALID SCHEMA USER:"
                        echo "========================="
                 else
                  break
                fi
        fi
 done
		fi

# Execution of SQL Statement:
# ##########################
${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 1000 linesize 169 heading on feedback on
prompt
prompt -------------------------------------------------

Prompt Listing all locks on object [${OBJECT_NAME}]
prompt -------------------------------------------------

column LOCK_TYPE      format A30
column LOCK_HELD      format A18
column LOCK_REQUESTED format A11
column STATUS         format A13
column LOCK_HELD_SEC  format 99999999
column "DB_SID | OS_PID"          format A15
column "OWNER.OBJECT_NAME"        format A45
column "LOCK HOLDER: DB_USER | OS_USER" format A30
select  /*+RULE*/ OWNER||'.'||OBJECT_NAME "OWNER.OBJECT_NAME", ORACLE_USERNAME||' | '||lo.OS_USER_NAME "LOCK HOLDER: DB_USER | OS_USER",l.sid||' | '|| lo.PROCESS "DB_SID | OS_PID",
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
                'TT', 'Temp Table', type)||' | '||
        decode(LMODE,
                0, 'None',
                1, 'Null',
                2, 'row share lock',
                3, 'row exclusive lock',
                4, 'Share',
                5, '(SSX)exclusive lock',
                6, 'Exclusive', lmode) lock_type,
                l.CTIME LOCK_HELD_SEC,
        decode(REQUEST,
                0, 'None',
                1, 'Null',
                2, 'row share lock',
                3, 'row exclusive lock',
                4, 'Share',
                5, '(SSX)exclusive lock',
                6, 'Exclusive', request) lock_requested,
        decode(BLOCK,
                0, 'Not Blocking',
                1, 'Blocking',
                2, 'Global', block) status
from    v\$locked_object lo, dba_objects do, v\$lock l
where   lo.OBJECT_ID = do.OBJECT_ID
AND 	OWNER=upper('${OBJECT_OWNER}')
AND	OBJECT_NAME=upper('${OBJECT_NAME}')
AND     l.SID = lo.SESSION_ID
order by OWNER,OBJECT_NAME;

EOF

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html

