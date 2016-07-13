SELECT table_name
FROM   DBA_TAB_PRIVS TP
WHERE  EXISTS
          (SELECT 1
           FROM   ALL_OBJECTS
           WHERE  1 = 1
           AND    OBJECT_NAME = TP.TABLE_NAME
           --           AND    OBJECT_NAME = 'ERP_FS_05221_T'
           AND    OWNER = 'FSMAN'
           AND    OBJECT_TYPE = 'TABLE')
AND    GRANTEE IN ('APFS', 'APOPS', 'FSMAN_ALL_ROLE')
GROUP BY TABLE_NAME;
           
select *
from ROLE_TAB_PRIVS       

DBA_TAB_PRIVS DBA_SYS_PRIVS DBA_ROLE_PRIVS    