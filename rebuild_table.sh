# #########################################################################################################################################################
# Ver 2.5
# SCRIPT TO REBUILD A GIVEN TABLE AND ITS INDEXES USING ONLINE FEATURES DBMS_REDEFINITION/ONLINE REBUILD IF AVAILABLE OR OFFLINE REBUILD AS A FINAL RESORT
# #########################################################################################################################################################
#
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	16-06-14	    #   #   # #   # 
#
# Modified:	17-06-14 Inform the user if the DB is in Force Logging Mode.
#		16-09-14 Added Search Feature.
#		04-01-16 Added DEGREE OF PARALLELISM calculation.
#		11-04-19 Added ONLINE table rebuild for Oracle 12.2.
#		15-04-19 Added pctfree option to the rebuild command.
#		16-04-19 Added DBMS_REDEIFINITION to the list of rebuild options.
#		18-04-19 Added ALERTLOG notification when the DBMS_REDEIFINITION process reach to the Final Step: [Manual Mode]
#		21-04-19 Added COMPRESSION option to ALTER TABLE REBUILD option.
#		25-04-19 Added the check for the free space on the underlying tablespace.
#		05-05-19 Added PCTFREE option for DBMS_REDEIFINITION process
#		05-05-19 Fix the bug of not showing UNUSABLE INDEXES after the rebuild by using the outer join.
#		05-05-19 Increased DDL LOCK timeout to 5 minutes to avoid the failure of the rebuild operation due to failure to aquire a lock.
#		09-05-19 Included "WHENEVER SQLERROR EXIT" to the SQLPLUS script to terminate the rebuild if any stage return errors.
#		25-08-19 Fix a bug of non integer index/lob size when login.sql is active.
# #########################################################################################################################################################

SCRIPT_NAME="rebuild_table"

# ###########
# VARIABLES:
# ###########
LIST_TOP_FRAG_TABS=Y	# LIST TOP 50 FRAGMENTED TABLE EACH TIME SCRIPT RUN [Y/N]
CHECK_SPACE=Y		# CHECK IF THE UNDERLYING TABLESPACE HAS SUFFICENT SPACE FOR THE REBUILD OPERATION [Y/N]

export LIST_TOP_FRAG_TABS
export CHECK_SPACE

# ###########
# Description:
# ###########
echo
echo "============================================"
echo "This script REBUILDS A TABLE and its INDEXES ..."
echo "============================================"
echo "It will check if the table is eligible for REBUILD using DBMS_REDEIFINITION [Very Minimal Downtime will happen on the table]."
echo "It will check if you are on 12.2 or higher so ALTER TABLE MOVE ONLINE will be used [Very Minimal Downtime will happen on the table]."
echo "If NO ONLINE TABLE REBUILD Options are available it will use ALTER TABLE MOVE and rebuild its INDEXES. [A DOWNTIME will be mandatory on the table]"
echo "Lastly, You will be prompted to utilize options like Parallelism/Compression/Gather Statistics if they are available in your DB Edition."
echo ""
echo "Note: It's highly recommended to take a FULL DB BACKUP before running the rebuild process, and make sure the UNDO TABLESPACE and ARCHIVE LOCATION are big enough."
echo
sleep 5


# #######################################
# Excluded INSTANCES:
# #######################################
# Here you can mention the instances the script will IGNORE and will NOT run against:
# Use pipe "|" as a separator between each instance name.
# e.g. Excluding: -MGMTDB, ASM instances:

EXL_DB="\-MGMTDB|ASM|APX"                           #Excluded INSTANCES [Will not get reported offline].

# ###########################
# List Available Databases:
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
          echo Selected Instance:
          echo
          echo "********"
          echo $DB_ID
          echo "********"
          echo
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
  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|egrep -v ${EXL_DB}|awk '{print $1}'|tail -1`
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

# #####################
# Getting DB Block Size:
# #####################
VAL302=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select value from v\$parameter where name='db_block_size';
exit;
EOF
)
blksize=`echo ${VAL302}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# ###################
# Checking DB Version:
# ###################

VAL311=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select version from v\$instance;
exit;
EOF
)
DB_VER=`echo ${VAL311}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`
DB_RELEASE=`echo ${VAL311}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f2 -d '.'`

CHK_IDX_ONLINE_OPTION_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off echo off;
SELECT count(*) from v\$option where parameter='Online Index Build' and value='TRUE';
exit;
EOF
)
CHK_IDX_ONLINE_OPTION=`echo ${CHK_IDX_ONLINE_OPTION_RAW} | awk '{print $NF}'`

	if [ ${CHK_IDX_ONLINE_OPTION} -eq 1 ]
         then
export ONLINE_REBUILD="ONLINE"
	fi

        if [ ${DB_VER} -eq 12 ]
         then
        	if [ ${DB_RELEASE} -gt 1 ]
	 	 then
                	if [ ${CHK_IDX_ONLINE_OPTION} -eq 1 ]
                 	 then
export ORACLE12_ONLINE="ONLINE"
export ORACLE12_HASH="--"
			fi
		fi
	fi

        if [ ${DB_VER} -gt 12 ]
         then
                        if [ ${CHK_IDX_ONLINE_OPTION} -eq 1 ]
                         then
export ORACLE12_ONLINE="ONLINE"
export ORACLE12_HASH="--"
                        fi
        fi


# ##############################
# LIST TOP 50 FRAGMENTED TABLES:
# ##############################

case ${LIST_TOP_FRAG_TABS} in
y|Y|yes|YES|Yes)

${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set pages 1000 lines 169 feedback off
col owner                for a30
col "%RECLAIMABLE_SPACE" for 99
col "%FRAGMENTED_SPACE"  for a17
col LAST_ANALYZED        for a13
PROMPT
PROMPT LIST OF TOP FRAGMENTED TABLES ON THE DB: [The accuracy of this list depends on the existance of recent STATISTICS on tables]
PROMPT ----------------------------------------

select * from (select owner,table_name,to_char(LAST_ANALYZED, 'DD-MON-YYYY') LAST_ANALYZED,
round(blocks * ${blksize}/1024/1024)     "FULL_SIZE_MB",
round(num_rows * avg_row_len/1024/1024)  "ACTUAL_SIZE_MB",
round(blocks * ${blksize}/1024/1024) - round(num_rows * avg_row_len/1024/1024) "FRAGMENTED_SPACE_MB",
round(((round((blocks * ${blksize}/1024/1024), 2) - round((num_rows * avg_row_len/1024/1024), 2)) / round((blocks * ${blksize}/1024/1024), 2)) * 100)||'%' "%FRAGMENTED_SPACE"
from dba_tables
where
owner <> 'SYS'
and blocks>10
and round(blocks * ${blksize}/1024/1024) > 10
-- List only the tables having Fragmented Space > 30%:
and ((round((blocks * ${blksize}/1024/1024), 2) - round((num_rows * avg_row_len/1024/1024), 2)) / round((blocks * ${blksize}/1024/1024), 2)) * 100 > 30
order by "FRAGMENTED_SPACE_MB" desc) where rownum<51;
PROMPT
EOF
echo "";;
esac


# Checking FORCE LOGGING mode:
# ###########################
VAL1=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
select force_logging from v\$database;
EOF
)
VAL2=`echo ${VAL1}| awk '{print $NF}'`
                        case ${VAL2} in
                        YES) echo
                             echo "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
                             echo "INFO: THE DATABASE IS IN FORCE LOGGING MODE."
                             echo "vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv"
                             echo;sleep 2;;
                        *);;
                        esac

echo
echo "Enter the OWNER of The Table:"
echo "============================="
while read OWNER
 do
        case ${OWNER} in
          "")echo
             echo "Enter the OWNER of the Table:"
             echo "============================";;
          *)
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_USERS WHERE USERNAME=upper('${OWNER}');
EOF
)

VAL22=`echo ${VAL11}| awk '{print $NF}'`
                        case ${VAL22} in
                        0) echo;echo "ERROR: USER [${OWNER}] IS NOT EXIST ON DATABASE [${ORACLE_SID}] !"
                           echo; echo "Searching For Users Match The Provided String ..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
select username "Users Match Provided String" from dba_users where username like upper ('%${OWNER}%');
EOF
                           echo;echo "Enter A Valid Table Owner:"
                           echo "=========================";;
                        *) break;;
                        esac
          esac
 done
echo
echo "Enter the TABLE Name:"
echo "===================="
while read OBJECT_NAME
 do
        case ${OBJECT_NAME} in
          "")echo
             echo "Enter the TABLE NAME:"
             echo "====================";;
          *)
VAL11=$(${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
SELECT COUNT(*) FROM DBA_TABLES WHERE OWNER=upper('${OWNER}') AND TABLE_NAME=UPPER('${OBJECT_NAME}');
EOF
)

VAL22=`echo ${VAL11}| awk '{print $NF}'`
                        case ${VAL22} in
                        0) echo;echo "INFO: TABLE [${OBJECT_NAME}] IS NOT EXIST UNDER SCHEMA [${OWNER}] !"
                           echo;echo "Searching for tables match the provided string ..."; sleep 1
${ORACLE_HOME}/bin/sqlplus -s '/ as sysdba' << EOF
set linesize 143
set pagesize 1000
set feedback off
set trim on
set echo off
select table_name "Tables Match Provided String" from dba_tables where owner=upper('${OWNER}') and table_name like upper ('%${OBJECT_NAME}%');
EOF
                           echo;echo "Enter A VALID TABLE NAME:"
                           echo "========================";;
                        *) break;;
                        esac
          esac
 done

VALLASTANALYZED=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select LAST_ANALYZED from DBA_TABLES where OWNER= upper('${OWNER}') and TABLE_NAME= upper('${OBJECT_NAME}');
exit;
EOF
)
LASTANALYZED=`echo ${VALLASTANALYZED}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

VALTABUPDATES=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select UPDATES from DBA_TAB_MODIFICATIONS where TABLE_OWNER= upper('${OWNER}') and TABLE_NAME= upper('${OBJECT_NAME}');
exit;
EOF
)
TABUPDATES=`echo ${VALTABUPDATES}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# ###################
# Getting DB Version:
# ###################

VAL311=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off;
prompt
select version from v\$instance;
exit;
EOF
)
DB_VER=`echo ${VAL311}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`


# ###################
# Getting TABLE SIZE:
# ###################
        case ${CHECK_SPACE} in
        y|Y|yes|YES|Yes)
	echo ""
	echo "[Calculating Table Size] ..."

# TABLE SIZE:
SINGLETABLESIZE_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off lines 1000;
prompt
select /*+RULE*/ ROUND(SUM(BYTES)/1024/1024) FROM DBA_SEGMENTS where owner=upper('${OWNER}') and SEGMENT_NAME=upper('${OBJECT_NAME}');
exit;
EOF
)
export SINGLETABLESIZE=`echo ${SINGLETABLESIZE_RAW} |perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# LOB SIZE:
LOBSIZE_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off lines 1000;
prompt
SELECT /*+RULE*/ ROUND(SUM(BYTES)/1024/1024) FROM DBA_SEGMENTS WHERE SEGMENT_NAME IN 
(SELECT /*+RULE*/ SEGMENT_NAME FROM DBA_LOBS WHERE owner=upper('${OWNER}') AND table_name=UPPER('${OBJECT_NAME}')); 
exit;
EOF
)
export LOBSIZE=`echo ${LOBSIZE_RAW} |perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# Zeriong an empty lob size:
        if [ -z ${LOBSIZE} ]
        then
        export LOBSIZE=0
        fi

# Zeriong a non integer LOB size:
INT='^[0-9]+$'
        if ! [[ ${LOBSIZE} =~ $INT ]]
         then
          export LOBSIZE=0

        fi


# INDEXES SIZE:
INDEXESSIZE_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off lines 1000;
prompt
SELECT /*+RULE*/ round(SUM(BYTES/1024/1024)) FROM SYS.DBA_SEGMENTS WHERE OWNER = upper('${OWNER}')
AND SEGMENT_NAME in (select index_name from dba_indexes where owner=upper('${OWNER}') and table_name=UPPER('${OBJECT_NAME}'));
exit;
EOF
)
export INDEXESSIZE=`echo ${INDEXESSIZE_RAW} |perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

# Zeriong an empty index size:
	if [ -z ${INDEXESSIZE} ]
	 then
	  export INDEXESSIZE=0
	fi

# Zeriong a non integer index size:
INT='^[0-9]+$'
	if ! [[ $INDEXESSIZE =~ $INT ]]
	 then
          export INDEXESSIZE=0

	fi

# TABLE + LOBS + INDEXES SIZE:
#export TABLESIZE=$(echo "${SINGLETABLESIZE} + ${LOBSIZE} + ${INDEXESSIZE}" | bc)
export TABLESIZE=$(awk "BEGIN {print ${SINGLETABLESIZE} + ${LOBSIZE} + ${INDEXESSIZE}}")
echo "[TABLE & INDEXES SIZE:  ${TABLESIZE} MB]"

export SAFE_MARGIN="1.25"
#export TABLESIZEPLUSMARGIN=$(echo "${TABLESIZE} * ${SAFE_MARGIN}" | bc)
export TABLESIZEPLUSMARGIN=$(awk "BEGIN {print ${TABLESIZE} * ${SAFE_MARGIN}}")

# Convert TABLESIZEPLUSMARGIN from float number to integer:
export TABLESIZEPLUSMARGIN=${TABLESIZEPLUSMARGIN%.*}

# ##########################################
# Check the underlying TABLESPACE FREE SPACE:
# ##########################################
# Check the underlying tablespace:
UNDERLYINGTBS_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off lines 1000;
prompt
select tablespace_name from dba_tables where owner=upper('${OWNER}') and table_name=upper('${OBJECT_NAME}');
prompt
exit;
EOF
)
UNDERLYINGTBS=`echo ${UNDERLYINGTBS_RAW} |perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`
	echo ""
        echo "[Checking if [${UNDERLYINGTBS}] tablespace has SUFFICIENT FREE SPACE for this REBUILD operation] ..."

# Check the FREE SPACE on the underlying tablespace:
UNDERLYINGTBS_FREE_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off lines 1000;
prompt
select /*+RULE*/ round(((tablespace_size*${blksize})/(1024*1024)) - ((used_space*${blksize})/(1024*1024)))
from dba_tablespace_usage_metrics where tablespace_name=upper('${UNDERLYINGTBS}');
prompt
exit;
EOF
)
UNDERLYINGTBS_FREE=`echo ${UNDERLYINGTBS_FREE_RAW} | awk '{print $NF}'`

# EXIT if the underlying tablespace FREE SPACE is less than TABLE SIZE + The SAFE MARGIN:

	if [ ${UNDERLYINGTBS_FREE} -lt ${TABLESIZEPLUSMARGIN} ]
	 then
	 #REQUIREDSPACE=$(echo "${TABLESIZE} - ${UNDERLYINGTBS_FREE}" | bc)
	 REQUIREDSPACE=$(awk "BEGIN {print ${TABLESIZE} - ${UNDERLYINGTBS_FREE}}")
	 echo ""
	 echo -e "\033[32;5mThe underlying tablespace [${UNDERLYINGTBS}] does NOT has SUFFICIENT FREE SPACE for this operation!\033[0m"
	 echo "TABLE & INDEXES SIZE:  ${TABLESIZE} MB"
	 echo "TABLESPACE FREE SPACE: ${UNDERLYINGTBS_FREE} MB"
	 echo "You need to add at least ${REQUIREDSPACE} MB of extra space to [${UNDERLYINGTBS}] tablespace and then re-run the rebuild script again."
	 echo "If you think [${UNDERLYINGTBS}] tablespace has sufficient space and you want to skip this check, set CHECK_SPACE=N in the script."
	 echo ""
	 echo "SCRIPT TERMINATED!"
	 echo ""
	 exit 1
	 else
	 echo "[TABLESPACE FREE SPACE: ${UNDERLYINGTBS_FREE} MB]"
	 echo ""
	 echo "[Tablespace [${UNDERLYINGTBS}] has SUFFICIENT FREE SPACE.]"
	fi

	;;
	esac


# ########################################################
# Check if the supplement logging is enabled on the table:
# ########################################################
CHECK_REPLICATION_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select count(*) from DBA_LOG_GROUPS where OWNER= upper('${OWNER}') and TABLE_NAME= upper('${OBJECT_NAME}');
exit;
EOF
)
CHECK_REPLICATION=`echo ${CHECK_REPLICATION_RAW} | awk '{print $NF}'`

        if [ ${CHECK_REPLICATION} -gt 0 ]
         then
	 echo ""
	 echo -e "\033[32;5mWARNING WARNING WARNING!\033[0m"
	 echo "IS THIS TABLE IS GETTING REPLICATED TO ANOTHER DATABASE USING A REPLICATION TOOL i.e. Goldengate/Streams?"
	 echo "If this is the case; Then please Note that target table MAY miss some live data during the final SWAP step."
	 echo "Be in the safe side and run this script in MANUAL mode and execute the SWAP command while the APPLICATION is DOWN."
	 echo ""
	 echo "..."
	 sleep 30
	fi
	

# ####################
# PARALLEL DEGREE:
# ####################

# Computing the default PARALLEL DEGREE based on CPU count:
        case `uname` in
        Linux ) export PARALLEL_DEGREE=`cat /proc/cpuinfo| grep processor|wc -l`;;
	AIX )   export PARALLEL_DEGREE=`lsdev -C|grep Process|wc -l`;;
        SunOS ) export PARALLEL_DEGREE=`kstat cpu_info|grep core_id|sort -u|wc -l`;;
        HP-UX)  export PARALLEL_DEGREE=`lsdev -C|grep Process|wc -l`;;
        esac

        if [ ! -z "${PARALLEL_DEGREE##[0-9]*}" ]
                 then
                 export PARALLEL_DEGREE=1
        fi

echo ""
echo "Enter the PARALLEL DEGREE for this rebuild operation? [Blank value means use the MAX CPU resources where DEGREE=${PARALLEL_DEGREE}]"
echo "===================================================="
echo "[The HIGHER the PARALLELISM DEGREE the FASTER the REBUILD, but don't exceed the current number of CPUs [${PARALLEL_DEGREE}] on your system.]"
echo "[Note: 1 means NO Parallelism.]"
while read ENTERED_DEGREE
        do
                integ='^[0-9]+$'
                if ! [[ ${ENTERED_DEGREE} =~ ${integ} ]] ; then
                        echo "Error: Not a valid number !"
                        echo
                        echo "Please Enter a VALID NUMBER for PARALLEL DEGREE:"
                        echo "------------------------------------------------"
                else
			export PARALLEL_DEGREE=${ENTERED_DEGREE}
                        break
                fi
        done


# ##########################################################
# Check if the table can be REBUILD using DBMS_REDEFINITION:
# ##########################################################
echo ""
echo "[Checking if DBMS_REDEFINITION can be used to rebuild the table] ..."
CHK_ONLINE_REDEFINITION_OPTION_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off echo off;
SELECT count(*) from v\$option where parameter='Online Redefinition' and value='TRUE';
exit;
EOF
)
CHK_ONLINE_REDEFINITION_OPTION=`echo ${CHK_ONLINE_REDEFINITION_OPTION_RAW} | awk '{print $NF}'`

        if [ ${CHK_ONLINE_REDEFINITION_OPTION} -eq 1 ]
         then

USEREDEFINITIONRAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 lines 1000;
prompt
EXEC DBMS_REDEFINITION.can_redef_table(upper('${OWNER}'),upper('${OBJECT_NAME}'),options_flag => DBMS_REDEFINITION.CONS_USE_ROWID);
exit;
EOF
)
USEREDEFINITION=`echo ${USEREDEFINITIONRAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

        case ${USEREDEFINITIONRAW} in
	*'currently being redefined'*)
	export OBJECT_NAME_INT=${OBJECT_NAME}_NTR
	echo "Looks you already ran the script against the same table and failed."
	echo -e "\033[32;5mPlease run the following command to CLEANUP the STATE of the previous execution then run rebuild_table script again:\033[0m"
	echo ""
	echo "EXEC DBMS_REDEFINITION.abort_redef_table(upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'));"
        echo ""
        echo "SCRIPT TERMINATED!"
        echo ""
        exit 1;;
	esac

	case ${USEREDEFINITION} in
	*completed*)
echo ""
echo -e "\033[32;5mVoila! TABLE [${OBJECT_NAME}] is eligible to be rebuild ONLINE using DBMS_REDEFINITION [with a Very Minimal Downtime on the table].\033[0m"

echo ""
echo "Do you want to use DBMS_REDEFINITION for ONLINE Table REBUILD with a MINIMAL DOWNTIME on the table? [Y|N] Y"
echo "==================================================================================================="
echo "Enter NO in case you want to use ALTER TABLE MOVE option."
while read ANS
  do
case $ANS in
""|y|Y|yes|YES|Yes)

# Creating the INTERIM TABLE:
export OBJECT_NAME_INT=${OBJECT_NAME}_INT

# Check if the INTERIM TABLE is already exist:
INTERIM_TABLE_EXIST_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off echo off;
SELECT count(*) from dba_tables where owner=upper('${OWNER}') and table_name=upper('${OBJECT_NAME_INT}');
exit;
EOF
)
INTERIM_TABLE_EXIST=`echo ${INTERIM_TABLE_EXIST_RAW} | awk '{print $NF}'`

        if [ ${INTERIM_TABLE_EXIST} -eq 1 ]
         then
	 echo -e "\033[32;5mThe INTERIM table [${OWNER}.${OBJECT_NAME_INT}] IS ALREADY EXIST!\033[0m"
         echo "Changing the INTERIM TABLE NAME to [${OBJECT_NAME}_XNT]."
         export OBJECT_NAME_INT=${OBJECT_NAME}_XNT

# Second Attempt of checking the existance of INTERIM table:
INTERIM_TABLE_EXIST2_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off echo off;
SELECT count(*) from dba_tables where owner=upper('${OWNER}') and table_name=upper('${OBJECT_NAME_INT}');
exit;
EOF
)
INTERIM_TABLE_EXIST2=`echo ${INTERIM_TABLE_EXIST2_RAW} | awk '{print $NF}'`

        if [ ${INTERIM_TABLE_EXIST2} -eq 1 ]
         then
         echo -e "\033[32;5mAgain! A table with same name of the INTERIM table [${OBJECT_NAME_INT}] IS ALREADY EXIST!\033[0m"
         echo "Most probably you ran this script multiple times against the same table, if this is the case; then please DROP the old INTERIM tables|MATERIALIZED VIEWS."
         echo "SCRIPT TERMINATED!"
         echo ""
         exit 1
        fi

        fi


# SETTING PCT_FREE FOR THE TABLE AFTER THE REBUILD:
# #################################################
VALDEFAULTPCTFREE=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select PCT_FREE from DBA_TABLES where owner=upper('${OWNER}') and table_name=upper('${OBJECT_NAME}');
exit;
EOF
)
DEFAULTPCTFREE=`echo ${VALDEFAULTPCTFREE}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

echo ""
echo "INFO: Current PCTFREE: ${DEFAULTPCTFREE}"
echo "INFO: Number of \"UPDATE\" transactions on the table since the last Statistics Gather on [${LASTANALYZED}]: ${TABUPDATES}"
echo 

echo
echo "Specify the table PCTFREE after the rebuild: [How much %Free space will be left in each block for future updates | Current ${DEFAULTPCTFREE}%]"
echo "==========================================="
echo "Note: The SMALLER the PCTFREE the SMALLER the table size after the rebuild. [Recommended for Archival/Datawarehouse Tables]"
echo "Note: If the table is highly updated it's recommended to keep the current PCTFREE: ${DEFAULTPCTFREE}"
echo "Leave it BLANK and hit Enter to keep the default PCTFREE."
while read TABPCTFREEVAL
 do
        case ${TABPCTFREEVAL} in
          "") export TABPCTFREE=${DEFAULTPCTFREE}
              break;;
    *[!0-9]*) echo "Please enter a valid NUMBER for PCTFREE:";;
           *) export TABPCTFREE=${TABPCTFREEVAL}
              break;;
        esac
 done

# INTERIM TABLE CREATION:
INTERIMTABLECREATIONRAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 lines 1000;
prompt
CREATE TABLE ${OWNER}.${OBJECT_NAME_INT} PCTFREE ${TABPCTFREE} AS SELECT * FROM ${OWNER}.${OBJECT_NAME} WHERE 1=2;
exit;
EOF
)
INTERIMTABLECREATION=`echo ${INTERIMTABLECREATIONRAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

        case ${INTERIMTABLECREATION} in
        *created*)
echo "The INTERIM table [${OBJECT_NAME_INT}] created successfully."

echo ""
echo "Do you want to run the FINAL step of SWAPPING to the new table MANUALLY? [Where the minimal DOWNTIME will occur] [Y|N] Y"
echo "======================================================================="
echo "Enter [NO] to let the script to run all the steps AUTOMATICALLY for you."
while read MANUALRUN
  do
	case $MANUALRUN in
	""|y|Y|yes|YES|Yes)export HASHNOTIFY="";export HASHSWAP="--";export HASHSTATS="--"; break;;
	n|N|no|NO|No)   export HASHNOTIFY="--";export HASHSWAP="";export HASHSTATS=""
			echo ""
			echo "Do you want to GATHER NEW STATISTICS after table rebuild [Recommended]? [Y|N] Y"
			echo "======================================================================"
			echo "Enter NO to keep the old statistics after the rebuild."
			while read ANS2
			  do
				case $ANS2 in
				""|y|Y|yes|YES|Yes) 	export HASHSTATS=""; break;;
				n|N|no|NO|No)       	export HASHSTATS="--"; break;;
				*) 			echo "Please enter a VALID answer [Y|N]" ;;
				esac
			  done
			break;;
	*)              echo "Please enter a VALID answer [Y|N]" ;;
	esac
 done

# Creating the REBUILD script:

        if [ ! -d ${USR_ORA_HOME} ]
         then
          export USR_ORA_HOME=/tmp
        fi

REBUILDTABLESCRIPT=${USR_ORA_HOME}/REBUILDTABLESCRIPT-${OWNER}.${OBJECT_NAME}.sql
REBUILDTABLESCRIPTRUNNER=${USR_ORA_HOME}/REBUILDTABLESCRIPT-${OWNER}.${OBJECT_NAME}.sh
REBUILDTABLESPOOL=${USR_ORA_HOME}/REBUILDTABLESCRIPT-${OWNER}.${OBJECT_NAME}.log

echo "spool ${REBUILDTABLESPOOL}"                                               >  ${REBUILDTABLESCRIPT}
echo "PROMPT THIS OPERATION IS LOGGED IN: [${REBUILDTABLESPOOL}]"               >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "set pages 0 feedback off lines 168"                                       >> ${REBUILDTABLESCRIPT}
echo "EXEC DBMS_SESSION.set_identifier('REBUILDING_${OWNER}.${OBJECT_NAME}');"  >> ${REBUILDTABLESCRIPT}
echo "PROMPT ***************"                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT Session Details:"                                                  >> ${REBUILDTABLESCRIPT}
echo "PROMPT ***************"                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "select 'OSPID:   '||p.spid from v\$session s, v\$process p where s.sid=(select sid from v\$mystat where rownum=1) and s.paddr=p.addr;"   >> ${REBUILDTABLESCRIPT}
echo "select 'SID:     '||sid from v\$mystat where rownum = 1;"                 >> ${REBUILDTABLESCRIPT}
echo "select 'Serial#: '||s.serial# from v\$session s where s.sid = (select sid from v\$mystat where rownum = 1);"	>> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT You can KILL this session using this command:"                     >> ${REBUILDTABLESCRIPT}
echo "PROMPT ********************************************"                      >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "select 'ALTER SYSTEM DISCONNECT SESSION '''||sid||','||serial#||''' IMMEDIATE;' from v\$session where sid = (select sid from v\$mystat where rownum = 1);"                                       >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT TABLE INFO BEFORE THE REBUILD:"  					>> ${REBUILDTABLESCRIPT}
echo "PROMPT *****************************"  					>> ${REBUILDTABLESCRIPT}
echo ""  									>> ${REBUILDTABLESCRIPT}
echo "set linesize 168 pages 1000 heading on feedback on"  			>> ${REBUILDTABLESCRIPT}
echo "col \"OWNER.TABLE\" for a35"  						>> ${REBUILDTABLESCRIPT}
echo "col tablespace_name for a20"  						>> ${REBUILDTABLESCRIPT}
echo "col \"READONLY\" for a8"  						>> ${REBUILDTABLESCRIPT}
echo "col \"%RECLAIMABLE_SPACE\" for 999"  					>> ${REBUILDTABLESCRIPT}
echo "col LAST_ANALYZED for a13"  						>> ${REBUILDTABLESCRIPT}
echo "col COMPRESSION for a8"                                                   >> ${REBUILDTABLESCRIPT}
echo ""  									>> ${REBUILDTABLESCRIPT}
echo "select /*+RULE*/ t.owner||'.'||t.table_name \"OWNER.TABLE\",t.TABLESPACE_NAME,d.extents,t.LOGGING"  	>> ${REBUILDTABLESCRIPT}
echo ",t.COMPRESSION,t.READ_ONLY \"READONLY\",o.created,to_char(t.LAST_ANALYZED, 'DD-MON-YYYY') LAST_ANALYZED"  >> ${REBUILDTABLESCRIPT}
echo ",round(d.bytes/1025/1024) SIZE_MB,"  					>> ${REBUILDTABLESCRIPT}
echo "round((t.blocks * ${blksize}/1024/1024), 2) - round((t.num_rows * t.avg_row_len/1024/1024), 2) \"FRAGMENTED_SPACE_MB\","  >> ${REBUILDTABLESCRIPT}
echo "((round((t.blocks * ${blksize}/1024/1024), 2) - round((t.num_rows * t.avg_row_len/1024/1024), 2)) /"  	>> ${REBUILDTABLESCRIPT}
echo "round((t.blocks * ${blksize}/1024/1024), 2)) * 100 \"%RECLAIMABLE_SPACE\""  				>> ${REBUILDTABLESCRIPT}
echo "from dba_tables t, dba_objects o, dba_segments d"  			>> ${REBUILDTABLESCRIPT}
echo "where t.owner= upper('${OWNER}')"  					>> ${REBUILDTABLESCRIPT}
echo "and t.table_name = upper('${OBJECT_NAME}')"  				>> ${REBUILDTABLESCRIPT}
echo "and o.owner=t.owner"  							>> ${REBUILDTABLESCRIPT}
echo "and o.object_name=t.table_name"  						>> ${REBUILDTABLESCRIPT}
echo "and o.owner=d.owner"  							>> ${REBUILDTABLESCRIPT}
echo "and t.table_name=d.SEGMENT_NAME;"  					>> ${REBUILDTABLESCRIPT}
echo ""  									>> ${REBUILDTABLESCRIPT}
echo "PROMPT LOBS:"                                                             >> ${REBUILDTABLESCRIPT}
echo "PROMPT -----"                                                             >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "col COMPRESSION for a8"                                                   >> ${REBUILDTABLESCRIPT}
echo "col SECUREFILE for a10"                                                   >> ${REBUILDTABLESCRIPT}
echo "col COLUMN_NAME for a40"                                                  >> ${REBUILDTABLESCRIPT}
echo "select SEGMENT_NAME,COLUMN_NAME,TABLESPACE_NAME,INDEX_NAME,SECUREFILE,COMPRESSION from dba_lobs"		>> ${REBUILDTABLESCRIPT}
echo "where owner=upper('${OWNER}') and table_name = upper('${OBJECT_NAME}');"  >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT INDEXES BEFORE THE REBUILD:"  					>> ${REBUILDTABLESCRIPT}
echo "PROMPT ---------------------------"  					>> ${REBUILDTABLESCRIPT}
echo ""  									>> ${REBUILDTABLESCRIPT}
echo "COLUMN OWNER FORMAT A25 heading \"Index Owner\""  			>> ${REBUILDTABLESCRIPT}
echo "COLUMN INDEX_NAME FORMAT A30 heading \"Index Name\""  			>> ${REBUILDTABLESCRIPT}
echo "COLUMN COLUMN_NAME FORMAT A25 heading \"On Column\""  			>> ${REBUILDTABLESCRIPT}
echo "COLUMN COLUMN_POSITION FORMAT 9999 heading \"Pos\""  			>> ${REBUILDTABLESCRIPT}
echo "COLUMN \"INDEX\" FORMAT A35"  						>> ${REBUILDTABLESCRIPT}
echo "COLUMN INDEX_TYPE FOR A21"  						>> ${REBUILDTABLESCRIPT}
echo "SELECT /*+RULE*/ IND.OWNER||'.'||IND.INDEX_NAME \"INDEX\","  		>> ${REBUILDTABLESCRIPT}
echo "       IND.INDEX_TYPE,"  							>> ${REBUILDTABLESCRIPT}
echo "       COL.COLUMN_NAME,"  						>> ${REBUILDTABLESCRIPT}
echo "       COL.COLUMN_POSITION,"  						>> ${REBUILDTABLESCRIPT}
echo "       IND.TABLESPACE_NAME,"  						>> ${REBUILDTABLESCRIPT}
echo "       IND.STATUS,"  							>> ${REBUILDTABLESCRIPT}
echo "       IND.UNIQUENESS,"  							>> ${REBUILDTABLESCRIPT}
echo "       IND.LAST_ANALYZED,round(d.bytes/1024/1024) SIZE_MB"  		>> ${REBUILDTABLESCRIPT}
echo "FROM   SYS.DBA_INDEXES IND,"  						>> ${REBUILDTABLESCRIPT}
echo "       SYS.DBA_IND_COLUMNS COL,"  					>> ${REBUILDTABLESCRIPT}
echo "       DBA_SEGMENTS d"  							>> ${REBUILDTABLESCRIPT}
echo "WHERE  IND.TABLE_NAME = upper('${OBJECT_NAME}')"  			>> ${REBUILDTABLESCRIPT}
echo "AND    IND.TABLE_OWNER = upper('${OWNER}')"  				>> ${REBUILDTABLESCRIPT}
echo "AND    IND.TABLE_NAME = COL.TABLE_NAME"  					>> ${REBUILDTABLESCRIPT}
echo "AND    IND.OWNER = d.OWNER(+)"  						>> ${REBUILDTABLESCRIPT}
echo "AND    IND.OWNER = COL.INDEX_OWNER"  					>> ${REBUILDTABLESCRIPT}
echo "AND    IND.TABLE_OWNER = COL.TABLE_OWNER"  				>> ${REBUILDTABLESCRIPT}
echo "AND    IND.INDEX_NAME = COL.INDEX_NAME"  					>> ${REBUILDTABLESCRIPT}
echo "AND    IND.INDEX_NAME = d.SEGMENT_NAME(+);"  				>> ${REBUILDTABLESCRIPT}
echo "PROMPT"  									>> ${REBUILDTABLESCRIPT}
echo ""  									>> ${REBUILDTABLESCRIPT}
echo "PROMPT CONSTRAINTS BEFORE THE REBUILD:"                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT -------------------------------"                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "col CONSTRAINT_NAME for a30"                                              >> ${REBUILDTABLESCRIPT}
echo "col R_CONSTRAINT_NAME for a30"                                            >> ${REBUILDTABLESCRIPT}
echo "select CONSTRAINT_NAME,CONSTRAINT_TYPE,R_CONSTRAINT_NAME,STATUS,DEFERRED,INDEX_NAME from dba_constraints where">> ${REBUILDTABLESCRIPT}
echo "OWNER=upper('${OWNER}') and TABLE_NAME=upper('${OBJECT_NAME}') order by CONSTRAINT_TYPE;"                      >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT [Setting the PARALLELISM FACTOR to ${PARALLEL_DEGREE}] ..."        >> ${REBUILDTABLESCRIPT}
echo "alter session enable parallel dml;"                                       >> ${REBUILDTABLESCRIPT}
echo "alter session force parallel dml parallel ${PARALLEL_DEGREE};"            >> ${REBUILDTABLESCRIPT}
echo "alter session force parallel ddl parallel ${PARALLEL_DEGREE};"            >> ${REBUILDTABLESCRIPT}
echo "alter session force parallel query parallel ${PARALLEL_DEGREE};"          >> ${REBUILDTABLESCRIPT}
echo "PROMPT [Setting the SESSION DDL WAIT FOR LOCK to 5 minutes] ..."          >> ${REBUILDTABLESCRIPT}
echo "alter session set ddl_lock_timeout=300;"                                  >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT [Setting the SESSION RESUMABLE TIMEOUT to 6 Hours] ..."            >> ${REBUILDTABLESCRIPT}
echo "ALTER SESSION ENABLE RESUMABLE TIMEOUT 21600 NAME 'REBUILD_OF_TABLE_${OBJECT_NAME}';"  >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT [Starting REBUILDING the table using DBMS_REDEFINITION] ..."       >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT At anytime you can abort the REBUILD process by executing this command:"  						  >> ${REBUILDTABLESCRIPT}
echo "PROMPT ----------------------------------------------------------------------"                                              >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT exec dbms_redefinition.abort_redef_table(upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'));;" >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT REBUILDING TABLE PROCEDURE WILL START WITHIN 5 Seconds ..."        >> ${REBUILDTABLESCRIPT}
echo "PROMPT -------------------------------------------------------"           >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "SET FEEDBACK OFF"                                                         >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(4);"                                                 >> ${REBUILDTABLESCRIPT}
echo "PROMPT [5]"                                                               >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(1);"                                                 >> ${REBUILDTABLESCRIPT}
echo "PROMPT [4]"                                                               >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(1);"                                                 >> ${REBUILDTABLESCRIPT}
echo "PROMPT [3]"                                                               >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(1);"                                                 >> ${REBUILDTABLESCRIPT}
echo "PROMPT [2]"                                                               >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(1);"                                                 >> ${REBUILDTABLESCRIPT}
echo "PROMPT [1]"                                                               >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(1);"                                                 >> ${REBUILDTABLESCRIPT}
echo "SET FEEDBACK ON"                                                          >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT Keep checking the progress using this statement:"                  >>${REBUILDTABLESCRIPT}
echo "PROMPT ------------------------------------------------"                  >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT col OPERATION                    for a21"                          >>${REBUILDTABLESCRIPT}
echo "PROMPT col \"%DONE\"                      for 999.999"                    >>${REBUILDTABLESCRIPT}
echo "PROMPT col \"STARTED|MIN_ELAPSED|REMAIN\" for a26"                        >>${REBUILDTABLESCRIPT}
echo "PROMPT col MESSAGE                      for a90"                          >>${REBUILDTABLESCRIPT}
echo "PROMPT col \"USERNAME| SID,SERIAL#\"      for a28"                        >>${REBUILDTABLESCRIPT}
echo "PROMPT select USERNAME||'| '||SID||','||SERIAL# \"USERNAME| SID,SERIAL#\",SQL_ID,round(SOFAR/TOTALWORK*100,2) \"%DONE\""    >>${REBUILDTABLESCRIPT}
echo "PROMPT ,to_char(START_TIME,'DD-Mon HH24:MI')||'| '||trunc(ELAPSED_SECONDS/60)||'|'||trunc(TIME_REMAINING/60) \"STARTED|MIN_ELAPSED|REMAIN\" ,MESSAGE" >>${REBUILDTABLESCRIPT}
echo "PROMPT from v\$session_longops"                                           >>${REBUILDTABLESCRIPT}
echo "PROMPT where TARGET LIKE UPPER('%${OBJECT_NAME}%') and TOTALWORK <> '0' and SOFAR/TOTALWORK*100 <>'100'"                    >>${REBUILDTABLESCRIPT}
echo "PROMPT order by \"STARTED|MIN_ELAPSED|REMAIN\" desc, \"USERNAME| SID,SERIAL#\";;"                                           >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "--Exit the script if any failure encountered at any stage:"               >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "set serveroutput on"                                                      >>${REBUILDTABLESCRIPT}
echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;"                                      >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT START DUPLICATING THE TABLE TO [${OBJECT_NAME_INT}]: [The execution time is dependant on the size of the table and its indexes]"	>>${REBUILDTABLESCRIPT}
echo "PROMPT ---------------------------------------------------------"         >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT EXEC DBMS_REDEFINITION.start_redef_table(upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'),options_flag => DBMS_REDEFINITION.CONS_USE_ROWID);;"  >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} PROMPT [AN ORA-NOTIFICATION MESSAGE WILL BE WRITTEN TO THE ALERTLOG ONEC THE REBUILD OPERATION IS COMPLETED.]"                >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT NOTE: Feel free to exit from this session as the script is running in the BACKGROUND." >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "SET TIMING ON"                                                            >>${REBUILDTABLESCRIPT}
echo "EXEC DBMS_REDEFINITION.start_redef_table(upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'),options_flag => DBMS_REDEFINITION.CONS_USE_ROWID);"         >>${REBUILDTABLESCRIPT}
echo "SET TIMING OFF"                                                           >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT [INTERIM TABLE INITIAL COPY COMPLETED.]"                           >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT Creating Dependant Objects [Including Indexes] ..."                >>${REBUILDTABLESCRIPT}
echo "PROMPT ----------------------------------------------"                    >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT DECLARE"                                                           >>${REBUILDTABLESCRIPT}
echo "PROMPT num_errors PLS_INTEGER;;"                                          >>${REBUILDTABLESCRIPT}
echo "PROMPT BEGIN"                                                             >>${REBUILDTABLESCRIPT}
echo "PROMPT DBMS_REDEFINITION.COPY_TABLE_DEPENDENTS (upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'),"   >>${REBUILDTABLESCRIPT}
echo "PROMPT DBMS_REDEFINITION.CONS_ORIG_PARAMS, TRUE, TRUE, TRUE, TRUE, num_errors, TRUE);;"                                     >>${REBUILDTABLESCRIPT}
echo "PROMPT END;;"                                                             >>${REBUILDTABLESCRIPT}
echo "PROMPT /"                                                                 >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "SET TIMING ON"                                                            >>${REBUILDTABLESCRIPT}
echo "DECLARE"                                                                  >>${REBUILDTABLESCRIPT}
echo "num_errors PLS_INTEGER;"                                                  >>${REBUILDTABLESCRIPT}
echo "BEGIN"                                                                    >>${REBUILDTABLESCRIPT}
echo "DBMS_REDEFINITION.COPY_TABLE_DEPENDENTS (upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'),"          >>${REBUILDTABLESCRIPT}
echo "DBMS_REDEFINITION.CONS_ORIG_PARAMS, TRUE, TRUE, TRUE, TRUE, num_errors, TRUE);" >>${REBUILDTABLESCRIPT}
echo "END;"                                                                     >>${REBUILDTABLESCRIPT}
echo "/"                                                                        >>${REBUILDTABLESCRIPT}
echo "SET TIMING OFF"                                                           >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT [DEPENDANT OBJECTS CREATED.]"                                      >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT [Checking the ERROR Log:]"                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT SELECT OBJECT_NAME,DDL_TEXT FROM DBA_REDEFINITION_ERRORS WHERE BASE_TABLE_NAME=UPPER('${OBJECT_NAME}');;"            >>${REBUILDTABLESCRIPT}
echo "set long 200"                                                             >>${REBUILDTABLESCRIPT}
echo "col DDL_TXT for a200"                                                     >>${REBUILDTABLESCRIPT}
echo "select object_name, ddl_txt from DBA_REDEFINITION_ERRORS where base_table_name=upper('${OBJECT_NAME}');"                    >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT Running the FINAL SYNC of the INTERIM TABLE Before the Actual SWAP:"   						  >>${REBUILDTABLESCRIPT}
echo "PROMPT ------------------------------------------------------------------">>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT EXEC DBMS_REDEFINITION.sync_interim_table(upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'));;">>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "SET TIMING ON"                                                            >>${REBUILDTABLESCRIPT}
echo "EXEC DBMS_REDEFINITION.sync_interim_table(upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'));"        >>${REBUILDTABLESCRIPT}
echo "SET TIMING OFF"                                                           >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT Running a COMPARISON between the OLD and NEW TABLE:"               >>${REBUILDTABLESCRIPT}
echo "PROMPT ***************************************************"               >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT TABLES:"                                                           >> ${REBUILDTABLESCRIPT}
echo "PROMPT ------"                                                            >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "set linesize 168 pages 1000 heading on feedback off"                      >> ${REBUILDTABLESCRIPT}
echo "col \"TABLE_NAME\" for a55"                                               >> ${REBUILDTABLESCRIPT}
echo "col COMPRESSION for a8"                                                   >> ${REBUILDTABLESCRIPT}
echo "col tablespace_name for a20"                                              >> ${REBUILDTABLESCRIPT}
echo "col \"READONLY\" for a8"                                                  >> ${REBUILDTABLESCRIPT}
echo "col DEGREE for a7"                                                        >> ${REBUILDTABLESCRIPT}
echo "col \"%RECLAIMABLE_SPACE\" for 999"                                       >> ${REBUILDTABLESCRIPT}
echo "COLUMN TABLE_NAME FORMAT A40 heading \"Table Name\""                      >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "select /*+RULE*/ 'ORIGINAL_TABLE: '||t.table_name \"TABLE_NAME\",t.TABLESPACE_NAME,d.extents,"	>> ${REBUILDTABLESCRIPT}
echo "t.COMPRESSION,t.READ_ONLY \"READONLY\""                                  	>> ${REBUILDTABLESCRIPT}
echo ",round(d.bytes/1025/1024) SIZE_MB,"                                       >> ${REBUILDTABLESCRIPT}
echo "round((t.blocks * ${blksize}/1024/1024), 2) - round((t.num_rows * t.avg_row_len/1024/1024), 2) \"FRAGMENTED_SPACE_MB\","  >> ${REBUILDTABLESCRIPT}
echo "((round((t.blocks * ${blksize}/1024/1024), 2) - round((t.num_rows * t.avg_row_len/1024/1024), 2)) /"                      >> ${REBUILDTABLESCRIPT}
echo "round((t.blocks * ${blksize}/1024/1024), 2)) * 100 \"%RECLAIMABLE_SPACE\"">> ${REBUILDTABLESCRIPT}
echo "from dba_tables t, dba_objects o, dba_segments d"                         >> ${REBUILDTABLESCRIPT}
echo "where t.owner= upper('${OWNER}')"                                         >> ${REBUILDTABLESCRIPT}
echo "and t.table_name = upper('${OBJECT_NAME}')"                               >> ${REBUILDTABLESCRIPT}
echo "and o.owner=t.owner"                                                      >> ${REBUILDTABLESCRIPT}
echo "and o.object_name=t.table_name"                                           >> ${REBUILDTABLESCRIPT}
echo "and o.owner=d.owner"                                                      >> ${REBUILDTABLESCRIPT}
echo "and t.table_name=d.SEGMENT_NAME"                                          >> ${REBUILDTABLESCRIPT}
echo "union"                                                                    >> ${REBUILDTABLESCRIPT}
echo "select /*+RULE*/ 'NEW_TABLE:      '||t.table_name TABLE_NAME,t.TABLESPACE_NAME,d.extents"		>> ${REBUILDTABLESCRIPT}
echo ",t.COMPRESSION,t.READ_ONLY \"READONLY\""                                  >> ${REBUILDTABLESCRIPT}
echo ",round(d.bytes/1025/1024) SIZE_MB"                                        >> ${REBUILDTABLESCRIPT}
echo ",round((t.blocks * ${blksize}/1024/1024), 2) - round((t.num_rows * t.avg_row_len/1024/1024), 2) \"FRAGMENTED_SPACE_MB\""  >> ${REBUILDTABLESCRIPT}
echo ",((round((t.blocks * ${blksize}/1024/1024), 2) - round((t.num_rows * t.avg_row_len/1024/1024), 2)) /"                     >> ${REBUILDTABLESCRIPT}
echo "round((t.blocks * ${blksize}/1024/1024), 2)) * 100 \"%RECLAIMABLE_SPACE\"">> ${REBUILDTABLESCRIPT}
echo "from dba_tables t, dba_objects o, dba_segments d"                         >> ${REBUILDTABLESCRIPT}
echo "where t.owner= upper('${OWNER}')"                                         >> ${REBUILDTABLESCRIPT}
echo "and t.table_name = upper('${OBJECT_NAME_INT}')"                           >> ${REBUILDTABLESCRIPT}
echo "and o.owner=t.owner"                                                      >> ${REBUILDTABLESCRIPT}
echo "and o.object_name=t.table_name"                                           >> ${REBUILDTABLESCRIPT}
echo "and o.owner=d.owner"                                                      >> ${REBUILDTABLESCRIPT}
echo "and t.table_name=d.SEGMENT_NAME"                                          >> ${REBUILDTABLESCRIPT}
echo "order by 1 desc;"                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "set pages 0"                                                              >> ${REBUILDTABLESCRIPT}
echo "select 'ORIGINAL_TABLE NUMBER OF ROWS: '||count(*) from ${OWNER}.${OBJECT_NAME};"       	>> ${REBUILDTABLESCRIPT}
echo "select 'NEW_TABLE NUMBER OF ROWS:      '||count(*) from ${OWNER}.${OBJECT_NAME_INT};"   	>> ${REBUILDTABLESCRIPT}
echo "set pages 1000"                                                           >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT LOBS:"                                                             >> ${REBUILDTABLESCRIPT}
echo "PROMPT -----"                                                             >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "col COMPRESSION for a8"                                                   >> ${REBUILDTABLESCRIPT}
echo "col SECUREFILE for a10"                                                   >> ${REBUILDTABLESCRIPT}
echo "col COLUMN_NAME for a40"                                                  >> ${REBUILDTABLESCRIPT}
echo "select 'ORIGINAL_TABLE: '||TABLE_NAME,SEGMENT_NAME,COLUMN_NAME,TABLESPACE_NAME,INDEX_NAME,SECUREFILE,COMPRESSION from dba_lobs"          >> ${REBUILDTABLESCRIPT}
echo "where owner=upper('${OWNER}') and table_name = upper('${OBJECT_NAME}')"   >> ${REBUILDTABLESCRIPT}
echo "union"                                                                    >> ${REBUILDTABLESCRIPT}
echo "select 'NEW_TABLE:      '||TABLE_NAME,SEGMENT_NAME,COLUMN_NAME,TABLESPACE_NAME,INDEX_NAME,SECUREFILE,COMPRESSION from dba_lobs"          >> ${REBUILDTABLESCRIPT}
echo "where owner=upper('${OWNER}') and table_name = upper('${OBJECT_NAME_INT}');"		>> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT INDEXES:"                                                          >>${REBUILDTABLESCRIPT}
echo "PROMPT --------"                                                          >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "COLUMN TABLE_NAME FORMAT A45 heading \"Table Name\""                      >>${REBUILDTABLESCRIPT}
echo "COLUMN INDEX_NAME FORMAT A30 heading \"Index Name\""                      >>${REBUILDTABLESCRIPT}
echo "COLUMN COLUMN_NAME FORMAT A25 heading \"On Column\""                      >>${REBUILDTABLESCRIPT}
echo "COLUMN COLUMN_POSITION FORMAT 9999 heading \"Pos\""                       >>${REBUILDTABLESCRIPT}
echo "COLUMN \"INDEX\"FORMAT A35"                                               >>${REBUILDTABLESCRIPT}
echo "COLUMN TABLESPACE_NAME FOR A25"                                           >>${REBUILDTABLESCRIPT}
echo "COLUMN INDEX_TYPE FOR A21"                                                >>${REBUILDTABLESCRIPT}
echo "SELECT /*+RULE*/  'ORIGINAL_TABLE: '||I.TABLE_NAME \"TABLE_NAME\", I.INDEX_NAME \"INDEX\",I.STATUS,I.INDEX_TYPE,C.COLUMN_NAME,C.COLUMN_POSITION," >>${REBUILDTABLESCRIPT}
echo "I.UNIQUENESS \"UNIQUE\",round(d.bytes/1024/1024) SIZE_MB FROM DBA_INDEXES I, DBA_IND_COLUMNS C, DBA_SEGMENTS d"             	>>${REBUILDTABLESCRIPT}
echo "WHERE I.TABLE_NAME = upper('${OBJECT_NAME}') AND I.TABLE_OWNER = upper('${OWNER}') AND I.TABLE_NAME = C.TABLE_NAME"                    >>${REBUILDTABLESCRIPT}
echo "AND I.OWNER = d.OWNER AND I.OWNER = C.INDEX_OWNER AND I.TABLE_OWNER = C.TABLE_OWNER AND I.INDEX_NAME = C.INDEX_NAME"                   >>${REBUILDTABLESCRIPT}
echo "AND I.INDEX_NAME = d.SEGMENT_NAME"                                        >>${REBUILDTABLESCRIPT}
echo "union"                                                                    >>${REBUILDTABLESCRIPT}
echo "SELECT 'NEW_TABLE:      '||I.TABLE_NAME \"TABLE_NAME\", I.INDEX_NAME \"INDEX\",I.STATUS,I.INDEX_TYPE,C.COLUMN_NAME,C.COLUMN_POSITION," >>${REBUILDTABLESCRIPT}
echo "I.UNIQUENESS \"UNIQUE\",round(d.bytes/1024/1024) SIZE_MB FROM DBA_INDEXES I, DBA_IND_COLUMNS C, DBA_SEGMENTS d"               >>${REBUILDTABLESCRIPT}
echo "WHERE I.TABLE_NAME = upper('${OBJECT_NAME_INT}') AND I.TABLE_OWNER = upper('${OWNER}') AND I.TABLE_NAME = C.TABLE_NAME"                >>${REBUILDTABLESCRIPT}
echo "AND I.OWNER = d.OWNER AND I.OWNER = C.INDEX_OWNER AND I.TABLE_OWNER = C.TABLE_OWNER AND I.INDEX_NAME = C.INDEX_NAME"                   >>${REBUILDTABLESCRIPT}
echo "AND I.INDEX_NAME = d.SEGMENT_NAME AND COLUMN_NAME <> 'M_ROW\$\$'"         >>${REBUILDTABLESCRIPT}
echo "order by 1 desc;"                                                         >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT Dependant Objects:"                                                >>${REBUILDTABLESCRIPT}
echo "PROMPT ------------------"                                                >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "select 'ORIGINAL_TABLE: '||NAME \"TABLE_NAME\",REFERENCED_OWNER,REFERENCED_NAME,REFERENCED_TYPE from DBA_DEPENDENCIES where">>${REBUILDTABLESCRIPT}
echo "OWNER=upper('${OWNER}') and NAME=upper('${OBJECT_NAME_INT}')"             >>${REBUILDTABLESCRIPT}
echo "union"                                                                    >>${REBUILDTABLESCRIPT}
echo "select 'NEW_TABLE:      '||NAME \"TABLE_NAME\",REFERENCED_OWNER,REFERENCED_NAME,REFERENCED_TYPE from DBA_DEPENDENCIES where">>${REBUILDTABLESCRIPT}
echo "OWNER=upper('${OWNER}') and NAME=upper('${OBJECT_NAME}')"                 >>${REBUILDTABLESCRIPT}
echo "order by 1 desc;"                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT CONSTRAINTS:"                                                      >>${REBUILDTABLESCRIPT}
echo "PROMPT ------------"                                                      >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "col CONSTRAINT_NAME for a30"                                              >> ${REBUILDTABLESCRIPT}
echo "col R_CONSTRAINT_NAME for a30"                                            >> ${REBUILDTABLESCRIPT}
echo "select 'ORIGINAL_TABLE: '||TABLE_NAME \"TABLE_NAME\",CONSTRAINT_NAME,CONSTRAINT_TYPE,R_CONSTRAINT_NAME,STATUS,DEFERRED,INDEX_NAME from dba_constraints where">>${REBUILDTABLESCRIPT}
echo "OWNER=upper('${OWNER}') and TABLE_NAME=upper('${OBJECT_NAME_INT}')"       >>${REBUILDTABLESCRIPT}
echo "union"                                                                    >>${REBUILDTABLESCRIPT}
echo "select 'NEW_TABLE:      '||TABLE_NAME \"TABLE_NAME\",CONSTRAINT_NAME,CONSTRAINT_TYPE,R_CONSTRAINT_NAME,STATUS,DEFERRED,INDEX_NAME from dba_constraints where">>${REBUILDTABLESCRIPT}
echo "OWNER=upper('${OWNER}') and TABLE_NAME=upper('${OBJECT_NAME}')"           >>${REBUILDTABLESCRIPT}
echo "order by 1 desc,CONSTRAINT_TYPE;"                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT [Checking the ERROR Log ...]"                                      >>${REBUILDTABLESCRIPT}
echo "select object_name, ddl_txt from DBA_REDEFINITION_ERRORS where base_table_name=upper('${OBJECT_NAME}');"                    >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} PROMPT"                                                       >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} PROMPT ***********************"                               >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} PROMPT Running the ACTUAL SWAP [FINAL STAGE]:"                >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} PROMPT ***********************"                               >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} PROMPT [AN ORA-NOTIFICATION MESSAGE WILL BE WRITTEN TO THE ALERTLOG ONEC THE SWAP IS COMPLETED.]"               >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} PROMPT EXEC DBMS_REDEFINITION.finish_redef_table(upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'));;">>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} SET TIMING ON"                                                >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} EXEC DBMS_REDEFINITION.finish_redef_table(upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'));"        >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} SET TIMING OFF"                                               >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} SET FEEDBACK OFF"                                             >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} exec dbms_system.ksdwrt(3,'ORA-NOTIFICATION: THE REBUILD OF TABLE [${OWNER}.${OBJECT_NAME}] USING DBMS_REDEFINITION COMPLETED.');">>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} SET FEEDBACK On"                                              >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} PROMPT [THE SWAP BETWEEN THE INTERIM AND ACTUAL TABLE IS COMPLETED.]"                                           >>${REBUILDTABLESCRIPT}
echo "${HASHSWAP} exec dbms_system.ksdwrt(3,'ORA-NOTIFICATION: ALL REBUILD STEPS OF TABLE [${OWNER}.${OBJECT_NAME}] COMPLETED. PLEASE CHECK THE LOGFILE: [${REBUILDTABLESPOOL}]');"                                                                    >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT ALL REBUILD STEPS ARE COMPLETED EXCEPT THE ACTUAL SWAP BETWEEN THE ORIGINAL AND INTERIM TABLE."       >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT"                                                     >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT **************************************************"                                                   >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT EXECUTE THE FOLLOWING ACTUAL SWAP COMMAND MANUALLY: [Minimal DOWNTIME will happen]"                   >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT **************************************************"                                                   >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT EXEC DBMS_REDEFINITION.finish_redef_table(upper('${OWNER}'), upper('${OBJECT_NAME}'), upper('${OBJECT_NAME_INT}'));;">>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT"                                                     >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} exec dbms_system.ksdwrt(3,'ORA-NOTIFICATION: ALL PRE-STEPS OF REBUILDING TABLE [${OWNER}.${OBJECT_NAME}] ARE COMPLETED PLEASE RUN THE FINAL SWAP COMMAND ASAP TO FINALISE THE REBUILD OPERATION:  EXEC DBMS_REDEFINITION.finish_redef_table(upper(''${OWNER}''), upper(''${OBJECT_NAME}''), upper(''${OBJECT_NAME_INT}''));');"                   >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT"                                                     >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT [Note: It's recommended to GATHER NEW STATISTICS on the table after the execution of the above SWAP command.]">>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT"                                                     >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT      BEGIN"                                               >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT      DBMS_STATS.GATHER_TABLE_STATS ("                     >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT      ownname   => upper('${OWNER}'),"                     >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT      TABNAME   => upper('${OBJECT_NAME}'),"               >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT      DEGREE    => DBMS_STATS.AUTO_DEGREE,"                >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT      CASCADE   => TRUE,"                                  >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT      estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE);;"  >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT      END;;"                                               >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT      /"                                                   >>${REBUILDTABLESCRIPT}
echo "${HASHNOTIFY} PROMPT"                                                     >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} PROMPT [GATHERING STATISTICS on the NEW TABLE] ..."          >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} SET TIMING ON"                                               >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} BEGIN"                                                       >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} DBMS_STATS.GATHER_TABLE_STATS ("                             >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} ownname   => upper('${OWNER}'),"                             >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} TABNAME   => upper('${OBJECT_NAME}'),"                       >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} DEGREE    => DBMS_STATS.AUTO_DEGREE,"                        >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} CASCADE   => TRUE,"                                          >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE);"           >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} END;"                                                        >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} /"                                                           >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} SET TIMING OFF"                                              >>${REBUILDTABLESCRIPT}
echo "${HASHSTATS} PROMPT"                                                      >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT FINALLY: PLEASE DOUBLE CHECK THE PROCESS, IF YOU ARE SATISFIED, DROP THE OLD TABLE USING THIS COMMAND:"       >>${REBUILDTABLESCRIPT}
echo "PROMPT -------- --------------------------------------------------------------------------------------------"        >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT [DROP TABLE ${OWNER}.${OBJECT_NAME_INT} CASCADE CONSTRAINTS PURGE;]">>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT [SCRIPT COMPLETED.]"                                               >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT SCRIPT:  [${REBUILDTABLESCRIPT}]"                                  >>${REBUILDTABLESCRIPT}
echo "PROMPT LOGFILE: [${REBUILDTABLESPOOL}]"                                   >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "EXIT"                                                                     >>${REBUILDTABLESCRIPT}

echo "#!/bin/bash"                                                                                                > ${REBUILDTABLESCRIPTRUNNER}
echo "nohup ${ORACLE_HOME}/bin/sqlplus \"/ as sysdba\" @${REBUILDTABLESCRIPT} | tee ${REBUILDTABLESPOOL} 2>&1 &"  >>${REBUILDTABLESCRIPTRUNNER}
chmod 740 ${REBUILDTABLESCRIPTRUNNER}
echo ""
echo -e "\033[32;5mFeel free to EXIT from this session as the REBUILD operation is running in the BACKGROUND.]\033[0m"
echo ""
source ${REBUILDTABLESCRIPTRUNNER}
           exit 1 ;;
	esac
break ;;
n|N|no|NO|No) 	echo "Moving to Other REBUILD Options..."; break ;;
*) 		echo "Please enter a VALID answer [Y|N]" ;;
esac
done
;;
         *object*) echo "The INTERIM TABLE [${OWNER}.${OBJECT_NAME_INT}] is already exist!";echo "Please check and run the script again.";echo "Script Terminated!"; exit 1;; 
		*) echo "";echo -e "\033[32;5mDBMS_REDEIFINITION cannot be used: The INTERIM table [${OWNER}.${OBJECT_NAME_INT}] cannot be created! Moving to 'ALTER TABLE MOVE' option ...\033[0m";;
		esac
	else
	echo ""
	echo -e "\033[32;5mDBMS_REDEIFINITION is NOT AVAILABLE in this Database Edition!\033[0m"
	fi


# ########################################
# SQLPLUS: TABLE REBUILD:
# ########################################

echo ""
echo "Moving to \"ALTER TABLE MOVE\" Option."
echo ""

# Checking if the table has any of NON SUPPORTED data types for ALTER TABLE MOVE operation:
VALDATATYPENOSUPPORTRAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select count(*) from dba_tab_columns where owner=upper('${OWNER}') and table_name=upper('${OBJECT_NAME}') and DATA_TYPE in ('LONG','LONG RAW');
exit;
EOF
)
VALDATATYPENOSUPPORT=`echo ${VALDATATYPENOSUPPORTRAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`
        if [ ${VALDATATYPENOSUPPORT} -eq 1 ]
         then
	 echo -e "\033[32;5m[Table [${OWNER}.${OBJECT_NAME}] Contains UN-SUPPORTED \"LONG\" DATA TYPE for \"ALTER TABLE MOVE\" operation.]\033[0m"
	 echo ""
	 echo "Script Terminated!"
	 echo ""
	 exit 1
	fi

# Checking DEFAULT LOGGING option:
VALDEFAULTLOGGINGRAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select LOGGING from DBA_TABLES where owner=upper('${OWNER}') and table_name=upper('${OBJECT_NAME}');
exit;
EOF
)
VALDEFAULTLOGGING=`echo ${VALDEFAULTLOGGINGRAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`
        case ${VALDEFAULTLOGGING} in
	NO) echo "[INFO: LOGGING is NOT enabled on table [${OWNER}.${OBJECT_NAME}]. Preserving the NOLOGGING setting.]";export DISABLELOGGING="--";;
	esac

# Checking ORIGINAL PARALLELIESM DEGREE:
VALTABPARALLELDEGREERAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select DEGREE from DBA_TABLES where owner=upper('${OWNER}') and table_name=upper('${OBJECT_NAME}');
exit;
EOF
)
VALTABPARALLELDEGREE=`echo ${VALTABPARALLELDEGREERAW}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`
	if [ ${VALTABPARALLELDEGREE} -gt 1 ]
	 then
	 echo "[INFO: TABLE's DEFAULT PARALLELISM DEGREE is: ${VALTABPARALLELDEGREE}]"; export VALTABPARALLELDEGREE
	 sleep 1
	fi	 

# Checking if COMPRESSION option is enabled:
COMPRESSION_OPTION_RAW=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" << EOF
set pages 0 feedback off echo off;
SELECT count(*) from v\$option where parameter='Basic Compression' and value='TRUE';
exit;
EOF
)
COMPRESSION_OPTION=`echo ${COMPRESSION_OPTION_RAW} | awk '{print $NF}'`

        if [ ${COMPRESSION_OPTION} -eq 1 ]
         then
echo
echo "Do you want to use BASIC COMPRESSION option while rebuilding the table?:  [Y|N] N [Compression Will Save much of space]"
echo "========================================================================"
while read COMPRESS_ANSWER
 do
        case ${COMPRESS_ANSWER} in
        y|Y|yes|YES|Yes)export COMPRESS="COMPRESS"; break;;
        ""|n|N|no|NO|No)export COMPRESS=""; break;;
        *)              echo "Please enter a VALID answer [Y|N]" ;;
	esac
 done
	else
	echo ""
	echo -e "\033[32;5mBASIC COMPRESSION option is NOT available in this Database Edition!\033[0m"
	echo ""
	fi

# #############################################
# SETTING PCT_FREE FOR TABLE AFTER THE REBUILD:
# #############################################
VALDEFAULTPCTFREE=$(${ORACLE_HOME}/bin/sqlplus -S "/ as sysdba" <<EOF
set pages 0 feedback off lines 1000;
prompt
select PCT_FREE from DBA_TABLES where owner=upper('${OWNER}') and table_name=upper('${OBJECT_NAME}');
exit;
EOF
)
DEFAULTPCTFREE=`echo ${VALDEFAULTPCTFREE}|perl -lpe'$_ = reverse' |awk '{print $1}'|perl -lpe'$_ = reverse'|cut -f1 -d '.'`

echo ""
echo "INFO: Current PCTFREE: ${DEFAULTPCTFREE}"
echo "INFO: Number of \"UPDATE\" transactions on the table since the last Statistics Gather on [${LASTANALYZED}]: ${TABUPDATES}"
echo 

echo
echo "Specify the new Table PCTFREE: [How much %Free space will be left in each block for future updates | Current ${DEFAULTPCTFREE}%]"
echo "============================="
echo "Note: The SMALLER the PCTFREE the SMALLER the table size after the rebuild. [Recommended for Archival/Datawarehouse Tables]"
echo "Note: If the table is highly updated it's recommended to keep the current PCTFREE: ${DEFAULTPCTFREE}"
echo "Leave it BLANK and hit Enter to keep the default PCTFREE."
while read TABPCTFREEVAL
 do
        case ${TABPCTFREEVAL} in
          "") export TABPCTFREE=${DEFAULTPCTFREE}
              break;;
    *[!0-9]*) echo "Please enter a valid NUMBER:";;
           *) export TABPCTFREE=${TABPCTFREEVAL}
	      break;;
	esac
 done

echo
echo "Specify the associated Indexes new PCTFREE: [How much %Free space will be left in each block for future updates]"
echo "=========================================="
echo "Note: The SMALLER the PCTFREE the SMALLER the index size after the rebuild."
echo "Note: If the table is highly updated it's recommended to keep the current PCTFREE: ${DEFAULTPCTFREE}"
echo "Leave it BLANK and hit Enter to accept the default PCTFREE=10"
while read IDXPCTFREEVAL
 do
        case ${IDXPCTFREEVAL} in
          "") export IDXPCTFREE=10
              break;;
    *[!0-9]*) echo "Please enter a valid NUMBER:";;
           *) export IDXPCTFREE=${IDXPCTFREEVAL}
              break;;
        esac
 done


# INFO AND REBUILD PROCEDURE:
# ##########################
REBUILDTABLESCRIPT=${USR_ORA_HOME}/REBUILDTABLESCRIPT-${OWNER}.${OBJECT_NAME}.sql
REBUILDINDEXSCRIPT=${USR_ORA_HOME}/REBUILDINDEXSCRIPT-${OWNER}.${OBJECT_NAME}.sql

REBUILDTABLESCRIPTRUNNER=${USR_ORA_HOME}/REBUILDTABLESCRIPT-${OWNER}.${OBJECT_NAME}.sh
REBUILDTABLESPOOL=${USR_ORA_HOME}/REBUILDTABLESCRIPT-${OWNER}.${OBJECT_NAME}.log
REBUILDINDEXSPOOL=${USR_ORA_HOME}/REBUILDINDEXSCRIPT-${OWNER}.${OBJECT_NAME}.log

echo "spool ${REBUILDTABLESPOOL}"                                               >  ${REBUILDTABLESCRIPT}
echo "PROMPT THIS OPERATION IS LOGGED IN: [${REBUILDTABLESPOOL}]"               >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} PROMPT ********************************************************************************">> ${REBUILDTABLESCRIPT}
echo ""                                                                                                        >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} PROMPT It's HIGHLY RECOMMENDED to run this script within a DOWNTIME WINDOW,            ">> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} PROMPT To AVOID INTERRUPTING long running queries against the table during the rebuild.">> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} PROMPT ********************************************************************************">> ${REBUILDTABLESCRIPT}
echo ""                                                                                                        >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} exec dbms_lock.sleep(9);"                                >> ${REBUILDTABLESCRIPT}
echo "set pages 0 feedback off lines 168"                                       >> ${REBUILDTABLESCRIPT}
echo "EXEC DBMS_SESSION.set_identifier('REBUILDING_${OWNER}.${OBJECT_NAME}');"  >> ${REBUILDTABLESCRIPT}
echo "PROMPT ***************"                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT Session Details:"                                                  >> ${REBUILDTABLESCRIPT}
echo "PROMPT ***************"                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "select 'OSPID:   '||p.spid from v\$session s, v\$process p where s.sid=(select sid from v\$mystat where rownum=1) and s.paddr=p.addr;"   >> ${REBUILDTABLESCRIPT}
echo "select 'SID:     '||sid from v\$mystat where rownum = 1;"                 >> ${REBUILDTABLESCRIPT}
echo "select 'Serial#: '||s.serial# from v\$session s where s.sid = (select sid from v\$mystat where rownum = 1);"      >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT You can KILL this session using this command:"                     >> ${REBUILDTABLESCRIPT}
echo "PROMPT ********************************************"                      >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "select 'ALTER SYSTEM DISCONNECT SESSION '''||sid||','||serial#||''' IMMEDIATE;' from v\$session where sid = (select sid from v\$mystat where rownum = 1);"                                       >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "set feedback on"                                                          >> ${REBUILDTABLESCRIPT}
echo "PROMPT TABLE INFO BEFORE THE REBUILD:"                                    >> ${REBUILDTABLESCRIPT}
echo "PROMPT *****************************"                                     >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "set linesize 168 pages 1000 heading on"                                   >> ${REBUILDTABLESCRIPT}
echo "col \"OWNER.TABLE\" for a35"                                              >> ${REBUILDTABLESCRIPT}
echo "col tablespace_name for a20"                                              >> ${REBUILDTABLESCRIPT}
echo "col \"READONLY\" for a8"                                                  >> ${REBUILDTABLESCRIPT}
echo "col \"%RECLAIMABLE_SPACE\" for 999"                                       >> ${REBUILDTABLESCRIPT}
echo "col LAST_ANALYZED for a13"                                                >> ${REBUILDTABLESCRIPT}
echo "col COMPRESSION for a8"                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "select /*+RULE*/ t.owner||'.'||t.table_name \"OWNER.TABLE\",t.TABLESPACE_NAME,d.extents,t.logging,"       >> ${REBUILDTABLESCRIPT}
echo "t.COMPRESSION,t.READ_ONLY \"READONLY\",o.created,to_char(t.LAST_ANALYZED, 'DD-MON-YYYY') LAST_ANALYZED"   >> ${REBUILDTABLESCRIPT}
echo ",round(d.bytes/1025/1024) SIZE_MB,"                                       >> ${REBUILDTABLESCRIPT}
echo "round((t.blocks * ${blksize}/1024/1024), 2) - round((t.num_rows * t.avg_row_len/1024/1024), 2) \"FRAGMENTED_SPACE_MB\","  >> ${REBUILDTABLESCRIPT}
echo "((round((t.blocks * ${blksize}/1024/1024), 2) - round((t.num_rows * t.avg_row_len/1024/1024), 2)) /"      >> ${REBUILDTABLESCRIPT}
echo "round((t.blocks * ${blksize}/1024/1024), 2)) * 100 \"%RECLAIMABLE_SPACE\""                                >> ${REBUILDTABLESCRIPT}
echo "from dba_tables t, dba_objects o, dba_segments d"                         >> ${REBUILDTABLESCRIPT}
echo "where t.owner= upper('${OWNER}')"                                         >> ${REBUILDTABLESCRIPT}
echo "and t.table_name = upper('${OBJECT_NAME}')"                               >> ${REBUILDTABLESCRIPT}
echo "and o.owner=t.owner"                                                      >> ${REBUILDTABLESCRIPT}
echo "and o.object_name=t.table_name"                                           >> ${REBUILDTABLESCRIPT}
echo "and o.owner=d.owner"                                                      >> ${REBUILDTABLESCRIPT}
echo "and t.table_name=d.SEGMENT_NAME;"                                         >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT LOBS:"                                                             >> ${REBUILDTABLESCRIPT}
echo "PROMPT -----"                                                             >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "col COMPRESSION for a8"                                                   >> ${REBUILDTABLESCRIPT}
echo "col SECUREFILE for a10"                                                   >> ${REBUILDTABLESCRIPT}
echo "col COLUMN_NAME for a40"                                                  >> ${REBUILDTABLESCRIPT}
echo "select SEGMENT_NAME,COLUMN_NAME,TABLESPACE_NAME,INDEX_NAME,SECUREFILE,COMPRESSION from dba_lobs"          >> ${REBUILDTABLESCRIPT}
echo "where owner=upper('${OWNER}') and table_name = upper('${OBJECT_NAME}');"  >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "set feedback on"                                                          >> ${REBUILDTABLESCRIPT}
echo "PROMPT INDEXES BEFORE THE REBUILD:"                                       >> ${REBUILDTABLESCRIPT}
echo "PROMPT ---------------------------"                                       >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "COLUMN OWNER FORMAT A25 heading \"Index Owner\""                          >> ${REBUILDTABLESCRIPT}
echo "COLUMN INDEX_NAME FORMAT A30 heading \"Index Name\""                      >> ${REBUILDTABLESCRIPT}
echo "COLUMN COLUMN_NAME FORMAT A25 heading \"On Column\""                      >> ${REBUILDTABLESCRIPT}
echo "COLUMN COLUMN_POSITION FORMAT 9999 heading \"Pos\""                       >> ${REBUILDTABLESCRIPT}
echo "COLUMN \"INDEX\" FORMAT A35"                                              >> ${REBUILDTABLESCRIPT}
echo "COLUMN INDEX_TYPE FOR A26"                                                >> ${REBUILDTABLESCRIPT}
echo "SELECT /*+RULE*/ IND.OWNER||'.'||IND.INDEX_NAME \"INDEX\","               >> ${REBUILDTABLESCRIPT}
echo "       IND.INDEX_TYPE,"                                                   >> ${REBUILDTABLESCRIPT}
echo "       COL.COLUMN_NAME,"                                                  >> ${REBUILDTABLESCRIPT}
echo "       COL.COLUMN_POSITION,"                                              >> ${REBUILDTABLESCRIPT}
echo "       IND.TABLESPACE_NAME,"                                              >> ${REBUILDTABLESCRIPT}
echo "       IND.STATUS,"                                                       >> ${REBUILDTABLESCRIPT}
echo "       IND.UNIQUENESS,"                                                   >> ${REBUILDTABLESCRIPT}
echo "       IND.LOGGING,"                                                      >> ${REBUILDTABLESCRIPT}
echo "       IND.LAST_ANALYZED,round(d.bytes/1024/1024) SIZE_MB"                >> ${REBUILDTABLESCRIPT}
echo "FROM   SYS.DBA_INDEXES IND,"                                              >> ${REBUILDTABLESCRIPT}
echo "       SYS.DBA_IND_COLUMNS COL,"                                          >> ${REBUILDTABLESCRIPT}
echo "       DBA_SEGMENTS d"                                                    >> ${REBUILDTABLESCRIPT}
echo "WHERE  IND.TABLE_NAME = upper('${OBJECT_NAME}')"                          >> ${REBUILDTABLESCRIPT}
echo "AND    IND.TABLE_OWNER = upper('${OWNER}')"                               >> ${REBUILDTABLESCRIPT}
echo "AND    IND.TABLE_NAME = COL.TABLE_NAME"                                   >> ${REBUILDTABLESCRIPT}
echo "AND    IND.OWNER = d.OWNER(+)"                                            >> ${REBUILDTABLESCRIPT}
echo "AND    IND.OWNER = COL.INDEX_OWNER"                                       >> ${REBUILDTABLESCRIPT}
echo "AND    IND.TABLE_OWNER = COL.TABLE_OWNER"                                 >> ${REBUILDTABLESCRIPT}
echo "AND    IND.INDEX_NAME = COL.INDEX_NAME"                                   >> ${REBUILDTABLESCRIPT}
echo "AND    IND.INDEX_NAME = d.SEGMENT_NAME(+);"                               >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT CONSTRAINTS BEFORE THE REBUILD:"                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT -------------------------------"                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "col CONSTRAINT_NAME for a30"                                              >> ${REBUILDTABLESCRIPT}
echo "col R_CONSTRAINT_NAME for a30"                                            >> ${REBUILDTABLESCRIPT}
echo "select CONSTRAINT_NAME,CONSTRAINT_TYPE,R_CONSTRAINT_NAME,STATUS,DEFERRED,INDEX_NAME from dba_constraints where">> ${REBUILDTABLESCRIPT}
echo "OWNER=upper('${OWNER}') and TABLE_NAME=upper('${OBJECT_NAME}') order by CONSTRAINT_TYPE;"                      >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT [Setting the PARALLELISM FACTOR to ${PARALLEL_DEGREE}] ..."        >> ${REBUILDTABLESCRIPT}
echo "alter session enable parallel dml;"                                       >> ${REBUILDTABLESCRIPT}
echo "alter session force parallel dml parallel ${PARALLEL_DEGREE};"            >> ${REBUILDTABLESCRIPT}
echo "alter session force parallel ddl parallel ${PARALLEL_DEGREE};"            >> ${REBUILDTABLESCRIPT}
echo "alter session force parallel query parallel ${PARALLEL_DEGREE};"          >> ${REBUILDTABLESCRIPT}
echo "PROMPT [Setting the SESSION DDL WAIT FOR LOCK to 5 minutes] ..."          >> ${REBUILDTABLESCRIPT}
echo "alter session set ddl_lock_timeout=300;"                                  >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT [Setting the SESSION RESUMABLE TIMEOUT to 6 Hours] ..."            >> ${REBUILDTABLESCRIPT}
echo "ALTER SESSION ENABLE RESUMABLE TIMEOUT 21600 NAME 'REBUILD_OF_TABLE_${OBJECT_NAME}';"  >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT [Start REBUILDING the table using ALTER TABLE MOVE command] ..."   >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT TABLE REBUILD PROCEDURE WILL START WITHIN 5 Seconds ..."           >> ${REBUILDTABLESCRIPT}
echo "PROMPT ---------------------------------------------------"               >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "SET FEEDBACK OFF"                                                         >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(4);"                                                 >> ${REBUILDTABLESCRIPT}
echo "PROMPT [5]"                                                               >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(1);"                                                 >> ${REBUILDTABLESCRIPT}
echo "PROMPT [4]"                                                               >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(1);"                                                 >> ${REBUILDTABLESCRIPT}
echo "PROMPT [3]"                                                               >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(1);"                                                 >> ${REBUILDTABLESCRIPT}
echo "PROMPT [2]"                                                               >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(1);"                                                 >> ${REBUILDTABLESCRIPT}
echo "PROMPT [1]"                                                               >> ${REBUILDTABLESCRIPT}
echo "exec dbms_lock.sleep(1);"                                                 >> ${REBUILDTABLESCRIPT}
echo "--Exit the script if any failure encountered at any stage:"               >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "set serveroutput on"                                                      >> ${REBUILDTABLESCRIPT}
echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;"                                      >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT [START REBUILDING TABLE [${OWNER}.${OBJECT_NAME}]] ..."            >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT [SETTING TABLE [${OWNER}.${OBJECT_NAME}] IN NOLOGGING MODE] ..."   >> ${REBUILDTABLESCRIPT}
echo "ALTER TABLE ${OWNER}.${OBJECT_NAME} NOLOGGING;"                           >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT [REBUILDING TABLE [${OWNER}.${OBJECT_NAME}] [This may take quite long depending on the table's size] ..."                  >> ${REBUILDTABLESCRIPT}
echo "SET FEEDBACK ON"                                                          >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT Keep checking the progress using this statement:"                  >>${REBUILDTABLESCRIPT}
echo "PROMPT -----------------------------------------------"                   >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT col OPERATION                    for a21"                          >>${REBUILDTABLESCRIPT}
echo "PROMPT col \"%DONE\"                      for 999.999"                    >>${REBUILDTABLESCRIPT}
echo "PROMPT col \"STARTED|MIN_ELAPSED|REMAIN\" for a26"                        >>${REBUILDTABLESCRIPT}
echo "PROMPT col MESSAGE                      for a90"                          >>${REBUILDTABLESCRIPT}
echo "PROMPT col \"USERNAME| SID,SERIAL#\"      for a28"                        >>${REBUILDTABLESCRIPT}
echo "PROMPT select USERNAME||'| '||SID||','||SERIAL# \"USERNAME| SID,SERIAL#\",SQL_ID,round(SOFAR/TOTALWORK*100,2) \"%DONE\""   >>${REBUILDTABLESCRIPT}
echo "PROMPT ,to_char(START_TIME,'DD-Mon HH24:MI')||'| '||trunc(ELAPSED_SECONDS/60)||'|'||trunc(TIME_REMAINING/60) \"STARTED|MIN_ELAPSED|REMAIN\" ,MESSAGE" >>${REBUILDTABLESCRIPT}
echo "PROMPT from v\$session_longops"                                           >>${REBUILDTABLESCRIPT}
echo "PROMPT where TARGET LIKE UPPER('%${OBJECT_NAME}%') and TOTALWORK <> '0' and SOFAR/TOTALWORK*100 <>'100'"                   >>${REBUILDTABLESCRIPT}
echo "PROMPT order by \"STARTED|MIN_ELAPSED|REMAIN\" desc, \"USERNAME| SID,SERIAL#\";;"                                          >>${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >>${REBUILDTABLESCRIPT}
echo "ALTER TABLE ${OWNER}.${OBJECT_NAME} MOVE ${ORACLE12_ONLINE} PARALLEL ${PARALLEL_DEGREE} PCTFREE ${TABPCTFREE} ${COMPRESS};">> ${REBUILDTABLESCRIPT}
echo "${DISABLELOGGING} PROMPT [SETTING TABLE [${OWNER}.${OBJECT_NAME}] IN LOGGING MODE] ..."     >> ${REBUILDTABLESCRIPT}
echo "${DISABLELOGGING} ALTER TABLE ${OWNER}.${OBJECT_NAME} LOGGING ;"                            >> ${REBUILDTABLESCRIPT}
echo "${DISABLELOGGING} PROMPT"                                                 >>${REBUILDTABLESCRIPT}
echo "${DISABLEPARALLELISM} PROMPT [SETTING TABLE [${OWNER}.${OBJECT_NAME}] TO ITS ORIGINAL PARALLELISM DEGREE ${VALTABPARALLELDEGREE}] ...">> ${REBUILDTABLESCRIPT}
echo "${DISABLEPARALLELISM} ALTER TABLE ${OWNER}.${OBJECT_NAME} PARALLEL ${VALTABPARALLELDEGREE};"                               >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >>${REBUILDTABLESCRIPT}
echo "SET TERMOUT OFF PAGES 1000 LINESIZE 167 HEADING OFF FEEDBACK OFF VERIFY OFF ECHO OFF" >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} SPOOL ${REBUILDINDEXSCRIPT}"                             >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} select 'SPOOL ${REBUILDINDEXSPOOL}' from dual;"          >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} select 'ALTER INDEX '||owner||'.\"'||index_name||'\" REBUILD ${ONLINE_REBUILD} PARALLEL ${PARALLEL_DEGREE} PCTFREE ${IDXPCTFREE} ${COMPRESS};'">> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} from dba_indexes where TABLE_OWNER=upper('${OWNER}') and TABLE_NAME=upper('${OBJECT_NAME}');"		 >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} select 'ALTER INDEX '||owner||'.\"'||index_name||'\" PARALLEL ${VALTABPARALLELDEGREE};'from dba_indexes where TABLE_OWNER=upper('${OWNER}') and TABLE_NAME=upper('${OBJECT_NAME}');"             >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} select 'spool off' from dual;"                           >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} SPOOL OFF"                                               >>${REBUILDTABLESCRIPT}
echo "SET TERMOUT ON ECHO OFF FEEDBACK ON VERIFY OFF"                           >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} PROMPT"                                                  >> ${REBUILDTABLESCRIPT}
echo "${ORACLE12_HASH} PROMPT [REBUILDING INDEXES] ..."                         >> ${REBUILDTABLESCRIPT} 
echo "${ORACLE12_HASH} @${REBUILDINDEXSCRIPT}"                                  >> ${REBUILDTABLESCRIPT} 
echo "${ORACLE12_HASH} PROMPT [INDEXES REBUILD COMPLETED.]"                     >> ${REBUILDTABLESCRIPT} 
echo "${ORACLE12_HASH} PROMPT"                                                  >> ${REBUILDTABLESCRIPT}
echo "PROMPT [GATHERING STATISTICS ON TABLE [${OWNER}.${OBJECT_NAME}] AND ITS INDEXES] ..." >> ${REBUILDTABLESCRIPT}
echo "BEGIN"                                                                    >> ${REBUILDTABLESCRIPT}
echo "DBMS_STATS.GATHER_TABLE_STATS ("                                          >> ${REBUILDTABLESCRIPT}
echo "ownname => upper('${OWNER}'),"                                            >> ${REBUILDTABLESCRIPT}
echo "tabname => upper('${OBJECT_NAME}'),"                                      >> ${REBUILDTABLESCRIPT}
echo "cascade => TRUE,"                                                         >> ${REBUILDTABLESCRIPT}
echo "METHOD_OPT => 'FOR ALL COLUMNS SIZE SKEWONLY',"                           >> ${REBUILDTABLESCRIPT}
echo "DEGREE  => DBMS_STATS.AUTO_DEGREE,"                                       >> ${REBUILDTABLESCRIPT}
echo "estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE);"                        >> ${REBUILDTABLESCRIPT}
echo "END;"                                                                     >> ${REBUILDTABLESCRIPT}
echo "/"                                                                        >> ${REBUILDTABLESCRIPT}
echo "PROMPT [GATHER STATISTICS COMPLETED.]"                                    >> ${REBUILDTABLESCRIPT} 
echo "${HASHNOTIFY} exec dbms_system.ksdwrt(3,'ORA-NOTIFICATION: REBUILD OF TABLE [${OWNER}.${OBJECT_NAME}] COMPLETED. LOGFILE: ${REBUILDTABLESPOOL}');">>${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "set feedback on"                                                          >> ${REBUILDTABLESCRIPT}
echo "PROMPT TABLE INFO AFTER THE REBUILD:"                                     >> ${REBUILDTABLESCRIPT}
echo "PROMPT ****************************"                                      >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "set linesize 168 pages 1000 heading on"                                   >> ${REBUILDTABLESCRIPT}
echo "col \"OWNER.TABLE\" for a35"                                              >> ${REBUILDTABLESCRIPT}
echo "col tablespace_name for a20"                                              >> ${REBUILDTABLESCRIPT}
echo "col \"READONLY\" for a8"                                                  >> ${REBUILDTABLESCRIPT}
echo "col \"%RECLAIMABLE_SPACE\" for 999"                                       >> ${REBUILDTABLESCRIPT}
echo "col LAST_ANALYZED for a13"                                                >> ${REBUILDTABLESCRIPT}
echo "col PCT_FREE for 99999999"                                                >> ${REBUILDTABLESCRIPT}
echo "col COMPRESSION for a8"                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "select /*+RULE*/ t.owner||'.'||t.table_name \"OWNER.TABLE\",t.TABLESPACE_NAME,d.extents,t.PCT_FREE,t.logging"             >> ${REBUILDTABLESCRIPT}
echo ",t.COMPRESSION,t.READ_ONLY \"READONLY\",to_char(t.LAST_ANALYZED, 'DD-MON-YYYY') LAST_ANALYZED"  				>> ${REBUILDTABLESCRIPT}
echo ",round(d.bytes/1025/1024) SIZE_MB,"                                       >> ${REBUILDTABLESCRIPT}
echo "round((t.blocks * ${blksize}/1024/1024), 2) - round((t.num_rows * t.avg_row_len/1024/1024), 2) \"FRAGMENTED_SPACE_MB\","  >> ${REBUILDTABLESCRIPT}
echo "((round((t.blocks * ${blksize}/1024/1024), 2) - round((t.num_rows * t.avg_row_len/1024/1024), 2)) /"      >> ${REBUILDTABLESCRIPT}
echo "round((t.blocks * ${blksize}/1024/1024), 2)) * 100 \"%RECLAIMABLE_SPACE\""                                >> ${REBUILDTABLESCRIPT}
echo "from dba_tables t, dba_objects o, dba_segments d"                         >> ${REBUILDTABLESCRIPT}
echo "where t.owner= upper('${OWNER}')"                                         >> ${REBUILDTABLESCRIPT}
echo "and t.table_name = upper('${OBJECT_NAME}')"                               >> ${REBUILDTABLESCRIPT}
echo "and o.owner=t.owner"                                                      >> ${REBUILDTABLESCRIPT}
echo "and o.object_name=t.table_name"                                           >> ${REBUILDTABLESCRIPT}
echo "and o.owner=d.owner"                                                      >> ${REBUILDTABLESCRIPT}
echo "and t.table_name=d.SEGMENT_NAME;"                                         >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT LOBS:"                                                             >> ${REBUILDTABLESCRIPT}
echo "PROMPT -----"                                                             >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "col SECUREFILE for a10"                                                   >> ${REBUILDTABLESCRIPT}
echo "col COLUMN_NAME for a40"                                                  >> ${REBUILDTABLESCRIPT}
echo "select SEGMENT_NAME,COLUMN_NAME,TABLESPACE_NAME,INDEX_NAME,SECUREFILE,COMPRESSION from dba_lobs"          >> ${REBUILDTABLESCRIPT}
echo "where owner=upper('${OWNER}') and table_name = upper('${OBJECT_NAME}');"  >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT INDEXES AFTER THE REBUILD:"                                        >> ${REBUILDTABLESCRIPT}
echo "PROMPT --------------------------"                                        >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "set feedback on"                                                          >> ${REBUILDTABLESCRIPT}
echo "COLUMN OWNER FORMAT A25 heading \"Index Owner\""                          >> ${REBUILDTABLESCRIPT}
echo "COLUMN INDEX_NAME FORMAT A30 heading \"Index Name\""                      >> ${REBUILDTABLESCRIPT}
echo "COLUMN COLUMN_NAME FORMAT A25 heading \"On Column\""                      >> ${REBUILDTABLESCRIPT}
echo "COLUMN COLUMN_POSITION FORMAT 999 heading Pos"                            >> ${REBUILDTABLESCRIPT}
echo "COLUMN INDEX FORMAT A35"                                                  >> ${REBUILDTABLESCRIPT}
echo "COLUMN INDEX_TYPE FORMAT A13"                                             >> ${REBUILDTABLESCRIPT}
echo "SELECT /*+RULE*/ IND.OWNER||'.'||IND.INDEX_NAME \"INDEX\","               >> ${REBUILDTABLESCRIPT}
echo "       IND.INDEX_TYPE,"                                                   >> ${REBUILDTABLESCRIPT}
echo "       IND.PCT_FREE,"                                                     >> ${REBUILDTABLESCRIPT}
echo "       COL.COLUMN_NAME,"                                                  >> ${REBUILDTABLESCRIPT}
echo "       COL.COLUMN_POSITION,"                                              >> ${REBUILDTABLESCRIPT}
echo "       IND.TABLESPACE_NAME,"                                              >> ${REBUILDTABLESCRIPT}
echo "       IND.STATUS,"                                                       >> ${REBUILDTABLESCRIPT}
echo "       IND.UNIQUENESS,"                                                   >> ${REBUILDTABLESCRIPT}
echo "       IND.LOGGING,"                                                      >> ${REBUILDTABLESCRIPT}
echo "       IND.LAST_ANALYZED,round(d.bytes/1024/1024) SIZE_MB"                >> ${REBUILDTABLESCRIPT}
echo "FROM   SYS.DBA_INDEXES IND,"                                              >> ${REBUILDTABLESCRIPT}
echo "       SYS.DBA_IND_COLUMNS COL,"                                          >> ${REBUILDTABLESCRIPT}
echo "       DBA_SEGMENTS d"                                                    >> ${REBUILDTABLESCRIPT}
echo "WHERE  IND.TABLE_NAME = upper('${OBJECT_NAME}')"                          >> ${REBUILDTABLESCRIPT}
echo "AND    IND.TABLE_OWNER = upper('${OWNER}')"                               >> ${REBUILDTABLESCRIPT}
echo "AND    IND.TABLE_NAME = COL.TABLE_NAME"                                   >> ${REBUILDTABLESCRIPT}
echo "AND    IND.OWNER = d.OWNER(+)"                                            >> ${REBUILDTABLESCRIPT}
echo "AND    IND.OWNER = COL.INDEX_OWNER"                                       >> ${REBUILDTABLESCRIPT}
echo "AND    IND.TABLE_OWNER = COL.TABLE_OWNER"                                 >> ${REBUILDTABLESCRIPT}
echo "AND    IND.INDEX_NAME = COL.INDEX_NAME"                                   >> ${REBUILDTABLESCRIPT}
echo "AND    IND.INDEX_NAME = d.SEGMENT_NAME(+);"                               >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT CONSTRAINTS AFTER THE REBUILD:"                                    >> ${REBUILDTABLESCRIPT}
echo "PROMPT ------------------------------"                                    >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "col CONSTRAINT_NAME for a30"                                              >> ${REBUILDTABLESCRIPT}
echo "col R_CONSTRAINT_NAME for a30"                                            >> ${REBUILDTABLESCRIPT}
echo "select CONSTRAINT_NAME,CONSTRAINT_TYPE,R_CONSTRAINT_NAME,STATUS,DEFERRED,INDEX_NAME from dba_constraints where">> ${REBUILDTABLESCRIPT}
echo "OWNER=upper('${OWNER}') and TABLE_NAME=upper('${OBJECT_NAME}') order by CONSTRAINT_TYPE;"                      >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT [TABLE REBUILD OPERATION COMPLETED.]"                              >> ${REBUILDTABLESCRIPT}
echo ""                                                                         >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT [SCRIPT COMPLETED.]"                                               >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT SCRIPT:  [${REBUILDTABLESCRIPT}]"                                  >> ${REBUILDTABLESCRIPT}
echo "PROMPT LOGFILE: [${REBUILDTABLESPOOL}]"                                   >> ${REBUILDTABLESCRIPT}
echo "PROMPT"                                                                   >> ${REBUILDTABLESCRIPT}
echo "EXIT"                                                                     >> ${REBUILDTABLESCRIPT}

echo "#!/bin/bash"                                                                                                > ${REBUILDTABLESCRIPTRUNNER}
echo "nohup ${ORACLE_HOME}/bin/sqlplus \"/ as sysdba\" @${REBUILDTABLESCRIPT} | tee ${REBUILDTABLESPOOL} 2>&1 &"  >>${REBUILDTABLESCRIPTRUNNER}
chmod 740 ${REBUILDTABLESCRIPTRUNNER}
echo ""
echo -e "\033[32;5mFeel free to EXIT from this session as the REBUILD operation is running in the BACKGROUND.\033[0m"
echo ""
source ${REBUILDTABLESCRIPTRUNNER}


# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM: http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
