SELECT ROUND(pga_target_for_estimate/1024/1024) target_mb,
       estd_pga_cache_hit_percentage cache_hit_perc,
       estd_overalloc_count
FROM   v$pga_target_advice;



SELECT ROUND(pga_target_for_estimate/1024/1024) target_mb,
       estd_sga_cache_hit_percentage cache_hit_perc
FROM   v$sga_target_advice;




SELECT a.sga_size,--SGA Expected size
A.sga_size_factor,--expected SGA size as a percentage of the actual SGA size
A.estd_db_time,--SGA is set to the desired size after its dbtime consumes the desired change
A.estd_db_time_factor,--Modify the size of the SGA as expected, dbtime the change in consumption and the percentage of changes before the change
a.estd_physical_reads--difference in physical reading before and after modification
From V$sga_target_advice A;




SELECT a.sga_size,
A.sga_size_factor,
A.estd_db_time,
A.estd_db_time_factor,
a.estd_physical_reads
From V$sga_target_advice A;


BAASDR

alter database switchover to B2BDR verify;



alter system set log_archive_config='DG_CONFIG=(ANALYTICS,ANALYTICSDR)' scope=both sid='*'; 
