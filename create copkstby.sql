(ADDRESS=(PROTOCOL=TCP)(HOST=172.16.214.12)(PORT=1531))
copkcbsdr-scan:1531/COPKSTBY

COPKSTBY =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = 172.16.214.12)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = COPKSTBY)
    )
  )
  
COPKFIN =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = copkcbsprd-scan)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = COPKFIN)
    )
  )




ON Primary

ALTER DATABASE FORCE LOGGING;
SQL> select FORCE_LOGGING,log_mode from v$database;
Step2:-Adding Redologfile for standby database
SQL> 
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1
GROUP 19 ('+FRAHCDG10','+DATHCDG10') SIZE 50M,
GROUP 20 ('+FRAHCDG10','+DATHCDG10') SIZE 50M,
GROUP 21 ('+FRAHCDG10','+DATHCDG10') SIZE 50M,
GROUP 22 ('+FRAHCDG10','+DATHCDG10') SIZE 50M;
SQL> 
ALTER DATABASE ADD STANDBY LOGFILE 
GROUP 23 ('+FRAHCDG10','+DATHCDG10') SIZE 50M,
GROUP 24 ('+FRAHCDG10','+DATHCDG10') SIZE 50M,
GROUP 25 ('+FRAHCDG10','+DATHCDG10') SIZE 50M,
GROUP 26 ('+FRAHCDG10','+DATHCDG10') SIZE 50M;

 alter database add standby logfile THREAD 1 group 19 ('+DATA(ONLINELOG)','+FRA(ONLINELOG)') SIZE 200M;
 
SQL> SELECT GROUP#,THREAD#,SEQUENCE#,ARCHIVED,STATUS FROM V$STANDBY_LOG ;

SQL> ALTER SYSTEM SET log_archive_config='dg_config=(COPKFIN,COPKSTBY)' SCOPE=both sid='*';
SQL> ALTER SYSTEM SET log_archive_dest_1='location=use_db_recovery_file_dest valid_for=(all_logfiles,all_roles) db_unique_name=COPKFIN' SCOPE=both  sid='*';
SQL> ALTER SYSTEM SET log_archive_dest_2='service=COPKSTBY async valid_for=(online_logfiles,primary_role) db_unique_name=COPKSTBY' SCOPE=both  sid='*';
SQL> ALTER SYSTEM SET fal_server='COPKSTBY' SCOPE=both    sid='*';
SQL> ALTER SYSTEM SET fal_client='COPKFIN' SCOPE=both  sid='*';
SQL> ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=both  sid='*';

rman target sys/"F_#jnaNyteu9GpXNZK6X"@COPKFIN auxiliary sys/"F_#jnaNyteu9GpXNZK6X"@COPKSTBY

asmcmd pwget --dbuniquename COPKFIN
srvctl config database -d COPKFIN
pwcopy +DATAC1/COPKFIN/PASSWORD/pwdcopkfin.281.1099478289 /tmp/orapwCOPKFIN
Note Hard code listener for replication and make the tns point one node 
SID_LIST_LISTENER =
    (SID_LIST =
       (SID_DESC =
         (ORACLE_HOME = /u01/app/copdbmgr/product/19.0.0.0/dbhome_1)
         (SID_NAME = COPKSTBY)
      )
    )

	
	
run
{
allocate channel p1 type disk;
allocate channel p2 type disk;
allocate channel p3 type disk;
allocate channel p4 type disk;
allocate auxiliary channel s1 type disk;
duplicate target database for standby from active database
spfile
parameter_value_convert 'COPKFIN','COPKSTBY'
set db_name='COPKFIN'
set db_unique_name='COPKSTBY'
set control_files='+DATAC1/COPKSTBY/CONTROLFILE/current.286.1099478419'
set log_archive_max_processes='5'
set fal_client='COPKSTBY'
set fal_server='COPKFIN'
set standby_file_management='AUTO'
set log_archive_config='dg_config=(COPKFIN,COPKSTBY)'
set compatible='19.4.0.1.0'
set memory_target='70G'
nofilenamecheck;
}

SQL> alter session  set nls_date_format="yyyy-mm-dd hh24:mi:ss";

Session altered.

SQL> SELECT sequence#, first_time, next_time, applied FROM v$archived_log ORDER BY 3;

SQL> alter database recover managed standby database disconnect nodelay;
Database altered.


SQL> SELECT sequence#, first_time, next_time, applied FROM v$archived_log ORDER BY sequence#;

	SELECT sequence#, first_time, next_time, applied FROM v$archived_log ORDER BY 3;
	select sequence#,first_time,next_time,applied,thread# from v$archived_log where  applied='NO' order by 2;

alter database recover managed standby database cancel;

startup mount ;

alter database open ;

alter database  recover managed standby database disconnect from session;


alter system set remote_listener='copkcbsdr-scan:1531'  scope =both;


alter system set local_listener='(ADDRESS=(PROTOCOL=TCP)(HOST=172.16.214.12)(PORT=1531))'   scope =both; 



log_archive_config                   string

NAME                                 TYPE
------------------------------------ --------------------------------
VALUE
------------------------------
DG_CONFIG=(BFUBPRD,bfubdr,COPKTRNG,COPK,COPKFIN)



log_archive_dest_state_7

show parameter log_archive_dest_


Recover from service;


recover database from service COPKFIN noredo using compressed backupset;



run
{
allocate channel p1 type disk;
allocate channel p2 type disk;
allocate channel p3 type disk;
allocate channel p4 type disk;
allocate auxiliary channel s1 type disk;
duplicate target database for standby from active database
spfile
parameter_value_convert 'COPKFIN','COPKSTBY'
set db_name='COPKFIN'
set db_unique_name='COPKSTBY'
set control_files='+DATAC1/COPKSTBY/CONTROLFILE/current.286.1099478419'
set log_archive_max_processes='5'
set fal_client='COPKSTBY'
set fal_server='COPKFIN'
set standby_file_management='AUTO'
set log_archive_config='dg_config=(COPKFIN,COPKSTBY)'
set compatible='19.4.0.1.0'
set sga_max_size='50g'
set sga_target='50g'
set pga_aggregate_target='20g'
set instance_number='1'
nofilenamecheck;
}


startup nomount pfile='/home/copdbmgr/initcopkstby.ora'



COPKFIN =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = copkcbsprd-scan)(PORT = 1531))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = COPKFIN)
    )
  )
