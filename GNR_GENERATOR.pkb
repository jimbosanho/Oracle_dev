CREATE OR REPLACE PACKAGE BODY APPS.GNR_GENERATOR IS
   G_OWNER VARCHAR2(30) := 'GNRMAN';

   ---------------------------------------------------------------------------------------------------
   FUNCTION IS_TABLE_EXIST(P_TABLE_NAME VARCHAR2)
      RETURN BOOLEAN IS
      V_COUNT NUMBER := 0;
   BEGIN
      V_COUNT                    := 0;

      BEGIN
         SELECT COUNT(1)
         INTO   V_COUNT
         FROM   ALL_OBJECTS
         WHERE  1 = 1
         AND    OWNER = G_OWNER
         AND    OBJECT_TYPE = 'TABLE'
         AND    OBJECT_NAME = P_TABLE_NAME;
      EXCEPTION
         WHEN OTHERS THEN
            V_COUNT                    := 0;
      END;

      IF V_COUNT > 0 THEN
         RETURN TRUE;
      ELSE
         RETURN FALSE;
      END IF;
   END IS_TABLE_EXIST;

   ---------------------------------------------------------------------------------------------------
   PROCEDURE CLEAR_TABLE_DATA(P_TABLE_NAME VARCHAR2) IS
   BEGIN
      EXECUTE IMMEDIATE 'DELETE ' || P_TABLE_NAME;
   END CLEAR_TABLE_DATA;

   ---------------------------------------------------------------------------------------------------
   FUNCTION GET_NEW_TABLE_NAME(P_TABLE_NAME VARCHAR2)
      RETURN VARCHAR2 IS
      V_TABLE_NAME VARCHAR2(30);
   BEGIN
      SELECT NEW_TABLE_NAME
      INTO   V_TABLE_NAME
      FROM   GNR_TABLE_REFERENCE
      WHERE  1 = 1
      AND    OLD_TABLE_NAME = P_TABLE_NAME
      AND    OBJECT_TYPE = 'TABLE';

      RETURN V_TABLE_NAME;
   END GET_NEW_TABLE_NAME;

   ---------------------------------------------------------------------------------------------------
   PROCEDURE DELETE_TABLE_DATA IS
   BEGIN
      DELETE ERP_GNR_NOTE_ALL N
      WHERE  1 = 1
      AND    (NOT EXISTS
                 (SELECT 1
                  FROM   ERP_GNR_MASTER_ALL M
                  WHERE  1 = 1
                  AND    M.GNR_TR_ID = N.GNR_TR_ID
                  AND    STATUS IN ('3', '4', '6', '7'))
      OR      STATUS NOT IN ('3', '4', '6', '7'));

      DELETE ERP_GNR_MASTER_ALL
      WHERE  1 = 1
      AND    STATUS NOT IN ('3', '4', '6', '7');
   END DELETE_TABLE_DATA;

   ---------------------------------------------------------------------------------------------------
   PROCEDURE RESULT_CHECK(P_TABLE_NAME VARCHAR2) IS
      V_COUNT NUMBER := 0;
      V_COUNT1 NUMBER := 0;
      V_NEW_TABLE_NAME VARCHAR2(30);
   BEGIN
      V_NEW_TABLE_NAME           := NULL;

      EXECUTE IMMEDIATE 'SELECT COUNT(1)
      FROM   TCCGNR.' || P_TABLE_NAME || '@R12TOR11' || ' WHERE  1 = 1' INTO V_COUNT;

      V_NEW_TABLE_NAME           := GET_NEW_TABLE_NAME(P_TABLE_NAME);

      --      DBMS_OUTPUT.PUT_LINE(V_NEW_TABLE_NAME);

      IF V_NEW_TABLE_NAME IS NOT NULL THEN
         EXECUTE IMMEDIATE 'SELECT COUNT(1)
      FROM   GNRMAN.' || V_NEW_TABLE_NAME || ' WHERE  1 = 1' INTO V_COUNT1;
      ELSE
         DBMS_OUTPUT.PUT_LINE(P_TABLE_NAME || '---不存在');
         V_COUNT1                   := 0;
      END IF;

      DBMS_OUTPUT.PUT_LINE(
            RPAD(P_TABLE_NAME, 30, '_')
         || ' - '
         || LPAD(V_COUNT, 10, ' ')
         || ' - '
         || LPAD(V_COUNT1, 10, ' ')
         || '---'
         || RPAD(V_NEW_TABLE_NAME, 30, '_')
      );
      V_COUNT                    := 0;
      V_COUNT1                   := 0;
   END RESULT_CHECK;

   ---------------------------------------------------------------------------------------------------
   PROCEDURE UPDATE_TABLE_DATA IS
      CURSOR C IS
         SELECT ATC.*
         FROM   ALL_TABLES AT,
                ALL_TAB_COLUMNS ATC
         WHERE  1 = 1
         AND    AT.OWNER = 'GNRMAN'
         AND    AT.TABLE_NAME = ATC.TABLE_NAME
         AND    AT.TABLE_NAME = 'ERP_GNR_USER_DEPT_ALL'
         AND    ATC.COLUMN_NAME IN ('ORG_ID', 'SET_OF_BOOKS_ID', 'USER_ID', 'DEPT_CODE');

      V_STRING VARCHAR2(32767);
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
            V_STRING                   := V_STRING || '(SELECT O_NEW.SET_OF_BOOKS_ID ';
            V_STRING                   := V_STRING || 'FROM   ORG_ORGANIZATION_DEFINITIONS O_NEW, ';
            V_STRING                   := V_STRING || 'ORG_ORGANIZATION_DEFINITIONS@R12TOR11 O_OLD ';
            V_STRING                   := V_STRING || 'WHERE  1 = 1 ';
            V_STRING                   := V_STRING || 'AND    O_NEW.ORGANIZATION_CODE = O_OLD.ORGANIZATION_CODE ';
            V_STRING                   :=
               V_STRING || 'AND    O_OLD.ORGANIZATION_CODE IN (''TWM'', ''TFN'', ''TDS'', ''TAG'') ';
            V_STRING                   := V_STRING || 'AND    O_OLD.SET_OF_BOOKS_ID = A.SET_OF_BOOKS_ID) ';
            V_STRING                   := V_STRING || 'WHERE  A.SET_OF_BOOKS_ID IN (1, 24, 25, 55) ';
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

--         DBMS_OUTPUT.PUT_LINE(V_STRING);

         EXECUTE IMMEDIATE V_STRING;
      END LOOP;
   END UPDATE_TABLE_DATA;

   ---------------------------------------------------------------------------------------------------
   PROCEDURE RUN IS
      CURSOR C(
         C_OWNER                 VARCHAR2,
         C_OBJECT_TYPE           VARCHAR2
      ) IS
         SELECT *
         FROM   ALL_OBJECTS@R12TOR11
         WHERE  1 = 1
         --         AND    OBJECT_NAME = 'TCC_GNR_INTERFACE_ALL'
         AND    OWNER = C_OWNER
         AND    OBJECT_TYPE = C_OBJECT_TYPE;

      CURSOR C_COLUMN(C_TABLE_NAME VARCHAR2) IS
         SELECT   *
         FROM     ALL_TAB_COLUMNS@R12TOR11
         WHERE    1 = 1
         AND      TABLE_NAME = C_TABLE_NAME
         ORDER BY COLUMN_ID;

      V_OWNER VARCHAR2(30) := 'TCCGNR';
      V_OBJECT_TYPE VARCHAR2(30) := 'TABLE';
      V_NEW_OBJECT_NAME VARCHAR2(30);
      V_NEW_OWNER VARCHAR2(30) := 'GNRMAN';
      V_STRING VARCHAR2(32767);
      V_COLUMN VARCHAR2(32767);
   BEGIN
      FOR V IN C(C_OWNER => V_OWNER, C_OBJECT_TYPE => V_OBJECT_TYPE) LOOP
         V_STRING                   := NULL;
         V_COLUMN                   := NULL;
         V_NEW_OBJECT_NAME          := GET_NEW_TABLE_NAME(P_TABLE_NAME => V.OBJECT_NAME);

         IF IS_TABLE_EXIST(P_TABLE_NAME => V_NEW_OBJECT_NAME) THEN
            CLEAR_TABLE_DATA(P_TABLE_NAME => V_NEW_OBJECT_NAME);

            FOR V_C IN C_COLUMN(V.OBJECT_NAME) LOOP
               IF V_COLUMN IS NULL THEN
                  V_COLUMN                   := V_C.COLUMN_NAME;
               ELSE
                  V_COLUMN                   := V_COLUMN || ',' || V_C.COLUMN_NAME;
               END IF;
            END LOOP;

            V_STRING                   :=
                  'INSERT INTO '
               || 'GNRMAN.'
               || V_NEW_OBJECT_NAME
               || '('
               || V_COLUMN
               || ')'
               || 'SELECT * FROM '
               || V.OWNER
               || '.'
               || V.OBJECT_NAME
               || '@R12TOR11';

            EXECUTE IMMEDIATE V_STRING;
         --            DBMS_OUTPUT.PUT_LINE(V_STRING);
         ELSE
            DBMS_OUTPUT.PUT_LINE(V.OBJECT_NAME || ' - 不存在，請先建立該物件');
         END IF;
      END LOOP;

      DELETE_TABLE_DATA;

      IF G_RESULT_CHECK_FLAG = 'Y' THEN
         FOR V_R IN C(C_OWNER => V_OWNER, C_OBJECT_TYPE => V_OBJECT_TYPE) LOOP
            RESULT_CHECK(V_R.OBJECT_NAME);
         END LOOP;
      END IF;

      UPDATE_TABLE_DATA;
   END RUN;

   ---------------------------------------------------------------------------------------------------
   PROCEDURE RUN_SEQ IS
      CURSOR C IS
         SELECT B.*
         FROM   ALL_SEQUENCES A,
                GNR_TABLE_REFERENCE B
         WHERE  A.SEQUENCE_NAME LIKE 'ERP_GNR%'
         --      AND    A.SEQUENCE_NAME = 'ERP_GNR_BANK_RATING_ALL_S'
         AND    A.SEQUENCE_NAME = B.NEW_TABLE_NAME(+)
         AND    B.OBJECT_TYPE(+) = 'SEQUENCE';

      V_CUR NUMBER := 0;
      V_CUR_NEW NUMBER := 0;
      V_ALTER_STRING VARCHAR2(32767);
      V_SELECT_STRING VARCHAR2(32767);
      V_DIFF NUMBER := 0;
      V_RETURN_STRING VARCHAR2(32767);
      V_VAL NUMBER := 0;
   BEGIN
      FOR V IN C LOOP
         EXECUTE IMMEDIATE
               'select last_number '
            || 'from all_sequences@R12TOR11 '
            || 'where 1=1 '
            || 'and sequence_name = '
            || ''''
            || V.OLD_TABLE_NAME
            || ''''
            INTO V_CUR;

         EXECUTE IMMEDIATE
               'select last_number '
            || 'from all_sequences '
            || 'where 1=1 '
            || 'and sequence_name = '
            || ''''
            || V.NEW_TABLE_NAME
            || ''''
            INTO V_CUR_NEW;

         --      DBMS_OUTPUT.PUT_LINE(V.NEW_TABLE_NAME || '-' || V_CUR_NEW || '-' || V_CUR || '-' || V.OLD_TABLE_NAME);

         IF V_CUR_NEW <> V_CUR THEN
            V_DIFF                     := V_CUR - V_CUR_NEW;
            V_ALTER_STRING             :=
               'alter sequence ' || V.NEW_TABLE_NAME || ' increment by ' || V_DIFF || ' minvalue 0';
            V_SELECT_STRING            := 'select ' || V.NEW_TABLE_NAME || '.nextval from dual';
            V_RETURN_STRING            := 'alter sequence ' || V.NEW_TABLE_NAME || ' increment by 1 minvalue 1';

            --         DBMS_OUTPUT.PUT_LINE(V_ALTER_STRING);
            --         DBMS_OUTPUT.PUT_LINE(V_SELECT_STRING);
            --         DBMS_OUTPUT.PUT_LINE(V_RETURN_STRING);
            EXECUTE IMMEDIATE V_ALTER_STRING;

            EXECUTE IMMEDIATE V_SELECT_STRING INTO V_VAL;

            EXECUTE IMMEDIATE V_RETURN_STRING;
         END IF;

         EXECUTE IMMEDIATE
               'select last_number '
            || 'from all_sequences '
            || 'where 1=1 '
            || 'and sequence_name = '
            || ''''
            || V.NEW_TABLE_NAME
            || ''''
            INTO V_CUR_NEW;

         IF G_RESULT_CHECK_FLAG = 'Y' THEN
            DBMS_OUTPUT.PUT_LINE(
               '--' || V.NEW_TABLE_NAME || '-' || V_CUR_NEW || '-' || V_CUR || '-' || V.OLD_TABLE_NAME
            );
         END IF;

         V_CUR_NEW                  := 0;
         V_CUR                      := 0;
         V_DIFF                     := 0;
         V_VAL                      := 0;
         V_ALTER_STRING             := NULL;
         V_SELECT_STRING            := NULL;
         V_RETURN_STRING            := NULL;
      END LOOP;
   END RUN_SEQ;
---------------------------------------------------------------------------------------------------
END GNR_GENERATOR;
/