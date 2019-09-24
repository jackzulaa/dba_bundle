# ##############################################################################################
# Script to be used on crontab to schedule an RMAN Image/Copy Backup
VER="[1.2]"
# ##############################################################################################
#                                       #   #     #
# Author:       Mahmmoud ADEL         # # # #   ###
# Created:      01-10-17            #   #   # #   #  
#
# Modified:	02-10-17
#		10-03-19 Add the option of deleting old CONTROLFILE AUTOBACKUP files.
#
#
# ##############################################################################################

# VARIABLES Section: [Must be Modified for each Env]
# #################

# INSTANCE Name: [Replace ${ORACLE_SID} with your instance SID]
export ORACLE_SID=${ORACLE_SID}

# ORACLE_HOME Location: [Replace ${ORACLE_HOME} with the right ORACLE_HOME path]
export ORACLE_HOME=${ORACLE_HOME}

# Backup Location: [Replace /backup/rmancopy with the right backup location path]
export BACKUPLOC=/backup/rmancopy

# Backup LOG location:
export RMANLOG=${BACKUPLOC}/rmancopy.log

# Perform Maintenance based on below Backup & Archive Retention: [Y|N] [Default DISABLED]
MAINTENANCEFLAG=N

# Backup Retention "In Days": [Backups older than this retention will be deleted]
export BKP_RETENTION=7

# Archives Deletion "In Days": [Archivelogs older than this retention will be deleted]
export ARCH_RETENTION=7

# CONTROLFILE AUTOBACKUP Retention "In Days": [AUTOBACKUP of CONTROLFILE older than this retention will be deleted]
CTRL_AUTOBKP_RETENTION=7

# Show the full DATE and TIME details in the backup log:
export NLS_DATE_FORMAT='DD-Mon-YYYY HH24:MI:SS'

export ORACLE_SID
export ORACLE_HOME
export BACKUPLOC
export COMPRESSION
export BKP_RETENTION
export ARCH_RETENTION
export RMANLOG
export NLS_DATE_FORMAT
export MAINTENANCEFLAG

# Check the selected MAINTENANCE option:
        case ${MAINTENANCEFLAG} in
        Y|y|YES|Yes|yes|ON|on)
        HASH_MAINT=""
        export HASH_MAINT
        ;;
        *)
        HASH_MAINT="#"
        export COMPRESSED_BKP
        ;;
        esac

# Append the date to the backup log for each script execution:
echo "----------------------------" >> ${RMANLOG}
date                                >> ${RMANLOG}
echo "----------------------------" >> ${RMANLOG}

# ###################
# RMAN SCRIPT Section:
# ###################

${ORACLE_HOME}/bin/rman target /  msglog=${RMANLOG} <<EOF
# Configuration Section:
# ---------------------
${HASH_MAINT}CONFIGURE BACKUP OPTIMIZATION ON;
${HASH_MAINT}CONFIGURE CONTROLFILE AUTOBACKUP ON;
${HASH_MAINT}CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '${BACKUPLOC}/%F';
${HASH_MAINT}CONFIGURE SNAPSHOT CONTROLFILE NAME TO '${ORACLE_HOME}/dbs/snapcf_${ORACLE_SID}.f';
## Avoid Deleting archivelogs NOT yet applied on the standby: [When FORCE is not used]
#CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY;

# Maintenance Section:
# -------------------
## Crosscheck backups/copied to check for expired backups which are physically not available on the media:
${HASH_MAINT}crosscheck backup completed before 'sysdate-${BKP_RETENTION}' device type disk;
${HASH_MAINT}crosscheck copy completed   before 'sysdate-${BKP_RETENTION}' device type disk;
## Report & Delete Obsolete backups which don't meet the RETENTION POLICY:
${HASH_MAINT}report obsolete RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
${HASH_MAINT}DELETE NOPROMPT OBSOLETE RECOVERY WINDOW OF ${BKP_RETENTION} DAYS device type disk;
## Delete All EXPIRED backups/copies which are not physically available:
${HASH_MAINT}DELETE NOPROMPT EXPIRED BACKUP COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
${HASH_MAINT}DELETE NOPROMPT EXPIRED COPY   COMPLETED BEFORE 'sysdate-${BKP_RETENTION}' device type disk;
## Crosscheck Archivelogs to avoid the backup failure:
${HASH_MAINT}CHANGE ARCHIVELOG ALL CROSSCHECK;
${HASH_MAINT}DELETE NOPROMPT EXPIRED ARCHIVELOG ALL;
## Delete Archivelogs older than ARCH_RETENTION days:
${HASH_MAINT}DELETE NOPROMPT archivelog all completed before 'sysdate -${ARCH_RETENTION}';
## Delete AUTOBACKUP Controlfile older than CTRL_AUTOBKP_RETENTION days:
DELETE NOPROMPT BACKUP of controlfile completed before 'sysdate-${CTRL_AUTOBKP_RETENTION}';

# Image Copy Backup Script starts here: [Create Image Copy and recover it]
# -------------------------------------
run{
allocate channel F1 type disk format '${BACKUPLOC}/%U';
allocate channel F2 type disk format '${BACKUPLOC}/%U';
allocate channel F3 type disk format '${BACKUPLOC}/%U';
allocate channel F4 type disk format '${BACKUPLOC}/%U';
BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 FOR RECOVER OF COPY WITH TAG 'DB_COPY_UPDTD_BKP'
DATABASE FORMAT '${BACKUPLOC}/%d_%t_%s_%p';						# Incremental Level 1 Backup to recover the Image COPY.
RECOVER COPY OF DATABASE WITH TAG 'DB_COPY_UPDTD_BKP';					# Recover Image Copy with the Incr lvl1.
DELETE noprompt backup TAG 'DB_COPY_UPDTD_BKP';						# Delete [only] the incrmental bkp used for recovery.
#DELETE noprompt backup TAG 'arc_for_image_recovery' completed before 'sysdate-1';	# Delete Archive bkp for the previous recover.
DELETE noprompt copy   TAG 'ctrl_after_image_reco';					# Delete Controlfile bkp for the previous run.
#sql 'alter system archive log current';
#BACKUP as compressed backupset archivelog from time not backed up 1 times
#format '${BACKUPLOC}/arc_%d_%t_%s_%p' tag 'arc_for_image_recovery';				# Backup Archivelogs after the Image Copy..
BACKUP as copy current controlfile format '${BACKUPLOC}/ctl_%U' tag 'ctrl_after_image_reco';	# Controlfile Copy Backup.
sql "ALTER DATABASE BACKUP CONTROLFILE TO TRACE AS ''${BACKUPLOC}/controlfile.trc'' reuse";	# Controlfile Trace Backup.
sql "create pfile=''${BACKUPLOC}/init${ORACLE_SID}.ora'' from spfile";				# Backup SPFILE.
}
EOF

# #############
# END OF SCRIPT
# #############
# REPORT BUGS to: mahmmoudadel@hotmail.com
# DOWNLOAD THE LATEST VERSION OF DATABASE ADMINISTRATION BUNDLE FROM:
# http://dba-tips.blogspot.com/2014/02/oracle-database-administration-scripts.html
# DISCLAIMER: THIS SCRIPT IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT WITHOUT ANY WARRANTY. IT IS PROVIDED "AS IS".
