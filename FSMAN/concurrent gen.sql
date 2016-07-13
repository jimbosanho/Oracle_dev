declare
   cursor C is
      select FEFV.USER_EXECUTABLE_NAME EXECUTABLE_NAME,
             FRG.REQUEST_GROUP_NAME,
             FA.APPLICATION_SHORT_NAME
      from   FND_REQUEST_GROUPS FRG,
             FND_REQUEST_GROUP_UNITS FRGU,
             FND_CONCURRENT_PROGRAMS_VL FCPV,
             FND_EXECUTABLES_FORM_V FEFV,
             FND_APPLICATION FA
      where  1 = 1
      and    FRG.REQUEST_GROUP_NAME = 'FS_¥[·ùIT_R'
      and    FRG.REQUEST_GROUP_ID = FRGU.REQUEST_GROUP_ID
      and    FRGU.REQUEST_UNIT_ID = FCPV.CONCURRENT_PROGRAM_ID
      and    FCPV.EXECUTABLE_ID = FEFV.EXECUTABLE_ID
      and    FEFV.APPLICATION_ID = FA.APPLICATION_ID;
begin
   for V in C loop
            DBMS_OUTPUT.PUT_LINE(
                  'FNDLOAD apps/apps 0 Y DOWNLOAD $FND_TOP/patch/115/import/afcpreqg.lct '
               || V.EXECUTABLE_NAME
               || '.ldt REQUEST_GROUP REQUEST_GROUP_NAME="'
               || V.REQUEST_GROUP_NAME
               || '" UNIT_APP="'
               || V.APPLICATION_SHORT_NAME
               || '" UNIT_NAME="'
               || V.EXECUTABLE_NAME
               || '" '
            );
      DBMS_OUTPUT.PUT_LINE('FNDLOAD apps/apps 0 Y UPLOAD $FND_TOP/patch/115/import/afcpreqg.lct ' || V.EXECUTABLE_NAME || '.ldt;');
   end loop;
end;