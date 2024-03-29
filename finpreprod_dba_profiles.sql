CREATE PROFILE "END_USER_PROFILE"
LIMIT 
    COMPOSITE_LIMIT UNLIMITED 
    SESSIONS_PER_USER UNLIMITED 
    CPU_PER_SESSION UNLIMITED 
    CPU_PER_CALL UNLIMITED 
    LOGICAL_READS_PER_SESSION UNLIMITED 
    LOGICAL_READS_PER_CALL UNLIMITED 
    IDLE_TIME UNLIMITED 
    CONNECT_TIME UNLIMITED 
    PRIVATE_SGA UNLIMITED 
    FAILED_LOGIN_ATTEMPTS 10 
    PASSWORD_LIFE_TIME 15552000/86400 
    PASSWORD_REUSE_TIME UNLIMITED 
    PASSWORD_REUSE_MAX UNLIMITED 
    PASSWORD_VERIFY_FUNCTION "ORA12C_STIG_VERIFY_FUNCTION" 
    PASSWORD_LOCK_TIME 86400/86400 
    PASSWORD_GRACE_TIME 604800/86400 
    INACTIVE_ACCOUNT_TIME DEFAULT 
    PASSWORD_ROLLOVER_TIME DEFAULT ;


CREATE PROFILE "AUDIT_TEAM"
LIMIT 
    COMPOSITE_LIMIT DEFAULT 
    SESSIONS_PER_USER 1 
    CPU_PER_SESSION DEFAULT 
    CPU_PER_CALL DEFAULT 
    LOGICAL_READS_PER_SESSION DEFAULT 
    LOGICAL_READS_PER_CALL DEFAULT 
    IDLE_TIME 15 
    CONNECT_TIME DEFAULT 
    PRIVATE_SGA DEFAULT 
    FAILED_LOGIN_ATTEMPTS 3 
    PASSWORD_LIFE_TIME 2592000/86400 
    PASSWORD_REUSE_TIME 31536000/86400 
    PASSWORD_REUSE_MAX 20 
    PASSWORD_VERIFY_FUNCTION "ORA12C_VERIFY_FUNCTION" 
    PASSWORD_LOCK_TIME 86400/86400 
    PASSWORD_GRACE_TIME 259200/86400 
    INACTIVE_ACCOUNT_TIME DEFAULT 
    PASSWORD_ROLLOVER_TIME DEFAULT ;


CREATE PROFILE "MONITORING_PROFILE"
LIMIT 
    COMPOSITE_LIMIT DEFAULT 
    SESSIONS_PER_USER 1 
    CPU_PER_SESSION DEFAULT 
    CPU_PER_CALL DEFAULT 
    LOGICAL_READS_PER_SESSION DEFAULT 
    LOGICAL_READS_PER_CALL DEFAULT 
    IDLE_TIME 15 
    CONNECT_TIME DEFAULT 
    PRIVATE_SGA DEFAULT 
    FAILED_LOGIN_ATTEMPTS 3 
    PASSWORD_LIFE_TIME 2592000/86400 
    PASSWORD_REUSE_TIME 31536000/86400 
    PASSWORD_REUSE_MAX 20 
    PASSWORD_VERIFY_FUNCTION "ORA12C_STIG_VERIFY_FUNCTION" 
    PASSWORD_LOCK_TIME 259200/86400 
    PASSWORD_GRACE_TIME 259200/86400 
    INACTIVE_ACCOUNT_TIME DEFAULT 
    PASSWORD_ROLLOVER_TIME DEFAULT ;


CREATE PROFILE "BAU_USERS"
LIMIT 
    COMPOSITE_LIMIT DEFAULT 
    SESSIONS_PER_USER 5 
    CPU_PER_SESSION DEFAULT 
    CPU_PER_CALL DEFAULT 
    LOGICAL_READS_PER_SESSION DEFAULT 
    LOGICAL_READS_PER_CALL DEFAULT 
    IDLE_TIME 15 
    CONNECT_TIME DEFAULT 
    PRIVATE_SGA DEFAULT 
    FAILED_LOGIN_ATTEMPTS 3 
    PASSWORD_LIFE_TIME 2592000/86400 
    PASSWORD_REUSE_TIME 31536000/86400 
    PASSWORD_REUSE_MAX 20 
    PASSWORD_VERIFY_FUNCTION "ORA12C_STIG_VERIFY_FUNCTION" 
    PASSWORD_LOCK_TIME 259200/86400 
    PASSWORD_GRACE_TIME 259200/86400 
    INACTIVE_ACCOUNT_TIME DEFAULT 
    PASSWORD_ROLLOVER_TIME DEFAULT ;


CREATE PROFILE "PERIPHERAL_SERVICE_ACCOUNTS"
LIMIT 
    COMPOSITE_LIMIT UNLIMITED 
    SESSIONS_PER_USER UNLIMITED 
    CPU_PER_SESSION UNLIMITED 
    CPU_PER_CALL UNLIMITED 
    LOGICAL_READS_PER_SESSION UNLIMITED 
    LOGICAL_READS_PER_CALL UNLIMITED 
    IDLE_TIME UNLIMITED 
    CONNECT_TIME UNLIMITED 
    PRIVATE_SGA UNLIMITED 
    FAILED_LOGIN_ATTEMPTS UNLIMITED 
    PASSWORD_LIFE_TIME UNLIMITED 
    PASSWORD_REUSE_TIME UNLIMITED 
    PASSWORD_REUSE_MAX UNLIMITED 
    PASSWORD_VERIFY_FUNCTION NULL 
    PASSWORD_LOCK_TIME UNLIMITED 
    PASSWORD_GRACE_TIME UNLIMITED 
    INACTIVE_ACCOUNT_TIME DEFAULT 
    PASSWORD_ROLLOVER_TIME DEFAULT ;


CREATE PROFILE "COPDBA"
LIMIT 
    COMPOSITE_LIMIT DEFAULT 
    SESSIONS_PER_USER 1 
    CPU_PER_SESSION DEFAULT 
    CPU_PER_CALL DEFAULT 
    LOGICAL_READS_PER_SESSION DEFAULT 
    LOGICAL_READS_PER_CALL DEFAULT 
    IDLE_TIME 15 
    CONNECT_TIME DEFAULT 
    PRIVATE_SGA DEFAULT 
    FAILED_LOGIN_ATTEMPTS 3 
    PASSWORD_LIFE_TIME 2592000/86400 
    PASSWORD_REUSE_TIME 31536000/86400 
    PASSWORD_REUSE_MAX 20 
    PASSWORD_VERIFY_FUNCTION "ORA12C_STIG_VERIFY_FUNCTION" 
    PASSWORD_LOCK_TIME 259200/86400 
    PASSWORD_GRACE_TIME 604800/86400 
    INACTIVE_ACCOUNT_TIME DEFAULT 
    PASSWORD_ROLLOVER_TIME DEFAULT ;


CREATE PROFILE "SERVICE_ACCOUNTS"
LIMIT 
    COMPOSITE_LIMIT UNLIMITED 
    SESSIONS_PER_USER UNLIMITED 
    CPU_PER_SESSION UNLIMITED 
    CPU_PER_CALL UNLIMITED 
    LOGICAL_READS_PER_SESSION UNLIMITED 
    LOGICAL_READS_PER_CALL UNLIMITED 
    IDLE_TIME UNLIMITED 
    CONNECT_TIME UNLIMITED 
    PRIVATE_SGA UNLIMITED 
    FAILED_LOGIN_ATTEMPTS UNLIMITED 
    PASSWORD_LIFE_TIME UNLIMITED 
    PASSWORD_REUSE_TIME UNLIMITED 
    PASSWORD_REUSE_MAX UNLIMITED 
    PASSWORD_VERIFY_FUNCTION NULL 
    PASSWORD_LOCK_TIME UNLIMITED 
    PASSWORD_GRACE_TIME UNLIMITED 
    INACTIVE_ACCOUNT_TIME DEFAULT 
    PASSWORD_ROLLOVER_TIME DEFAULT ;


CREATE PROFILE "SERVICE_ACCOUNT"
LIMIT 
    COMPOSITE_LIMIT UNLIMITED 
    SESSIONS_PER_USER UNLIMITED 
    CPU_PER_SESSION UNLIMITED 
    CPU_PER_CALL UNLIMITED 
    LOGICAL_READS_PER_SESSION UNLIMITED 
    LOGICAL_READS_PER_CALL UNLIMITED 
    IDLE_TIME UNLIMITED 
    CONNECT_TIME UNLIMITED 
    PRIVATE_SGA UNLIMITED 
    FAILED_LOGIN_ATTEMPTS UNLIMITED 
    PASSWORD_LIFE_TIME UNLIMITED 
    PASSWORD_REUSE_TIME UNLIMITED 
    PASSWORD_REUSE_MAX UNLIMITED 
    PASSWORD_VERIFY_FUNCTION NULL 
    PASSWORD_LOCK_TIME UNLIMITED 
    PASSWORD_GRACE_TIME UNLIMITED 
    INACTIVE_ACCOUNT_TIME DEFAULT 
    PASSWORD_ROLLOVER_TIME DEFAULT ;

