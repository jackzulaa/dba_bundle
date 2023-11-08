
alter pluggable database TIPLUS3 close;

alter pluggable database TIPLUS3 open restricted;

alter session set container=TIPLUS3;

alter pluggable database rename global_name to TIPLUS3_ORIG;
alter pluggable database close immediate;
alter pluggable database open;
exec dbms_service.create_service('TIPLUS3', 'TIPLUS3'); 
exec dbms_service.start_service('TIPLUS3');