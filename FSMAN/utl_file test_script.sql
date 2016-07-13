DECLARE
   IN_FILE           UTL_FILE.FILE_TYPE;
   MAXLINESIZE       NUMBER := 32767;
   PO_ERR_CODE       VARCHAR2( 30 );
   PO_ERR_MSG        VARCHAR2( 2000 );
   PO_CHECK_FLAG     VARCHAR2( 1 );
   V_FILE_NAME       VARCHAR2( 30 ) := 'RECYCLE_WEBFS_20160316.csv';
   V_TEMP_STR        VARCHAR2( 2000 );
BEGIN
   IN_FILE   := UTL_FILE.FOPEN( 'FS_TWM_BC', V_FILE_NAME, 'R', MAXLINESIZE );

   FOR V_LOOP IN 1 .. 6 LOOP
      BEGIN
         UTL_FILE.GET_LINE( FILE => IN_FILE, BUFFER => V_TEMP_STR );
      EXCEPTION
         WHEN OTHERS THEN
            V_TEMP_STR   := NULL;
      END;

      DBMS_OUTPUT.PUT_LINE( V_TEMP_STR );
   END LOOP;

   UTL_FILE.FCLOSE( IN_FILE );
EXCEPTION
   WHEN UTL_FILE.INVALID_PATH THEN
      UTL_FILE.FCLOSE( IN_FILE );
      PO_ERR_CODE     := '99';
      PO_ERR_MSG      := '傳檔路徑錯誤! ' || SQLERRM;
      FND_FILE.PUT_LINE( FND_FILE.LOG, PO_ERR_MSG );
      PO_CHECK_FLAG   := 'N';
      DBMS_OUTPUT.PUT_LINE( PO_ERR_MSG );
      RETURN;                                               --RAISE V_EXCEPTION;
   WHEN UTL_FILE.READ_ERROR THEN
      UTL_FILE.FCLOSE( IN_FILE );
      PO_ERR_CODE     := '99';
      PO_ERR_MSG      := '讀檔失敗! ' || SQLERRM;
      FND_FILE.PUT_LINE( FND_FILE.LOG, PO_ERR_MSG );
      PO_CHECK_FLAG   := 'N';
      DBMS_OUTPUT.PUT_LINE( PO_ERR_MSG );
      RETURN;                                               --RAISE V_EXCEPTION;
   WHEN UTL_FILE.FILE_OPEN THEN
      UTL_FILE.FCLOSE( IN_FILE );
      PO_ERR_CODE     := '99';
      PO_ERR_MSG      := '檔案已開啟! ' || SQLERRM;
      FND_FILE.PUT_LINE( FND_FILE.LOG, PO_ERR_MSG );
      PO_CHECK_FLAG   := 'N';
      DBMS_OUTPUT.PUT_LINE( PO_ERR_MSG );
      RETURN;                                               --RAISE V_EXCEPTION;
   WHEN UTL_FILE.INVALID_FILENAME THEN
      UTL_FILE.FCLOSE( IN_FILE );
      PO_ERR_CODE     := '99';
      PO_ERR_MSG      := 'FILENAME參數無效! ' || SQLERRM;
      FND_FILE.PUT_LINE( FND_FILE.LOG, PO_ERR_MSG );
      PO_CHECK_FLAG   := 'N';
      DBMS_OUTPUT.PUT_LINE( PO_ERR_MSG );
      RETURN;                                               --RAISE V_EXCEPTION;
   WHEN UTL_FILE.INVALID_OPERATION THEN
      UTL_FILE.FCLOSE( IN_FILE );
      PO_ERR_CODE     := '99';
      PO_ERR_MSG      := V_FILE_NAME || ' 檔名錯誤! 無此檔名! ';
      FND_FILE.PUT_LINE( FND_FILE.LOG, PO_ERR_MSG );
      PO_CHECK_FLAG   := 'N';
      DBMS_OUTPUT.PUT_LINE( PO_ERR_MSG );
      RETURN;
   WHEN OTHERS THEN
      UTL_FILE.FCLOSE( IN_FILE );
      PO_ERR_CODE     := '99';
      PO_ERR_MSG      := '開檔失敗! ' || SQLERRM;
      FND_FILE.PUT_LINE( FND_FILE.LOG, PO_ERR_MSG );
      PO_CHECK_FLAG   := 'N';
      DBMS_OUTPUT.PUT_LINE( PO_ERR_MSG );
      RETURN;                                               --RAISE V_EXCEPTION;
END CHECK_FILE;