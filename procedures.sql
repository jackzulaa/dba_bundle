
  CREATE OR REPLACE FORCE EDITIONABLE VIEW "SYSMAN"."MGMT_V_TABLESPACES" ("DB_NAME", "TABLESPACE_NAME", "SIZE_MB", "FREE_MB", "MAX_SIZE_MB", "MAX_FREE_MB", "FREE_PCT", "USED_PCT") AS 
  SELECT 'BFUB' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@BFUB.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@BFUB.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name ) 
;
SELECT 'RTPS' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@RTPS.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@RTPS.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name ) 
;
SELECT 'MCOOP4.0' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@MCOOPRD.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@MCOOPRD.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name ) 
;
SELECT 'MCOOP3.0/MWALPRD' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@MWALPRD.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@MWALPRD.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name ) 
;
SELECT 'SOA' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@SOA.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@SOA.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name )
;
SELECT 'SOA_BW6SOA' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@BW6SOA
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@BW6SOA
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name )
;
SELECT 'SOALOGDB' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@SOALOGDB.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@SOALOGDB.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name )
;
SELECT 'CBX' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@CBXPDB.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@CBXPDB.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name )
;
SELECT 'DFRPRD' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@DFRPRD.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@DFRPRD.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name )
;
SELECT 'CMS' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@RPT_CMS
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@RPT_CMS
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'MPCS' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@MPCS.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@MPCS.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'CL2' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@CL2.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@CL2.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'ISSUING' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@RPT_ISSUINGPR
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@RPT_ISSUINGPR
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'OPICS' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@OPICS.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@OPICS.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'CORONA' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@CORONA.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@CORONA.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'MANDATE' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@MANDATE.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@MANDATE.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'ANALYTICS' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@ANALYTICS.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@ANALYTICS.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'ECOLLECT' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@ECOLLECT.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@ECOLLECT.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'AMLDB' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@AMLDB.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@AMLDB.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'REPORTDB' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@REPORTDB.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@REPORTDB.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'OPENBANKDB' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@OPENBANKDB.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@OPENBANKDB.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name)
;
SELECT 'WSO2' db_name,tablespace_name, size_mb, free_mb, max_size_mb, max_free_mb, TRUNC((max_free_mb/max_size_mb) * 100) AS free_pct, TRUNC((max_size_mb-max_free_mb)/max_size_mb*100) AS used_pct
FROM  (SELECT a.tablespace_name,b.size_mb,a.free_mb,b.max_size_mb,a.free_mb + (b.max_size_mb - b.size_mb) AS max_free_mb FROM   (SELECT tablespace_name,TRUNC(SUM(bytes)/1024/1024) AS free_mb FROM   dba_free_space@WSO2.COOP.KE
GROUP BY tablespace_name) a, (SELECT tablespace_name, TRUNC(SUM(bytes)/1024/1024) AS size_mb, TRUNC(SUM(GREATEST(bytes,maxbytes))/1024/1024) AS max_size_mb FROM   dba_data_files@WSO2.COOP.KE
GROUP BY tablespace_name) b WHERE  a.tablespace_name = b.tablespace_name);