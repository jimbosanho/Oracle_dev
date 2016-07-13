DECLARE
   CURSOR C IS
      SELECT ATC.*
      FROM   ALL_TABLES AT,
             ALL_TAB_COLUMNS ATC
      WHERE  1 = 1
      AND    AT.OWNER = 'GNRMAN'
      AND    AT.TABLE_NAME = ATC.TABLE_NAME
--      AND    AT.TABLE_NAME = 'ERP_GNR_USER_DEPT_ALL'
      AND    ATC.COLUMN_NAME IN ('ORG_ID', 'SET_OF_BOOKS_ID', 'USER_ID', 'DEPT_CODE');

   V_STRING VARCHAR2(32767);
--   V_OPERATING_UNIT ORG_ORGANIZATION_DEFINITIONS.OPERATING_UNIT%TYPE;
--   V_SET_OF_BOOKS_ID ORG_ORGANIZATION_DEFINITIONS.SET_OF_BOOKS_ID%TYPE;
BEGIN
   FOR V IN C LOOP
      V_STRING                   := NULL;

      IF V.COLUMN_NAME = 'ORG_ID' THEN
         V_STRING                   := 'UPDATE ' || V.TABLE_NAME || ' A ';
         V_STRING                   := V_STRING || 'SET    A.ORG_ID                    = ';
         V_STRING                   := V_STRING || '(SELECT O_NEW.OPERATING_UNIT ';
         V_STRING                   := V_STRING || 'FROM   ORG_ORGANIZATION_DEFINITIONS O_NEW, ';
         V_STRING                   := V_STRING || 'ORG_ORGANIZATION_DEFINITIONS@R12TOR11 O_OLD ';
         V_STRING                   := V_STRING || 'WHERE  1 = 1 ';
         V_STRING                   := V_STRING || 'AND    O_NEW.ORGANIZATION_CODE = O_OLD.ORGANIZATION_CODE ';
         V_STRING                   :=
            V_STRING || 'AND    O_OLD.ORGANIZATION_CODE IN (''TWM'', ''TFN'', ''TDS'', ''TAG'') ';
         V_STRING                   := V_STRING || 'AND    O_OLD.OPERATING_UNIT = A.ORG_ID) ';
         V_STRING                   := V_STRING || 'WHERE  A.ORG_ID IN (102, 1085, 2397, 1025) ';
      ELSIF V.COLUMN_NAME = 'SET_OF_BOOKS_ID' THEN
         V_STRING                   := 'UPDATE ' || V.TABLE_NAME || ' A ';
         V_STRING                   := V_STRING || 'SET    A.SET_OF_BOOKS_ID           = ';
         V_STRING                   := V_STRING || '(SELECT O_NEW_SET_OF_BOOKS_ID ';
         V_STRING                   := V_STRING || 'FROM   ORG_ORGANIZATION_DEFINITIONS O_NEW, ';
         V_STRING                   := V_STRING || 'ORG_ORGANIZATION_DEFINITIONS@R12TOR11 O_OLD ';
         V_STRING                   := V_STRING || 'WHERE  1 = 1 ';
         V_STRING                   := V_STRING || 'AND    O_NEW.ORGANIZATINO_CODE = O_OLD.ORGANIZATION_CODE ';
         V_STRING                   :=
            V_STRING || 'AND    O_OLD.ORGANIZATION_CODE IN (''TWM'', ''TFN'', ''TDS'', ''TAG'') ';
         V_STRING                   := V_STRING || 'AND    O_OLD.SET_OF_BOOKS_ID = A.SET_OF_BOOKS_ID) ';
         V_STRING                   := V_STRING || 'WHERE  A.SET_OF_BOOK_ID IN (1, 24, 25, 55) ';
      ELSIF V.COLUMN_NAME = 'USER_ID' THEN
         V_STRING                   := ' UPDATE ' || V.TABLE_NAME || ' A ';
         V_STRING                   := V_STRING || 'SET    USER_ID                     = ';
         V_STRING                   := V_STRING || '(SELECT P_NEW.PERSON_ID ';
         V_STRING                   := V_STRING || 'FROM   APPS.PER_ALL_PEOPLE_F P_NEW, ';
         V_STRING                   := V_STRING || 'APPS.PER_ALL_PEOPLE_F@R12TOR11 P_OLD ';
         V_STRING                   := V_STRING || 'WHERE  P_NEW.EMPLOYEE_NUMBER = P_OLD.EMPLOYEE_NUMBER ';
         V_STRING                   := V_STRING || 'AND    P_OLD.PERSON_ID = A.USER_ID) ';
         V_STRING                   := V_STRING || 'WHERE  1 = 1 ';
      ELSIF V.COLUMN_NAME = 'DEPT_CODE' THEN
         V_STRING                   := ' UPDATE ' || V.TABLE_NAME || ' A ';
         V_STRING                   := V_STRING || 'SET    DEPT_CODE                   = ';
         V_STRING                   := V_STRING || '(SELECT NEW_SEGMENT ';
         V_STRING                   := V_STRING || 'FROM   ERP_GL_R12_SEGMENT2_MAP ';
         V_STRING                   := V_STRING || 'WHERE  1 = 1 ';
         V_STRING                   := V_STRING || 'AND    ORG_ID IN (SELECT OPERATING_UNIT ';
         V_STRING                   := V_STRING || 'FROM   ORG_ORGANIZATION_DEFINITIONS ';
         V_STRING                   := V_STRING || 'WHERE  ORGANIZATION_CODE IN (''TWM'', ''TFN'')) ';
         V_STRING                   := V_STRING || 'AND    OLD_SEGMENT = A.DEPT_CODE) ';
      END IF;

      DBMS_OUTPUT.PUT_LINE(V_STRING);
   END LOOP;
END;

--SELECT O_OLD.ORGANIZATION_ID,
--       O_OLD.SET_OF_BOOKS_ID,
--       O_OLD.ORGANIZATION_CODE,
--       O_NEW.ORGANIZATION_ID,
--       O_NEW.SET_OF_BOOKS_ID
--FROM   ORG_ORGANIZATION_DEFINITIONS O_NEW,
--       ORG_ORGANIZATION_DEFINITIONS@R12TOR11 O_OLD
--WHERE  1 = 1
--AND    O_OLD.ORGANIZATION_ID IN (102, 1085, 2397, 1025)
--AND    O_OLD.ORGANIZATION_CODE = O_NEW.ORGANIZATION_CODE
--SELECT O_OLD.ORGANIZATION_ID,
--       O_OLD.SET_OF_BOOKS_ID,
--       O_OLD.OPERATING_UNIT,
--       O_OLD.ORGANIZATION_CODE,
--       O_NEW.ORGANIZATION_ID,
--       O_NEW.SET_OF_BOOKS_ID,
--       O_NEW.OPERATING_UNIT
--FROM   ORG_ORGANIZATION_DEFINITIONS@R12TOR11 O_OLD,
--       ORG_ORGANIZATION_DEFINITIONS O_NEW
--WHERE  1 = 1
--AND    O_OLD.OPERATING_UNIT IN (102, 1085, 2397, 1025)
--AND    O_OLD.ORGANIZATION_CODE IN ('TWM', 'TFN', 'TDS', 'TAG')
--AND    O_OLD.ORGANIZATION_CODE = O_NEW.ORGANIZATION_CODE

--SELECT *
--FROM   ERP_GL_R12_SEGMENT2_MAP
--WHERE  ORG_ID IN (SELECT OPERATING_UNIT
--                  FROM   ORG_ORGANIZATION_DEFINITIONS
--                  WHERE  1 = 1
--                  AND    ORGANIZATION_CODE IN ('TWM', 'TFN'))