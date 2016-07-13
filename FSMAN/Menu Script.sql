SELECT            LPAD(' ', 4 * (LEVEL - 1)) || TO_CHAR(A.MENU_NAME) U_MENU_NAME,
                  LPAD(' ', 4 * (LEVEL - 1)) || A.ENTRY_SEQUENCE SS,
                  LPAD(' ', 4 * (LEVEL - 1)) || A.PROMPT,
                  --                          A.SUB_MENU_ID,
                  --                          A.FUNCTION_ID,
                  LPAD(' ', 4 * (LEVEL - 1)) || A.FUNCTION_NAME FN,
                  LPAD(' ', 4 * (LEVEL - 1)) || A.USER_FUNCTION_NAME UFN,
                  LPAD(' ', 4 * (LEVEL - 1)) || A.DESCRIPTION DE,
                  A.ENTRY_SEQUENCE SEQ
FROM              (SELECT FMV.MENU_ID,
                          FMV.MENU_NAME,
                          FMV.USER_MENU_NAME,
                          FMEV.ENTRY_SEQUENCE,
                          FMEV.PROMPT,
                          FMEV.SUB_MENU_ID,
                          FMEV.FUNCTION_ID,
                          FFFV.FUNCTION_NAME,
                          FFFV.USER_FUNCTION_NAME,
                          FMEV.DESCRIPTION
                   FROM   FND_MENUS_VL FMV,
                          FND_MENU_ENTRIES_VL FMEV,
                          FND_FORM_FUNCTIONS_VL FFFV
                   WHERE  1 = 1
                   AND    FMV.MENU_ID = FMEV.MENU_ID
                   AND    FMEV.FUNCTION_ID = FFFV.FUNCTION_ID(+)) A
START WITH        UPPER(A.USER_MENU_NAME) = 'FS_¥[·ùIT_M'
CONNECT BY        PRIOR A.SUB_MENU_ID = A.MENU_ID
ORDER SIBLINGS BY SEQ