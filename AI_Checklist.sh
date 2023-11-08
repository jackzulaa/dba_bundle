copdbmgr@copkprdcard01:~/sandbox/scripts/alerting/ver1.0$ cat scripts.sh
#!/usr/bin/bash

# # Check if container DB
function getContainer() {
CDB=$(sqlplus -s "/ as sysdba"<<EOF
SET FEEDBACK OFF PAUSE OFF PAGESIZE 0 HEADING OFF VERIFY OFF TERM OFF;
SELECT CDB FROM V\$DATABASE;
EOF
)
echo $CDB
}

# # Get database role
function getDatabaseRole(){
DBROLE=$(sqlplus -s "/ as sysdba"<<EOF
SET FEEDBACK OFF PAUSE OFF PAGESIZE 0 HEADING OFF VERIFY OFF LINESIZE 500 TERM OFF;
SELECT DATABASE_ROLE FROM V\$DATABASE;
EOF
)
echo $DBROLE
}

# # Check if container DB
function getDBName() {
dbname=$(sqlplus -s "/ as sysdba"<<EOF
SET FEEDBACK OFF PAUSE OFF PAGESIZE 0 HEADING OFF VERIFY OFF TERM OFF;
SELECT NAME FROM V\$DATABASE;
EOF
)
echo $dbname
}

# # Get Alert Log location
function getAlertLogLocation(){
alert_log_location=$(sqlplus -s "/ as sysdba"<<EOF
SET FEEDBACK OFF PAUSE OFF PAGESIZE 0 HEADING OFF VERIFY OFF TERM OFF;
select value from v\$parameter where name = 'core_dump_dest';
EOF
)
alert_log_location=`echo $alert_log_location|sed 's/cdump/trace/g'`
echo $alert_log_location
}

# # Empty file
function emptyFile(){
FILE=$1
cat /dev/null > $FILE
}

# # Get Tablespace usage
function getTablespaceUsage(){

iscdb=$1
dbname=$2

emptyFile $TEMPFILE
# emptyFile $ALERTLOG

sqlplus -s "/ as sysdba"<<EOF
SET PAGESIZE 0
set termout off
set feedback off
set echo off
set trimspool on
SET HEADING OFF
set linesize 200
set verify off
col name for a20
spool $TEMPFILE
select a.con_id,
c.name,
b.tablespace_name,
round(a.bytes_alloc/(1024*1024*1024),2) "MAXSIZE (GB)",
round(nvl(a.physical_bytes,0)/(1024*1024*1024),2) "ALLOC (GB)",
round(nvl(b.tot_used,0)/(1024*1024*1024),2) "USED (GB)",
round((nvl(b.tot_used,0)/a.bytes_alloc)*100) "PCT_USED"
from
(select con_id,tablespace_name, sum(bytes) physical_bytes,sum(decode(autoextensible,'NO',bytes,'YES',maxbytes)) bytes_alloc
 from cdb_data_files group by con_id,tablespace_name ) a,
(select con_id,tablespace_name, sum(bytes) tot_used from cdb_segments group by con_id,tablespace_name ) b,
(select name,con_id from v\$containers) c
where a.con_id= b.con_id and a.con_id = c.con_id and a.tablespace_name = b.tablespace_name (+)
order by 1,3;
spool off
exit
EOF


# Loop through tablespace output
i=1
tbsresult=`cat $TEMPFILE | awk '{ print $7 }' | sed 's/%//g'`
for percent in $tbsresult; do
if ((percent >= $TBS_CRIT_THRESHOLD))
then
pdb=""
if [[ "$iscdb" == "YES" ]];then
pdb=": "`cat $TEMPFILE | head -$i | tail -1| awk '{print $2}'`
fi
tbs=`cat $TEMPFILE | head -$i | tail -1| awk '{print $3}'`
message="$dbname$pdb Tablespace ${tbs} is ${percent}% used."
echo "`(date +%Y-%m-%d-%H:%M)`: $message" >> $LOG_FILE
echo "$message"
fi
let i=$i+1
done >> $ALERTLOG

}


function getFRAUsage(){
dbname=$1

emptyFile $TEMPFILE

sqlplus -s "/ as sysdba"<<EOF
SET PAGESIZE 0
set termout off
set feedback off
set echo off
set trimspool on
SET HEADING OFF
set linesize 200
set verify off
col name for a20
spool $TEMPFILE
SELECT SPACE_LIMIT/1024/1024/1024 "TOTAL GB",
ROUND(SPACE_USED/1024/1024/1024) "USED GB",
ROUND((SPACE_USED)/SPACE_LIMIT*100) "USED%" FROM V\$RECOVERY_FILE_DEST;
spool off
exit
EOF

# Loop through FRA output
i=1
fraresult=`cat $TEMPFILE | awk '{ print $3 }' | sed 's/%//g'`
for percent in $fraresult; do
if ((percent >= $FRA_CRIT_THRESHOLD))
then
message="$dbname FRA is ${percent}% used."
echo "`(date +%Y-%m-%d-%H:%M)`: $message" >> $LOG_FILE
echo "$message"
fi
let i=$i+1
done >> $ALERTLOG
}


function getASMUsage(){
dbname=$1

emptyFile $TEMPFILE

sqlplus -s "/ as sysdba"<<EOF
SET PAGESIZE 0
set termout off
set feedback off
set echo off
set trimspool on
SET HEADING OFF
set linesize 200
set verify off
col name for a20
spool $TEMPFILE
SELECT NAME,
ROUND((TOTAL_MB/1024),2) TOTALGB,
ROUND((FREE_MB/1024),2) FREEGB,
ROUND((USABLE_FILE_MB/1024)) USABLE_FILE_GB,
round((((TOTAL_MB-FREE_MB)/TOTAL_MB)*100)) "USED%"
FROM V\$ASM_DISKGROUP
WHERE TOTAL_MB != 0;
spool off
exit
EOF

# Loop through ASM output
i=1
=`cat $TEMPFILasmresultE | awk '{ print $4 }' | sed 's/%//g'`
diskgroup=`cat $TEMPFILE | awk '{ print $1 }' | sed 's/%//g'`
for usable_free in $asmresult; do
if ((usable_free < $ASM_CRIT_THRESHOLD))
then
message="${CLUSTER} : Diskgroup ${diskgroup} has ${usable_free} GB free usable."
echo "`(date +%Y-%m-%d-%H:%M)`: $message" >> $LOG_FILE
echo "$message"
fi
let i=$i+1
done >> $ALERTLOG
}


function getAlertErrors(){
dbname=$1

emptyFile $TEMPFILE

# Get location of alert log
alert_log_location="$(getAlertLogLocation)"

# Copy the alert log to this location - ensure that the logs are always truncated or backed up
cd $HOME_FOLDER
cp $alert_log_location/alert_${ORACLE_SID}.log .



# Loop through ASM output
i=1
asmresult=`cat $TEMPFILE | awk '{ print $4 }' | sed 's/%//g'`
diskgroup=`cat $TEMPFILE | awk '{ print $1 }' | sed 's/%//g'`
for usable_free in $asmresult; do
if ((usable_free < $ASM_CRIT_THRESHOLD))
then
message="${CLUSTER} : Diskgroup ${diskgroup} has ${usable_free} GB free usable."
echo "`(date +%Y-%m-%d-%H:%M)`: $message" >> $LOG_FILE
echo "$message"
fi
let i=$i+1
done >> $ALERTLOG
}
function formatFile(){
file=$1
for line in $file
do
echo -e "$line\n" 
done
}

function checkDiskUsage(){
ALERT=60
df -H | sed -n '1!p'| awk '{ print $5 " " $1 }' | while read -r output;
do
  #echo "$output"
  usep=$(echo "$output" | awk '{ print $1}' | cut -d'%' -f1 )
  partition=$(echo "$output" | awk '{ print $2 }' )
  if [ $usep -ge $ALERT ]; then
    echo "Running out of space \"$partition ($usep%)\" on $(hostname) as on $(date)" 
  fi
  

done 
}