set pages 999 lines 400
col h0 format 999
col h1 format 999
col h2 format 999
col h3 format 999
col h4 format 999
col h5 format 999
col h6 format 999
col h7 format 999
col h8 format 999
col h9 format 999
col h10 format 999
col h11 format 999
col h12 format 999
col h13 format 999
col h14 format 999
col h15 format 999
col h16 format 999
col h17 format 999
col h18 format 999
col h19 format 999
col h20 format 999
col h21 format 999
col h22 format 999
col h23 format 999
SELECT TRUNC (first_time) "Date", inst_id, TO_CHAR (first_time, 'Dy') "Day",
 COUNT (1) "Total",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '00', 1, 0)) "h0",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '01', 1, 0)) "h1",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '02', 1, 0)) "h2",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '03', 1, 0)) "h3",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '04', 1, 0)) "h4",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '05', 1, 0)) "h5",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '06', 1, 0)) "h6",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '07', 1, 0)) "h7",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '08', 1, 0)) "h8",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '09', 1, 0)) "h9",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '10', 1, 0)) "h10",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '11', 1, 0)) "h11",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '12', 1, 0)) "h12",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '13', 1, 0)) "h13",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '14', 1, 0)) "h14",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '15', 1, 0)) "h15",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '16', 1, 0)) "h16",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '17', 1, 0)) "h17",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '18', 1, 0)) "h18",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '19', 1, 0)) "h19",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '20', 1, 0)) "h20",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '21', 1, 0)) "h21",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '22', 1, 0)) "h22",
 SUM (DECODE (TO_CHAR (first_time, 'hh24'), '23', 1, 0)) "h23",
 ROUND (COUNT (1) / 24, 2) "Avg"
FROM gv$log_history
WHERE thread# = inst_id
AND first_time > sysdate -7
GROUP BY TRUNC (first_time), inst_id, TO_CHAR (first_time, 'Dy')
ORDER BY 1,2;


---------------------------
set pages 999 lines 400
col FIRST_CHANGE# format 999999999999999
select GROUP#, THREAD#, SEQUENCE#, BYTES/1024/1024 SIZE_MB, BLOCKSIZE, MEMBERS, ARCHIVED, STATUS, FIRST_CHANGE#, FIRST_TIME, NEXT_CHANGE#, NEXT_TIME, CON_ID from v$log;


