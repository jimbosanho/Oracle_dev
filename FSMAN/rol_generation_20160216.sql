DECLARE
   CURSOR C IS
      SELECT *
      FROM   ALL_OBJECTS
      WHERE  1 = 1
      AND    OBJECT_TYPE IN ('TABLE', 'SEQUENCE')
      AND    OWNER = 'FSMAN';

   CURSOR C_A IS
      SELECT *
      FROM   ALL_OBJECTS
      WHERE  1 = 1
      AND    OBJECT_TYPE IN ('VIEW', 'PAKCAGE')
      AND    OWNER = 'APPS'
      AND    ( OBJECT_NAME LIKE 'ERP_FS%'
      OR      OBJECT_NAME LIKE 'ERPFS%'
      OR      OBJECT_NAME LIKE 'HP%'
      OR      OBJECT_NAME LIKE 'FS%'
      OR      OBJECT_NAME = 'MSI_VW_FS_INFO_V'
      OR      OBJECT_NAME = 'VW_TRUS_RP_INCOME_INFO_FS'
      OR      OBJECT_NAME = 'WP_VW_POS_SALES_FS'
      OR      OBJECT_NAME = 'MSI_VW_BUS_PERIOD_V'
      OR      OBJECT_NAME = 'ERP_ERPFS03008_V' );
BEGIN
   FOR V IN C LOOP
      IF V.OBJECT_TYPE = 'SEQUENCE' THEN
         DBMS_OUTPUT.PUT_LINE(
                               'GRANT SELECT ON FSMAN.' ||
                               V.OBJECT_NAME ||
                               ' TO APPS WITH GRANT OPTION;'
         );
         DBMS_OUTPUT.PUT_LINE(
                               'GRANT SELECT ON FSMAN.' ||
                               V.OBJECT_NAME ||
                               ' TO APFS;'
         );
         DBMS_OUTPUT.PUT_LINE(
                               'GRANT SELECT ON FSMAN.' ||
                               V.OBJECT_NAME ||
                               ' TO RL_FSMAN_ALL;'
         );
      ELSE
         DBMS_OUTPUT.PUT_LINE(
                               'GRANT SELECT ON FSMAN.' ||
                               V.OBJECT_NAME ||
                               ' TO APPS WITH GRANT OPTION;'
         );
         DBMS_OUTPUT.PUT_LINE(
                               'GRANT SELECT,INSERT,DELETE,UPDATE ON FSMAN.' ||
                               V.OBJECT_NAME ||
                               ' TO APFS;'
         );
         DBMS_OUTPUT.PUT_LINE(
                               'GRANT SELECT,INSERT,DELETE,UPDATE ON FSMAN.' ||
                               V.OBJECT_NAME ||
                               ' TO RL_FSMAN_ALL;'
         );
      END IF;
   END LOOP;

   FOR V_A IN C_A LOOP
      IF V_A.OBJECT_TYPE = 'VIEW' THEN
         DBMS_OUTPUT.PUT_LINE(
                               'GRANT SELECT ON APPS.' ||
                               V_A.OBJECT_NAME ||
                               ' TO APFS;'
         );
         DBMS_OUTPUT.PUT_LINE(
                               'GRANT SELECT ON APPS.' ||
                               V_A.OBJECT_NAME ||
                               ' TO RL_FSMAN_ALL;'
         );
      ELSIF V_A.OBJECT_TYPE = 'PACKAGE' THEN
         DBMS_OUTPUT.PUT_LINE(
                               'GRANT EXECUTE ON APPS.' ||
                               V_A.OBJECT_NAME ||
                               ' TO APPS;'
         );
         DBMS_OUTPUT.PUT_LINE(
                               'GRANT EXECUTE ON APPS.' ||
                               V_A.OBJECT_NAME ||
                               ' TO RL_FSMAN_ALL;'
         );
      END IF;
   END LOOP;
END;