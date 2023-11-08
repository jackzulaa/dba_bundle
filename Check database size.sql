SET LINESIZE 200
SET PAGESIZE 200
select round(sum(used.bytes) / 1024 / 1024 / 1024 ) || 'GB' "Database Size"
, round(sum(used.bytes) / 1024 / 1024 / 1024 )- round(free.p / 1024 / 1024 / 1024) || 'GB' "Used space"
, round(free.p / 1024 / 1024 / 1024) || 'GB' "Free space"
from (select bytes
from v$datafile
union all
select bytes
from v$tempfile
union all
select bytes
from v$log) used
, (select sum(bytes) as p
from dba_free_space) free
group by free.p ;
/

AGNTPROD
CUSTOMCOPKE.MERCHANT_DETAILS 

/u01/app/copgdmgr/diag/tnslsnr/copkprdomni02/listener/alert/
find . -type f -mmin +5 -name '*.xml*' -exec rm -f {} \;
/u01/app/copgdmgr/diag/tnslsnr/copkprdomni02/listener/trace/
find . -type f -name '*.xml*' -exec rm -f {} \;


/u01/app/copgdmgr/diag/tnslsnr/copkprdomni02/listener/alert/

/u01/app/copgdmgr/diag/tnslsnr/copkprdomni02/listener/trace/




cd /u01/app/copdbmgr/admin/DFRPRD/adump
find . -type f -name '*.aud*' -exec rm -f {} \;

cd /u01/app/copdbmgr/admin/MWALLET/adump
find . -type f -name '*.aud*' -exec rm -f {} \;

i restarted one node of db  bila kuambia apps 


-------------------------------------
How to check Database Growth in Oracle 

1. Set the coloumn and page format.
SET LINESIZE 200
SET PAGESIZE 200
COL “Database Size” FORMAT a13
COL “Used Space” FORMAT a11
COL “Used in %” FORMAT a11
COL “Free in %” FORMAT a11
COL “Database Name” FORMAT a13
COL “Free Space” FORMAT a12
COL “Growth DAY” FORMAT a11
COL “Growth WEEK” FORMAT a12
COL “Growth DAY in %” FORMAT a16
COL “Growth WEEK in %” FORMAT a16
2. Query to find Database Growth
SELECT
(select min(creation_time) from v$datafile) “Create Time”,
(select name from v$database) “Database Name”,
ROUND((SUM(USED.BYTES) / 1024 / 1024 ),2) || ‘ MB’ “Database Size”,
ROUND((SUM(USED.BYTES) / 1024 / 1024 ) – ROUND(FREE.P / 1024 / 1024 ),2) || ‘ MB’ “Used Space”,
ROUND(((SUM(USED.BYTES) / 1024 / 1024 ) – (FREE.P / 1024 / 1024 )) / ROUND(SUM(USED.BYTES) / 1024 / 1024 ,2)*100,2) || ‘% MB’ “Used in %”,
ROUND((FREE.P / 1024 / 1024 ),2) || ‘ MB’ “Free Space”,
ROUND(((SUM(USED.BYTES) / 1024 / 1024 ) – ((SUM(USED.BYTES) / 1024 / 1024 ) – ROUND(FREE.P / 1024 / 1024 )))/ROUND(SUM(USED.BYTES) / 1024 / 1024,2 )*100,2) || ‘% MB’ “Free in %”,
ROUND(((SUM(USED.BYTES) / 1024 / 1024 ) – (FREE.P / 1024 / 1024 ))/(select sysdate-min(creation_time) from v$datafile),2) || ‘ MB’ “Growth DAY”,
ROUND(((SUM(USED.BYTES) / 1024 / 1024 ) – (FREE.P / 1024 / 1024 ))/(select sysdate-min(creation_time) from v$datafile)/ROUND((SUM(USED.BYTES) / 1024 / 1024 ),2)*100,3) || ‘% MB’ “Growth DAY in %”,
ROUND(((SUM(USED.BYTES) / 1024 / 1024 ) – (FREE.P / 1024 / 1024 ))/(select sysdate-min(creation_time) from v$datafile)*7,2) || ‘ MB’ “Growth WEEK”,
ROUND((((SUM(USED.BYTES) / 1024 / 1024 ) – (FREE.P / 1024 / 1024 ))/(select sysdate-min(creation_time) from v$datafile)/ROUND((SUM(USED.BYTES) / 1024 / 1024 ),2)*100)*7,3) || ‘% MB’ “Growth WEEK in %”
FROM    (SELECT BYTES FROM V$DATAFILE
UNION ALL
SELECT BYTES FROM V$TEMPFILE
UNION ALL
SELECT BYTES FROM V$LOG) USED,
(SELECT SUM(BYTES) AS P FROM DBA_FREE_SPACE) FREE
GROUP BY FREE.P;