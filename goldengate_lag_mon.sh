# ####################################################################################################################
# This Script Detects GOLDENGATE LAG If The LAG Hits the Pre-defined Threshold
# [Ver 1.0]                                     
# 
# To get this script work you need to Define the following variables:
# ORACLE_HOME	# Must be set to the ORACLE_HOME path of the database where GoldenGate is running against.
# GG_HOME	# Should be set to the Goldengate installation home directory path.
# LAG=xxxx 	# The number of minutes of lag, if reached an email alert will be sent [10 minutes is the default].
# EXL_PROC_NAME="DONOTREMOVE|REP11|REP12" 	In case you want to exclude specific processes e.g. REP11 & REP12
# LOG_DIR 	# The location of script logs [/tmp by default].
#
#					#   #     #
# Author:	Mahmmoud ADEL	      # # # #   ###
# Created:	26-02-17	    #   #   # #   # 
# Modified:		     
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
#
#
# ####################################################################################################################
MAIL_LIST="youremail@yourcompany.com"
export MAIL_LIST

        case ${MAIL_LIST} in "youremail@yourcompany.com")
         echo
         echo "******************************************************************"
         echo "Buddy! You forgot to edit line# 30 in the script."
         echo "Please replace youremail@yourcompany.com with your E-mail address."
         echo "******************************************************************"
         echo
        esac

SERVER_NAME=`uname -n`
export SERVER_NAME


# ###########################################
# Mandatory Parameters To Be Set By The User:
# ###########################################
ORACLE_HOME=			# ORACLE_HOME path of the database where GoldenGate is running against.
GG_HOME=                        # GoldenGate Installation Home path. e.g. GG_HOME=/goldengate/gghome


# ################
# Script Settings:
# ################
# LAG THRESHOLD in minutes: [If reached an e-mail alert will be sent. Default 10 minutes]
LAG_IN_MINUTES=10

# Excluded Specific PROCESSES NAME:
# e.g. If you want to exclude two replicate processes with names REP_11 and REP_12 from being reported then add them to below parameter as shown:
# EXL_PROC_NAME="DONOTREMOVE|REP_11|REP_12"
EXL_PROC_NAME="DONOTREMOVE"


# ###############
# VARIABLES:
# ###############
LOG_DIRECTORY=/tmp		# Log Location

LAG=$((LAG_IN_MINUTES * 100))
export LAG
export EXL_PROC_NAME

# #############################################
# Finding GoldenGate Installation Home Location: [In case the user didn't set it up above]
# #############################################

if [ ! -f ${GG_HOME}/ggsci ]
 then
  GG_PID=`pgrep  -lf mgr.prm|awk '{print $1}'`
  export GG_PID
  GG_HOME=`pwdx ${GG_PID}|awk '{print $NF}'`
  export GG_HOME
fi

if [ ! -f ${GG_HOME}/ggsci ]
 then
  GG_HOME=`ps -ef|grep "./mgr"|grep -v grep|awk '{print $10}'|sed -e 's/\/dirprm\/mgr\.prm//g'|grep -v sed|grep -v "//g"|tail -1`
  export GG_HOME
fi

if [ ! -f ${GG_HOME}/ggsci ]
 then
  echo "The script cannot find GoldenGate installation home path, please export it inside the script just before \"VARIABLES\" section"
  echo "e.g."
  echo "export GG_HOME=/u01/goldengate"
fi


# ###############
# Script Engine:
# ###############

# ###################
# Getting ORACLE_HOME: [In case the user didn't set it up above]
# ###################

if [ -z ${ORACLE_SID} ]
 then
  ORACLE_SID=`ps -ef|grep pmon|grep -v grep|awk '{print $NF}'|sed -e 's/ora_pmon_//g'|grep -v sed|grep -v "s///g"|tail -1`
  export ORACLE_SID
fi


  ORA_USER=`ps -ef|grep ${ORACLE_SID}|grep pmon|grep -v grep|awk '{print $1}'|tail -1`
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
fi

# ATTEMPT5: If ORACLE_HOME is still not found, search for orapipe: [Least accurate]
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  ORACLE_HOME=`locate -i orapipe|head -1|sed -e 's/\/bin\/orapipe//g'`
  export ORACLE_HOME
fi

# TERMINATE: If all above attempts failed to get ORACLE_HOME location, EXIT the script:
if [ ! -f ${ORACLE_HOME}/bin/sqlplus ]
 then
  echo "Please export ORACLE_HOME variable inside this script in order to get it run properly."
  echo "e.g."
  echo "export ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_1"
mail -s "goldengate_lag_mon script failed on Server [${SRV_NAME}] due to the failure of finding ORACLE_HOME, Please export ORACLE_HOME variable inside the script" ${MAIL_LIST} < /dev/null
exit
fi

export LD_LIBRARY_PATH=${ORACLE_HOME}/lib
echo LD_LIBRARY_PATH is: $LD_LIBRARY_PATH

# ################################################
# Checking the LAG status from Goldengate Console:
# ################################################
for GREP_SERVICE in EXTRACT REPLICAT
do
export GREP_SERVICE

export LOG_DIR=${LOG_DIRECTORY}
export LOG_FILE=${LOG_DIR}/${GREP_SERVICE}_lag_mon.log

# Identify lagging operation name:
	case ${GREP_SERVICE} in
	"REPLICAT") 	LAST_COL_OPNAME="RECEIVING"
			export LAST_COL_OPNAME
			BFR_LAST_COL_OPNAME="APPLYING"
			export BFR_LAST_COL_OPNAME
	;;
	"EXTRACT")	LAST_COL_OPNAME="SENDING"

			export LAST_COL_OPNAME
			BFR_LAST_COL_OPNAME="EXTRACTING"
			export BFR_LAST_COL_OPNAME
	;;
	esac


$GG_HOME/ggsci << EOF |grep "${GREP_SERVICE}" > ${LOG_FILE}
info all
exit
EOF

# ################################
# Email Notification if LAG Found:
# ################################

for i  in `cat ${LOG_FILE}|egrep -v ${EXL_PROC_NAME}|awk '{print $NF}'|sed -e 's/://g'`
do
	if [ $i -ge ${LAG} ]
	then
mail -s "Goldengate LAG detected in ${LAST_COL_OPNAME} TRAIL FILES on Server [${SERVER_NAME}]" ${MAIL_LIST} < ${LOG_FILE}
echo "Goldengate LAG detected in ${LAST_COL_OPNAME} TRAIL FILES on Server [${SERVER_NAME}]"
	fi
done


for i  in `cat ${LOG_FILE}|egrep -v ${EXL_PROC_NAME}|awk '{print $(NF-1)}'|sed -e 's/://g'`
do
	if [ $i -ge ${LAG} ]
	then
mail -s "Goldengate LAG detected in ${BFR_LAST_COL_OPNAME} TRAIL FILES on Server [${SERVER_NAME}]" ${MAIL_LIST} < ${LOG_FILE}
echo "Goldengate LAG detected in ${BFR_LAST_COL_OPNAME} TRAIL FILES on Server [${SERVER_NAME}]"
	fi
done

done

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
