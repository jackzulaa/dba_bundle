01fp8ba70n8ts


1. Create Tuning Task
DECLARE
l_sql_tune_task_id VARCHAR2(100);
BEGIN
l_sql_tune_task_id := DBMS_SQLTUNE.create_tuning_task (
sql_id => '01fp8ba70n8ts',
scope => DBMS_SQLTUNE.scope_comprehensive,
time_limit => 500,
task_name => '01fp8ba70n8ts_tuning_task11',
description => 'Tuning task1 for statement 01fp8ba70n8ts');
DBMS_OUTPUT.put_line('l_sql_tune_task_id: ' || l_sql_tune_task_id);
END;
/

2. Execute Tuning task:
EXEC DBMS_SQLTUNE.execute_tuning_task(task_name => '01fp8ba70n8ts_tuning_task11');

3. Get the Tuning advisor report.

set long 65536
set longchunksize 65536
set linesize 100
select dbms_sqltune.report_tuning_task('01fp8ba70n8ts_tuning_task11') from dual;


ACCESS ADVISOR
select TASK_ID,TASK_NAME,ADVISOR_NAME from dba_advisor_tasks 
	where ADVISOR_NAME in ('SQL Access Advisor','SQL Tuning Advisor');

exec dbms_advisor.ADD_STS_REF ('01fp8ba70n8ts_tuning_task11','SYS','01fp8ba70n8ts_tuning_task11');


SET LINES 150
SET pages 50000
SET long 5000000
SET longc 5000000

SELECT DBMS_SQLTUNE.report_tuning_task('01fp8ba70n8ts_tuning_task11') AS recommendations FROM dual;

 172.16.210.12/



 SELECT RESULTTYPE,RESULTCODE,RESULTDESC,TRANSACTIONID,
             utl_raw.cast_to_varchar2(dbms_lob.substr(RESPONSEPAYLOAD,100))
             As RESPONSEPAYLOAD FROM HOST2HOST.IMTTRANSACTIONS
             WHERE ORIGINATORCONVERSATIONID='05216631e83-becb-43ac-a17c-e8c0c2225822VAL';
