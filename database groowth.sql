set serveroutput on

col SNAP_TIME for a45
col "Database Size(GB)" for 99999999999999999
Declare
    v_BaselineSize    number(20);
    v_CurrentSize    number(20);
    v_TotalGrowth    number(20);
    v_Space        number(20);
    cursor usageHist is
            select a.snap_id,
            SNAP_TIME,
            sum(TOTAL_SPACE_ALLOCATED_DELTA) over ( order by a.SNAP_ID) ProgSum
        from
            (select SNAP_ID,
                sum(SPACE_ALLOCATED_DELTA) TOTAL_SPACE_ALLOCATED_DELTA
            from DBA_HIST_SEG_STAT
            group by SNAP_ID
            having sum(SPACE_ALLOCATED_TOTAL) <> 0
            order by 1 ) a,
            (select distinct SNAP_ID,
                to_char(END_INTERVAL_TIME,'DD-Mon-YYYY HH24:Mi') SNAP_TIME
            from DBA_HIST_SNAPSHOT) b
        where a.snap_id=b.snap_id;
Begin
    select sum(SPACE_ALLOCATED_DELTA) into v_TotalGrowth from DBA_HIST_SEG_STAT;
    select sum(bytes) into v_CurrentSize from dba_segments;
    v_BaselineSize := (v_CurrentSize - v_TotalGrowth) ;
    dbms_output.put_line('SNAP_TIME           Database Size(GB)');
    for row in usageHist loop
            v_Space := (v_BaselineSize + row.ProgSum)/(1024*1024*1024);
        dbms_output.put_line(row.SNAP_TIME || '           ' || to_char(v_Space) );
    end loop;
end;
/
