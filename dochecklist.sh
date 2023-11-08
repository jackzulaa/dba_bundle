copdbmgr@copkprdcard01:~$ cat /export/home/copdbmgr/sandbox/scripts/alerting/ver1.0/Wrapper.sh
#!/usr/bin/bash
# Version 1.0
# Alert Wrapper script
#
# # Script/File/Folder Components
# -------------------------------
#
#
# # Monitored Aspects
# -------------------
#  *. Disk Usage                                                        - Not Implemented
#  *. FRA usage                                                         - Implemented
#  *. Tablespace usage                                          - Implemented
#  *. ASM Usage                                                         - Not Implemented
#

# Server and User that consolidates and sends the report as an email
REPORTINGSERVER="172.30.2.54"
REPORTINGUSER="oracle"

# THRESHOLDS
TBS_CRIT_THRESHOLD=79
FRA_CRIT_THRESHOLD=50
ASM_CRIT_THRESHOLD=400

# General Variables
TIMESTAMP=$(date +%Y-%m-%d-%H:%M)
export TODAY=$(date +%Y%m%d)
HOSTNAME=$(hostname)
export HOME_FOLDER="/export/home/copdbmgr/sandbox/scripts/alerting/ver1.0"
export LOG_FOLDER="/export/home/copdbmgr/sandbox/scripts/alerting/ver1.0/logs"

# Set GRID_HOME
if [ -d "/u01/app/12.2.0.1/grid" ]
then
    export GRID_HOME="/u01/app/12.2.0.1/grid"
else
    export GRID_HOME="/u01/app/19.0.0.0/grid"
fi

export CLUSTER=`$GRID_HOME/bin/olsnodes -c`

cd $HOME_FOLDER
source scripts.sh

# Output Variables
ISSUELOG="$HOME_FOLDER/logs/issue_$TIMESTAMP.log"
TEMPFILE="$HOME_FOLDER/tempfile.txt"
ALERTLOG="$HOME_FOLDER/alert_$TIMESTAMP.log"
LOG_FILE="$LOG_FOLDER/${TODAY}_JOB_MONITOR.log"

emptyFile $TEMPFILE
emptyFile $ALERTLOG

# Identify the Operating System
UNAME=$(uname)

if [ "$UNAME" == "SunOS" ] ; then
        ORATAB=/var/opt/oracle/oratab
else
        ORATAB=/etc/oratab
fi

# Main Function
function main(){

db=`egrep -i ":Y|:N" $ORATAB | cut -d":" -f1 | grep -v 'ASM' | grep -v 'MGMTDB' | grep -v "\#" | grep -v "\*"`
for i in $db ; do
processes=`ps -ef|grep -w ora_pmon_$i | grep -v 'grep' | wc -l`
if [[ $processes -ne 0 ]]; then
#Find ORACLE_HOME info for current instance
SEARCH_LINE=$i
ORATABLINE=`grep $SEARCH_LINE $ORATAB`
        # If this instance is not on oratab, please log
        if [ -z "$ORATABLINE" ];then
                echo "Instance: $i is not on oratab" >> $ISSUELOG
                exit
        else
                export ORACLE_SID=$i
                ORACLE_HOME=`echo $ORATABLINE | cut -f2 -d:`
                export ORACLE_HOME
                LD_LIBRARY_PATH=$ORACLE_HOME/lib:/usr/lib
                export LD_LIBRARY_PATH
                export PATH=$ORACLE_HOME/bin:$PATH
        fi

        # get db name
        dbname="$(getDBName)"

        dbrole="$(getDatabaseRole)"

        iscdb="$(getContainer)"
        # Get tablespace usage

        if [[ $dbrole == "PRIMARY" ]]; then
                getTablespaceUsage $iscdb $dbname
        fi

        # Get FRA Usage
        getFRAUsage $dbname

        # Get ASM Usage
        getASMUsage

fi
done
# copy the file to reporting server
scp $ALERTLOG $REPORTINGUSER@$REPORTINGSERVER:/u01/oracle/sandbox/scripts/monitoring/alerts/pending
rm $ALERTLOG
}

main
