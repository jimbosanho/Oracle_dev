DECLARE
   CURSOR C IS
      SELECT   FEFV.USER_EXECUTABLE_NAME,
               FEFV.EXECUTABLE_NAME,
               FEFV.APPLICATION_NAME,
               FEFV.DESCRIPTION,
               FEFV.EXECUTION_METHOD_CODE,
               FEFV.EXECUTION_FILE_NAME,
               FEFV.SUBROUTINE_NAME,
               FEFV.EXECUTION_FILE_PATH,
               FEFV.APPLICATION_ID,
               FEFV.EXECUTABLE_ID,
               FEFV.LAST_UPDATE_DATE,
               FEFV.LAST_UPDATED_BY,
               FEFV.LAST_UPDATE_LOGIN,
               FEFV.CREATION_DATE,
               FEFV.CREATED_BY,
               FEFV.ROW_ID,
               FA.APPLICATION_SHORT_NAME
      FROM     FND_EXECUTABLES_FORM_V FEFV,
               FND_CONCURRENT_PROGRAMS_VL FCPV,
               FND_APPLICATION FA
      WHERE    1 = 1
      AND      FEFV.EXECUTABLE_ID > 4
      AND      FEFV.APPLICATION_ID = FA.APPLICATION_ID
      AND      FA.APPLICATION_SHORT_NAME = 'FS'
--      AND      FEFV.EXECUTABLE_NAME = 'ERPFS01010'
      AND      FEFV.EXECUTABLE_ID = FCPV.EXECUTABLE_ID
      AND      EXISTS
                  (SELECT 1
                   FROM   ERP_SYS_PROGRAM_LOG_V
                   WHERE  1 = 1
                   AND    TRUNC( ACTUAL_START_DATE ) >= TRUNC( SYSDATE ) - 547 --365+365/2 = 1.5
                   AND    STATUS_CODE IN ('C', 'R')
                   AND    USER_CONCURRENT_PROGRAM_NAME =
                             FCPV.USER_CONCURRENT_PROGRAM_NAME)   --檢查1.5年內是否有使用
      ORDER BY FEFV.APPLICATION_NAME,
               FEFV.EXECUTABLE_NAME;
BEGIN
   FOR V IN C LOOP
      FND_GLOBAL.SET_NLS_CONTEXT( 'AMERICAN' );
      DBMS_OUTPUT.PUT_LINE( ' DECLARE ' );
      DBMS_OUTPUT.PUT_LINE( ' V_APPLICATION_ID     NUMBER; ' );
      DBMS_OUTPUT.PUT_LINE( ' V_ROWID              NUMBER; ' );
      DBMS_OUTPUT.PUT_LINE( ' V_EXECUTABLE_ID      NUMBER; ' );
      DBMS_OUTPUT.PUT_LINE( ' V_EXIST_FLAG         VARCHAR2( 1 ); ' );
      DBMS_OUTPUT.PUT_LINE( ' V_FLAG               VARCHAR2( 1 ); ' );
      DBMS_OUTPUT.PUT_LINE( ' BEGIN ' );
      DBMS_OUTPUT.PUT_LINE( ' BEGIN ' );
      DBMS_OUTPUT.PUT_LINE( ' SELECT APPLICATION_ID ' );
      DBMS_OUTPUT.PUT_LINE( ' INTO   V_APPLICATION_ID ' );
      DBMS_OUTPUT.PUT_LINE( ' FROM   FND_APPLICATION ' );
      DBMS_OUTPUT.PUT_LINE(
                            ' WHERE  APPLICATION_SHORT_NAME = ' ||
                            '''' ||
                            V.APPLICATION_SHORT_NAME ||
                            '''' ||
                            '; '
      );
      DBMS_OUTPUT.PUT_LINE( ' EXCEPTION ' );
      DBMS_OUTPUT.PUT_LINE( ' WHEN OTHERS THEN ' );
      DBMS_OUTPUT.PUT_LINE( ' V_FLAG   := ''N''; ' );
      DBMS_OUTPUT.PUT_LINE( ' END; ' );
      DBMS_OUTPUT.PUT_LINE( '  ' );
      DBMS_OUTPUT.PUT_LINE( ' BEGIN ' );
      DBMS_OUTPUT.PUT_LINE( ' SELECT ''Y'',EXECUTABLE_ID ' );
      DBMS_OUTPUT.PUT_LINE( ' INTO   V_EXIST_FLAG,V_EXECUTABLE_ID ' );
      DBMS_OUTPUT.PUT_LINE( ' FROM   FND_EXECUTABLES ' );
      DBMS_OUTPUT.PUT_LINE( ' WHERE  EXECUTABLE_NAME = V.EXECUTABLE_NAME ' );
      DBMS_OUTPUT.PUT_LINE( ' AND    APPLICATION_ID = V_APPLICATION_ID; ' );
      DBMS_OUTPUT.PUT_LINE( ' EXCEPTION ' );
      DBMS_OUTPUT.PUT_LINE( ' WHEN OTHERS THEN ' );
      DBMS_OUTPUT.PUT_LINE( ' V_EXIST_FLAG   := ''N''; ' );
      DBMS_OUTPUT.PUT_LINE( ' END; ' );
      DBMS_OUTPUT.PUT_LINE( '  ' );
      DBMS_OUTPUT.PUT_LINE( ' IF V_FLAG <> ''N'' then ' );
      DBMS_OUTPUT.PUT_LINE( ' IF V_EXIST_FLAG = ''N'' THEN ' );
      DBMS_OUTPUT.PUT_LINE( ' BEGIN ' );
      DBMS_OUTPUT.PUT_LINE( ' SELECT FND_EXECUTABLES_S ' );
      DBMS_OUTPUT.PUT_LINE( ' INTO   V_EXECUTABLE_ID ' );
      DBMS_OUTPUT.PUT_LINE( ' FROM   DUAL ' );
      DBMS_OUTPUT.PUT_LINE( ' WHERE  1 = 1; ' );
      DBMS_OUTPUT.PUT_LINE( ' END; ' );
      DBMS_OUTPUT.PUT_LINE( '  ' );
      DBMS_OUTPUT.PUT_LINE( ' FND_EXECUTABLES_PKG.INSERT_ROW( ' );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_ROWID                 => V_ROWID, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_APPLICATION_ID        => V_APPLICAITON_ID, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_EXECUTABLE_ID         => V_EXECUTABLE_ID, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_EXECUTABLE_NAME       => ' ||
                            '''' ||
                            V.EXECUTABLE_NAME ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_EXECUTION_METHOD_CODE => ' ||
                            '''' ||
                            V.EXECUTION_METHOD_CODE ||
                            '''' || --                            NVL( V.EXECUTION_METHOD_CODE, '''''' )||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_EXECUTION_FILE_NAME   => ' ||
                            '''' ||
                            V.EXECUTION_FILE_NAME ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_SUBROUTINE_NAME       => ' ||
                            '''' ||
                            V.SUBROUTINE_NAME ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_EXECUTION_FILE_PATH   => ' ||
                            '''' ||
                            V.EXECUTION_FILE_PATH ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_USER_EXECUTABLE_NAME  => ' ||
                            '''' ||
                            V.USER_EXECUTABLE_NAME ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_DESCRIPTION           => ' ||
                            '''' ||
                            V.DESCRIPTION ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_CREATION_DATE         => SYSDATE, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_CREATED_BY            => -1, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_LAST_UPDATE_DATE      => SYSDATE, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_LAST_UPDATED_BY       => -1, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_LAST_UPDATE_LOGIN     => -1 '
      );
      DBMS_OUTPUT.PUT_LINE( ' ); ' );

      DBMS_OUTPUT.PUT_LINE( ' ELSIF V_EXIST_FLAG = ''Y'' THEN ' );
      DBMS_OUTPUT.PUT_LINE( ' FND_EXECUTABLES_PKG.UPDATE_ROW( ' );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_APPLICATION_ID        => V_APPLICATION_ID, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_EXECUTABLE_ID         => V_EXECUTABLE_ID, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_EXECUTABLE_NAME       => ' ||
                            '''' ||
                            V.EXECUTABLE_NAME ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_EXECUTION_METHOD_CODE => ' ||
                            '''' ||
                            V.EXECUTION_METHOD_CODE ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_EXECUTION_FILE_NAME   => ' ||
                            '''' ||
                            V.EXECUTION_FILE_NAME ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_SUBROUTINE_NAME       => ' ||
                            '''' ||
                            V.SUBROUTINE_NAME ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_EXECUTION_FILE_PATH   => ' ||
                            '''' ||
                            V.EXECUTION_FILE_PATH ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_USER_EXECUTABLE_NAME  => ' ||
                            '''' ||
                            V.USER_EXECUTABLE_NAME ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_DESCRIPTION           => ' ||
                            '''' ||
                            V.DESCRIPTION ||
                            '''' ||
                            ', '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_LAST_UPDATE_DATE      => SYSDATE, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_LAST_UPDATED_BY       => -1, '
      );
      DBMS_OUTPUT.PUT_LINE(
                            '                                             X_LAST_UPDATE_LOGIN     => -1 '
      );
      DBMS_OUTPUT.PUT_LINE( ' ); ' );



      DBMS_OUTPUT.PUT_LINE( ' END IF; ' );
      DBMS_OUTPUT.PUT_LINE( ' END IF; ' );
      DBMS_OUTPUT.PUT_LINE( ' END; ' );
      DBMS_OUTPUT.PUT_LINE( ' commit; ' );
   END LOOP;
END;