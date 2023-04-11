CREATE OR REPLACE PACKAGE BODY APPS.MK_GL_TRANSFER_ENGINE_PKG AS
    P_USER_ID              NUMBER := APPS.FND_GLOBAL.USER_ID;                                               --FND_PROFILE.VALUE ('USER_ID');
    P_LOGIN_ID             NUMBER := FND_PROFILE.VALUE ('LOGIN_ID');
    G_STATUS               GL_JE_HEADERS.STATUS%TYPE := FND_PROFILE.VALUE ('ATK_JOURNAL_STATUS');
    P_ERP_USER             VARCHAR2 (20);
    G_ERR_STRING           VARCHAR2 (3000);
    --   G_CONVERSION_TYPE_AV     VARCHAR2 (30) := 'Accounting Rate';
    G_CONVERSION_TYPE_AV   VARCHAR2 (30) := 'Average Rate';
    G_CONVERSION_TYPE_AC   VARCHAR2 (30) := 'Average Rate';                                                             --'Accounting Rate';
    G_USER_NAME            VARCHAR2 (30) := 'JIMBOCHANG';
    G_USER_ID              NUMBER := 36361;
    G_TPV_SOB_ID           NUMBER := 22;
    G_MSG                  VARCHAR2 (32767);
    G_PREFIX               VARCHAR2 (30) := '2891';
    G_CON                  VARCHAR2 (1) := '_';
    G_GCC                  GL_CODE_COMBINATIONS_KFV%ROWTYPE;

    --   G_LINE                   LINE_CT;
    TYPE LINE_CT IS TABLE OF GL_JE_LINES%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE R_REC IS RECORD
    (
        P_BATCH_NAME                 GL_INTERFACE.REFERENCE1%TYPE,
        P_JOURNAL_ENTRY_NAME         GL_INTERFACE.REFERENCE4%TYPE,
        P_PERIOD_NAME                GL_INTERFACE.PERIOD_NAME%TYPE,
        P_USER_JE_SOURCE_NAME        GL_INTERFACE.USER_JE_SOURCE_NAME%TYPE,
        P_USER_JE_CATEGORY_NAME      GL_INTERFACE.USER_JE_CATEGORY_NAME%TYPE,
        P_CURRENCY_CODE              GL_INTERFACE.CURRENCY_CODE%TYPE,
        P_CURRENCY_CONVERSION_DATE   GL_INTERFACE.CURRENCY_CONVERSION_DATE%TYPE,
        P_EXCHANGE_RATE              GL_INTERFACE.CURRENCY_CONVERSION_RATE%TYPE,
        P_CCID                       GL_INTERFACE.CODE_COMBINATION_ID%TYPE,
        P_DESCRIPTION                GL_INTERFACE.REFERENCE10%TYPE,
        P_DATE                       GL_INTERFACE.ACCOUNTING_DATE%TYPE,
        P_USER_ID                    NUMBER,
        P_SET_OF_BOOKS_ID            GL_INTERFACE.SET_OF_BOOKS_ID%TYPE,
        P_GROUP_ID                   GL_INTERFACE.GROUP_ID%TYPE,
        P_DR                         GL_INTERFACE.ENTERED_DR%TYPE,
        P_CR                         GL_INTERFACE.ENTERED_CR%TYPE,
        P_DR_ACC                     GL_INTERFACE.ACCOUNTED_DR%TYPE,
        P_CR_ACC                     GL_INTERFACE.ACCOUNTED_CR%TYPE,
        P_ATTRIBUTE1                 GL_INTERFACE.ATTRIBUTE1%TYPE,                                                                    --異損編號
        P_ATTRIBUTE2                 GL_INTERFACE.ATTRIBUTE2%TYPE,                                                                   --Style
        P_ATTRIBUTE3                 GL_INTERFACE.ATTRIBUTE3%TYPE,                                                                --Customer
        P_ATTRIBUTE4                 GL_INTERFACE.ATTRIBUTE4%TYPE,                                                                --Supplier
        P_ATTRIBUTE5                 GL_INTERFACE.ATTRIBUTE5%TYPE,                                                             --Account Num
        P_ATTRIBUTE6                 GL_INTERFACE.ATTRIBUTE6%TYPE,                                                        --Ecolot End Buyer
        P_ATTRIBUTE7                 GL_INTERFACE.ATTRIBUTE7%TYPE,                                                                      --外幣
        P_ATTRIBUTE8                 GL_INTERFACE.ATTRIBUTE8%TYPE,                                                         --Ecolot Customer
        P_ATTRIBUTE9                 GL_INTERFACE.ATTRIBUTE9%TYPE,                                                              --IDR Amount
        P_ATTRIBUTE10                GL_INTERFACE.ATTRIBUTE10%TYPE,                                                                     --備註
        P_ATTRIBUTE11                GL_INTERFACE.ATTRIBUTE11%TYPE,                                                      --Ecolot Sales Dept
        P_ATTRIBUTE12                GL_INTERFACE.ATTRIBUTE12%TYPE,                                                       --付款日(DD-MON-YYYY)
        P_ATTRIBUTE13                GL_INTERFACE.ATTRIBUTE13%TYPE,                                                      --PO NO/Contract no
        P_ATTRIBUTE14                GL_INTERFACE.ATTRIBUTE14%TYPE,                                                                   --科目分類
        P_ATTRIBUTE15                GL_INTERFACE.ATTRIBUTE15%TYPE
    );

    ----------------------------------------------------------------------------------------------------------------------------------------------------
    FUNCTION GET_CC_ID (V_REC GL_CODE_COMBINATIONS%ROWTYPE)
        RETURN NUMBER AS
        V_CODE_COMBINATION_ID   GL_CODE_COMBINATIONS.CODE_COMBINATION_ID%TYPE;
    BEGIN
        SELECT CODE_COMBINATION_ID
          INTO V_CODE_COMBINATION_ID
          FROM GL_CODE_COMBINATIONS
         WHERE 1 = 1
           AND SEGMENT1 = V_REC.SEGMENT1
           AND SEGMENT2 = V_REC.SEGMENT2
           AND SEGMENT3 = V_REC.SEGMENT3
           AND SEGMENT4 = V_REC.SEGMENT4
           AND SEGMENT5 = V_REC.SEGMENT5
           AND SEGMENT6 = V_REC.SEGMENT6;

        RETURN NVL (V_CODE_COMBINATION_ID, -1);
    EXCEPTION
        WHEN OTHERS THEN
            V_CODE_COMBINATION_ID := -1;                                                                                 --TO_NUMBER (NULL);
            RETURN -1;
    --            g_err_string :=
    --                   v_rec.segment1
    --                || '.'
    --                || v_rec.segment2
    --                || '.'
    --                || v_rec.segment3
    --                || '.'
    --                || v_rec.segment4
    --                || '.'
    --                || v_rec.segment5
    --                || '.'
    --                || v_rec.segment6
    --                || ' 會計科目未產生';
    END GET_CC_ID;

    ----------------------------------------------------------------------------------------------------------------------------------------------------
    FUNCTION GEN_CC_ID (V_REC GL_CODE_COMBINATIONS%ROWTYPE, P_SET_OF_BOOKS_ID NUMBER)
        RETURN NUMBER AS
        V_CODE_COMBINATION_ID   GL_CODE_COMBINATIONS.CODE_COMBINATION_ID%TYPE;
        V_MSG                   VARCHAR2 (32767);
        V_CCID                  NUMBER;
    BEGIN
        V_CCID := GET_CC_ID (V_REC);

        IF V_CCID = -1 THEN
            MK_GL_PUB.CREATE_GL_ACCOUNT (
                P_SET_OF_BOOKS_ID,
                   V_REC.SEGMENT1
                || '.'
                || V_REC.SEGMENT2
                || '.'
                || V_REC.SEGMENT3
                || '.'
                || V_REC.SEGMENT4
                || '.'
                || V_REC.SEGMENT5
                || '.'
                || V_REC.SEGMENT6,
                G_ERR_STRING);
            V_CCID := GET_CC_ID (V_REC);
        END IF;

        RETURN V_CCID;
    EXCEPTION
        WHEN OTHERS THEN
            G_ERR_STRING := 'E' || SQLERRM;
            RETURN NULL;
    END GEN_CC_ID;

    ----------------------------------------------------------------------------------------------------------------------------------------------------
    FUNCTION RATE_CONVERSION (IN_FROM_CURRENCY    VARCHAR2,
                              IN_TO_CURRENCY      VARCHAR2,
                              IN_RATE_TYPE        VARCHAR2,
                              IN_RATE_DATE        DATE,
                              IN_AMOUNT           NUMBER DEFAULT 1)
        RETURN NUMBER IS
        V_RETURN   NUMBER;
    BEGIN
        IF (IN_FROM_CURRENCY = 'VND'
        AND IN_TO_CURRENCY = 'TWD')
        OR (IN_FROM_CURRENCY = 'TWD'
        AND IN_TO_CURRENCY = 'VND') THEN
            RETURN MK_GL_PUB.GET_ACTUAL_RATE_AMOUNT (IN_AMOUNT,
                                                     IN_FROM_CURRENCY,
                                                     IN_TO_CURRENCY,
                                                     IN_RATE_TYPE,
                                                     IN_RATE_DATE);
        ELSE
            V_RETURN := IN_AMOUNT * MIC_PO_RATE_PKG.GET_RATE (IN_FROM_CURRENCY, IN_TO_CURRENCY, IN_RATE_TYPE, IN_RATE_DATE);
        END IF;

        RETURN V_RETURN;
    END RATE_CONVERSION;

    ----------------------------------------------------------------------------------------------------------------------------------------------------
    PROCEDURE IMP_GI (P_REC IN OUT R_REC) IS
    BEGIN
        --INSERT GL INTERFACE
        P_REC.P_DR := NVL (P_REC.P_DR, 0);
        P_REC.P_CR := NVL (P_REC.P_CR, 0);
        ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (P_BATCH_NAME              => P_REC.P_BATCH_NAME,
                                                   P_JOURNAL_ENTRY_NAME      => P_REC.P_JOURNAL_ENTRY_NAME,
                                                   P_PERIOD_NAME             => P_REC.P_PERIOD_NAME,
                                                   P_USER_JE_SOURCE_NAME     => P_REC.P_USER_JE_SOURCE_NAME,
                                                   P_USER_JE_CATEGORY_NAME   => P_REC.P_USER_JE_CATEGORY_NAME,
                                                   P_CURRENCY_CODE           => P_REC.P_CURRENCY_CODE,
                                                   P_CCID                    => P_REC.P_CCID,
                                                   P_DESCRIPTION             => P_REC.P_DESCRIPTION,
                                                   P_DATE                    => P_REC.P_DATE,
                                                   P_USER_ID                 => P_REC.P_USER_ID,
                                                   P_SET_OF_BOOKS_ID         => P_REC.P_SET_OF_BOOKS_ID,
                                                   P_GROUP_ID                => P_REC.P_GROUP_ID,
                                                   P_DR                      => P_REC.P_DR,
                                                   P_CR                      => P_REC.P_CR,
                                                   P_ATTRIBUTE1              => P_REC.P_ATTRIBUTE1,
                                                   P_ATTRIBUTE2              => P_REC.P_ATTRIBUTE2,
                                                   P_ATTRIBUTE3              => P_REC.P_ATTRIBUTE3,
                                                   P_ATTRIBUTE4              => P_REC.P_ATTRIBUTE4,
                                                   P_ATTRIBUTE5              => P_REC.P_ATTRIBUTE5,
                                                   P_ATTRIBUTE6              => P_REC.P_ATTRIBUTE6,
                                                   P_ATTRIBUTE7              => P_REC.P_ATTRIBUTE7,
                                                   P_ATTRIBUTE8              => P_REC.P_ATTRIBUTE8,
                                                   P_ATTRIBUTE9              => P_REC.P_ATTRIBUTE9,
                                                   P_ATTRIBUTE10             => P_REC.P_ATTRIBUTE10,
                                                   P_ATTRIBUTE11             => P_REC.P_ATTRIBUTE11,
                                                   P_ATTRIBUTE12             => P_REC.P_ATTRIBUTE12,
                                                   P_ATTRIBUTE13             => P_REC.P_ATTRIBUTE13,
                                                   P_ATTRIBUTE14             => P_REC.P_ATTRIBUTE14,
                                                   P_ATTRIBUTE15             => P_REC.P_ATTRIBUTE15);
        COMMIT;
    END IMP_GI;

    PROCEDURE INSERT_GL_INTERFACE_ALL_CURR (P_BATCH_NAME                  VARCHAR2,
                                            P_JOURNAL_ENTRY_NAME          VARCHAR2,
                                            P_PERIOD_NAME                 VARCHAR2,
                                            P_USER_JE_SOURCE_NAME         VARCHAR2,
                                            P_USER_JE_CATEGORY_NAME       VARCHAR2,
                                            P_CURRENCY_CODE               VARCHAR2,
                                            P_CURRENCY_CONVERSION_DATE    DATE,
                                            P_EXCHANGE_RATE               NUMBER,
                                            P_CCID                        NUMBER,
                                            P_DESCRIPTION                 VARCHAR2,
                                            P_DATE                        DATE,
                                            P_USER_ID                     NUMBER,
                                            P_SET_OF_BOOKS_ID             NUMBER,
                                            P_GROUP_ID                    NUMBER,
                                            P_DR                          NUMBER,
                                            P_CR                          NUMBER,
                                            P_DR_ACC                      NUMBER,
                                            P_CR_ACC                      NUMBER,
                                            P_ATTRIBUTE1                  VARCHAR2 DEFAULT NULL,                                      --異損編號
                                            P_ATTRIBUTE2                  VARCHAR2 DEFAULT NULL,                                     --Style
                                            P_ATTRIBUTE3                  VARCHAR2 DEFAULT NULL,                                  --Customer
                                            P_ATTRIBUTE4                  VARCHAR2 DEFAULT NULL,                                  --Supplier
                                            P_ATTRIBUTE5                  VARCHAR2 DEFAULT NULL,                               --Account Num
                                            P_ATTRIBUTE6                  VARCHAR2 DEFAULT NULL,                          --Ecolot End Buyer
                                            P_ATTRIBUTE7                  VARCHAR2 DEFAULT NULL,                                        --外幣
                                            P_ATTRIBUTE8                  VARCHAR2 DEFAULT NULL,                           --Ecolot Customer
                                            P_ATTRIBUTE9                  VARCHAR2 DEFAULT NULL,                                --IDR Amount
                                            P_ATTRIBUTE10                 VARCHAR2 DEFAULT NULL,                                        --備註
                                            P_ATTRIBUTE11                 VARCHAR2 DEFAULT NULL,                         --Ecolot Sales Dept
                                            P_ATTRIBUTE12                 VARCHAR2 DEFAULT NULL,                          --付款日(DD-MON-YYYY)
                                            P_ATTRIBUTE13                 VARCHAR2 DEFAULT NULL,
                                            P_ATTRIBUTE14                 VARCHAR2 DEFAULT NULL,
                                            P_ATTRIBUTE15                 VARCHAR2 DEFAULT NULL) IS
        NTOTAL       NUMBER;
        NDR          NUMBER;
        NCR          NUMBER;
        NDR_ACC      NUMBER;
        NCR_ACC      NUMBER;
        NTOTAL_ACC   NUMBER;
    BEGIN
        IF P_DR = 0 THEN
            NDR := NULL;
            NCR := P_CR;
            NTOTAL := NCR;
        ELSE
            NCR := NULL;
            NDR := P_DR;
            NTOTAL := NDR;
        END IF;

        IF P_DR_ACC = 0 THEN
            NDR_ACC := NULL;
            NCR_ACC := P_CR_ACC;
            NTOTAL_ACC := NCR_ACC;
        ELSE
            NCR_ACC := NULL;
            NDR_ACC := P_DR_ACC;
            NTOTAL_ACC := NDR_ACC;
        END IF;

        INSERT INTO GL_INTERFACE (STATUS,
                                  SET_OF_BOOKS_ID,
                                  USER_JE_SOURCE_NAME,
                                  USER_JE_CATEGORY_NAME,
                                  ACCOUNTING_DATE,
                                  CURRENCY_CODE,
                                  DATE_CREATED,
                                  CREATED_BY,
                                  ACTUAL_FLAG,
                                  USER_CURRENCY_CONVERSION_TYPE,
                                  CURRENCY_CONVERSION_DATE,
                                  CURRENCY_CONVERSION_RATE,
                                  CODE_COMBINATION_ID,
                                  ENTERED_DR,
                                  ENTERED_CR,
                                  ACCOUNTED_DR,
                                  ACCOUNTED_CR,
                                  REFERENCE1,
                                  REFERENCE4,
                                  REFERENCE10,
                                  GROUP_ID,
                                  PERIOD_NAME,
                                  INVOICE_DATE,
                                  INVOICE_AMOUNT,
                                  ATTRIBUTE1,
                                  ATTRIBUTE2,
                                  ATTRIBUTE3,
                                  ATTRIBUTE4,
                                  ATTRIBUTE5,
                                  ATTRIBUTE6,
                                  ATTRIBUTE7,
                                  ATTRIBUTE8,
                                  ATTRIBUTE9,
                                  ATTRIBUTE10,
                                  ATTRIBUTE11,
                                  ATTRIBUTE12,
                                  ATTRIBUTE13,
                                  ATTRIBUTE14,
                                  ATTRIBUTE15)
             VALUES ('NEW',
                     P_SET_OF_BOOKS_ID,
                     TRIM (P_USER_JE_SOURCE_NAME),
                     TRIM (P_USER_JE_CATEGORY_NAME),
                     P_DATE,
                     TRIM (P_CURRENCY_CODE),
                     SYSDATE,
                     P_USER_ID,
                     'A',
                     'Average Rate',                                                                                    --'Accounting Rate',
                     P_CURRENCY_CONVERSION_DATE,
                     P_EXCHANGE_RATE,
                     P_CCID,
                     NDR,
                     NCR,
                     NDR_ACC,
                     NCR_ACC,
                     TRIM (P_BATCH_NAME),
                     TRIM (P_JOURNAL_ENTRY_NAME),
                     P_DESCRIPTION,
                     P_GROUP_ID,
                     TRIM (P_PERIOD_NAME),
                     P_DATE,
                     NTOTAL,
                     P_ATTRIBUTE1,
                     P_ATTRIBUTE2,
                     P_ATTRIBUTE3,
                     P_ATTRIBUTE4,
                     P_ATTRIBUTE5,
                     P_ATTRIBUTE6,
                     P_ATTRIBUTE7,
                     P_ATTRIBUTE8,
                     P_ATTRIBUTE9,
                     P_ATTRIBUTE10,
                     P_ATTRIBUTE11,
                     P_ATTRIBUTE12,
                     P_ATTRIBUTE13,
                     P_ATTRIBUTE14,
                     P_ATTRIBUTE15);

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE ('ATK Error:' || SQLERRM);
    END INSERT_GL_INTERFACE_ALL_CURR;

    ----------------------------------------------------------------------------------------------------------------------------------------------------
    PROCEDURE IMP_GI_CURR (P_REC IN OUT R_REC) IS
    BEGIN
        P_REC.P_DR := NVL (P_REC.P_DR, 0);
        P_REC.P_CR := NVL (P_REC.P_CR, 0);
        P_REC.P_DR_ACC := NVL (P_REC.P_DR_ACC, 0);
        P_REC.P_CR_ACC := NVL (P_REC.P_CR_ACC, 0);
        --INSERT GL INTERFACE
        --            ATK_GL_COMMON_PKG.
        INSERT_GL_INTERFACE_ALL_CURR (P_BATCH_NAME                 => P_REC.P_BATCH_NAME,
                                      P_JOURNAL_ENTRY_NAME         => P_REC.P_JOURNAL_ENTRY_NAME,
                                      P_PERIOD_NAME                => P_REC.P_PERIOD_NAME,
                                      P_USER_JE_SOURCE_NAME        => P_REC.P_USER_JE_SOURCE_NAME,
                                      P_USER_JE_CATEGORY_NAME      => P_REC.P_USER_JE_CATEGORY_NAME,
                                      P_CURRENCY_CODE              => P_REC.P_CURRENCY_CODE,
                                      P_CURRENCY_CONVERSION_DATE   => P_REC.P_CURRENCY_CONVERSION_DATE,
                                      P_EXCHANGE_RATE              => P_REC.P_EXCHANGE_RATE,
                                      P_CCID                       => P_REC.P_CCID,
                                      P_DESCRIPTION                => P_REC.P_DESCRIPTION,
                                      P_DATE                       => P_REC.P_DATE,
                                      P_USER_ID                    => P_REC.P_USER_ID,
                                      P_SET_OF_BOOKS_ID            => P_REC.P_SET_OF_BOOKS_ID,
                                      P_GROUP_ID                   => P_REC.P_GROUP_ID,
                                      P_DR                         => P_REC.P_DR,
                                      P_CR                         => P_REC.P_CR,
                                      P_DR_ACC                     => P_REC.P_DR_ACC,
                                      P_CR_ACC                     => P_REC.P_CR_ACC,
                                      P_ATTRIBUTE1                 => P_REC.P_ATTRIBUTE1,
                                      P_ATTRIBUTE2                 => P_REC.P_ATTRIBUTE2,
                                      P_ATTRIBUTE3                 => P_REC.P_ATTRIBUTE3,
                                      P_ATTRIBUTE4                 => P_REC.P_ATTRIBUTE4,
                                      P_ATTRIBUTE5                 => P_REC.P_ATTRIBUTE5,
                                      P_ATTRIBUTE6                 => P_REC.P_ATTRIBUTE6,
                                      P_ATTRIBUTE7                 => P_REC.P_ATTRIBUTE7,
                                      P_ATTRIBUTE8                 => P_REC.P_ATTRIBUTE8,
                                      P_ATTRIBUTE9                 => P_REC.P_ATTRIBUTE9,
                                      P_ATTRIBUTE10                => P_REC.P_ATTRIBUTE10,
                                      P_ATTRIBUTE11                => P_REC.P_ATTRIBUTE11,
                                      P_ATTRIBUTE12                => P_REC.P_ATTRIBUTE12,
                                      P_ATTRIBUTE13                => P_REC.P_ATTRIBUTE13,
                                      P_ATTRIBUTE14                => P_REC.P_ATTRIBUTE14,
                                      P_ATTRIBUTE15                => P_REC.P_ATTRIBUTE15);
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            G_MSG := 'IMP_GI_CURR Error!' || SQLERRM;
    END IMP_GI_CURR;

    FUNCTION GET_BATCH_NAME (P_STRING VARCHAR2, P_PERIOD VARCHAR2, P_SOB_NAME VARCHAR2)
        RETURN VARCHAR2 IS
    BEGIN
        RETURN G_PREFIX || G_CON || P_SOB_NAME || G_CON || P_STRING || G_CON || P_PERIOD || G_CON;
    END GET_BATCH_NAME;

    FUNCTION GET_JOURNAL_NAME (P_STRING VARCHAR2, P_PERIOD VARCHAR2, P_SOB_NAME VARCHAR2)
        RETURN VARCHAR2 IS
    BEGIN
        RETURN GET_BATCH_NAME (P_STRING, P_PERIOD, P_SOB_NAME);
    --      RETURN G_PREFIX || G_CON || P_STRING || G_CON || P_SOB_NAME || G_CON || TO_CHAR (P_PERIOD, 'MON-YY') || G_CON;
    END GET_JOURNAL_NAME;

    FUNCTION GET_SOB (P_SOB_ID NUMBER)
        RETURN GL_SETS_OF_BOOKS%ROWTYPE IS
        R_SOB   GL_SETS_OF_BOOKS%ROWTYPE;
    BEGIN
        BEGIN
            SELECT *
              INTO R_SOB
              FROM GL_SETS_OF_BOOKS
             WHERE 1 = 1
               AND SET_OF_BOOKS_ID = P_SOB_ID;
        EXCEPTION
            WHEN OTHERS THEN
                R_SOB := NULL;
        END;

        RETURN R_SOB;
    END GET_SOB;

    ----------------------------------------------------------------------------------------------------------------------------------------------------
    PROCEDURE PRE_SETTING (P_SOB_ID                  IN     NUMBER,
                           P_PERIOD                  IN     VARCHAR2,
                           P_SET_OF_BOOKS_ID            OUT NUMBER,
                           P_PERIOD_NAME                OUT VARCHAR2,
                           P_USER_JE_SOURCE_NAME        OUT VARCHAR2,
                           P_USER_JE_CATEGORY_NAME      OUT VARCHAR2,
                           P_BASE_CURRENCY_CODE         OUT VARCHAR2,
                           P_ACCOUNTING_DATE            OUT DATE,
                           P_GROUP_ID                   OUT NUMBER,
                           P_BATCH_NAME                 OUT VARCHAR2) IS
        R_GSOB   GL_SETS_OF_BOOKS%ROWTYPE;
    BEGIN
        P_SET_OF_BOOKS_ID := P_SOB_ID;
        P_PERIOD_NAME := P_PERIOD;
        P_USER_JE_SOURCE_NAME := 'Dos-Accounting';
        P_USER_JE_CATEGORY_NAME := 'Transfer';
        R_GSOB := GET_SOB (P_SOB_ID);

        BEGIN
            SELECT CURRENCY_CODE
              INTO P_BASE_CURRENCY_CODE
              FROM GL_SETS_OF_BOOKS
             WHERE 1 = 1
               AND SET_OF_BOOKS_ID = P_SOB_ID;
        EXCEPTION
            WHEN OTHERS THEN
                P_BASE_CURRENCY_CODE := NULL;
        END;

        SELECT TO_DATE (P_PERIOD, 'MON-RR') INTO P_ACCOUNTING_DATE FROM DUAL;

        SELECT GL_INTERFACE_CONTROL_S.NEXTVAL INTO P_GROUP_ID FROM DUAL;

        --      P_BATCH_NAME              := G_PREFIX || '樣品中心' || TO_CHAR (P_ACCOUNTING_DATE, 'yyyymmdd') || P_GROUP_ID;
        P_BATCH_NAME := GET_BATCH_NAME ('SAMPLE OH', P_PERIOD, R_GSOB.SHORT_NAME);
    END PRE_SETTING;

    FUNCTION IMP_AD_SAMPLE_FAC (P_PERIOD VARCHAR2, P_SOB_ID NUMBER)
        RETURN VARCHAR2 IS
        CURSOR JOU (
            P_PERIOD    VARCHAR2,
            P_SOB_ID    NUMBER) IS
              SELECT A.PERIOD_NAME,
                     LAST_DAY (TO_DATE (A.PERIOD_NAME, 'MON-RR')) ACCOUNTING_DATE,
                     A.FACTORY_ERP,
                     A.FACTORY,
                     G.SHORT_NAME,
                     G.SET_OF_BOOKS_ID,
                     SUM (A.AMOUNT)                             AMOUNT,
                     SUM (
                           A.AMOUNT
                         * RATE_CONVERSION ('USD',
                                            DECODE (SHORT_NAME,  'CPV', 'CNY',  'VTX', 'VND',  'VPV', 'VND',  'USD'),
                                            G_CONVERSION_TYPE_AV,
                                            LAST_DAY (TO_DATE (A.PERIOD_NAME, 'MON-RR'))))
                         ACCOUNTED_AMOUNT
                FROM ATK_AD_FACTORY_AMT_V A, ESB.MAPPING_MANUFACTORY M, GL_SETS_OF_BOOKS G
               WHERE A.PERIOD_NAME = P_PERIOD
                 AND A.FACTORY_ERP = M.ERP_NAME
                 AND M.ATTRIBUTE4 = G.SHORT_NAME
                 AND A.AMOUNT IS NOT NULL
                 AND M.ATTRIBUTE5 = 'AD Sample'
                 AND G.SET_OF_BOOKS_ID = P_SOB_ID
            GROUP BY A.PERIOD_NAME,
                     G.SHORT_NAME,
                     G.SET_OF_BOOKS_ID,
                     A.FACTORY,
                     A.FACTORY_ERP
            ORDER BY G.SET_OF_BOOKS_ID;

        LN_ORG_ID                  NUMBER;
        LC_USER_NAME               VARCHAR2 (100);
        LC_USER_JE_SOURCE_NAME     VARCHAR2 (255);
        LC_USER_JE_CATEGORY_NAME   VARCHAR2 (255);
        LC_PERIOD_NAME             VARCHAR2 (255);
        LC_BASE_CURRENCY_CODE      VARCHAR2 (15);
        LC_BATCH_NAME              VARCHAR2 (255);
        LN_SET_OF_BOOKS_ID         NUMBER;
        LN_GROUP_ID                NUMBER;
        LC_JOURNAL_ENTRY_NAME      VARCHAR2 (255);
        LN_REQ_ID                  NUMBER;
        X_DR_ACCT_CCID             NUMBER;
        X_CR_ACCT_CCID             NUMBER;
        V_DESCRIPTION              VARCHAR2 (3000) := '一級樣品室/產區二級樣品室支援製樣/專案';
        R_SOB                      GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE            VARCHAR2 (30) := 'AD SAMPLE';
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);
        LC_BASE_CURRENCY_CODE := R_SOB.CURRENCY_CODE;
        LC_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
        LC_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);

        --取得  GROUP_ID,BATCH_NAME
        /*                  APPS.ATK_GL_COMMON_PKG.GET_COMMON_INFO(LN_ORG_ID,TO_DATE(P_PERIOD,'MON-RR') ,1206,
                                                                                   LC_USER_JE_SOURCE_NAME,LC_USER_JE_CATEGORY_NAME,
                                                                                   LC_PERIOD_NAME ,
                                                                                   LC_BASE_CURRENCY_CODE ,
                                                                                   LC_BATCH_NAME ,
                                                                                   LN_SET_OF_BOOKS_ID,
                                                                                   LN_GROUP_ID ) ;           */
        ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      SELECT G_PREFIX || 'AD SAMPLE' || '-' || P_PERIOD || '-' || 'Dos-Accounting' || '/' || 'Transfer' INTO LC_BATCH_NAME FROM DUAL;
        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'AD SAMPLE'
        --                || '-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 19, 2)), '00')) + 1, 2, '0')
        --           INTO LC_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = P_SOB_ID
        --            AND SUBSTR (NAME, 1, 18) LIKE G_PREFIX || 'AD SAMPLE' || '-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --      END;
        SELECT GL_INTERFACE_CONTROL_S.NEXTVAL INTO LN_GROUP_ID FROM DUAL;

        FOR AA IN JOU (P_PERIOD, P_SOB_ID) LOOP
            /*   DR.2891.00
                       CR.6210.96 ADM-Indirect Labor-AD Sample Support */
            /*Step1-處理借方 */
            BEGIN
                SELECT ACCT_CCID
                  INTO X_DR_ACCT_CCID
                  FROM MK_AD_SAMPLE_ACCT_S
                 WHERE SHORT_NAME = AA.SHORT_NAME
                   AND DEPT_CODE = AA.FACTORY_ERP
                   AND DR_CR = 'DR';
            EXCEPTION
                WHEN OTHERS THEN
                    X_DR_ACCT_CCID := NULL;
            END;

            --DR INSERT GL INTERFACE
            ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (LC_BATCH_NAME,
                                                       LC_JOURNAL_ENTRY_NAME,
                                                       AA.PERIOD_NAME,
                                                       'Dos-Accounting',
                                                       'Transfer',
                                                       LC_BASE_CURRENCY_CODE,
                                                       X_DR_ACCT_CCID,
                                                       V_DESCRIPTION,
                                                       AA.ACCOUNTING_DATE,
                                                       P_USER_ID,
                                                       P_SOB_ID,
                                                       LN_GROUP_ID,
                                                       AA.ACCOUNTED_AMOUNT,
                                                       0,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL);

            /*Step2-處理貸方 */
            BEGIN
                SELECT ACCT_CCID
                  INTO X_CR_ACCT_CCID
                  FROM MK_AD_SAMPLE_ACCT_S
                 WHERE SHORT_NAME = AA.SHORT_NAME
                   AND DEPT_CODE = AA.FACTORY_ERP
                   AND DR_CR = 'CR';
            EXCEPTION
                WHEN OTHERS THEN
                    X_CR_ACCT_CCID := NULL;
            END;

            -- CR INSERT GL INTERFACE
            ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (LC_BATCH_NAME,
                                                       LC_JOURNAL_ENTRY_NAME,
                                                       AA.PERIOD_NAME,
                                                       'Dos-Accounting',
                                                       'Transfer',
                                                       LC_BASE_CURRENCY_CODE,
                                                       X_CR_ACCT_CCID,
                                                       V_DESCRIPTION,
                                                       AA.ACCOUNTING_DATE,
                                                       P_USER_ID,
                                                       P_SOB_ID,
                                                       LN_GROUP_ID,
                                                       0,
                                                       AA.ACCOUNTED_AMOUNT,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL);
            COMMIT;
        /* Lock由FORM控制，Lock後再拋傳票，避免資料異動*/
        /*  UPDATE ATK_AD_SAMPLE_QTY
          SET LOCK_FLAG='Y'
          WHERE  PERIOD_NAME=AA.PERIOD_NAME
          AND FACTORY=AA.FACTORY;

          COMMIT;   */
        END LOOP;

        -- Run Journal Import
        LN_REQ_ID := ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE (P_SOB_ID, P_USER_ID, LN_GROUP_ID, 'Dos-Accounting');

        IF LN_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('AD Sample Failure!! GROUP ID:' || LN_GROUP_ID);
            RETURN 'AD Sample Failure!! GROUP ID:' || LN_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('AD Sample Success!! Concurrent ID:' || LN_REQ_ID);
            RETURN 'AD Sample Success!! Concurrent ID:' || LN_REQ_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'AD Sample Error:' || SQLERRM;
    END IMP_AD_SAMPLE_FAC;

    FUNCTION IMP_AD_SAMPLE_TPE (P_PERIOD VARCHAR2, P_SOB_ID NUMBER DEFAULT NULL)
        RETURN VARCHAR2 IS
        CURSOR JOU (
            P_PERIOD             VARCHAR2,
            P_SET_OF_BOOKS_ID    NUMBER) IS
              SELECT A.PERIOD_NAME,
                     A.SET_OF_BOOKS_ID,
                     MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (A.SET_OF_BOOKS_ID))                                          SEGMENT3,
                     A.CUSTOMER_NAME,
                     A.FACTORY,
                     A.FACTORY_ERP,
                     A.CURRENCY_CODE,
                     LAST_DAY (TO_DATE (A.PERIOD_NAME, 'MON-RR'))                                                               ACCOUNTING_DATE,
                     CASE
                         WHEN A.FACTORY_ERP NOT LIKE 'S%'
                          AND A.FACTORY LIKE '%SVN-TPL%' THEN
                             'SVN-TPL'
                         WHEN A.FACTORY_ERP NOT LIKE 'S%'
                          AND (A.FACTORY LIKE '%SVN-LR%'
                            OR A.FACTORY LIKE 'LR-%') THEN
                             'SVN-LR'
                         WHEN A.FACTORY_ERP LIKE 'S%'
                          AND A.CUSTOMER_NAME NOT IN ('DSH', 'MST', 'WOW') THEN
                             'TPV'
                         WHEN A.FACTORY_ERP LIKE 'S%'
                          AND A.CUSTOMER_NAME IN ('DSH', 'MST', 'WOW') THEN
                             'TPV'
                         ELSE
                             SUBSTR (A.FACTORY, 1, INSTR (A.FACTORY, '-') - 1)
                     END
                         ORIGIN_COUNTRY,
                     A.DEPT_NAME,
                     M.ERP_NAME,
                     RATE_CONVERSION (A.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (A.PERIOD_NAME, 'MON-RR'))) RATE,
                     SUM (A.AMOUNT)                                                                                             AMOUNT,
                     SUM (
                           A.AMOUNT
                         * RATE_CONVERSION (A.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (A.PERIOD_NAME, 'MON-RR'))))
                         AS ACCOUNTED_AMOUNT
                FROM APPS.ATK_AD_SAMPLE_AMT_V A, ESB.PLN_MAPPING_DEPT M
               WHERE A.DEPT_NAME = M.ATTRIBUTE4
                 AND M.ATTRIBUTE5 = 'AD Sample'
                 AND A.PERIOD_NAME = P_PERIOD
                 AND A.AMOUNT IS NOT NULL
                 AND A.FACTORY_ERP IS NOT NULL
                 AND NVL (A.SET_OF_BOOKS_ID, -1) = NVL (P_SET_OF_BOOKS_ID, NVL (A.SET_OF_BOOKS_ID, -1))
            GROUP BY A.PERIOD_NAME,
                     A.SET_OF_BOOKS_ID,
                     A.CUSTOMER_NAME,
                     A.FACTORY,
                     A.FACTORY_ERP,
                     A.CURRENCY_CODE,
                     CASE
                         WHEN A.FACTORY_ERP NOT LIKE 'S%'
                          AND A.FACTORY LIKE '%SVN-TPL%' THEN
                             'SVN-TPL'
                         WHEN A.FACTORY_ERP NOT LIKE 'S%'
                          AND (A.FACTORY LIKE '%SVN-LR%'
                            OR A.FACTORY LIKE 'LR-%') THEN
                             'SVN-LR'
                         WHEN A.FACTORY_ERP LIKE 'S%'
                          AND A.CUSTOMER_NAME NOT IN ('DSH', 'MST', 'WOW') THEN
                             'TPV'
                         WHEN A.FACTORY_ERP LIKE 'S%'
                          AND A.CUSTOMER_NAME IN ('DSH', 'MST', 'WOW') THEN
                             'TPV'
                         ELSE
                             SUBSTR (A.FACTORY, 1, INSTR (A.FACTORY, '-') - 1)
                     END,
                     A.DEPT_NAME,
                     M.ERP_NAME
            ORDER BY M.ERP_NAME;

        LN_ORG_ID                  NUMBER;
        LC_USER_NAME               VARCHAR2 (100);
        LC_USER_JE_SOURCE_NAME     VARCHAR2 (255);
        LC_USER_JE_CATEGORY_NAME   VARCHAR2 (255);
        LC_PERIOD_NAME             VARCHAR2 (255);
        LC_BASE_CURRENCY_CODE      VARCHAR2 (15);
        LC_BATCH_NAME              VARCHAR2 (255);
        LN_SET_OF_BOOKS_ID         NUMBER;
        LN_GROUP_ID                NUMBER;
        LC_JOURNAL_ENTRY_NAME      VARCHAR2 (255);
        LN_REQ_ID                  NUMBER;
        X_DR_ACCT_CCID             NUMBER;
        X_CR_ACCT_CCID             NUMBER;
        P_CURRENCY_CODE            VARCHAR2 (30) := 'USD';
        V_DESCRIPTION              VARCHAR2 (3000) := '一級樣品室/產區二級樣品室支援製樣/專案';
        R_SOB                      GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE            VARCHAR2 (30) := 'AD SAMPLE';
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);

        --            LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        SELECT ORGANIZATION_ID
          INTO LN_ORG_ID
          FROM ORG_ORGANIZATION_DEFINITIONS
         WHERE ORGANIZATION_CODE = 'TPV';

        --取得  GROUP_ID,BATCH_NAME
        APPS.ATK_GL_COMMON_PKG.GET_COMMON_INFO (LN_ORG_ID,
                                                TO_DATE (P_PERIOD, 'MON-RR'),
                                                P_USER_ID,
                                                LC_USER_JE_SOURCE_NAME,
                                                LC_USER_JE_CATEGORY_NAME,
                                                LC_PERIOD_NAME,
                                                LC_BASE_CURRENCY_CODE,
                                                LC_BATCH_NAME,
                                                LN_SET_OF_BOOKS_ID,
                                                LN_GROUP_ID);
        LC_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
        LC_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);

        ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      SELECT G_PREFIX || 'AD SAMPLE' || '-' || P_PERIOD INTO LC_BATCH_NAME FROM DUAL;
        --
        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'AD SAMPLE'
        --                || '-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 19, 2)), '00')) + 1, 2, '0')
        --           INTO LC_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = LN_SET_OF_BOOKS_ID
        --            AND SUBSTR (NAME, 1, 18) LIKE G_PREFIX || 'AD SAMPLE' || '-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --      END;
        FOR AA IN JOU (P_PERIOD, P_SOB_ID) LOOP
            /*   DR.15.01.XXXXX.6144.55.000        XXXXX:部門別
                  DR. 15.01.00000.6144.50.097       DSH
                  DR. 15.01.00000.6144.50.052      WOW
                  DR. 15.01.01530.6144.50.000       MST
                       CR.15.01.09901.2891.00.619   PHL菲
                       CR.15.01.09902.2891.00.669   CHN中
                       CR.15.01.09910.2891.00.629   CAB柬
                       CR.15.01.09915.2891.00.640   NVN北越
                       CR.15.01.09909.2891.00.650   SVN-TPL
                       CR.15.01.09909.2891.00.651   SVN-LR
                       CR.15.01.09917.2891.00.639   IND印
                       CR.15.01.SXXXX.6144.55.000      自製樣品中心 /外發    */
            /*Step1-處理借方 */
            IF AA.ORIGIN_COUNTRY = 'TPV' THEN
                IF AA.CUSTOMER_NAME = 'DSH' THEN                                                                 /*15.01.00000.6144.55.097*/
                    X_DR_ACCT_CCID := 167637;
                ELSIF AA.CUSTOMER_NAME = 'WOW' THEN
                    X_DR_ACCT_CCID := 167467;                                                                    /*15.01.00000.6144.55.052*/
                ELSIF AA.CUSTOMER_NAME = 'MST' THEN
                    X_DR_ACCT_CCID := 71348;                                                                     /*15.01.01530.6144.55.000*/
                ELSE
                    BEGIN
                        SELECT ACCT_CCID
                          INTO X_DR_ACCT_CCID
                          FROM MK_AD_SAMPLE_ACCT_S
                         WHERE SHORT_NAME = 'TPV'
                           AND DEPT_CODE = AA.ERP_NAME
                           AND DR_CR = 'DR';
                    EXCEPTION
                        WHEN OTHERS THEN
                            X_DR_ACCT_CCID := NULL;
                    END;
                END IF;
            ELSE
                BEGIN
                    SELECT ACCT_CCID
                      INTO X_DR_ACCT_CCID
                      FROM MK_AD_SAMPLE_ACCT_S
                     WHERE SHORT_NAME = 'TPV'
                       AND DEPT_CODE = AA.ERP_NAME
                       AND DR_CR = 'DR';
                EXCEPTION
                    WHEN OTHERS THEN
                        X_DR_ACCT_CCID := NULL;
                END;
            END IF;

            --DR INSERT GL INTERFACE
            --            atk_gl_common_pkg.insert_gl_interface_all_curr
            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                          LC_JOURNAL_ENTRY_NAME,
                                          AA.PERIOD_NAME,
                                          LC_USER_JE_SOURCE_NAME,
                                          LC_USER_JE_CATEGORY_NAME,
                                          AA.CURRENCY_CODE,
                                          LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),
                                          AA.RATE,
                                          X_DR_ACCT_CCID,
                                          V_DESCRIPTION,
                                          AA.ACCOUNTING_DATE,
                                          P_USER_ID,
                                          LN_SET_OF_BOOKS_ID,
                                          LN_GROUP_ID,
                                          AA.AMOUNT,
                                          0,
                                          AA.ACCOUNTED_AMOUNT,
                                          0,
                                          NULL,
                                          NULL,
                                          AA.CUSTOMER_NAME,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);

            /*Step2-處理貸方 ;直接Assign CCID*/
            IF AA.ORIGIN_COUNTRY = 'TPV' THEN
                BEGIN
                    SELECT ACCT_CCID
                      INTO X_CR_ACCT_CCID
                      FROM MK_AD_SAMPLE_ACCT_S
                     WHERE SHORT_NAME = 'TPV'
                       AND DEPT_CODE = AA.FACTORY_ERP
                       AND DR_CR = 'CR';
                EXCEPTION
                    WHEN OTHERS THEN
                        X_CR_ACCT_CCID := NULL;
                END;
            ELSE
                G_GCC.SEGMENT1 := '15';
                G_GCC.SEGMENT2 := '01';
                G_GCC.SEGMENT3 := AA.SEGMENT3;
                G_GCC.SEGMENT4 := '2891';
                G_GCC.SEGMENT5 := '00';

                IF AA.ORIGIN_COUNTRY = 'SVN-TPL' THEN
                    G_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (AA.SET_OF_BOOKS_ID), 'TPM', '64');
                ELSIF AA.ORIGIN_COUNTRY = 'SVN-LR' THEN
                    G_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (AA.SET_OF_BOOKS_ID), 'TPM', '65');
                ELSE
                    G_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (AA.SET_OF_BOOKS_ID), 'TPM', NULL);
                END IF;

                G_GCC.CONCATENATED_SEGMENTS :=
                       G_GCC.SEGMENT1
                    || '.'
                    || G_GCC.SEGMENT2
                    || '.'
                    || G_GCC.SEGMENT3
                    || '.'
                    || G_GCC.SEGMENT4
                    || '.'
                    || G_GCC.SEGMENT5
                    || '.'
                    || G_GCC.SEGMENT6;
                X_CR_ACCT_CCID := MK_GL_PUB.GET_CCID (LN_SET_OF_BOOKS_ID, G_GCC.CONCATENATED_SEGMENTS, G_MSG);
            END IF;

            --            IF AA.ORIGIN_COUNTRY = 'PHL' THEN
            --                x_cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09901.2891.00.619');
            --            --                X_CR_ACCT_CCID := 118515;
            --            ELSIF AA.ORIGIN_COUNTRY = 'CHN' THEN
            --                x_cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09902.2891.00.669');
            --            --                X_CR_ACCT_CCID := 120499;
            --            ELSIF AA.ORIGIN_COUNTRY = 'CAB' THEN
            --                x_cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09910.2891.00.629');
            --            --                X_CR_ACCT_CCID := 118511;
            --            ELSIF AA.ORIGIN_COUNTRY = 'NVN' THEN
            --                x_cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.2891.00.640');
            --            --                X_CR_ACCT_CCID := 118513;
            --            ELSIF AA.ORIGIN_COUNTRY = 'SVN-TPL' THEN
            --                x_cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.2891.00.650');
            --            --                X_CR_ACCT_CCID := 118514;
            --            ELSIF AA.ORIGIN_COUNTRY = 'SVN-LR' THEN
            --                x_cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.2891.00.651');
            --            --                X_CR_ACCT_CCID := 133832;
            --            ELSIF AA.ORIGIN_COUNTRY = 'IND' THEN
            --                x_cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09905.2891.00.639');
            --            --                X_CR_ACCT_CCID := 118776;
            --            ELSIF AA.ORIGIN_COUNTRY = 'TPV' THEN
            --                BEGIN
            --                    SELECT ACCT_CCID
            --                      INTO X_CR_ACCT_CCID
            --                      FROM MK_AD_SAMPLE_ACCT_S
            --                     WHERE SHORT_NAME = 'TPV'
            --                       AND DEPT_CODE = AA.FACTORY_ERP
            --                       AND DR_CR = 'CR';
            --                EXCEPTION
            --                    WHEN OTHERS THEN
            --                        X_CR_ACCT_CCID := NULL;
            --                END;
            --            END IF;
            -- CR INSERT GL INTERFACE
            --            atk_gl_common_pkg.insert_gl_interface_all_curr
            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                          LC_JOURNAL_ENTRY_NAME,
                                          AA.PERIOD_NAME,
                                          LC_USER_JE_SOURCE_NAME,
                                          LC_USER_JE_CATEGORY_NAME,
                                          AA.CURRENCY_CODE,
                                          LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),
                                          AA.RATE,
                                          X_CR_ACCT_CCID,
                                          V_DESCRIPTION,
                                          AA.ACCOUNTING_DATE,
                                          P_USER_ID,
                                          LN_SET_OF_BOOKS_ID,
                                          LN_GROUP_ID,
                                          0,
                                          AA.AMOUNT,
                                          0,
                                          AA.ACCOUNTED_AMOUNT,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);
            COMMIT;
        END LOOP;

        -- Run Journal Import
        LN_REQ_ID := ATK_GL_COMMON_PKG.INSERT_GL_CONTROL (LN_SET_OF_BOOKS_ID, P_USER_ID, LN_GROUP_ID);

        IF LN_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('TPV-AD Sample Failure!! GROUP ID:' || LN_GROUP_ID);
            RETURN ' TPV-AD Sample Failure!! GROUP ID:' || LN_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('(TPV-AD Sample Success!! Concurrent ID:' || LN_REQ_ID);
            RETURN 'TPV-AD Sample Success!! Concurrent ID:' || LN_REQ_ID || ' ; Group ID: ' || LN_GROUP_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'TPV-AD Sample Error:' || SQLERRM;
    END IMP_AD_SAMPLE_TPE;

    FUNCTION IMP_FA_SPECIAL_EXP_FAC (P_PERIOD VARCHAR2, P_SOB_ID NUMBER)
        RETURN VARCHAR2 IS
        CURSOR JOU (P_SOB_ID NUMBER) IS
              SELECT A.BOOK_TYPE_CODE,
                     A.FACTORY_CODE,
                     A.DEPT_CODE,
                     FBC.SET_OF_BOOKS_ID,
                     G.CURRENCY_CODE,
                     A.DESCRIPTION,
                     A.BUDGET_TYPE,
                     MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (FBC.SET_OF_BOOKS_ID)) TARGET_BOOK,
                     SUM (DEPRN_AMOUNT)                                                       DEPRN_AMOUNT
                FROM APPS.MK_FA_SPECIAL_DEPRN_AMT_V A, FA_BOOK_CONTROLS FBC, GL_SETS_OF_BOOKS G
               WHERE 1 = 1
                 AND A.BOOK_TYPE_CODE = FBC.BOOK_TYPE_CODE
                 AND MK_GL_PUB.GET_MGMT_SOB_ID (FBC.SET_OF_BOOKS_ID) = G.SET_OF_BOOKS_ID
                 AND G.SET_OF_BOOKS_ID = P_SOB_ID
            GROUP BY A.BOOK_TYPE_CODE,
                     A.FACTORY_CODE,
                     A.DEPT_CODE,
                     FBC.SET_OF_BOOKS_ID,
                     G.CURRENCY_CODE,
                     A.DESCRIPTION,
                     A.BUDGET_TYPE
              HAVING SUM (DEPRN_AMOUNT) <> 0
            ORDER BY 3;

        --機台租借費用
        CURSOR JOU_MTM (
            P_SOB_ID    NUMBER,
            P_PERIOD    VARCHAR2) IS
              SELECT DECODE (A.COUNTRY,  'SMG', 'IPV',  'NVN', 'VPV',  'SVN', 'VTX',  'CHN', 'CPV',  'CAB', 'MPV',  A.COUNTRY) AS SOB,
                     M.ERP_NAME,
                     A.COUNTRY,
                     M.ESSBASE_NAME,
                     SUM (A.QUANTITY * A."SharePrice")                                                                       AMOUNT,
                     G.CURRENCY_CODE,
                     A."Prepare_Type"                                                                                        DESCRIPTION,
                     SUM (
                           A.QUANTITY
                         * A."SharePrice"
                         * RATE_CONVERSION ('USD',
                                            DECODE (A.COUNTRY,  'SMG', 'USD',  'NVN', 'VND',  'SVN', 'VND',  'CHN', 'CNY',  'CAB', 'USD'),
                                            G_CONVERSION_TYPE_AV,
                                            LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR'))))
                         ACCOUNTED_AMOUNT
                FROM MTM_RENT_COST_V2@PDM39_DBLINK           A,
                     WEBPDM.MK_RATE_COST_MAKER_V@PDM39_DBLINK B,
                     ESB.MAPPING_MANUFACTORY                 M,
                     GL_SETS_OF_BOOKS                        G
               WHERE A.COUNTRY || '-' || A.MAKER = B.ERP_MAKER
                 AND M.ESSBASE_NAME = B.ESS_MAKER_D
                 AND TO_CHAR (A.EXPDATE, 'MON-YY') = P_PERIOD
                 AND DECODE (A.COUNTRY,  'SMG', 'IPV',  'NVN', 'VPV',  'SVN', 'VTX',  'CHN', 'CPV',  'CAB', 'MPV',  A.COUNTRY) = G.SHORT_NAME
                 AND G.SET_OF_BOOKS_ID = P_SOB_ID
            GROUP BY M.ERP_NAME,
                     A.COUNTRY,
                     A.MAKER,
                     M.ESSBASE_NAME,
                     G.CURRENCY_CODE,
                     A."Prepare_Type";

        LN_ORG_ID                  NUMBER;
        LC_USER_NAME               VARCHAR2 (100);
        LC_USER_JE_SOURCE_NAME     VARCHAR2 (255);
        LC_USER_JE_CATEGORY_NAME   VARCHAR2 (255);
        LC_PERIOD_NAME             VARCHAR2 (255);
        LC_BASE_CURRENCY_CODE      VARCHAR2 (15);
        LC_BATCH_NAME              VARCHAR2 (255);
        LN_SET_OF_BOOKS_ID         NUMBER;
        LN_GROUP_ID                NUMBER;
        LC_JOURNAL_ENTRY_NAME      VARCHAR2 (255);
        LD_ACCOUNTING_DATE         DATE;
        LN_REQ_ID                  NUMBER;
        X_DR_ACCT_CCID             NUMBER;
        X_CR_ACCT_CCID             NUMBER;
        R_SOB                      GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE            VARCHAR2 (30) := 'FA SPEXP';
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);
        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        LC_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
        LC_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);

        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'FA SPEXP'
        --                || '-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 18, 2)), '00')) + 1, 2, '0')
        --           INTO LC_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = P_SOB_ID
        --            AND SUBSTR (NAME, 1, 17) LIKE G_PREFIX || 'FA SPEXP' || '-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --      END;
        --
        --      ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      SELECT G_PREFIX || 'FA SPEXP' || '-' || P_PERIOD || '-' || 'Dos-Accounting' || '/' || 'Transfer' INTO LC_BATCH_NAME FROM DUAL;
        SELECT GL_INTERFACE_CONTROL_S.NEXTVAL INTO LN_GROUP_ID FROM DUAL;

        SELECT TO_DATE (P_PERIOD, 'MON-YY') INTO LD_ACCOUNTING_DATE FROM DUAL;

        FOR AA IN JOU (P_SOB_ID) LOOP
            /*   DR.2891.00
                       CR.5524.91 MFG-折舊 */
            /*Step1-處理借方 */
            BEGIN
                SELECT ACCT_CCID
                  INTO X_DR_ACCT_CCID
                  FROM MK_FA_ACCT_SETUP
                 WHERE SHORT_NAME = AA.TARGET_BOOK
                   AND DEPT_CODE = AA.DEPT_CODE
                   AND DR_CR = 'DR'
                   AND ITEM_TYPE = '特殊機台';
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;

            --DR INSERT GL INTERFACE
            ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (LC_BATCH_NAME,
                                                       LC_JOURNAL_ENTRY_NAME,
                                                       P_PERIOD,
                                                       'Dos-Accounting',
                                                       'Transfer',
                                                       AA.CURRENCY_CODE,
                                                       X_DR_ACCT_CCID,
                                                       AA.DESCRIPTION,
                                                       LD_ACCOUNTING_DATE,
                                                       P_USER_ID,
                                                       P_SOB_ID,
                                                       LN_GROUP_ID,
                                                       AA.DEPRN_AMOUNT,
                                                       0,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL);

            /*Step2-處理貸方 */
            BEGIN
                SELECT ACCT_CCID
                  INTO X_CR_ACCT_CCID
                  FROM MK_FA_ACCT_SETUP
                 WHERE SHORT_NAME = AA.TARGET_BOOK
                   AND DEPT_CODE = AA.DEPT_CODE
                   AND DR_CR = 'CR'
                   AND ITEM_TYPE = '特殊機台';
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;

            -- CR INSERT GL INTERFACE
            ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (LC_BATCH_NAME,
                                                       LC_JOURNAL_ENTRY_NAME,
                                                       P_PERIOD,
                                                       'Dos-Accounting',
                                                       'Transfer',
                                                       AA.CURRENCY_CODE,
                                                       X_CR_ACCT_CCID,
                                                       AA.DESCRIPTION,
                                                       LD_ACCOUNTING_DATE,
                                                       P_USER_ID,
                                                       P_SOB_ID,
                                                       LN_GROUP_ID,
                                                       0,
                                                       AA.DEPRN_AMOUNT,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL);
            COMMIT;
        END LOOP;

        FOR BB IN JOU_MTM (P_SOB_ID, P_PERIOD) LOOP
            /*   DR.2891.00
                       CR.5511.91 MFG-租金 */
            /*Step1-處理借方 */
            BEGIN
                SELECT ACCT_CCID
                  INTO X_DR_ACCT_CCID
                  FROM MK_FA_ACCT_SETUP
                 WHERE SHORT_NAME = BB.SOB
                   AND DEPT_CODE = BB.ERP_NAME
                   AND DR_CR = 'DR'
                   AND ITEM_TYPE = '租借';
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;

            --DR INSERT GL INTERFACE
            ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (LC_BATCH_NAME,
                                                       LC_JOURNAL_ENTRY_NAME,
                                                       P_PERIOD,
                                                       'Dos-Accounting',
                                                       'Transfer',
                                                       BB.CURRENCY_CODE,
                                                       X_DR_ACCT_CCID,
                                                       BB.DESCRIPTION,
                                                       LD_ACCOUNTING_DATE,
                                                       P_USER_ID,
                                                       P_SOB_ID,
                                                       LN_GROUP_ID,
                                                       BB.ACCOUNTED_AMOUNT,
                                                       0,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL);

            /*Step2-處理貸方 */
            BEGIN
                SELECT ACCT_CCID
                  INTO X_CR_ACCT_CCID
                  FROM MK_FA_ACCT_SETUP
                 WHERE SHORT_NAME = BB.SOB
                   AND DEPT_CODE = BB.ERP_NAME
                   AND DR_CR = 'CR'
                   AND ITEM_TYPE = '租借';
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;

            -- CR INSERT GL INTERFACE
            ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (LC_BATCH_NAME,
                                                       LC_JOURNAL_ENTRY_NAME,
                                                       P_PERIOD,
                                                       'Dos-Accounting',
                                                       'Transfer',
                                                       BB.CURRENCY_CODE,
                                                       X_CR_ACCT_CCID,
                                                       BB.DESCRIPTION,
                                                       LD_ACCOUNTING_DATE,
                                                       P_USER_ID,
                                                       P_SOB_ID,
                                                       LN_GROUP_ID,
                                                       0,
                                                       BB.ACCOUNTED_AMOUNT,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL,
                                                       NULL);
            COMMIT;
        END LOOP;

        -- Run Journal Import
        LN_REQ_ID := ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE (P_SOB_ID, P_USER_ID, LN_GROUP_ID, 'Dos-Accounting');

        IF LN_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('特殊 Failure!! GROUP ID:' || LN_GROUP_ID);
            RETURN ' 特殊 Failure!! GROUP ID:' || LN_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('特殊 Success!! Concurrent ID:' || LN_REQ_ID);
            RETURN '特殊 Success!! Concurrent ID:' || LN_REQ_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN '特殊 Error:' || SQLERRM;
    END IMP_FA_SPECIAL_EXP_FAC;

    FUNCTION IMP_FA_SPECIAL_EXP_TPE (P_PERIOD VARCHAR2, P_SOB_ID NUMBER)
        RETURN VARCHAR2 IS
        CURSOR JOU (
            P_PERIOD    VARCHAR2,
            P_SOB_ID    NUMBER) IS
              SELECT BUDGET_TYPE,
                     SET_OF_BOOKS_ID,
                     MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (SET_OF_BOOKS_ID))                                     SEGMENT3,
                     CUST_NAME,
                     ORIGIN_COUNTRY,
                     DESCRIPTION,
                     CURRENCY_CODE,
                     RATE_CONVERSION (CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR'))) CONVERSION_RATE,
                     SUM (DEPRN_AMOUNT)                                                                                  AS ENTERED_AMOUNT,
                     SUM (ACCOUNTED_AMOUNT)
                         AS ACCOUNTED_AMOUNT
                FROM (SELECT A.BOOK_TYPE_CODE,
                             G.SET_OF_BOOKS_ID,
                             A.DESCRIPTION,
                             A.BUDGET_TYPE,
                             A.CUST_NAME,
                             CASE
                                 WHEN A.FACTORY_CODE LIKE '%SVN-TPL%' THEN 'SVN-TPL'
                                 WHEN A.FACTORY_CODE LIKE '%SVN-LR%' THEN 'SVN-LR'
                                 ELSE SUBSTR (A.FACTORY_CODE, 1, INSTR (A.FACTORY_CODE, '-') - 1)
                             END
                                 ORIGIN_COUNTRY,
                             A.DEPRN_AMOUNT,
                             CASE
                                 WHEN (A.BOOK_TYPE_CODE = 'CAB'
                                    OR A.BOOK_TYPE_CODE = 'MOH'
                                    OR A.BOOK_TYPE_CODE = 'IGI'
                                    OR A.BOOK_TYPE_CODE = 'ISL') THEN
                                     'USD'
                                 WHEN (A.BOOK_TYPE_CODE = 'CJY'
                                    OR A.BOOK_TYPE_CODE = 'CMZ'
                                    OR A.BOOK_TYPE_CODE = 'CJR') THEN
                                     'CNY'
                                 WHEN (A.BOOK_TYPE_CODE = 'VMK'
                                    OR A.BOOK_TYPE_CODE = 'VLR'
                                    OR A.BOOK_TYPE_CODE = 'VTP') THEN
                                     'VND'
                                 ELSE
                                     'USD'
                             END
                                 CURRENCY_CODE,
                             CASE
                                 WHEN (A.BOOK_TYPE_CODE = 'CAB'
                                    OR A.BOOK_TYPE_CODE = 'MOH'
                                    OR A.BOOK_TYPE_CODE = 'IGI'
                                    OR A.BOOK_TYPE_CODE = 'ISL') THEN
                                       A.DEPRN_AMOUNT
                                     * RATE_CONVERSION ('USD', 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')))
                                 WHEN (A.BOOK_TYPE_CODE = 'CJY'
                                    OR A.BOOK_TYPE_CODE = 'CMZ'
                                    OR A.BOOK_TYPE_CODE = 'CJR') THEN
                                       A.DEPRN_AMOUNT
                                     * RATE_CONVERSION ('CNY', 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')))
                                 WHEN (A.BOOK_TYPE_CODE = 'VMK'
                                    OR A.BOOK_TYPE_CODE = 'VLR'
                                    OR A.BOOK_TYPE_CODE = 'VTP') THEN
                                       A.DEPRN_AMOUNT
                                     * RATE_CONVERSION ('VND', 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')))
                                 ELSE
                                     0
                             END
                                 ACCOUNTED_AMOUNT
                        FROM APPS.MK_FA_SPECIAL_DEPRN_AMT_V A, FA_BOOK_CONTROLS FBC, GL_SETS_OF_BOOKS G
                       WHERE 1 = 1
                         AND A.BOOK_TYPE_CODE = FBC.BOOK_TYPE_CODE
                         AND MK_GL_PUB.GET_MGMT_SOB_ID (FBC.SET_OF_BOOKS_ID) = G.SET_OF_BOOKS_ID
                         AND G.SET_OF_BOOKS_ID = P_SOB_ID)
            GROUP BY DESCRIPTION,
                     SET_OF_BOOKS_ID,
                     BUDGET_TYPE,
                     CUST_NAME,
                     CURRENCY_CODE,
                     ORIGIN_COUNTRY
              HAVING SUM (ACCOUNTED_AMOUNT) <> 0
            ORDER BY 3, 4;

        CURSOR JOU_MTM (
            P_PERIOD    VARCHAR2,
            P_SOB_ID    NUMBER) IS
              SELECT DECODE (A.COUNTRY,  'SMG', 'IPV',  'NVN', 'VPV',  'SVN', 'VTX',  'CHN', 'CPV',  'CAB', 'MPV',  A.COUNTRY) AS SOB,
                     MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (GSOB.SET_OF_BOOKS_ID))                                    SEGMENT3,
                     GSOB.SET_OF_BOOKS_ID,
                     M.ERP_NAME,
                     A.COUNTRY,
                     M.ESSBASE_NAME,
                     SUM (A.QUANTITY * A."SharePrice")                                                                       ENTERED_AMOUNT,
                     A."Prepare_Type"                                                                                        AS DESCRIPTION,
                     CASE
                         WHEN M.ESSBASE_NAME LIKE '%SVN-TPL%' THEN 'SVN-TPL'
                         WHEN M.ESSBASE_NAME LIKE '%SVN-LR%' THEN 'SVN-LR'
                         ELSE SUBSTR (M.ESSBASE_NAME, 1, INSTR (M.ESSBASE_NAME, '-') - 1)
                     END
                         ORIGIN_COUNTRY,
                     'USD'                                                                                                   CURRENCY_CODE,
                     RATE_CONVERSION ('USD', 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')))
                         CONVERSION_RATE,
                     SUM (
                           A.QUANTITY
                         * A."SharePrice"
                         * RATE_CONVERSION ('USD', 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR'))))
                         ACCOUNTED_AMOUNT
                FROM MTM_RENT_COST_V2@PDM39_DBLINK           A,
                     WEBPDM.MK_RATE_COST_MAKER_V@PDM39_DBLINK B,
                     ESB.MAPPING_MANUFACTORY                 M,
                     GL_SETS_OF_BOOKS                        GSOB
               WHERE A.COUNTRY || '-' || A.MAKER = B.ERP_MAKER
                 AND M.ESSBASE_NAME = B.ESS_MAKER_D
                 AND TO_CHAR (A.EXPDATE, 'MON-YY') = P_PERIOD
                 AND DECODE (A.COUNTRY,  'SMG', 'IPV',  'NVN', 'VPV',  'SVN', 'VTX',  'CHN', 'CPV',  'CAB', 'MPV',  A.COUNTRY) =
                         GSOB.SHORT_NAME
                 AND GSOB.SET_OF_BOOKS_ID = P_SOB_ID
            GROUP BY M.ERP_NAME,
                     GSOB.SET_OF_BOOKS_ID,
                     A.COUNTRY,
                     A.MAKER,
                     M.ESSBASE_NAME,
                     A."Prepare_Type"
            ORDER BY 2;

        --管帳領用數(樣品中心(SD)和產區一起處理 )
        CURSOR JOU_DUMMY (
            P_PERIOD    VARCHAR2,
            P_SOB_ID    NUMBER) IS
              SELECT CASE
                         WHEN ORIGIN_DISTRICT || '-' || MAKER LIKE 'SVN-TPL%' THEN 'SVN-TPL'
                         WHEN ORIGIN_DISTRICT || '-' || MAKER LIKE 'SVN-LR%' THEN 'SVN-LR'
                         ELSE ORIGIN_DISTRICT
                     END
                         ORIGIN_DISTRICT,
                     OOD.SET_OF_BOOKS_ID,
                     MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (OOD.SET_OF_BOOKS_ID))) SEGMENT3,
                     MFDIV.CURRENCY_CODE,
                     RATE_CONVERSION (MFDIV.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')))
                         CONVERSION_RATE,
                     SUM (UNIT_PRICE)                                                                              ENTERED_AMOUNT,
                     SUM (
                           UNIT_PRICE
                         * RATE_CONVERSION (MFDIV.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR'))))
                         ACCOUNTED_AMOUNT,
                     MFDIV.ATTRIBUTE6                                                                              AS CUST_NAME,
                     ORIGIN_DISTRICT || '-' || ITEM_DESCRIPTION                                                    AS DESCRIPTION
                FROM APPS.MK_FAC_DUMMY_INSPECT_V MFDIV, ORG_ORGANIZATION_DEFINITIONS OOD
               WHERE 1 = 1
                 AND TO_CHAR (RCV_DATE, 'MON-YY') = P_PERIOD
                 AND MFDIV.ORG_ID = OOD.ORGANIZATION_ID
                 AND MK_GL_PUB.GET_MGMT_SOB_ID (OOD.SET_OF_BOOKS_ID) = P_SOB_ID
            GROUP BY CASE
                         WHEN ORIGIN_DISTRICT || '-' || MAKER LIKE 'SVN-TPL%' THEN 'SVN-TPL'
                         WHEN ORIGIN_DISTRICT || '-' || MAKER LIKE 'SVN-LR%' THEN 'SVN-LR'
                         ELSE ORIGIN_DISTRICT
                     END,
                     OOD.SET_OF_BOOKS_ID,
                     ORIGIN_DISTRICT || '-' || ITEM_DESCRIPTION,
                     MAKER,
                     MFDIV.CURRENCY_CODE,
                     MFDIV.ATTRIBUTE6
            ORDER BY 1;

        --樣品中心-發生數
        CURSOR SD_DUMMY (
            P_PERIOD    VARCHAR2,
            P_SOB_ID    NUMBER) IS
              SELECT BUDGET_TYPE,
                     SET_OF_BOOKS_ID,
                     MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (SET_OF_BOOKS_ID))                                     SEGMENT3,
                     FACTORY_CODE,
                     CUST_NAME,
                     DESCRIPTION,
                     CURRENCY_CODE,
                     RATE_CONVERSION (CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR'))) CONVERSION_RATE,
                     SUM (ENTERED_AMOUNT)                                                                                AS ENTERED_AMOUNT,
                     SUM (ACCOUNTED_AMOUNT)
                         AS ACCOUNTED_AMOUNT
                FROM (SELECT BOOK_TYPE_CODE,
                             A.DESCRIPTION,
                             G.SET_OF_BOOKS_ID,
                             BUDGET_TYPE,
                             CUST_NAME,
                             FACTORY_CODE,
                             DEPRN_AMOUNT,
                             CASE
                                 WHEN (BOOK_TYPE_CODE = 'CAB'
                                    OR BOOK_TYPE_CODE = 'MOH'
                                    OR BOOK_TYPE_CODE = 'IGI'
                                    OR BOOK_TYPE_CODE = 'ISL') THEN
                                     'USD'
                                 WHEN (BOOK_TYPE_CODE = 'CJY'
                                    OR BOOK_TYPE_CODE = 'CMZ'
                                    OR BOOK_TYPE_CODE = 'CJR') THEN
                                     'CNY'
                                 WHEN (BOOK_TYPE_CODE = 'VMK'
                                    OR BOOK_TYPE_CODE = 'VLR'
                                    OR BOOK_TYPE_CODE = 'VTP') THEN
                                     'VND'
                                 ELSE
                                     'USD'
                             END
                                 CURRENCY_CODE,
                             DEPRN_AMOUNT ENTERED_AMOUNT,
                             CASE
                                 WHEN (BOOK_TYPE_CODE = 'CAB'
                                    OR BOOK_TYPE_CODE = 'MOH'
                                    OR BOOK_TYPE_CODE = 'IGI'
                                    OR BOOK_TYPE_CODE = 'ISL') THEN
                                       DEPRN_AMOUNT
                                     * RATE_CONVERSION ('USD', 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')))
                                 WHEN (BOOK_TYPE_CODE = 'CJY'
                                    OR BOOK_TYPE_CODE = 'CMZ'
                                    OR BOOK_TYPE_CODE = 'CJR') THEN
                                       DEPRN_AMOUNT
                                     * RATE_CONVERSION ('CNY', 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')))
                                 WHEN (BOOK_TYPE_CODE = 'VMK'
                                    OR BOOK_TYPE_CODE = 'VLR'
                                    OR BOOK_TYPE_CODE = 'VTP') THEN
                                       DEPRN_AMOUNT
                                     * RATE_CONVERSION ('VND', 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')))
                                 ELSE
                                     0
                             END
                                 ACCOUNTED_AMOUNT
                        FROM APPS.MK_SD_DUMMY_DEPRN_AMT_V A, GL_SETS_OF_BOOKS G
                       WHERE 1 = 1
                         AND DECODE (A.BOOK_TYPE_CODE,
                                     'CAB', 'MPV',
                                     'MOH', 'MPV',
                                     'CJR', 'CPV',
                                     'CJY', 'CPV',
                                     'CMZ', 'CPV',
                                     'IGI', 'IPV',
                                     'ISL', 'IPV',
                                     'VMK', 'VPV',
                                     'VLR', 'VTX',
                                     'VTP', 'VTX',
                                     A.BOOK_TYPE_CODE) = G.SHORT_NAME
                         AND g.set_of_bookS_id = p_sob_id)
            --                         AND MK_GL_PUB.GET_MGMT_SOB_ID (G.SET_OF_BOOKS_ID) = P_SOB_ID)
            GROUP BY DESCRIPTION,
                     SET_OF_BOOKS_ID,
                     BUDGET_TYPE,
                     CUST_NAME,
                     FACTORY_CODE,
                     CURRENCY_CODE
              HAVING SUM (ACCOUNTED_AMOUNT) <> 0
            ORDER BY 2;

        LN_ORG_ID                  NUMBER;
        LC_USER_NAME               VARCHAR2 (100);
        LC_USER_JE_SOURCE_NAME     VARCHAR2 (255);
        LC_USER_JE_CATEGORY_NAME   VARCHAR2 (255);
        LC_PERIOD_NAME             VARCHAR2 (255);
        LC_BASE_CURRENCY_CODE      VARCHAR2 (15);
        LC_BATCH_NAME              VARCHAR2 (255);
        LN_SET_OF_BOOKS_ID         NUMBER;
        LN_GROUP_ID                NUMBER;
        LC_JOURNAL_ENTRY_NAME      VARCHAR2 (255);
        LN_REQ_ID                  NUMBER;
        X_DR_ACCT_CCID             NUMBER;
        X_CR_ACCT_CCID             NUMBER;
        LD_ACCOUNTING_DATE         DATE;
        X_ACCT_CATEGORY            VARCHAR2 (60);
        R_SOB                      GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE            VARCHAR2 (30) := 'FA SPEXP';
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);

        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        SELECT ORGANIZATION_ID
          INTO LN_ORG_ID
          FROM ORG_ORGANIZATION_DEFINITIONS
         WHERE ORGANIZATION_CODE = 'TPV';

        --取得  GROUP_ID,BATCH_NAME
        APPS.ATK_GL_COMMON_PKG.GET_COMMON_INFO (LN_ORG_ID,
                                                TO_DATE (P_PERIOD, 'MON-RR'),
                                                P_USER_ID,
                                                LC_USER_JE_SOURCE_NAME,
                                                LC_USER_JE_CATEGORY_NAME,
                                                LC_PERIOD_NAME,
                                                LC_BASE_CURRENCY_CODE,
                                                LC_BATCH_NAME,
                                                LN_SET_OF_BOOKS_ID,
                                                LN_GROUP_ID);
        LC_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
        LC_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);

        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'FA SPEXP'
        --                || '-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 18, 2)), '00')) + 1, 2, '0')
        --           INTO LC_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = LN_SET_OF_BOOKS_ID
        --            AND SUBSTR (NAME, 1, 17) LIKE G_PREFIX || 'FA SPEXP' || '-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --      END;
        --
        --      ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      SELECT G_PREFIX || 'FA SPEXP' || '-' || P_PERIOD || '-' || 'Dos-Accounting' || '/' || 'Transfer' INTO LC_BATCH_NAME FROM DUAL;
        SELECT TO_DATE (P_PERIOD, 'MON-YY') INTO LD_ACCOUNTING_DATE FROM DUAL;

        FOR AA IN JOU (P_PERIOD, P_SOB_ID) LOOP
            /*   DR.15.01.00000.XXXX.XX.000       依不同項目不同科目(SPECIAL:6235.04;Dummy:2178.28;工安專案:6235.01.092
              'Areen : 2020/2/6:   工安專案  6224.00.092 i/o 6235.01.092
                                             6235.04要到產區但不用ICP，因為是費用科目
              DR.15.01.09901.6235.04.000   PHL菲
             DR.15.01.09902.6235.04.000   CHN中
             DR.15.01.09910.6235.04.000  CAB柬
             DR.15.01.09915.6235.04.000   NVN北越
             DR.15.01.09909.6235.04.000   SVN-TPL
             DR.15.01.09909.6235.04.000   SVN-LR
             DR.15.01.09917.6235.04.000  IND印

                       CR.15.01.09901.2891.00.619   PHL菲
                       CR.15.01.09902.2891.00.669   CHN中
                       CR.15.01.09910.2891.00.629   CAB柬
                       CR.15.01.09915.2891.00.640   NVN北越
                       CR.15.01.09909.2891.00.650   SVN-TPL
                       CR.15.01.09909.2891.00.651   SVN-LR
                       CR.15.01.09917.2891.00.639   IND印
                       'Areen : 2020/1/3:為了解決客戶部門別&客人存續問題，修改統一都轉策略費用機台  Dummy:6235.04  可先不入客戶別資訊 */
            /*20220920自動化(訂單調節 產區.6235.04.000(策略費用.機台)改為00000.6224.00.009(折舊費用.智慧生產)-AngelaLin */
            /*Step1-處理借方  ;直接Assign CCID*/
            IF AA.BUDGET_TYPE = '092' THEN
                X_DR_ACCT_CCID := MK_GL_PUB.GET_CCID ('15.01.00000.6224.00.092');
            --                X_DR_ACCT_CCID := 158630;                                                                                   /*6224.00.092 */
            ELSIF AA.BUDGET_TYPE = '04' THEN
                X_DR_ACCT_CCID := MK_GL_PUB.GET_CCID ('15.01.00000.6224.00.009');
            --                X_DR_ACCT_CCID := 180722;                                                                       /* 15.01.00000.6224.00.009*/
            ELSE
                G_GCC.SEGMENT1 := '15';
                G_GCC.SEGMENT2 := '01';
                G_GCC.SEGMENT3 := AA.SEGMENT3;
                G_GCC.SEGMENT4 := '6235';
                G_GCC.SEGMENT5 := '04';
                G_GCC.SEGMENT6 := '000';

                G_GCC.CONCATENATED_SEGMENTS :=
                       G_GCC.SEGMENT1
                    || '.'
                    || G_GCC.SEGMENT2
                    || '.'
                    || G_GCC.SEGMENT3
                    || '.'
                    || G_GCC.SEGMENT4
                    || '.'
                    || G_GCC.SEGMENT5
                    || '.'
                    || G_GCC.SEGMENT6;
                X_DR_ACCT_CCID := MK_GL_PUB.GET_CCID (LN_SET_OF_BOOKS_ID, G_GCC.CONCATENATED_SEGMENTS, G_MSG);
            --                IF AA.ORIGIN_COUNTRY = 'PHL' THEN
            --                    x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09901.6235.04.000');
            --                --                    X_DR_ACCT_CCID := 150398;
            --                ELSIF AA.ORIGIN_COUNTRY = 'CHN' THEN
            --                    x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09902.6235.04.000');
            --                --                    X_DR_ACCT_CCID := 150449;
            --                ELSIF AA.ORIGIN_COUNTRY = 'CAB' THEN
            --                    x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09910.6235.04.000');
            --                --                    X_DR_ACCT_CCID := 150409;
            --                ELSIF AA.ORIGIN_COUNTRY = 'NVN' THEN
            --                    x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.6235.04.000');
            --                --                    X_DR_ACCT_CCID := 150401;
            --                ELSIF AA.ORIGIN_COUNTRY = 'SVN-TPL' THEN
            --                    x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.6235.04.000');
            --                --                    X_DR_ACCT_CCID := 150389;
            --                ELSIF AA.ORIGIN_COUNTRY = 'SVN-LR' THEN
            --                    x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.6235.04.000');
            --                --                    X_DR_ACCT_CCID := 150389;
            --                ELSIF AA.ORIGIN_COUNTRY = 'IND' THEN
            --                    x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09909.6235.04.000');
            --                --                    X_DR_ACCT_CCID := 150410;
            --                END IF;
            --
            --                x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.00000.6235.04.000');
            --            X_DR_ACCT_CCID:= 150640;
            END IF;

            --DR INSERT GL INTERFACE
            --            atk_gl_common_pkg.insert_gl_interface_all_curr
            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                          LC_JOURNAL_ENTRY_NAME,
                                          P_PERIOD,
                                          LC_USER_JE_SOURCE_NAME,
                                          LC_USER_JE_CATEGORY_NAME,
                                          AA.CURRENCY_CODE,                                                         --LC_BASE_CURRENCY_CODE,
                                          LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),
                                          AA.CONVERSION_RATE,
                                          X_DR_ACCT_CCID,
                                          AA.DESCRIPTION,
                                          LD_ACCOUNTING_DATE,
                                          P_USER_ID,
                                          LN_SET_OF_BOOKS_ID,
                                          LN_GROUP_ID,
                                          AA.ENTERED_AMOUNT,
                                          0,
                                          AA.ACCOUNTED_AMOUNT,
                                          0,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);
            /*Step2-處理貸方 ;直接Assign CCID*/
            G_GCC.SEGMENT4 := '2891';
            G_GCC.SEGMENT5 := '00';

            IF AA.ORIGIN_COUNTRY = 'SVN-TPL' THEN
                G_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (AA.SET_OF_BOOKS_ID), 'TPM', '64');
            ELSIF AA.ORIGIN_COUNTRY = 'SVN-LR' THEN
                G_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (AA.SET_OF_BOOKS_ID), 'TPM', '65');
            ELSE
                G_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (AA.SET_OF_BOOKS_ID), 'TPM', NULL);
            END IF;

            X_CR_ACCT_CCID := MK_GL_PUB.GET_CC_ID (G_GCC);
            --            IF AA.ORIGIN_COUNTRY = 'PHL' THEN
            --                x_Cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09901.2891.00.619');
            --            --                X_CR_ACCT_CCID := 118515;
            --            ELSIF AA.ORIGIN_COUNTRY = 'CHN' THEN
            --                x_Cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09902.2891.00.669');
            --            --                X_CR_ACCT_CCID := 120499;
            --            ELSIF AA.ORIGIN_COUNTRY = 'CAB' THEN
            --                x_Cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09910.2891.00.629');
            --            --                X_CR_ACCT_CCID := 118511;
            --            ELSIF AA.ORIGIN_COUNTRY = 'NVN' THEN
            --                x_Cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.2891.00.640');
            --            --                X_CR_ACCT_CCID := 118513;
            --            ELSIF AA.ORIGIN_COUNTRY = 'SVN-TPL' THEN
            --                x_Cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.2891.00.650');
            --            --                X_CR_ACCT_CCID := 118514;
            --            ELSIF AA.ORIGIN_COUNTRY = 'SVN-LR' THEN
            --                x_Cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.2891.00.651');
            --            --                X_CR_ACCT_CCID := 133832;
            --            ELSIF AA.ORIGIN_COUNTRY = 'IND' THEN
            --                x_Cr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09905.2891.00.639');
            --            --                X_CR_ACCT_CCID := 118776;
            --            END IF;
            -- CR INSERT GL INTERFACE
            --            atk_gl_common_pkg.insert_gl_interface_all_curr
            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                          LC_JOURNAL_ENTRY_NAME,
                                          P_PERIOD,
                                          LC_USER_JE_SOURCE_NAME,
                                          LC_USER_JE_CATEGORY_NAME,
                                          AA.CURRENCY_CODE,                                                         --LC_BASE_CURRENCY_CODE,
                                          LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),
                                          AA.CONVERSION_RATE,
                                          X_CR_ACCT_CCID,
                                          AA.DESCRIPTION,
                                          LD_ACCOUNTING_DATE,
                                          P_USER_ID,
                                          LN_SET_OF_BOOKS_ID,
                                          LN_GROUP_ID,
                                          0,
                                          AA.ENTERED_AMOUNT,
                                          0,
                                          AA.ACCOUNTED_AMOUNT,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);
            COMMIT;
        END LOOP;

        FOR BB IN JOU_MTM (P_PERIOD, P_SOB_ID) LOOP
            /*   DR.15.01.09901.XXXX.XX.000       機台租借費用6235.04
                       15.01.09902.XXXX.XX.000
                       15.01.09910.XXXX.XX.000
                       15.01.09915.XXXX.XX.000
                       15.01.09909.XXXX.XX.000
                       15.01.09917.XXXX.XX.000
                                       CR.15.01.09901.2891.00.619   PHL菲
                                       CR.15.01.09902.2891.00.669   CHN中
                                       CR.15.01.09910.2891.00.629   CAB柬
                                       CR.15.01.09915.2891.00.640   NVN北越
                                       CR.15.01.09909.2891.00.650   SVN-TPL
                                       CR.15.01.09909.2891.00.651   SVN-LR
                                       CR.15.01.09917.2891.00.639   IND印             */
            /*Step1-處理借方  ;依產區直接Assign CCID*/
            G_GCC.SEGMENT1 := '15';
            G_GCC.SEGMENT2 := '01';
            G_GCC.SEGMENT3 := BB.SEGMENT3;
            G_GCC.SEGMENT4 := '6235';
            G_GCC.SEGMENT5 := '04';
            G_GCC.SEGMENT6 := '000';
            X_DR_ACCT_CCID := MK_GL_PUB.GET_CC_ID (G_GCC);
            --            IF BB.ORIGIN_COUNTRY = 'PHL' THEN
            --                x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09901.6235.04.000');
            --            --                X_DR_ACCT_CCID := 150398;
            --            ELSIF BB.ORIGIN_COUNTRY = 'CHN' THEN
            --                x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09902.6235.04.000');
            --            --                X_DR_ACCT_CCID := 150449;
            --            ELSIF BB.ORIGIN_COUNTRY = 'CAB' THEN
            --                x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09910.6235.04.000');
            --            --                X_DR_ACCT_CCID := 150409;
            --            ELSIF BB.ORIGIN_COUNTRY = 'NVN' THEN
            --                x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.6235.04.000');
            --            --                X_DR_ACCT_CCID := 150401;
            --            ELSIF BB.ORIGIN_COUNTRY = 'SVN-TPL' THEN
            --                x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.6235.04.000');
            --            --                X_DR_ACCT_CCID := 150389;
            --            ELSIF BB.ORIGIN_COUNTRY = 'SVN-LR' THEN
            --                x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09915.6235.04.000');
            --            --                X_DR_ACCT_CCID := 150389;
            --            ELSIF BB.ORIGIN_COUNTRY = 'IND' THEN
            --                x_Dr_acct_ccid := mk_gl_pub.get_ccid ('15.01.09905.6235.04.000');
            --            --                X_DR_ACCT_CCID := 150410;
            --            END IF;
            --DR INSERT GL INTERFACE
            --            atk_gl_common_pkg.insert_gl_interface_all_curr
            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                          LC_JOURNAL_ENTRY_NAME,
                                          P_PERIOD,
                                          LC_USER_JE_SOURCE_NAME,
                                          LC_USER_JE_CATEGORY_NAME,
                                          BB.CURRENCY_CODE,                                                         --LC_BASE_CURRENCY_CODE,
                                          LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),
                                          BB.CONVERSION_RATE,
                                          X_DR_ACCT_CCID,
                                          BB.DESCRIPTION,
                                          LD_ACCOUNTING_DATE,
                                          P_USER_ID,
                                          LN_SET_OF_BOOKS_ID,
                                          LN_GROUP_ID,
                                          BB.ENTERED_AMOUNT,
                                          0,
                                          BB.ACCOUNTED_AMOUNT,
                                          0,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);
            /*Step2-處理貸方 ;直接Assign CCID*/
            G_GCC.SEGMENT4 := '2891';
            G_GCC.SEGMENT5 := '00';

            IF BB.ORIGIN_COUNTRY = 'SVN-TPL' THEN
                G_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (BB.SET_OF_BOOKS_ID), 'TPM', '64');
            ELSIF BB.ORIGIN_COUNTRY = 'SVN-LR' THEN
                G_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (BB.SET_OF_BOOKS_ID), 'TPM', '65');
            ELSE
                G_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (BB.SET_OF_BOOKS_ID), 'TPM', NULL);
            END IF;

            X_CR_ACCT_CCID := MK_GL_PUB.GET_CC_ID (G_GCC);
            --            IF BB.ORIGIN_COUNTRY = 'PHL' THEN
            --                X_CR_ACCT_CCID := 118515;
            --            ELSIF BB.ORIGIN_COUNTRY = 'CHN' THEN
            --                X_CR_ACCT_CCID := 120499;
            --            ELSIF BB.ORIGIN_COUNTRY = 'CAB' THEN
            --                X_CR_ACCT_CCID := 118511;
            --            ELSIF BB.ORIGIN_COUNTRY = 'NVN' THEN
            --                X_CR_ACCT_CCID := 118513;
            --            ELSIF BB.ORIGIN_COUNTRY = 'SVN-TPL' THEN
            --                X_CR_ACCT_CCID := 118514;
            --            ELSIF BB.ORIGIN_COUNTRY = 'SVN-LR' THEN
            --                X_CR_ACCT_CCID := 133832;
            --            ELSIF BB.ORIGIN_COUNTRY = 'IND' THEN
            --                X_CR_ACCT_CCID := 118776;
            --            END IF;
            -- CR INSERT GL INTERFACE
            --            atk_gl_common_pkg.insert_gl_interface_all_curr
            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                          LC_JOURNAL_ENTRY_NAME,
                                          P_PERIOD,
                                          LC_USER_JE_SOURCE_NAME,
                                          LC_USER_JE_CATEGORY_NAME,
                                          BB.CURRENCY_CODE,                                                         --LC_BASE_CURRENCY_CODE,
                                          LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),
                                          BB.CONVERSION_RATE,
                                          X_CR_ACCT_CCID,
                                          BB.DESCRIPTION,
                                          LD_ACCOUNTING_DATE,
                                          P_USER_ID,
                                          LN_SET_OF_BOOKS_ID,
                                          LN_GROUP_ID,
                                          0,
                                          BB.ENTERED_AMOUNT,
                                          0,
                                          BB.ACCOUNTED_AMOUNT,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);
            COMMIT;
        END LOOP;

        FOR CC IN JOU_DUMMY (P_PERIOD, P_SOB_ID) LOOP
            /*   DR.15.01.00000.2178.28.000
                       CR.15.01.09901.6235.04.000   PHL菲
                       CR.15.01.09902.6235.04.000   CHN中
                       CR.15.01.09910.6235.04.000  CAB柬
                       CR.15.01.09915.6235.04.000   NVN北越
                      CR.15.01.09909.6235.04.000   SVN-TPL
                      CR.15.01.09909.6235.04.000   SVN-LR
                      CR.15.01.09917.6235.04.000  IND印          策略費用-機台 (分產區)*/
            /*Step1-處理借方  ;直接Assign CCID*/
            X_DR_ACCT_CCID := MK_GL_PUB.GET_CCID ('15.01.00000.2178.28.000');
            --            X_DR_ACCT_CCID := 123532;
            X_ACCT_CATEGORY := '06其他';
            --DR INSERT GL INTERFACE
            --            atk_gl_common_pkg.insert_gl_interface_all_curr
            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                          LC_JOURNAL_ENTRY_NAME,
                                          P_PERIOD,
                                          LC_USER_JE_SOURCE_NAME,
                                          LC_USER_JE_CATEGORY_NAME,
                                          CC.CURRENCY_CODE,                                                         --LC_BASE_CURRENCY_CODE,
                                          LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),
                                          CC.CONVERSION_RATE,
                                          X_DR_ACCT_CCID,
                                          CC.DESCRIPTION,
                                          LD_ACCOUNTING_DATE,
                                          P_USER_ID,
                                          LN_SET_OF_BOOKS_ID,
                                          LN_GROUP_ID,
                                          CC.ENTERED_AMOUNT,
                                          0,
                                          CC.ACCOUNTED_AMOUNT,
                                          0,
                                          NULL,
                                          NULL,
                                          CC.CUST_NAME,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          X_ACCT_CATEGORY,
                                          NULL);
            /*Step2-處理貸方 ;直接Assign CCID*/
            G_GCC.SEGMENT1 := '15';
            G_GCC.SEGMENT2 := '01';
            G_GCC.SEGMENT3 := CC.SEGMENT3;
            G_GCC.SEGMENT4 := '6235';
            G_GCC.SEGMENT5 := '04';
            G_GCC.SEGMENT6 := '000';
            X_CR_ACCT_CCID := MK_GL_PUB.GET_CC_ID (G_GCC);
            --            IF CC.ORIGIN_DISTRICT = 'PHL' THEN
            --                X_CR_ACCT_CCID := 150398;
            --            ELSIF CC.ORIGIN_DISTRICT = 'CHN' THEN
            --                X_CR_ACCT_CCID := 150449;
            --            ELSIF CC.ORIGIN_DISTRICT = 'CAB' THEN
            --                X_CR_ACCT_CCID := 150409;
            --            ELSIF CC.ORIGIN_DISTRICT = 'NVN' THEN
            --                X_CR_ACCT_CCID := 150401;
            --            ELSIF CC.ORIGIN_DISTRICT = 'SVN-TPL' THEN
            --                X_CR_ACCT_CCID := 150389;
            --            ELSIF CC.ORIGIN_DISTRICT = 'SVN-LR' THEN
            --                X_CR_ACCT_CCID := 150389;
            --            ELSIF CC.ORIGIN_DISTRICT = 'SMG' THEN
            --                X_CR_ACCT_CCID := 150410;
            --            END IF;
            -- CR INSERT GL INTERFACE
            --            atk_gl_common_pkg.insert_gl_interface_all_curr
            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                          LC_JOURNAL_ENTRY_NAME,
                                          P_PERIOD,
                                          LC_USER_JE_SOURCE_NAME,
                                          LC_USER_JE_CATEGORY_NAME,
                                          CC.CURRENCY_CODE,                                                         --LC_BASE_CURRENCY_CODE,
                                          LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),
                                          CC.CONVERSION_RATE,
                                          X_CR_ACCT_CCID,
                                          CC.DESCRIPTION,
                                          LD_ACCOUNTING_DATE,
                                          P_USER_ID,
                                          LN_SET_OF_BOOKS_ID,
                                          LN_GROUP_ID,
                                          0,
                                          CC.ENTERED_AMOUNT,
                                          0,
                                          CC.ACCOUNTED_AMOUNT,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);
            COMMIT;
        END LOOP;

        FOR DD IN SD_DUMMY (P_PERIOD, P_SOB_ID) LOOP
            /*   DR.策略費用機台15.01.00000.6235.04 .000 (X) AREEN 20200604 DR分產區別
                 DR.15.01.09909.6235.04.000   SVN
                 DR.15.01.09910.6235.04.000  CAB柬
                 DR.15.01.09902.6235.04.000   CHN中
                          CR. 15.01.S5000.6124.00.000   南越樣品中心 (x) AREEN 20221229 不再拋轉 by Jimbo
                              15.01.S3000.6124.00.000   柬樣品中心
                              15.01.S7000.6124.00.000   滬辦樣品中心    */
            /*Step1-處理借方  ;直接Assign CCID*/
            G_GCC.SEGMENT1 := '15';
            G_GCC.SEGMENT2 := '01';
            G_GCC.SEGMENT3 := DD.SEGMENT3;
            G_GCC.SEGMENT4 := '6235';
            G_GCC.SEGMENT5 := '04';
            G_GCC.SEGMENT6 := '000';
            X_DR_ACCT_CCID := MK_GL_PUB.GET_CC_ID (G_GCC);
            --X_DR_ACCT_CCID:= 150640;
            --            IF DD.FACTORY_CODE = 'CAB-SD' THEN
            --                X_DR_ACCT_CCID := 150409;
            --            ELSIF DD.FACTORY_CODE = 'CHN-JYSD' THEN
            --                X_DR_ACCT_CCID := 150449;
            --            ELSIF DD.FACTORY_CODE = 'SVN-TPSD' THEN
            --                X_DR_ACCT_CCID := 150389;
            --            END IF;
            --DR INSERT GL INTERFACE
            --            atk_gl_common_pkg.insert_gl_interface_all_curr
            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                          LC_JOURNAL_ENTRY_NAME,
                                          P_PERIOD,
                                          LC_USER_JE_SOURCE_NAME,
                                          LC_USER_JE_CATEGORY_NAME,
                                          DD.CURRENCY_CODE,                                                         --LC_BASE_CURRENCY_CODE,
                                          LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),
                                          DD.CONVERSION_RATE,
                                          X_DR_ACCT_CCID,
                                          DD.DESCRIPTION,
                                          LD_ACCOUNTING_DATE,
                                          P_USER_ID,
                                          LN_SET_OF_BOOKS_ID,
                                          LN_GROUP_ID,
                                          DD.ENTERED_AMOUNT,
                                          0,
                                          DD.ACCOUNTED_AMOUNT,
                                          0,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);

            /*Step2-處理貸方 ;直接Assign CCID*/
            IF DD.FACTORY_CODE = 'CAB-SD' THEN
                X_CR_ACCT_CCID := 148853;
            ELSIF DD.FACTORY_CODE = 'CHN-JYSD' THEN
                X_CR_ACCT_CCID := 159278;
            ELSIF DD.FACTORY_CODE = 'SVN-TPSD' THEN
                X_CR_ACCT_CCID := 148978;
            END IF;

            -- CR INSERT GL INTERFACE
            --            atk_gl_common_pkg.insert_gl_interface_all_curr
            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                          LC_JOURNAL_ENTRY_NAME,
                                          P_PERIOD,
                                          LC_USER_JE_SOURCE_NAME,
                                          LC_USER_JE_CATEGORY_NAME,
                                          DD.CURRENCY_CODE,                                                         --LC_BASE_CURRENCY_CODE,
                                          LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),
                                          DD.CONVERSION_RATE,
                                          X_CR_ACCT_CCID,
                                          DD.DESCRIPTION,
                                          LD_ACCOUNTING_DATE,
                                          P_USER_ID,
                                          LN_SET_OF_BOOKS_ID,
                                          LN_GROUP_ID,
                                          0,
                                          DD.ENTERED_AMOUNT,
                                          0,
                                          DD.ACCOUNTED_AMOUNT,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL,
                                          NULL);
            COMMIT;
        END LOOP;

        -- Run Journal Import
        LN_REQ_ID := ATK_GL_COMMON_PKG.INSERT_GL_CONTROL (LN_SET_OF_BOOKS_ID, P_USER_ID, LN_GROUP_ID);

        IF LN_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('TPV-特殊 Failure!! GROUP ID:' || LN_GROUP_ID);
            RETURN ' TPV-特殊 Failure!! GROUP ID:' || LN_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('TPV-特殊 Success!! Concurrent ID:' || LN_REQ_ID);
            RETURN 'TPV-特殊 Success!! Concurrent ID:' || LN_REQ_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'TPV-特殊 Error:' || SQLERRM;
    END IMP_FA_SPECIAL_EXP_TPE;

    FUNCTION IMP_INSPECTION_FEE_FAC (P_PERIOD VARCHAR2, P_SOB_ID NUMBER)
        RETURN VARCHAR2 IS
        --產區稅轉管(非GU & GU）非GU 填STYLE/ GU 不填STYLE填GU-A 或GU-B  -inspection fee
        CURSOR JOU (
            P_PERIOD    VARCHAR2,
            P_SOB_ID    NUMBER) IS
              SELECT JL.JE_HEADER_ID,
                     JH.NAME,
                     JL.SET_OF_BOOKS_ID,
                     JL.CODE_COMBINATION_ID                                                AS CR_CCID,
                     JH.CURRENCY_CODE                                                      AS CURRENCY_CODE,
                     SUM (NVL (JL.ENTERED_DR, 0) - NVL (JL.ENTERED_CR, 0))                 AS AMOUNT,
                     GCC.SEGMENT1,
                     GCC.SEGMENT2,
                     GCC.SEGMENT3,
                     GCC.SEGMENT4,
                     GCC.SEGMENT5,
                     GCC.SEGMENT6,
                     JL.ATTRIBUTE2                                                         AS STYLE,
                     GB.SHORT_NAME,
                     GBM.SHORT_NAME                                                        AS TARGET_BOOK,
                     NVL (
                         DECODE (C.CUST_CODE,
                                 'KOH', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'TGT', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'GAP', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'ONY', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'GOT', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'V1D', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'V2D', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'V3D', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'V4D', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'V5D', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'SMC', 'S1D',
                                 C.CUST_CODE),
                         C.CUST_CODE)
                         AS CUST_NAME,
                     GB.SHORT_NAME || ' ' || 'INSPECT FEE' || ' ' || SUBSTR (JH.NAME, 1, 20) AS DESCRIPTION
                FROM GL_JE_HEADERS         JH,
                     GL_JE_LINES           JL,
                     GL_CODE_COMBINATIONS_V GCC,
                     GL_JE_CATEGORIES_TL   JC,
                     GL_SETS_OF_BOOKS      GB,
                     GL_SETS_OF_BOOKS      GBM,
                     APPS.ATK_OE_STYLE_V   OE,
                     ACP_OE_HEADERS_DFF    ACP,
                     MK_CUSTOMER_DEPT_ALL  C
               WHERE JH.JE_HEADER_ID = JL.JE_HEADER_ID
                 AND JH.JE_CATEGORY = JC.JE_CATEGORY_NAME
                 AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                 AND GCC.SEGMENT3 NOT IN ('26162', '25162', '25562')                      --Add by Jimbo 2020/09/15排除GU部門(下方IMP_GQC_FEE_XXX)
                 --              AND GCC.SEGMENT3 NOT IN ('31101', '31161', '31361')                                                      --Add by Jimbo 2020/12/04排除指定部門
                 AND GCC.SEGMENT3 IN (SELECT DEPT_CODE
                                        FROM MK_GL_DEPTS
                                       WHERE 1 = 1
                                         AND PARENT_ID IS NOT NULL
                                         AND PRIOR_FLAG = 'Y'
                                         AND ACTIVE_FLAG = 'Y')                                         --Add by Jimbo 2020/12/23 僅抓取本廠Maker
                 AND GCC.SEGMENT4 || '.' || GCC.SEGMENT5 = '6144.00'
                 AND JH.PERIOD_NAME = P_PERIOD
                 AND JH.STATUS = NVL (G_STATUS, JH.STATUS)
                 AND JH.SET_OF_BOOKS_ID = GB.SET_OF_BOOKS_ID
                 --              AND JH.SET_OF_BOOKS_ID = P_SOB_ID                                                                        --Add by Jimbo 2020/12/30 抓產區稅帳
                 AND DECODE (GB.SHORT_NAME,
                             'CAM', 'MPV',
                             'MOH', 'MPV',
                             'CMK', 'CPV',
                             'CJR', 'CPV',
                             'CJY', 'CPV',
                             'CMZ', 'CPV',
                             'IGI', 'IPV',
                             'ISL-US', 'IPV',
                             'VMK', 'VPV',
                             'VLR', 'VTX',
                             'VTP', 'VTX',
                             'XXX') = GBM.SHORT_NAME
                 AND GBM.SET_OF_BOOKS_ID = P_SOB_ID                                                      --Marked by Jimbo 2020/12/30 改抓產區稅帳
                 AND (JL.ATTRIBUTE3 IS NULL
                   OR JL.ATTRIBUTE3 NOT LIKE 'GU%')                                                                                   --排除GU
                 AND JL.ATTRIBUTE2 = OE.STYLE
                 AND OE.OE_FOLDERID = ACP.OE_FOLDERID
                 AND ACP.CUST_NAME = C.CUSTOMER(+)
                 AND ACP.SUB_GROUP = C.SUBGROUP(+)
                 AND C.L3 IS NOT NULL
                 AND C.ENABLE = 'Y'
            GROUP BY JL.JE_HEADER_ID,
                     JH.NAME,
                     JL.SET_OF_BOOKS_ID,
                     JL.CODE_COMBINATION_ID,
                     GB.SHORT_NAME,
                     JH.CURRENCY_CODE,
                     GCC.SEGMENT1,
                     GCC.SEGMENT2,
                     GCC.SEGMENT3,
                     GCC.SEGMENT4,
                     GCC.SEGMENT5,
                     GCC.SEGMENT6,
                     JL.ATTRIBUTE2,
                     GB.SHORT_NAME,
                     GBM.SHORT_NAME,
                     C.CUST_CODE,
                     C.L3
            UNION ALL
              -- 產區稅轉管(GU）-inspection fee
              SELECT JL.JE_HEADER_ID,
                     JH.NAME,
                     JL.SET_OF_BOOKS_ID,
                     JL.CODE_COMBINATION_ID                                                AS CR_CCID,
                     JH.CURRENCY_CODE                                                      AS CURRENCY_CODE,
                     SUM (NVL (JL.ENTERED_DR, 0) - NVL (JL.ENTERED_CR, 0))                 AS AMOUNT,
                     GCC.SEGMENT1,
                     GCC.SEGMENT2,
                     GCC.SEGMENT3,
                     GCC.SEGMENT4,
                     GCC.SEGMENT5,
                     GCC.SEGMENT6,
                     NULL                                                                  AS STYLE,
                     GB.SHORT_NAME,
                     GBM.SHORT_NAME                                                        AS TARGET_BOOK,
                     JL.ATTRIBUTE3                                                         AS CUST_NAME,
                     GB.SHORT_NAME || ' ' || 'INSPECT FEE' || ' ' || SUBSTR (JH.NAME, 1, 20) AS DESCRIPTION
                FROM GL_JE_HEADERS         JH,
                     GL_JE_LINES           JL,
                     GL_CODE_COMBINATIONS_V GCC,
                     GL_JE_CATEGORIES_TL   JC,
                     GL_SETS_OF_BOOKS      GB,
                     GL_SETS_OF_BOOKS      GBM
               WHERE JH.JE_HEADER_ID = JL.JE_HEADER_ID
                 AND JH.JE_CATEGORY = JC.JE_CATEGORY_NAME
                 AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                 AND GCC.SEGMENT3 IN (SELECT DEPT_CODE
                                        FROM MK_GL_DEPTS
                                       WHERE 1 = 1
                                         AND PARENT_ID IS NOT NULL
                                         AND PRIOR_FLAG = 'Y'
                                         AND ACTIVE_FLAG = 'Y')                                         --Add by Jimbo 2020/12/23 僅抓取本廠Maker
                 AND GCC.SEGMENT4 || '.' || GCC.SEGMENT5 = '6144.00'
                 AND JH.PERIOD_NAME = P_PERIOD
                 AND JH.STATUS = NVL (G_STATUS, JH.STATUS)
                 AND JH.SET_OF_BOOKS_ID = GB.SET_OF_BOOKS_ID
                 AND DECODE (GB.SHORT_NAME,
                             'CAM', 'MPV',
                             'MOH', 'MPV',
                             'CMK', 'CPV',
                             'CJR', 'CPV',
                             'CJY', 'CPV',
                             'CMZ', 'CPV',
                             'IGI', 'IPV',
                             'ISL-US', 'IPV',
                             'VMK', 'VPV',
                             'VLR', 'VTX',
                             'VTP', 'VTX',
                             'XXX') = GBM.SHORT_NAME
                 AND GBM.SET_OF_BOOKS_ID = P_SOB_ID
                 AND JL.ATTRIBUTE3 LIKE 'GU%'
            GROUP BY JL.JE_HEADER_ID,
                     JH.NAME,
                     JL.SET_OF_BOOKS_ID,
                     JL.CODE_COMBINATION_ID,
                     GB.SHORT_NAME,
                     JH.CURRENCY_CODE,
                     GCC.SEGMENT1,
                     GCC.SEGMENT2,
                     GCC.SEGMENT3,
                     GCC.SEGMENT4,
                     GCC.SEGMENT5,
                     GCC.SEGMENT6,
                     JL.ATTRIBUTE3,
                     GB.SHORT_NAME,
                     GBM.SHORT_NAME
            ORDER BY 1;

        LN_ORG_ID                  NUMBER;
        LC_USER_NAME               VARCHAR2 (100);
        LC_USER_JE_SOURCE_NAME     VARCHAR2 (255);
        LC_USER_JE_CATEGORY_NAME   VARCHAR2 (255);
        LC_PERIOD_NAME             VARCHAR2 (255);
        LC_BASE_CURRENCY_CODE      VARCHAR2 (15);
        LC_BATCH_NAME              VARCHAR2 (255);
        LN_SET_OF_BOOKS_ID         NUMBER;
        LN_GROUP_ID                NUMBER;
        LC_JOURNAL_ENTRY_NAME      VARCHAR2 (255);
        LD_ACCOUNTING_DATE         DATE;
        LN_REQ_ID                  NUMBER;
        X_DR_ACCT_CCID             NUMBER;
        X_CR_ACCT_CCID             NUMBER;
        R_SOB                      GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE            VARCHAR2 (30) := 'INSPECT FEE';
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);
        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        LC_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
        LC_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
        G_ERR_STRING := '1.0';

        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'INSPECT FEE'
        --                || '-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 21, 2)), '00')) + 1, 2, '0')
        --           INTO LC_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = P_SOB_ID
        --            AND SUBSTR (NAME, 1, 20) LIKE G_PREFIX || 'INSPECT FEE' || '-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --      END;
        --
        --      ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      SELECT G_PREFIX || 'INSPECT FEE' || '-' || P_PERIOD || '-' || 'Dos-Accounting' || '/' || 'Transfer' INTO LC_BATCH_NAME FROM DUAL;
        SELECT GL_INTERFACE_CONTROL_S.NEXTVAL INTO LN_GROUP_ID FROM DUAL;

        SELECT TO_DATE (P_PERIOD, 'MON-RR') INTO LD_ACCOUNTING_DATE FROM DUAL;

        G_ERR_STRING := '1.1';

        FOR AA IN JOU (P_PERIOD, P_SOB_ID) LOOP
            IF AA.AMOUNT >= 0 THEN                                                                                                   --費用在借方
                /*   Dr: 產區部門.2891.00.ICP
                           CR.:6144.00.專案別    (彈性欄位style/customer)

                     /*Step1-處理借方 */
                BEGIN
                    IF AA.TARGET_BOOK = 'IPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '635';                                                                                  -- TPV-SMG
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 132117;                                                                /*43.01.25000.2891.00.635*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'MPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '628';                                                                                  -- TPV-CAB
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 121446;                                                                /*58.01.31000.2891.00.628*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'VPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '63'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '649';                                                                                  -- TPV-NVN
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 89302;                                                                 /*63.01.36100.2891.00.000*/
                END;

                BEGIN
                    IF (AA.TARGET_BOOK = 'VTX'
                    AND AA.SHORT_NAME = 'VTP') THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '64'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '659';                                                                                  -- TPV-SVN
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 149758;                                                                /*64.01.37000.2891.00.659*/
                END;

                BEGIN
                    IF (AA.TARGET_BOOK = 'VTX'
                    AND AA.SHORT_NAME = 'VLR') THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '659';                                                                                  -- TPV-SVN
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 157573;                                                                /*65.01.38000.2891.00.659*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'CPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '35'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '668';                                                                                  -- TPV-CHN
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 119951;                                                                /*35.01.11000.2891.00.668*/
                END;

                --DR INSERT GL INTERFACE
                ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (LC_BATCH_NAME,
                                                           LC_JOURNAL_ENTRY_NAME,
                                                           P_PERIOD,
                                                           'Dos-Accounting',
                                                           'Transfer',
                                                           AA.CURRENCY_CODE,
                                                           X_DR_ACCT_CCID,
                                                           AA.DESCRIPTION,
                                                           LD_ACCOUNTING_DATE,
                                                           P_USER_ID,
                                                           P_SOB_ID,
                                                           LN_GROUP_ID,
                                                           AA.AMOUNT,
                                                           0,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL);

                /*Step2-處理貸方  CR.:6144.00.專案別 */
                BEGIN
                    IF AA.TARGET_BOOK = 'IPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 138979;                                                                /*43.01.25000.6144.00.000*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'MPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 161079;                                                                /*58.01.31000.6144.00.000*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'VPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '63'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 89663;                                                                 /*63.01.36100.6144.00.000*/
                END;

                BEGIN
                    IF (AA.TARGET_BOOK = 'VTX'
                    AND AA.SHORT_NAME = 'VTP') THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '64'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 88113;                                                                 /*64.01.37100.6144.00.000*/
                END;

                BEGIN
                    IF (AA.TARGET_BOOK = 'VTX'
                    AND AA.SHORT_NAME = 'VLR') THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 153703;                                                                /*65.01.38000.6144.00.000*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'CPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '35'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 89059;                                                                 /*35.01.11000.6144.00.000*/
                END;

                -- CR INSERT GL INTERFACE
                ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (LC_BATCH_NAME,
                                                           LC_JOURNAL_ENTRY_NAME,
                                                           P_PERIOD,
                                                           'Dos-Accounting',
                                                           'Transfer',
                                                           AA.CURRENCY_CODE,
                                                           X_CR_ACCT_CCID,
                                                           AA.DESCRIPTION,
                                                           LD_ACCOUNTING_DATE,
                                                           P_USER_ID,
                                                           P_SOB_ID,
                                                           LN_GROUP_ID,
                                                           0,
                                                           AA.AMOUNT,
                                                           NULL,
                                                           AA.STYLE,
                                                           AA.CUST_NAME,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL);
                COMMIT;
            ELSE                                                                                                                     --費用在貸方
                /*   Dr: 6144.00.專案別    (彈性欄位style/customer)
                         CR.: 產區部門.2891.00.ICP

                        /*Step1-處理借方  DR.:6144.00.專案別 */
                BEGIN
                    IF AA.TARGET_BOOK = 'IPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 138979;                                                                /*43.01.25000.6144.00.000*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'MPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 161079;                                                                /*58.01.31000.6144.00.000*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'VPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '63'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 89663;                                                                 /*63.01.36100.6144.00.000*/
                END;

                BEGIN
                    IF (AA.TARGET_BOOK = 'VTX'
                    AND AA.SHORT_NAME = 'VTP') THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '64'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 88113;                                                                 /*64.01.37100.6144.00.000*/
                END;

                BEGIN
                    IF (AA.TARGET_BOOK = 'VTX'
                    AND AA.SHORT_NAME = 'VLR') THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 153703;                                                                /*65.01.38000.6144.00.000*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'CPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_DR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '35'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = AA.SEGMENT4
                           AND SEGMENT5 = AA.SEGMENT5
                           AND SEGMENT6 = AA.SEGMENT6;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_DR_ACCT_CCID := 89059;                                                                 /*35.01.11000.6144.00.000*/
                END;

                -- DR INSERT GL INTERFACE
                ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (LC_BATCH_NAME,
                                                           LC_JOURNAL_ENTRY_NAME,
                                                           P_PERIOD,
                                                           'Dos-Accounting',
                                                           'Transfer',
                                                           AA.CURRENCY_CODE,
                                                           X_DR_ACCT_CCID,
                                                           AA.DESCRIPTION,
                                                           LD_ACCOUNTING_DATE,
                                                           P_USER_ID,
                                                           P_SOB_ID,
                                                           LN_GROUP_ID,
                                                           AA.AMOUNT * (-1),
                                                           0,
                                                           NULL,
                                                           AA.STYLE,
                                                           AA.CUST_NAME,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL);

                /*Step2-處理貸方 */
                BEGIN
                    IF AA.TARGET_BOOK = 'IPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '635';                                                                                  -- TPV-SMG
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 132117;                                                                /*43.01.25000.2891.00.635*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'MPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '628';                                                                                  -- TPV-CAB
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 121446;                                                                /*58.01.31000.2891.00.628*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'VPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '63'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '649';                                                                                  -- TPV-NVN
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 89302;                                                                 /*63.01.36100.2891.00.000*/
                END;

                BEGIN
                    IF (AA.TARGET_BOOK = 'VTX'
                    AND AA.SHORT_NAME = 'VTP') THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '64'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '659';                                                                                  -- TPV-SVN
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 149758;                                                                /*64.01.37000.2891.00.659*/
                END;

                BEGIN
                    IF (AA.TARGET_BOOK = 'VTX'
                    AND AA.SHORT_NAME = 'VLR') THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = AA.SEGMENT1
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '659';                                                                                  -- TPV-SVN
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 157573;                                                                /*65.01.38000.2891.00.659*/
                END;

                BEGIN
                    IF AA.TARGET_BOOK = 'CPV' THEN
                        SELECT CODE_COMBINATION_ID
                          INTO X_CR_ACCT_CCID
                          FROM GL_CODE_COMBINATIONS_V
                         WHERE SEGMENT1 = '35'
                           AND SEGMENT2 = AA.SEGMENT2
                           AND SEGMENT3 = AA.SEGMENT3
                           AND SEGMENT4 = '2891'
                           AND SEGMENT5 = '00'
                           AND SEGMENT6 = '668';                                                                                  -- TPV-CHN
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        X_CR_ACCT_CCID := 119951;                                                                /*35.01.11000.2891.00.668*/
                END;

                --CR INSERT GL INTERFACE
                ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL (LC_BATCH_NAME,
                                                           LC_JOURNAL_ENTRY_NAME,
                                                           P_PERIOD,
                                                           'Dos-Accounting',
                                                           'Transfer',
                                                           AA.CURRENCY_CODE,
                                                           X_CR_ACCT_CCID,
                                                           AA.DESCRIPTION,
                                                           LD_ACCOUNTING_DATE,
                                                           P_USER_ID,
                                                           P_SOB_ID,
                                                           LN_GROUP_ID,
                                                           0,
                                                           AA.AMOUNT * (-1),
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL,
                                                           NULL);
                COMMIT;
            END IF;
        END LOOP;

        G_ERR_STRING := '1.2';
        -- Run Journal Import
        LN_REQ_ID := ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE (P_SOB_ID, P_USER_ID, LN_GROUP_ID, 'Dos-Accounting');

        IF LN_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('FAC 驗貨費 Failure!! GROUP ID:' || LN_GROUP_ID);
            RETURN 'FAC 驗貨費 Failure!! GROUP ID:' || LN_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('FAC 驗貨費 Success!! Concurrent ID:' || LN_REQ_ID);
            RETURN 'FAC 驗貨費 Success!! Concurrent ID:' || LN_REQ_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 'FAC 驗貨費 Error:' || G_ERR_STRING || '-' || SQLERRM;
    END IMP_INSPECTION_FEE_FAC;

    ----------------------------------------------------------------------------------------------------------------------------------------------------
    FUNCTION IMP_INSPECTION_FEE_TPE (P_PERIOD VARCHAR2, P_SOB_ID NUMBER DEFAULT NULL)
        RETURN VARCHAR2 IS
        CURSOR JOU (
            P_PERIOD    VARCHAR2,
            P_SOB_ID    NUMBER) IS
              --轉台北管帳2178 (非GU)
              SELECT JL.SET_OF_BOOKS_ID,
                     MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (JL.SET_OF_BOOKS_ID)))         SEGMENT3,
                     JH.CURRENCY_CODE                                                                                       AS CURRENCY_CODE,
                     SUM (NVL (JL.ENTERED_DR, 0) - NVL (JL.ENTERED_CR, 0))                                                  AS AMOUNT,
                     RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR'))) RATE,
                       SUM (NVL (JL.ENTERED_DR, 0) - NVL (JL.ENTERED_CR, 0))
                     * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')))
                         ACCOUNTED_AMOUNT,
                     GB.SHORT_NAME,
                     NVL (
                         DECODE (C.CUST_CODE,
                                 'KOH', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'TGT', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'GAP', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'ONY', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'GOT', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'V1D', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'V2D', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'V3D', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'V4D', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'V5D', C.CUST_CODE || '-' || SUBSTR (L3, 3, 1),
                                 'SMC', 'S1D',
                                 C.CUST_CODE),
                         C.CUST_CODE)
                         AS CUST_NAME,
                     JL.ATTRIBUTE14,
                     GB.SHORT_NAME || ' ' || 'INSPECTION FEE'                                                               AS DESCRIPTION
                FROM GL_JE_HEADERS         JH,
                     GL_JE_LINES           JL,
                     GL_CODE_COMBINATIONS_V GCC,
                     GL_JE_CATEGORIES_TL   JC,
                     GL_SETS_OF_BOOKS      GB,
                     APPS.ATK_OE_STYLE_V   OE,
                     ACP_OE_HEADERS_DFF    ACP,
                     MK_CUSTOMER_DEPT_ALL  C
               WHERE 1 = 1
                 AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
                 AND JH.JE_CATEGORY = JC.JE_CATEGORY_NAME
                 AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                 AND GCC.SEGMENT3 NOT IN ('26162',
                                          '25162',
                                          '25562',
                                          '31361')                                        --Add by Jimbo 2020/09/15排除GU部門(下方IMP_GQC_FEE_XXX)
                 AND GCC.SEGMENT3 IN (SELECT DEPT_CODE
                                        FROM MK_GL_DEPTS
                                       WHERE 1 = 1
                                         AND PARENT_ID IS NOT NULL
                                         AND PRIOR_FLAG = 'Y'
                                         AND ACTIVE_FLAG = 'Y')                                         --Add by Jimbo 2020/12/23 僅抓取本廠Maker
                 AND GCC.SEGMENT4 || '.' || GCC.SEGMENT5 = '6144.00'
                 AND JH.PERIOD_NAME = P_PERIOD
                 AND JH.STATUS = NVL (G_STATUS, JH.STATUS)
                 AND JH.SET_OF_BOOKS_ID = NVL (P_SOB_ID, JH.SET_OF_BOOKS_ID)
                 AND JH.SET_OF_BOOKS_ID = GB.SET_OF_BOOKS_ID
                 AND (JL.ATTRIBUTE3 IS NULL
                   OR JL.ATTRIBUTE3 NOT LIKE 'GU%')                                                                                   --排除GU
                 AND JL.ATTRIBUTE2 = OE.STYLE
                 AND OE.OE_FOLDERID = ACP.OE_FOLDERID
                 AND ACP.CUST_NAME = C.CUSTOMER(+)
                 AND ACP.SUB_GROUP = C.SUBGROUP(+)
                 AND C.L3 IS NOT NULL
                 AND C.ENABLE = 'Y'
                 AND GB.ATTRIBUTE1 = 'T'                                                                                             --抓稅的帳本
                 AND GB.SHORT_NAME IN ('CAM',
                                       'MOH',
                                       'IGI',
                                       'ISL-US',
                                       'CJY',
                                       'CMZ',
                                       'CJR',
                                       'CMK',
                                       'VMK',
                                       'VLR',
                                       'VTP')
            GROUP BY JL.SET_OF_BOOKS_ID,
                     MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (JL.SET_OF_BOOKS_ID))),
                     GB.SHORT_NAME,
                     JH.CURRENCY_CODE,
                     GB.SHORT_NAME,
                     C.CUST_CODE,
                     JL.ATTRIBUTE14,
                     C.L3
            ORDER BY 1;

        -- 轉台北管帳2178(GU)
        --依GL月份GU部門別的出口『實打』%分攤至GU-A &GU-B
        CURSOR JOU_GU (
            P_PERIOD    VARCHAR2,
            P_SOB_ID    NUMBER) IS
              SELECT AA.SET_OF_BOOKS_ID,
                     MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (AA.SET_OF_BOOKS_ID))) SEGMENT3,
                     AA.SOB_NAME,
                     AA.CURRENCY_CODE,
                     AA.AMOUNT * BB.PERCENTAGE                                                                    AMOUNT,
                     AA.RATE,
                     AA.ACCOUNTED_AMOUNT * BB.PERCENTAGE                                                          ACCOUNTED_AMOUNT,
                     BB.CUST                                                                                      AS CUST_NAME,
                     AA.ATTRIBUTE14,
                     AA.DESCRIPTION
                FROM (  SELECT JL.SET_OF_BOOKS_ID,
                               GB.SHORT_NAME                                                                                        AS SOB_NAME,
                               JH.CURRENCY_CODE                                                                                     AS CURRENCY_CODE,
                               SUM (NVL (JL.ENTERED_DR, 0) - NVL (JL.ENTERED_CR, 0))                                                AS AMOUNT,
                               RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR'))) RATE,
                                 SUM (NVL (JL.ENTERED_DR, 0) - NVL (JL.ENTERED_CR, 0))
                               * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')))
                                   ACCOUNTED_AMOUNT,
                               GB.SHORT_NAME,
                               'GU'
                                   AS CUST_NAME,
                               JL.ATTRIBUTE14,
                               GB.SHORT_NAME || ' ' || 'INSPECTION FEE'
                                   AS DESCRIPTION
                          FROM GL_JE_HEADERS       JH,
                               GL_JE_LINES         JL,
                               GL_CODE_COMBINATIONS_V GCC,
                               GL_JE_CATEGORIES_TL JC,
                               GL_SETS_OF_BOOKS    GB
                         WHERE JH.JE_HEADER_ID = JL.JE_HEADER_ID
                           AND JH.JE_CATEGORY = JC.JE_CATEGORY_NAME
                           AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                           AND GCC.SEGMENT4 || '.' || GCC.SEGMENT5 = '6144.00'
                           AND GCC.SEGMENT3 IN (SELECT DEPT_CODE
                                                  FROM MK_GL_DEPTS
                                                 WHERE 1 = 1
                                                   AND PARENT_ID IS NOT NULL
                                                   AND PRIOR_FLAG = 'Y'
                                                   AND ACTIVE_FLAG = 'Y')                               --Add by Jimbo 2020/12/23 僅抓取本廠Maker
                           AND JH.PERIOD_NAME = P_PERIOD
                           AND JH.STATUS = NVL (G_STATUS, JH.STATUS)
                           AND JH.SET_OF_BOOKS_ID = NVL (P_SOB_ID, JH.SET_OF_BOOKS_ID)
                           AND JH.SET_OF_BOOKS_ID = GB.SET_OF_BOOKS_ID
                           AND JL.ATTRIBUTE3 LIKE 'GU%'                                                                                 --GU
                           AND GB.ATTRIBUTE1 = 'T'
                           AND GB.SHORT_NAME IN ('CAM',
                                                 'MOH',
                                                 'IGI',
                                                 'ISL-US',
                                                 'CJY',
                                                 'CMZ',
                                                 'CJR',
                                                 'CMK',
                                                 'VMK',
                                                 'VLR',
                                                 'VTP')
                      GROUP BY JL.SET_OF_BOOKS_ID,
                               GB.SHORT_NAME,
                               JL.ATTRIBUTE14,
                               JH.CURRENCY_CODE,
                               GB.SHORT_NAME) AA,
                     (SELECT AA.CUST,
                             AA.DZ,
                             BB.TOTAL_DZ,
                             AA.DZ / BB.TOTAL_DZ PERCENTAGE
                        FROM (  SELECT AR.CUSTOMER_NAME || '-' || SUBSTR (MCD.L3, 3, 1) CUST, SUM (QUANTITY_PC / 12) DZ
                                  FROM MIC_AR_TRX_V AR, MK_CUSTOMER_DEPT_ALL MCD
                                 WHERE AR.CUST_CODE = MCD.CUST_CODE
                                   AND AR.SUB_GROUP = MCD.SUBGROUP
                                   AND TO_CHAR (AR.GL_DATE, 'MON-RR') = P_PERIOD
                                   AND AR.CUSTOMER_NAME = 'GU'
                              GROUP BY AR.CUSTOMER_NAME || '-' || SUBSTR (MCD.L3, 3, 1)) AA,
                             (  SELECT CUSTOMER_NAME CUST, SUM (QUANTITY_PC / 12) TOTAL_DZ
                                  FROM MIC_AR_TRX_V
                                 WHERE TO_CHAR (GL_DATE, 'MON-RR') = P_PERIOD
                                   AND CUSTOMER_NAME = 'GU'
                              GROUP BY CUSTOMER_NAME) BB
                       WHERE SUBSTR (AA.CUST, 1, 2) = BB.CUST) BB
               WHERE SUBSTR (BB.CUST, 1, 2) = AA.CUST_NAME
            ORDER BY 1;

        LN_ORG_ID                  NUMBER;
        LC_USER_NAME               VARCHAR2 (100);
        LC_USER_JE_SOURCE_NAME     VARCHAR2 (255);
        LC_USER_JE_CATEGORY_NAME   VARCHAR2 (255);
        LC_PERIOD_NAME             VARCHAR2 (255);
        LC_BASE_CURRENCY_CODE      VARCHAR2 (15);
        LC_BATCH_NAME              VARCHAR2 (255);
        LN_SET_OF_BOOKS_ID         NUMBER;
        LN_GROUP_ID                NUMBER;
        LC_JOURNAL_ENTRY_NAME      VARCHAR2 (255);
        LN_REQ_ID                  NUMBER;
        X_DR_ACCT_CCID             NUMBER;
        X_CR_ACCT_CCID             NUMBER;
        LD_ACCOUNTING_DATE         DATE;
        X_ACCT_CATEGORY            VARCHAR2 (60);
        R_SOB                      GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE            VARCHAR2 (30) := 'INSPECT FEE';
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);
        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        LC_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
        LC_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
        G_ERR_STRING := '1.0';

        SELECT ORGANIZATION_ID
          INTO LN_ORG_ID
          FROM ORG_ORGANIZATION_DEFINITIONS
         WHERE ORGANIZATION_CODE = 'TPV';

        --取得  GROUP_ID,BATCH_NAME
        APPS.ATK_GL_COMMON_PKG.GET_COMMON_INFO (LN_ORG_ID,
                                                TO_DATE (P_PERIOD, 'MON-RR'),
                                                P_USER_ID,
                                                LC_USER_JE_SOURCE_NAME,
                                                LC_USER_JE_CATEGORY_NAME,
                                                LC_PERIOD_NAME,
                                                LC_BASE_CURRENCY_CODE,
                                                LC_BATCH_NAME,
                                                LN_SET_OF_BOOKS_ID,
                                                LN_GROUP_ID);

        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'INSPECT FEE'
        --                || '-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 21, 2)), '00')) + 1, 2, '0')
        --           INTO LC_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = LN_SET_OF_BOOKS_ID
        --            AND SUBSTR (NAME, 1, 20) LIKE G_PREFIX || 'INSPECT FEE' || '-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --      END;
        --
        --      ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      SELECT G_PREFIX || 'INSPECT FEE' || '-' || P_PERIOD || '-' || 'Dos-Accounting' || '/' || 'Transfer' INTO LC_BATCH_NAME FROM DUAL;
        SELECT TO_DATE (P_PERIOD, 'MON-YY') INTO LD_ACCOUNTING_DATE FROM DUAL;

        G_ERR_STRING := '1.1';

        FOR AA IN JOU (P_PERIOD, P_SOB_ID) LOOP
            G_ERR_STRING := '2.0';

            IF AA.ACCOUNTED_AMOUNT >= 0 THEN
                G_ERR_STRING := '2.1';
                /*   DR.:15.01.00000.2178.28.000     彈性欄位:客戶別 ,科目分類(ATT14)
                                   CR.15.01.09901.2891.00.619   PHL菲
                                   CR.15.01.09902.2891.00.669   CHN中
                                   CR.15.01.09910.2891.00.629   CAB柬
                                   CR.15.01.09915.2891.00.640   NVN北越
                                   CR.15.01.09909.2891.00.650   SVN-TPL
                                   CR.15.01.09909.2891.00.651   SVN-LR
                                   CR.15.01.09917.2891.00.639   IND印

                     /*Step1-處理借方  ;直接Assign CCID*/
                X_DR_ACCT_CCID := 123532;                                                                        /*15.01.00000.2178.28.000*/
                X_ACCT_CATEGORY := NVL (AA.ATTRIBUTE14, '01驗貨費');
                G_ERR_STRING := '2.1.1' || '/' || P_USER_ID;
                --DR INSERT GL INTERFACE
                --                atk_gl_common_pkg.insert_gl_interface_all_curr
                INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                              LC_JOURNAL_ENTRY_NAME,
                                              P_PERIOD,
                                              LC_USER_JE_SOURCE_NAME,
                                              LC_USER_JE_CATEGORY_NAME,
                                              AA.CURRENCY_CODE,                                                     --LC_BASE_CURRENCY_CODE,
                                              LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),                          --p_currency_conversion_date
                                              AA.RATE,                                                                     --p_exchange_rate
                                              X_DR_ACCT_CCID,
                                              AA.DESCRIPTION,
                                              LD_ACCOUNTING_DATE,
                                              P_USER_ID,
                                              LN_SET_OF_BOOKS_ID,
                                              LN_GROUP_ID,
                                              AA.AMOUNT,
                                              0,
                                              AA.ACCOUNTED_AMOUNT,
                                              0,
                                              NULL,
                                              NULL,
                                              AA.CUST_NAME,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              X_ACCT_CATEGORY,
                                              NULL);
                /*Step2-處理貸方 */
                G_GCC.SEGMENT1 := '15';
                G_GCC.SEGMENT2 := '01';
                G_GCC.SEGMENT3 := AA.SEGMENT3;
                G_GCC.SEGMENT4 := '2891';
                G_GCC.SEGMENT5 := '00';

                IF AA.SHORT_NAME = 'VTP' THEN
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (AA.SET_OF_BOOKS_ID)), 'TPM', '64');
                ELSIF AA.SHORT_NAME = 'VLR' THEN
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (AA.SET_OF_BOOKS_ID)), 'TPM', '65');
                ELSE
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (AA.SET_OF_BOOKS_ID)), 'TPM', NULL);
                END IF;

                G_GCC.CONCATENATED_SEGMENTS :=
                       G_GCC.SEGMENT1
                    || '.'
                    || G_GCC.SEGMENT2
                    || '.'
                    || G_GCC.SEGMENT3
                    || '.'
                    || G_GCC.SEGMENT4
                    || '.'
                    || G_GCC.SEGMENT5
                    || '.'
                    || G_GCC.SEGMENT6;
                X_CR_ACCT_CCID := MK_GL_PUB.GET_CCID (LN_SET_OF_BOOKS_ID, G_GCC.CONCATENATED_SEGMENTS, G_MSG);
                --                IF (AA.SHORT_NAME = 'CJY'
                --                 OR AA.SHORT_NAME = 'CMZ'
                --                 OR AA.SHORT_NAME = 'CJR'
                --                 OR AA.SHORT_NAME = 'CMK') THEN
                --                    X_CR_ACCT_CCID := 120499;
                --                ELSIF (AA.SHORT_NAME = 'CAM'
                --                    OR AA.SHORT_NAME = 'MOH') THEN
                --                    X_CR_ACCT_CCID := 118511;
                --                ELSIF AA.SHORT_NAME = 'VMK' THEN
                --                    X_CR_ACCT_CCID := 118513;
                --                ELSIF AA.SHORT_NAME = 'VTP' THEN
                --                    X_CR_ACCT_CCID := 118514;
                --                ELSIF AA.SHORT_NAME = 'VLR' THEN
                --                    X_CR_ACCT_CCID := 133832;
                --                ELSIF AA.SHORT_NAME = 'IGI'
                --                   OR AA.SHORT_NAME = 'ISL-US' THEN
                --                    X_CR_ACCT_CCID := 118776;
                --                END IF;
                G_ERR_STRING := '2.1.2';
                -- CR INSERT GL INTERFACE
                --                atk_gl_common_pkg.insert_gl_interface_all_curr
                INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                              LC_JOURNAL_ENTRY_NAME,
                                              P_PERIOD,
                                              LC_USER_JE_SOURCE_NAME,
                                              LC_USER_JE_CATEGORY_NAME,
                                              AA.CURRENCY_CODE,                                                     --LC_BASE_CURRENCY_CODE,
                                              LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),                          --p_currency_conversion_date
                                              AA.RATE,                                                                     --p_exchange_rate
                                              X_CR_ACCT_CCID,
                                              AA.DESCRIPTION,
                                              LD_ACCOUNTING_DATE,
                                              P_USER_ID,
                                              LN_SET_OF_BOOKS_ID,
                                              LN_GROUP_ID,
                                              0,
                                              AA.AMOUNT,
                                              0,
                                              AA.ACCOUNTED_AMOUNT,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL);
                COMMIT;
            ELSE
                G_ERR_STRING := '2.2';
                /*             DR.15.01.09901.2891.00.619   PHL菲
                                DR.15.01.09902.2891.00.669   CHN中
                                DR.15.01.09910.2891.00.629   CAB柬
                                D.15.01.09915.2891.00.640   NVN北越
                                DR.15.01.09909.2891.00.650   SVN-TPL
                                DR.15.01.09909.2891.00.651   SVN-LR
                                DR.15.01.09917.2891.00.639   IND印
                                                               CR.:15.01.00000.2178.28.000     彈性欄位:客戶別,科目分類(ATT14)    */
                /*Step1-處理借方 */
                G_GCC.SEGMENT1 := '15';
                G_GCC.SEGMENT2 := '01';
                G_GCC.SEGMENT3 := AA.SEGMENT3;
                G_GCC.SEGMENT4 := '2891';
                G_GCC.SEGMENT5 := '00';

                IF AA.SHORT_NAME = 'VTP' THEN
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (AA.SET_OF_BOOKS_ID)), 'TPM', '64');
                ELSIF AA.SHORT_NAME = 'VLR' THEN
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (AA.SET_OF_BOOKS_ID)), 'TPM', '65');
                ELSE
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (AA.SET_OF_BOOKS_ID)), 'TPM', NULL);
                END IF;

                G_GCC.CONCATENATED_SEGMENTS :=
                       G_GCC.SEGMENT1
                    || '.'
                    || G_GCC.SEGMENT2
                    || '.'
                    || G_GCC.SEGMENT3
                    || '.'
                    || G_GCC.SEGMENT4
                    || '.'
                    || G_GCC.SEGMENT5
                    || '.'
                    || G_GCC.SEGMENT6;
                X_DR_ACCT_CCID := MK_GL_PUB.GET_CCID (LN_SET_OF_BOOKS_ID, G_GCC.CONCATENATED_SEGMENTS, G_MSG);
                --                IF (AA.SHORT_NAME = 'CJY'
                --                 OR AA.SHORT_NAME = 'CMZ'
                --                 OR AA.SHORT_NAME = 'CJR'
                --                 OR AA.SHORT_NAME = 'CMK') THEN
                --                    X_DR_ACCT_CCID := 120499;
                --                ELSIF (AA.SHORT_NAME = 'CAM'
                --                    OR AA.SHORT_NAME = 'MOH') THEN
                --                    X_DR_ACCT_CCID := 118511;
                --                ELSIF AA.SHORT_NAME = 'VMK' THEN
                --                    X_DR_ACCT_CCID := 118513;
                --                ELSIF AA.SHORT_NAME = 'VTP' THEN
                --                    X_DR_ACCT_CCID := 118514;
                --                ELSIF AA.SHORT_NAME = 'VLR' THEN
                --                    X_DR_ACCT_CCID := 133832;
                --                ELSIF AA.SHORT_NAME = 'IGI'
                --                   OR AA.SHORT_NAME = 'ISL-US' THEN
                --                    X_DR_ACCT_CCID := 118776;
                --                END IF;
                -- DR INSERT GL INTERFACE
                --                atk_gl_common_pkg.insert_gl_interface_all_curr
                INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                              LC_JOURNAL_ENTRY_NAME,
                                              P_PERIOD,
                                              LC_USER_JE_SOURCE_NAME,
                                              LC_USER_JE_CATEGORY_NAME,
                                              AA.CURRENCY_CODE,                                                     --LC_BASE_CURRENCY_CODE,
                                              LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),                          --p_currency_conversion_date
                                              AA.RATE,                                                                     --p_exchange_rate
                                              X_DR_ACCT_CCID,
                                              AA.DESCRIPTION,
                                              LD_ACCOUNTING_DATE,
                                              P_USER_ID,
                                              LN_SET_OF_BOOKS_ID,
                                              LN_GROUP_ID,
                                              AA.AMOUNT * (-1),
                                              0,
                                              AA.ACCOUNTED_AMOUNT * (-1),
                                              0,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL);
                /*Step2-處理貸方  ;直接Assign CCID*/
                X_CR_ACCT_CCID := 123532;                                                                        /*15.01.00000.2178.28.000*/
                X_ACCT_CATEGORY := NVL (AA.ATTRIBUTE14, '01驗貨費');
                --CR INSERT GL INTERFACE
                --                atk_gl_common_pkg.insert_gl_interface_all_curr
                INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                              LC_JOURNAL_ENTRY_NAME,
                                              P_PERIOD,
                                              LC_USER_JE_SOURCE_NAME,
                                              LC_USER_JE_CATEGORY_NAME,
                                              AA.CURRENCY_CODE,                                                     --LC_BASE_CURRENCY_CODE,
                                              LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),                          --p_currency_conversion_date
                                              AA.RATE,                                                                     --p_exchange_rate
                                              X_CR_ACCT_CCID,
                                              AA.DESCRIPTION,
                                              LD_ACCOUNTING_DATE,
                                              P_USER_ID,
                                              LN_SET_OF_BOOKS_ID,
                                              LN_GROUP_ID,
                                              0,
                                              AA.AMOUNT * (-1),
                                              0,
                                              AA.ACCOUNTED_AMOUNT * (-1),
                                              NULL,
                                              NULL,
                                              AA.CUST_NAME,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              X_ACCT_CATEGORY,
                                              NULL);
                COMMIT;
            END IF;
        END LOOP;

        G_ERR_STRING := '1.2';

        FOR BB IN JOU_GU (P_PERIOD, P_SOB_ID) LOOP
            IF BB.ACCOUNTED_AMOUNT >= 0 THEN
                /*   DR.:15.01.00000.2178.28.000     彈性欄位:客戶別 GU-A,GU-B
                                   CR.15.01.09901.2891.00.619   PHL菲
                                   CR.15.01.09902.2891.00.669   CHN中
                                   CR.15.01.09910.2891.00.629   CAB柬
                                   CR.15.01.09915.2891.00.640   NVN北越
                                   CR.15.01.09909.2891.00.650   SVN-TPL
                                   CR.15.01.09909.2891.00.651   SVN-LR
                                   CR.15.01.09917.2891.00.639   IND印            */
                /*Step1-處理借方  ;直接Assign CCID*/
                X_DR_ACCT_CCID := 123532;                                                                        /*15.01.00000.2178.28.000*/
                X_ACCT_CATEGORY := NVL (BB.ATTRIBUTE14, '01驗貨費');
                --DR INSERT GL INTERFACE
                --                atk_gl_common_pkg.insert_gl_interface_all_curr
                INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                              LC_JOURNAL_ENTRY_NAME,
                                              P_PERIOD,
                                              LC_USER_JE_SOURCE_NAME,
                                              LC_USER_JE_CATEGORY_NAME,
                                              BB.CURRENCY_CODE,                                                     --LC_BASE_CURRENCY_CODE,
                                              LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),                          --p_currency_conversion_date
                                              BB.RATE,                                                                     --p_exchange_rate
                                              X_DR_ACCT_CCID,
                                              BB.DESCRIPTION,
                                              LD_ACCOUNTING_DATE,
                                              P_USER_ID,
                                              LN_SET_OF_BOOKS_ID,
                                              LN_GROUP_ID,
                                              BB.AMOUNT,
                                              0,
                                              BB.ACCOUNTED_AMOUNT,
                                              0,
                                              NULL,
                                              NULL,
                                              BB.CUST_NAME,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              X_ACCT_CATEGORY,
                                              NULL);
                /*Step2-處理貸方 */
                G_GCC.SEGMENT1 := '15';
                G_GCC.SEGMENT2 := '01';
                G_GCC.SEGMENT3 := BB.SEGMENT3;
                G_GCC.SEGMENT4 := '2891';
                G_GCC.SEGMENT5 := '00';

                IF BB.SOB_NAME = 'VTP' THEN
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (BB.SET_OF_BOOKS_ID)), 'TPM', '64');
                ELSIF BB.SOB_NAME = 'VLR' THEN
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (BB.SET_OF_BOOKS_ID)), 'TPM', '65');
                ELSE
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (BB.SET_OF_BOOKS_ID)), 'TPM', NULL);
                END IF;

                G_GCC.CONCATENATED_SEGMENTS :=
                       G_GCC.SEGMENT1
                    || '.'
                    || G_GCC.SEGMENT2
                    || '.'
                    || G_GCC.SEGMENT3
                    || '.'
                    || G_GCC.SEGMENT4
                    || '.'
                    || G_GCC.SEGMENT5
                    || '.'
                    || G_GCC.SEGMENT6;
                X_CR_ACCT_CCID := MK_GL_PUB.GET_CCID (LN_SET_OF_BOOKS_ID, G_GCC.CONCATENATED_SEGMENTS, G_MSG);
                --
                --                IF (BB.SOB_NAME = 'CJY'
                --                 OR BB.SOB_NAME = 'CMZ'
                --                 OR BB.SOB_NAME = 'CJR'
                --                 OR BB.SOB_NAME = 'CMK') THEN
                --                    X_CR_ACCT_CCID := 120499;
                --                ELSIF (BB.SOB_NAME = 'CAM'
                --                    OR BB.SOB_NAME = 'MOH') THEN
                --                    X_CR_ACCT_CCID := 118511;
                --                ELSIF BB.SOB_NAME = 'VMK' THEN
                --                    X_CR_ACCT_CCID := 118513;
                --                ELSIF BB.SOB_NAME = 'VTP' THEN
                --                    X_CR_ACCT_CCID := 118514;
                --                ELSIF BB.SOB_NAME = 'VLR' THEN
                --                    X_CR_ACCT_CCID := 133832;
                --                ELSIF BB.SOB_NAME = 'IGI'
                --                   OR BB.SOB_NAME = 'ISL-US' THEN
                --                    X_CR_ACCT_CCID := 118776;
                --                END IF;
                -- CR INSERT GL INTERFACE
                --                atk_gl_common_pkg.insert_gl_interface_all_curr
                INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                              LC_JOURNAL_ENTRY_NAME,
                                              P_PERIOD,
                                              LC_USER_JE_SOURCE_NAME,
                                              LC_USER_JE_CATEGORY_NAME,
                                              BB.CURRENCY_CODE,                                                     --LC_BASE_CURRENCY_CODE,
                                              LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),                          --p_currency_conversion_date
                                              BB.RATE,                                                                     --p_exchange_rate
                                              X_CR_ACCT_CCID,
                                              BB.DESCRIPTION,
                                              LD_ACCOUNTING_DATE,
                                              P_USER_ID,
                                              LN_SET_OF_BOOKS_ID,
                                              LN_GROUP_ID,
                                              0,
                                              BB.AMOUNT,
                                              0,
                                              BB.ACCOUNTED_AMOUNT,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL);
                COMMIT;
            ELSE
                /*     DR.15.01.09901.2891.00.619   PHL菲
                        DR.15.01.09902.2891.00.669   CHN中
                        DR.15.01.09910.2891.00.629   CAB柬
                        DR.15.01.09915.2891.00.640   NVN北越
                        DR.15.01.09909.2891.00.650   SVN-TPL
                        DR.15.01.09909.2891.00.651   SVN-LR
                        DR.15.01.09917.2891.00.639   IND印
                                              CR.:15.01.00000.2178.28.000     彈性欄位:客戶別 GU-A,GU-B        */
                /*Step1-處理借方 */
                G_GCC.SEGMENT1 := '15';
                G_GCC.SEGMENT2 := '01';
                G_GCC.SEGMENT3 := BB.SEGMENT3;
                G_GCC.SEGMENT4 := '2891';
                G_GCC.SEGMENT5 := '00';

                IF BB.SOB_NAME = 'VTP' THEN
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (BB.SET_OF_BOOKS_ID)), 'TPM', '64');
                ELSIF BB.SOB_NAME = 'VLR' THEN
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (BB.SET_OF_BOOKS_ID)), 'TPM', '65');
                ELSE
                    G_GCC.SEGMENT6 :=
                        MK_GL_PUB.SOB2SEG6 (MK_GL_PUB.GET_SHORT_NAME (MK_GL_PUB.GET_MGMT_SOB_ID (BB.SET_OF_BOOKS_ID)), 'TPM', NULL);
                END IF;

                G_GCC.CONCATENATED_SEGMENTS :=
                       G_GCC.SEGMENT1
                    || '.'
                    || G_GCC.SEGMENT2
                    || '.'
                    || G_GCC.SEGMENT3
                    || '.'
                    || G_GCC.SEGMENT4
                    || '.'
                    || G_GCC.SEGMENT5
                    || '.'
                    || G_GCC.SEGMENT6;
                X_DR_ACCT_CCID := MK_GL_PUB.GET_CCID (LN_SET_OF_BOOKS_ID, G_GCC.CONCATENATED_SEGMENTS, G_MSG);
                --                IF (BB.SOB_NAME = 'CJY'
                --                 OR BB.SOB_NAME = 'CMZ'
                --                 OR BB.SOB_NAME = 'CJR'
                --                 OR BB.SOB_NAME = 'CMK') THEN
                --                    X_DR_ACCT_CCID := 120499;
                --                ELSIF (BB.SOB_NAME = 'CAM'
                --                    OR BB.SOB_NAME = 'MOH') THEN
                --                    X_DR_ACCT_CCID := 118511;
                --                ELSIF BB.SOB_NAME = 'VMK' THEN
                --                    X_DR_ACCT_CCID := 118513;
                --                ELSIF BB.SOB_NAME = 'VTP' THEN
                --                    X_DR_ACCT_CCID := 118514;
                --                ELSIF BB.SOB_NAME = 'VLR' THEN
                --                    X_DR_ACCT_CCID := 133832;
                --                ELSIF BB.SOB_NAME = 'IGI'
                --                   OR BB.SOB_NAME = 'ISL-US' THEN
                --                    X_DR_ACCT_CCID := 118776;
                --                END IF;
                -- DR INSERT GL INTERFACE
                --                atk_gl_common_pkg.insert_gl_interface_all_curr
                INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                              LC_JOURNAL_ENTRY_NAME,
                                              P_PERIOD,
                                              LC_USER_JE_SOURCE_NAME,
                                              LC_USER_JE_CATEGORY_NAME,
                                              BB.CURRENCY_CODE,                                                     --LC_BASE_CURRENCY_CODE,
                                              LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),                          --p_currency_conversion_date
                                              BB.RATE,                                                                     --p_exchange_rate
                                              X_DR_ACCT_CCID,
                                              BB.DESCRIPTION,
                                              LD_ACCOUNTING_DATE,
                                              P_USER_ID,
                                              LN_SET_OF_BOOKS_ID,
                                              LN_GROUP_ID,
                                              BB.AMOUNT * (-1),
                                              0,
                                              BB.ACCOUNTED_AMOUNT * (-1),
                                              0,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL);
                /*Step2-處理貸方  ;直接Assign CCID*/
                X_CR_ACCT_CCID := 123532;                                                                        /*15.01.00000.2178.28.000*/
                X_ACCT_CATEGORY := NVL (BB.ATTRIBUTE14, '01驗貨費');
                --CR INSERT GL INTERFACE
                --                atk_gl_common_pkg.insert_gl_interface_all_curr
                INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                              LC_JOURNAL_ENTRY_NAME,
                                              P_PERIOD,
                                              LC_USER_JE_SOURCE_NAME,
                                              LC_USER_JE_CATEGORY_NAME,
                                              BB.CURRENCY_CODE,                                                     --LC_BASE_CURRENCY_CODE,
                                              LAST_DAY (TO_DATE (P_PERIOD, 'MON-RR')),                          --p_currency_conversion_date
                                              BB.RATE,                                                                     --p_exchange_rate
                                              X_CR_ACCT_CCID,
                                              BB.DESCRIPTION,
                                              LD_ACCOUNTING_DATE,
                                              P_USER_ID,
                                              LN_SET_OF_BOOKS_ID,
                                              LN_GROUP_ID,
                                              0,
                                              BB.AMOUNT * (-1),
                                              0,
                                              BB.ACCOUNTED_AMOUNT * (-1),
                                              NULL,
                                              NULL,
                                              BB.CUST_NAME,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              NULL,
                                              X_ACCT_CATEGORY,
                                              NULL);
                COMMIT;
            END IF;
        END LOOP;

        G_ERR_STRING := '1.3';
        -- Run Journal Import
        LN_REQ_ID := ATK_GL_COMMON_PKG.INSERT_GL_CONTROL (LN_SET_OF_BOOKS_ID, P_USER_ID, LN_GROUP_ID);

        IF LN_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('TPV 驗貨費 Failure!! GROUP ID:' || LN_GROUP_ID);
            RETURN 'TPV 驗貨費 Failure!! GROUP ID:' || LN_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('TPV 驗貨費 Success!! Concurrent ID:' || LN_REQ_ID);
            RETURN 'TPV 驗貨費 Success!! Concurrent ID:' || LN_REQ_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN    'TPV 驗貨費 Error:'
                   || G_ERR_STRING
                   || '-'
                   || LN_SET_OF_BOOKS_ID
                   || '-'
                   || P_USER_ID
                   || '-'
                   || LN_GROUP_ID
                   || '-'
                   || SQLERRM;
    END IMP_INSPECTION_FEE_TPE;

    FUNCTION IMP_SAE_FEE_FAC (P_PERIOD_NAME VARCHAR2, P_SOB_ID NUMBER)
        RETURN VARCHAR2 AS
        CURSOR C IS
            SELECT GB.SHORT_NAME,
                   GB.SET_OF_BOOKS_ID,
                   JH.JE_HEADER_ID,
                   JH.NAME,
                   JH.CURRENCY_CODE,
                   JH.PERIOD_NAME,
                   JH.STATUS,
                   JH.DEFAULT_EFFECTIVE_DATE,
                   JL.CODE_COMBINATION_ID                      AS CCID,
                   JL.ENTERED_DR,
                   JL.ENTERED_CR,
                   JL.DESCRIPTION,
                   JL.ATTRIBUTE1,
                   JL.ATTRIBUTE2,
                   JL.ATTRIBUTE3,
                   JL.ATTRIBUTE4,
                   JL.ATTRIBUTE5,
                   JL.ATTRIBUTE6,
                   JL.ATTRIBUTE7,
                   JL.ATTRIBUTE8,
                   JL.ATTRIBUTE9,
                   JL.ATTRIBUTE10,
                   JL.ATTRIBUTE11,
                   JL.ATTRIBUTE12,
                   JL.ATTRIBUTE13,
                   JL.ATTRIBUTE14,
                   JL.ATTRIBUTE15,
                   JC.USER_JE_CATEGORY_NAME,
                   JS.USER_JE_SOURCE_NAME,
                   GCC.SEGMENT1,
                   GCC.SEGMENT2,
                   GCC.SEGMENT3,
                   GCC.SEGMENT4,
                   GCC.SEGMENT5,
                   GCC.SEGMENT6,
                   MK_GL_PUB.SOB2SEG1 (GB.SHORT_NAME)          D_SEGMENT1,
                   MK_GL_PUB.SOB2SEG6 (GB.SHORT_NAME, 'FAC')   D_SEGMENT6,
                   MK_GL_PUB.SOB_TAX2MGMT (GB.SHORT_NAME)      D_SOB_NAME,
                   MK_GL_PUB.SOB_TAX2MGMT (GB.SET_OF_BOOKS_ID) D_SOB_ID
              FROM GL_JE_HEADERS           JH,
                   GL_JE_LINES             JL,
                   GL_CODE_COMBINATIONS_V  GCC,
                   GL_JE_CATEGORIES_VL     JC,
                   GL_JE_SOURCES_VL        JS,
                   GL_SETS_OF_BOOKS        GB
             WHERE 1 = 1
               AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
               AND JL.ATTRIBUTE3 IS NOT NULL                                                                                         --客戶別必填
               AND JH.JE_CATEGORY = JC.JE_CATEGORY_NAME
               AND JH.JE_SOURCE = JS.JE_SOURCE_NAME
               AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
               AND GCC.SEGMENT4 = '6215'
               AND GCC.SEGMENT5 = '03'
               AND JH.PERIOD_NAME = P_PERIOD_NAME
               AND JH.STATUS = NVL (G_STATUS, JH.STATUS)
               AND JH.SET_OF_BOOKS_ID = GB.SET_OF_BOOKS_ID
               AND MK_GL_PUB.SOB_TAX2MGMT (GB.SHORT_NAME) <> 'XXX'
               AND GB.SET_OF_BOOKS_ID = P_SOB_ID
               --            AND GCC.SEGMENT3 NOT IN ('31101', '31161', '31361')
               AND GCC.SEGMENT3 IN (SELECT DEPT_CODE
                                      FROM MK_GL_DEPTS
                                     WHERE 1 = 1
                                       AND PARENT_ID IS NOT NULL
                                       AND PRIOR_FLAG = 'Y'
                                       AND ACTIVE_FLAG = 'Y')                                           --Add by Jimbo 2020/12/23 僅抓取本廠Maker
               AND (GB.SHORT_NAME, GCC.SEGMENT3) NOT IN (SELECT MGD.SHORT_CODE, MGED.SEGMENT3
                                                           FROM MK_GL_EXCLUDE_DEPTS MGED, MK_GL_DEPTS MGD
                                                          WHERE 1 = 1
                                                            AND MGED.DEPT_ID = MGD.DEPT_ID);

        V_REC                  R_REC;
        V_REQ_ID               VARCHAR2 (300);                                       --ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE%TYPE;
        V_GCC                  GL_CODE_COMBINATIONS%ROWTYPE;
        V_STRING               VARCHAR2 (3000);
        V_SHORT_NAME           GL_SETS_OF_BOOKS.SHORT_NAME%TYPE;
        R_SOB                  GL_SETS_OF_BOOKS%ROWTYPE;
        --        v_txn_type_code        VARCHAR2 (30) := 'SAE';
        V_TXN_TYPE_CODE        VARCHAR2 (30) := 'SAMPLE AF';
        E_GEN_CCID_EXCEPTION   EXCEPTION;
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);
        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        V_REC.P_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        V_REC.P_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 共用變數
        ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      V_REC.P_BATCH_NAME              := G_PREFIX || 'INSPECT SAE-' || P_PERIOD_NAME || '-' || 'Dos-Accounting' || '/' || 'Transfer';
        G_ERR_STRING := '1';
        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'INSPECT SAE-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 21, 2)), '00')) + 1, 2, '0')
        --           INTO V_REC.P_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE 1 = 1
        --            AND JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = MK_GL_PUB.SOB_TAX2MGMT (P_SOB_ID)
        --            AND SUBSTR (NAME, 1, 20) LIKE G_PREFIX || 'INSPECT SAE-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --            G_ERR_STRING   := '1.1';
        --      END;
        V_REC.P_USER_JE_SOURCE_NAME := 'Dos-Accounting';
        V_REC.P_USER_JE_CATEGORY_NAME := 'Transfer';
        V_REC.P_GROUP_ID := GL_INTERFACE_CONTROL_PKG.GET_UNIQUE_ID;
        G_ERR_STRING := '2';

        FOR V IN C LOOP
            -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 逐筆變數
            --      V_REC.P_JOURNAL_ENTRY_NAME      := '';                                                                                              --pre_cursor
            V_REC.P_PERIOD_NAME := V.PERIOD_NAME;
            --         V_REC.P_USER_JE_SOURCE_NAME     := V.USER_JE_SOURCE_NAME;                                                                        --pre_cursor
            --         V_REC.P_USER_JE_CATEGORY_NAME   := V.USER_JE_CATEGORY_NAME;                                                                      --pre_cursor
            V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;
            V_REC.P_CCID := V.CCID;
            V_REC.P_DESCRIPTION := V.SHORT_NAME || '樣品快遞費';
            --         V_REC.P_DATE              := V.DEFAULT_EFFECTIVE_DATE;                                                                               --統一日期即可
            V_REC.P_DATE := TO_DATE (P_PERIOD_NAME, 'MON-RR');
            V_REC.P_USER_ID := P_USER_ID;
            V_SHORT_NAME := V.D_SOB_NAME;
            V_REC.P_SET_OF_BOOKS_ID := V.D_SOB_ID;
            --      V_REC.P_GROUP_ID                := GL_INTERFACE_CONTROL_PKG.GET_UNIQUE_ID;                                                          --pre_cursor
            -- 借貸沿用
            V_REC.P_DR := NVL (V.ENTERED_DR, 0);
            V_REC.P_CR := NVL (V.ENTERED_CR, 0);
            V_REC.P_ATTRIBUTE1 := V.ATTRIBUTE1;
            V_REC.P_ATTRIBUTE2 := V.ATTRIBUTE2;
            V_REC.P_ATTRIBUTE3 := V.ATTRIBUTE3;
            V_REC.P_ATTRIBUTE4 := V.ATTRIBUTE4;
            V_REC.P_ATTRIBUTE5 := V.ATTRIBUTE5;
            V_REC.P_ATTRIBUTE6 := V.ATTRIBUTE6;
            V_REC.P_ATTRIBUTE7 := V.ATTRIBUTE7;
            V_REC.P_ATTRIBUTE8 := V.ATTRIBUTE8;
            V_REC.P_ATTRIBUTE9 := V.ATTRIBUTE9;
            V_REC.P_ATTRIBUTE10 := V.ATTRIBUTE10;
            V_REC.P_ATTRIBUTE11 := V.ATTRIBUTE11;
            V_REC.P_ATTRIBUTE12 := V.ATTRIBUTE12;
            V_REC.P_ATTRIBUTE13 := V.ATTRIBUTE13;
            V_REC.P_ATTRIBUTE14 := '12樣品快遞費';
            V_REC.P_ATTRIBUTE15 := V.ATTRIBUTE15;
            /*
            BOOK  SITE D/C  ACCT
            ----- ---- ---  -------------------------
              ISU STL  Dr.  xx.xx.26162.2891.00.635
                        Cr.  xx.xx.26162.xxxxx.xx.xxx
              IGI GLR1 Dr.  xx.xx.25162.2891.00.635
                        Cr.  xx.xx.25162.xxxxx.xx.xxx
              IGI GLD1 Dr.  xx.xx.25562.2891.00.635
                        Cr.  xx.xx.25562.xxxxx.xx.xxx
              CAM MK2  Dr.  xx.xx.31361.2891.00.628
                        Cr.  xx.xx.31361.xxxxx.xx.xxx
            */
            --借方
            V_GCC.SEGMENT1 := V.D_SEGMENT1;
            V_GCC.SEGMENT2 := V.SEGMENT2;
            V_GCC.SEGMENT3 := V.SEGMENT3;
            -- 指定產區管帳帳本會科
            V_GCC.SEGMENT4 := '2891';
            V_GCC.SEGMENT5 := '00';
            -- 依產區決定專案代碼--ICP
            V_GCC.SEGMENT6 := V.D_SEGMENT6;
            V_REC.P_CCID := GET_CC_ID (V_GCC);

            IF V_REC.P_CCID = -1 THEN
                MK_GL_PUB.CREATE_GL_ACCOUNT (
                    V_REC.P_SET_OF_BOOKS_ID,
                       V_GCC.SEGMENT1
                    || '.'
                    || V_GCC.SEGMENT2
                    || '.'
                    || V_GCC.SEGMENT3
                    || '.'
                    || V_GCC.SEGMENT4
                    || '.'
                    || V_GCC.SEGMENT5
                    || '.'
                    || V_GCC.SEGMENT6,
                    V_STRING);

                IF V_STRING IS NOT NULL THEN
                    RAISE E_GEN_CCID_EXCEPTION;
                ELSE
                    V_REC.P_CCID := GET_CC_ID (V_GCC);
                END IF;
            END IF;

            IMP_GI (V_REC);
            -- 產生產區管帳貸方
            V_GCC.SEGMENT1 := V.D_SEGMENT1;
            V_GCC.SEGMENT2 := V.SEGMENT2;
            V_GCC.SEGMENT3 := V.SEGMENT3;
            V_GCC.SEGMENT4 := V.SEGMENT4;
            V_GCC.SEGMENT5 := V.SEGMENT5;
            V_GCC.SEGMENT6 := V.SEGMENT6;
            V_REC.P_CCID := GET_CC_ID (V_GCC);

            IF V_REC.P_CCID = -1 THEN
                MK_GL_PUB.CREATE_GL_ACCOUNT (
                    V_REC.P_SET_OF_BOOKS_ID,
                       V_GCC.SEGMENT1
                    || '.'
                    || V_GCC.SEGMENT2
                    || '.'
                    || V_GCC.SEGMENT3
                    || '.'
                    || V_GCC.SEGMENT4
                    || '.'
                    || V_GCC.SEGMENT5
                    || '.'
                    || V_GCC.SEGMENT6,
                    V_STRING);

                IF V_STRING IS NOT NULL THEN
                    RAISE E_GEN_CCID_EXCEPTION;
                ELSE
                    V_REC.P_CCID := GET_CC_ID (V_GCC);
                END IF;
            END IF;

            -- 借貸互轉(沖銷原始方)
            V_REC.P_DR := NVL (V.ENTERED_CR, 0);
            V_REC.P_CR := NVL (V.ENTERED_DR, 0);
            -- 產生產區管帳借方
            IMP_GI (V_REC);
        END LOOP;

        G_ERR_STRING := '3';
        -- Run Journal Import
        G_ERR_STRING := V_REC.P_SET_OF_BOOKS_ID || '-' || V_REC.P_USER_ID || '-' || V_REC.P_GROUP_ID || '-' || V_REC.P_USER_JE_SOURCE_NAME;
        V_REQ_ID :=
            ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE (V_REC.P_SET_OF_BOOKS_ID,
                                                             V_REC.P_USER_ID,
                                                             V_REC.P_GROUP_ID,
                                                             V_REC.P_USER_JE_SOURCE_NAME);
        G_ERR_STRING := '4';

        IF V_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('FAC 樣品 Failure!! GROUP ID:' || V_REC.P_GROUP_ID);
            RETURN 'FAC 樣品 Failure!! GROUP ID:' || V_REC.P_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('FAC 樣品 Success!! Concurrent ID:' || V_REQ_ID);
            RETURN 'FAC 樣品 Success!! Concurrent ID:' || V_REQ_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN E_GEN_CCID_EXCEPTION THEN
            RETURN V_STRING;
        WHEN OTHERS THEN
            RETURN 'FAC 樣品 Error:' || G_ERR_STRING || '-' || SQLERRM;
    END IMP_SAE_FEE_FAC;

    FUNCTION IMP_SAE_FEE_TPE (P_PERIOD_NAME VARCHAR2, P_SOB_ID NUMBER DEFAULT NULL)
        RETURN VARCHAR2 AS
        CURSOR C IS
              SELECT GB.SHORT_NAME,
                     GB.SET_OF_BOOKS_ID,
                     JH.CURRENCY_CODE,
                     JH.PERIOD_NAME,
                     JH.STATUS,
                     SUM (JL.ENTERED_DR)                                                                                         ENTERED_DR,
                     SUM (JL.ENTERED_CR)                                                                                         ENTERED_CR,
                     SUM (NVL (JL.ENTERED_DR, 0) - NVL (JL.ENTERED_CR, 0))                                                       ENTERED_AMOUNT,
                     RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR'))) RATE,
                       SUM (JL.ENTERED_DR)
                     * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')))
                         ACCT_DR,
                       SUM (JL.ENTERED_CR)
                     * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')))
                         ACCT_CR,
                       SUM (NVL (JL.ENTERED_DR, 0) - NVL (JL.ENTERED_CR, 0))
                     * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')))
                         ACCT_AMOUNT,
                     GCC.SEGMENT1,
                     GCC.SEGMENT2,
                     GCC.SEGMENT3,
                     JL.ATTRIBUTE3,
                     MK_GL_PUB.SOB2SEG6 (GB.SHORT_NAME, 'TPE')                                                                   D_SEGMENT6,
                     MK_GL_PUB.SOB_TAX2MGMT (GB.SHORT_NAME)                                                                      D_SOB_NAME,
                     MK_GL_PUB.SOB_TAX2MGMT (GB.SET_OF_BOOKS_ID)                                                                 D_SOB_ID
                FROM GL_JE_HEADERS         JH,
                     GL_JE_LINES           JL,
                     GL_CODE_COMBINATIONS_V GCC,
                     GL_JE_CATEGORIES_VL   JC,
                     GL_JE_SOURCES_VL      JS,
                     GL_SETS_OF_BOOKS      GB
               WHERE 1 = 1
                 AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
                 AND JL.ATTRIBUTE3 IS NOT NULL
                 AND JH.JE_CATEGORY = JC.JE_CATEGORY_NAME
                 AND JH.JE_SOURCE = JS.JE_SOURCE_NAME
                 AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                 AND GCC.SEGMENT4 = '6215'
                 AND GCC.SEGMENT5 = '03'
                 AND JH.PERIOD_NAME = P_PERIOD_NAME
                 AND JH.STATUS = NVL (G_STATUS, JH.STATUS)
                 AND JH.SET_OF_BOOKS_ID = NVL (P_SOB_ID, JH.SET_OF_BOOKS_ID)
                 AND JH.SET_OF_BOOKS_ID = GB.SET_OF_BOOKS_ID
                 AND MK_GL_PUB.SOB_TAX2MGMT (GB.SHORT_NAME) <> 'XXX'
                 AND (MK_GL_PUB.SOB_TAX2MGMT (GB.SET_OF_BOOKS_ID), GCC.SEGMENT3) NOT IN (SELECT MGD.SOB_ID, MGED.SEGMENT3
                                                                                           FROM MK_GL_EXCLUDE_DEPTS MGED, MK_GL_DEPTS MGD
                                                                                          WHERE 1 = 1
                                                                                            AND MGED.DEPT_ID = MGD.DEPT_ID)
            GROUP BY GB.SHORT_NAME,
                     GB.SET_OF_BOOKS_ID,
                     JH.CURRENCY_CODE,
                     JH.PERIOD_NAME,
                     JH.STATUS,
                     JL.ATTRIBUTE3,
                     GCC.SEGMENT1,
                     GCC.SEGMENT2,
                     GCC.SEGMENT3;

        V_REC                  R_REC;
        V_REQ_ID               VARCHAR2 (300);                                       --ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE%TYPE;
        V_GCC                  GL_CODE_COMBINATIONS%ROWTYPE;
        V_ORG                  ORG_ORGANIZATION_DEFINITIONS%ROWTYPE;
        V_POS                  VARCHAR2 (30);
        R_SOB                  GL_SETS_OF_BOOKS%ROWTYPE;
        --        v_txn_type_code        VARCHAR2 (30) := 'SAE';
        V_TXN_TYPE_CODE        VARCHAR2 (30) := 'SAMPLE AF';
        V_STRING               VARCHAR2 (3000);
        E_GEN_CCID_EXCEPTION   EXCEPTION;
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);
        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        V_REC.P_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        V_REC.P_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        --      指定帳本
        G_ERR_STRING := '1.0';

        SELECT *
          INTO V_ORG
          FROM ORG_ORGANIZATION_DEFINITIONS
         WHERE ORGANIZATION_CODE = 'TPV';

        --取得  GROUP_ID,BATCH_NAME
        APPS.ATK_GL_COMMON_PKG.GET_COMMON_INFO (V_ORG.ORGANIZATION_ID,
                                                TO_DATE (P_PERIOD_NAME, 'MON-RR'),
                                                V_REC.P_USER_ID,
                                                V_REC.P_USER_JE_SOURCE_NAME,
                                                V_REC.P_USER_JE_CATEGORY_NAME,
                                                V_REC.P_PERIOD_NAME,
                                                V_REC.P_CURRENCY_CODE,
                                                V_REC.P_BATCH_NAME,
                                                V_REC.P_SET_OF_BOOKS_ID,
                                                V_REC.P_GROUP_ID);
        -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 共用變數
        --      ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      V_REC.P_BATCH_NAME              := G_PREFIX || 'INSPECT SAE-' || P_PERIOD_NAME || '-' || 'Dos-Accounting' || '/' || 'Transfer';
        --
        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'INSPECT SAE-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 21, 2)), '00')) + 1, 2, '0')
        --           INTO V_REC.P_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE 1 = 1
        --            AND JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = V_REC.P_SET_OF_BOOKS_ID
        --            AND SUBSTR (NAME, 1, 20) LIKE G_PREFIX || 'INSPECT SAE-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --      END;
        V_REC.P_USER_JE_SOURCE_NAME := 'Dos-Accounting';
        V_REC.P_USER_JE_CATEGORY_NAME := 'Transfer';
        V_REC.P_GROUP_ID := GL_INTERFACE_CONTROL_PKG.GET_UNIQUE_ID;
        G_ERR_STRING := '1.2';

        FOR V IN C LOOP
            -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 逐筆變數
            V_REC.P_PERIOD_NAME := V.PERIOD_NAME;
            V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;
            V_REC.P_DATE := TO_DATE (P_PERIOD_NAME, 'MON-RR');
            V_REC.P_CURRENCY_CONVERSION_DATE := TO_DATE (P_PERIOD_NAME, 'MON-RR');
            V_REC.P_EXCHANGE_RATE := V.RATE;
            V_REC.P_USER_ID := P_USER_ID;
            --            V_REC.P_DESCRIPTION := V.SHORT_NAME || '-樣品快遞費';
            v_rec.p_description := v.D_SOB_NAME || '-樣品快遞費';
            V_REC.P_ATTRIBUTE3 := V.ATTRIBUTE3;
            V_REC.P_ATTRIBUTE14 := '12樣品快遞費';
            /*
            BOOK  SITE D/C  ACCT
            ----- ---- ---  -------------------------
              ISU STL  Dr.  15.01.00000.2178.28.000(摘要：GU?% STL GQC分攤)(GU-? / 01驗貨費 )
                        Cr.  15.01.09917.2891.00.639(摘要：GU?% STL GQC分攤)(GU-? / 01驗貨費 )
              IGI GLR1 Dr.  15.01.00000.2178.28.000(摘要：GU?% GLR GQC分攤)(GU-? / 01驗貨費 )
                        Cr.  15.01.09917.2891.00.639(摘要：GU?% GLR GQC分攤)(GU-? / 01驗貨費 )
              IGI GLD1 Dr.  15.01.00000.2178.28.000(摘要：GU?% GLD GQC分攤)(GU-? / 01驗貨費 )
                        Cr.  15.01.09917.2891.00.639(摘要：GU?% GLD GQC分攤)(GU-? / 01驗貨費 )
              CAM MK2  Dr.  15.01.00000.2178.28.000(摘要：GU?% CAM GQC分攤)(GU-? / 01驗貨費 )
                        Cr.  15.01.09917.2891.00.629(摘要：GU?% CAM GQC分攤)(GU-? / 01驗貨費 )
            */
            --TPV管帳帳本會科
            --借方
            --         V_GCC.SEGMENT1          := V.SEGMENT1;
            --         V_GCC.SEGMENT2          := V.SEGMENT2;
            --         V_GCC.SEGMENT3          := V.SEGMENT3;
            V_GCC.SEGMENT1 := '15';
            V_GCC.SEGMENT2 := '01';
            V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V.D_SOB_NAME);
            V_GCC.SEGMENT4 := '1253';
            V_GCC.SEGMENT5 := '12';
            V_GCC.SEGMENT6 := '000';
            V_REC.P_CCID := GET_CC_ID (V_GCC);

            IF V_REC.P_CCID = -1 THEN
                MK_GL_PUB.CREATE_GL_ACCOUNT (
                    V_REC.P_SET_OF_BOOKS_ID,
                       V_GCC.SEGMENT1
                    || '.'
                    || V_GCC.SEGMENT2
                    || '.'
                    || V_GCC.SEGMENT3
                    || '.'
                    || V_GCC.SEGMENT4
                    || '.'
                    || V_GCC.SEGMENT5
                    || '.'
                    || V_GCC.SEGMENT6,
                    V_STRING);

                IF V_STRING IS NOT NULL THEN
                    RAISE E_GEN_CCID_EXCEPTION;
                ELSE
                    V_REC.P_CCID := GET_CC_ID (V_GCC);
                END IF;
            END IF;

            IF V.ENTERED_AMOUNT >= 0 THEN
                V_REC.P_DR := V.ENTERED_AMOUNT;
                V_REC.P_CR := 0;
            ELSIF V.ENTERED_AMOUNT < 0 THEN
                V_REC.P_DR := 0;
                V_REC.P_CR := -1 * V.ENTERED_AMOUNT;
            END IF;

            IF V.ACCT_AMOUNT >= 0 THEN
                V_REC.P_DR_ACC := V.ACCT_AMOUNT;
                V_REC.P_CR_ACC := 0;
            ELSIF V.ACCT_AMOUNT < 0 THEN
                V_REC.P_DR_ACC := 0;
                V_REC.P_CR_ACC := -1 * V.ACCT_AMOUNT;
            END IF;

            IMP_GI_CURR (V_REC);
            --TPV管帳帳本會科
            --貸方
            V_REC.P_ATTRIBUTE3 := NULL;
            V_REC.P_ATTRIBUTE14 := NULL;
            V_GCC.SEGMENT4 := '2891';
            V_GCC.SEGMENT5 := '00';
            V_GCC.SEGMENT6 := V.D_SEGMENT6;
            V_REC.P_CCID := GET_CC_ID (V_GCC);

            IF V_REC.P_CCID = -1 THEN
                MK_GL_PUB.CREATE_GL_ACCOUNT (
                    V_REC.P_SET_OF_BOOKS_ID,
                       V_GCC.SEGMENT1
                    || '.'
                    || V_GCC.SEGMENT2
                    || '.'
                    || V_GCC.SEGMENT3
                    || '.'
                    || V_GCC.SEGMENT4
                    || '.'
                    || V_GCC.SEGMENT5
                    || '.'
                    || V_GCC.SEGMENT6,
                    V_STRING);

                IF V_STRING IS NOT NULL THEN
                    RAISE E_GEN_CCID_EXCEPTION;
                ELSE
                    V_REC.P_CCID := GET_CC_ID (V_GCC);
                END IF;
            END IF;

            -- 借貸互轉(沖銷原始方)
            IF V.ENTERED_AMOUNT >= 0 THEN
                V_REC.P_DR := 0;
                V_REC.P_CR := V.ENTERED_AMOUNT;
            ELSIF V.ENTERED_AMOUNT < 0 THEN
                V_REC.P_DR := -1 * V.ENTERED_AMOUNT;
                V_REC.P_CR := 0;
            END IF;

            IF V.ACCT_AMOUNT >= 0 THEN
                V_REC.P_DR_ACC := 0;
                V_REC.P_CR_ACC := V.ACCT_AMOUNT;
            ELSIF V.ACCT_AMOUNT < 0 THEN
                V_REC.P_DR_ACC := -1 * V.ACCT_AMOUNT;
                V_REC.P_CR_ACC := 0;
            END IF;

            -- 產生產區管帳貸方
            IMP_GI_CURR (V_REC);
        END LOOP;

        G_ERR_STRING := '1.3';
        -- Run Journal Import
        V_REQ_ID :=
            ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE (V_REC.P_SET_OF_BOOKS_ID,
                                                             V_REC.P_USER_ID,
                                                             V_REC.P_GROUP_ID,
                                                             V_REC.P_USER_JE_SOURCE_NAME);

        IF V_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('TPV 樣品 Failure!! GROUP ID:' || V_REC.P_GROUP_ID);
            RETURN 'TPV 樣品 Failure!! GROUP ID:' || V_REC.P_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('TPV 樣品 Success!! Concurrent ID:' || V_REQ_ID);
            RETURN 'TPV 樣品 Success!! Concurrent ID:' || V_REQ_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN E_GEN_CCID_EXCEPTION THEN
            RETURN V_STRING;
        WHEN OTHERS THEN
            RETURN 'TPV 樣品 Error:' || G_ERR_STRING || '-' || SQLERRM;
    END IMP_SAE_FEE_TPE;

    FUNCTION IMP_RTWEX_FEE_TPE (P_PERIOD_NAME VARCHAR2, P_SOB_ID NUMBER DEFAULT NULL)
        RETURN VARCHAR2 AS
        CURSOR C IS
              SELECT GB.SHORT_NAME,
                     GB.SET_OF_BOOKS_ID,
                     JH.CURRENCY_CODE,
                     JH.PERIOD_NAME,
                     JH.STATUS,
                     JL.ATTRIBUTE1,
                     SUM (JL.ENTERED_DR)                                                                                         ENTERED_DR,
                     SUM (JL.ENTERED_CR)                                                                                         ENTERED_CR,
                     SUM (NVL (JL.ENTERED_DR, 0) - NVL (JL.ENTERED_CR, 0))                                                       ENTERED_AMOUNT,
                     RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR'))) RATE,
                       SUM (JL.ENTERED_DR)
                     * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')))
                         ACCT_DR,
                       SUM (JL.ENTERED_CR)
                     * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')))
                         ACCT_CR,
                       SUM (NVL (JL.ENTERED_DR, 0) - NVL (JL.ENTERED_CR, 0))
                     * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')))
                         ACCT_AMOUNT,
                     GCC.SEGMENT1,
                     GCC.SEGMENT2,
                     GCC.SEGMENT3,
                     GCC.SEGMENT4,
                     GCC.SEGMENT5,
                     GCC.SEGMENT6,
                     MK_GL_PUB.SOB2SEG6 (GB.SHORT_NAME, 'TPE')                                                                   D_SEGMENT6,
                     MK_GL_PUB.SOB_TAX2MGMT (GB.SHORT_NAME)                                                                      D_SOB_NAME,
                     MK_GL_PUB.SOB_TAX2MGMT (GB.SET_OF_BOOKS_ID)                                                                 D_SOB_ID
                FROM GL_JE_HEADERS         JH,
                     GL_JE_LINES           JL,
                     GL_CODE_COMBINATIONS_V GCC,
                     GL_JE_CATEGORIES_VL   JC,
                     GL_JE_SOURCES_VL      JS,
                     GL_SETS_OF_BOOKS      GB
               WHERE 1 = 1
                 AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
                 AND JL.ATTRIBUTE1 IS NOT NULL
                 AND JH.JE_CATEGORY = JC.JE_CATEGORY_NAME
                 AND JH.JE_SOURCE = JS.JE_SOURCE_NAME
                 AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                 AND GCC.SEGMENT4 = '1198'
                 AND GCC.SEGMENT5 = '05'
                 AND JH.PERIOD_NAME = P_PERIOD_NAME
                 --              AND JH.STATUS = NVL (G_STATUS, JH.STATUS)
                 AND JH.SET_OF_BOOKS_ID = NVL (P_SOB_ID, JH.SET_OF_BOOKS_ID)
                 AND JH.SET_OF_BOOKS_ID = GB.SET_OF_BOOKS_ID
                 AND GB.CURRENCY_CODE <> 'CNY'
                 AND MK_GL_PUB.SOB_TAX2MGMT (GB.SHORT_NAME) <> 'XXX'
            GROUP BY GB.SHORT_NAME,
                     GB.SET_OF_BOOKS_ID,
                     JH.CURRENCY_CODE,
                     JH.PERIOD_NAME,
                     JH.STATUS,
                     JL.ATTRIBUTE1,
                     GCC.SEGMENT1,
                     GCC.SEGMENT2,
                     GCC.SEGMENT3,
                     GCC.SEGMENT4,
                     GCC.SEGMENT5,
                     GCC.SEGMENT6;

        V_REC                  R_REC;
        V_REQ_ID               VARCHAR2 (300);                                       --ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE%TYPE;
        V_GCC                  GL_CODE_COMBINATIONS%ROWTYPE;
        V_ORG                  ORG_ORGANIZATION_DEFINITIONS%ROWTYPE;
        E_TOO_MANY_CUSTOMERS   EXCEPTION;
        R_SOB                  GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE        VARCHAR2 (30) := 'RTWEX';
        V_STRING               VARCHAR2 (3000);
        E_GEN_CCID_EXCEPTION   EXCEPTION;
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);

        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        --      指定帳本
        SELECT *
          INTO V_ORG
          FROM ORG_ORGANIZATION_DEFINITIONS
         WHERE ORGANIZATION_CODE = 'TPV';

        --取得  GROUP_ID,BATCH_NAME
        APPS.ATK_GL_COMMON_PKG.GET_COMMON_INFO (V_ORG.ORGANIZATION_ID,
                                                TO_DATE (P_PERIOD_NAME, 'MON-RR'),
                                                V_REC.P_USER_ID,
                                                V_REC.P_USER_JE_SOURCE_NAME,
                                                V_REC.P_USER_JE_CATEGORY_NAME,
                                                V_REC.P_PERIOD_NAME,
                                                V_REC.P_CURRENCY_CODE,
                                                V_REC.P_BATCH_NAME,
                                                V_REC.P_SET_OF_BOOKS_ID,
                                                V_REC.P_GROUP_ID);
        V_REC.P_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        V_REC.P_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);

        -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 共用變數
        ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      V_REC.P_BATCH_NAME              := G_PREFIX || 'INSPECT RTW-' || P_PERIOD_NAME || '-' || 'Dos-Accounting' || '/' || 'Transfer';
        --
        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'INSPECT RTW-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 21, 2)), '00')) + 1, 2, '0')
        --           INTO V_REC.P_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE 1 = 1
        --            AND JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = V_REC.P_SET_OF_BOOKS_ID
        --            AND SUBSTR (NAME, 1, 20) LIKE G_PREFIX || 'INSPECT RTW-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --      END;
        BEGIN
            SELECT USER_ID
              INTO G_USER_ID
              FROM MKFND_USER_V
             WHERE USER_NAME = G_USER_NAME;
        EXCEPTION
            WHEN OTHERS THEN
                G_MSG := 'User Error(' || G_USER_NAME || '):' || SQLERRM;
                RETURN G_MSG;
        END;

        V_REC.P_USER_JE_SOURCE_NAME := 'Dos-Accounting';
        V_REC.P_USER_JE_CATEGORY_NAME := 'Transfer';
        V_REC.P_GROUP_ID := APPS.GL_INTERFACE_CONTROL_PKG.GET_UNIQUE_ID;

        FOR V IN C LOOP
            -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 逐筆變數
            V_REC.P_PERIOD_NAME := V.PERIOD_NAME;
            V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;
            V_REC.P_DATE := TO_DATE (P_PERIOD_NAME, 'MON-RR');
            V_REC.P_CURRENCY_CONVERSION_DATE := TO_DATE (P_PERIOD_NAME, 'MON-RR');
            V_REC.P_EXCHANGE_RATE := V.RATE;
            V_REC.P_USER_ID := G_USER_ID;
            V_REC.P_DESCRIPTION := V.SHORT_NAME || '成衣空運費';
            V_REC.P_ATTRIBUTE1 := V.ATTRIBUTE1;                                                                                       --異損編號
            /*
            D/C   ACCT
            ----  -------------------------
            Dr.   xx.xx.xxxxx.6114.00.000-frgt
            Dr.   xx.xx.xxxxx.7888.10.000
             Cr.   xx.xx.xxxxx.2892.00.ICP
            */
            V_GCC.SEGMENT1 := '15';
            V_GCC.SEGMENT2 := '01';
            --09917 IND
            --09917 ISL-US
            --09901 PHL-US
            --09910 MOH
            --09915 VMK
            --09909 VTP
            --09910 CAM
            --09917 IGI
            --09909 VLR
            V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V.D_SOB_NAME);

            IF UPPER (V.ATTRIBUTE1) LIKE '%-FRGT' THEN
                --MK_UNUSUAL_LIST_V
                BEGIN
                      SELECT MK_GL_PUB.GET_VT_CUSTOMER ("STYLE") CUSTOMER
                        INTO V_REC.P_ATTRIBUTE3
                        --                        FROM WF_LOSS_CUSTOMER_FORERP@SQL_NETSQL
                        FROM WF_LOSS_CUSTOMER_FORERP@SQL_BPMDB_EW
                       WHERE 1 = 1
                         AND "LossSerial" = V_REC.P_ATTRIBUTE1
                    GROUP BY MK_GL_PUB.GET_VT_CUSTOMER ("STYLE");
                EXCEPTION
                    WHEN TOO_MANY_ROWS THEN
                        V_REC.P_ATTRIBUTE3 := NULL;
                        G_ERR_STRING := '異損編號:' || V.ATTRIBUTE1 || '包含多個客戶';
                        RAISE E_TOO_MANY_CUSTOMERS;
                    WHEN OTHERS THEN
                        V_REC.P_ATTRIBUTE3 := NULL;
                END;

                V_REC.P_ATTRIBUTE14 := NULL;
                --借方
                V_GCC.SEGMENT4 := '6114';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := '000';
                V_REC.P_CCID := GET_CC_ID (V_GCC);

                IF V_REC.P_CCID = -1 THEN
                    MK_GL_PUB.CREATE_GL_ACCOUNT (
                        V_REC.P_SET_OF_BOOKS_ID,
                           V_GCC.SEGMENT1
                        || '.'
                        || V_GCC.SEGMENT2
                        || '.'
                        || V_GCC.SEGMENT3
                        || '.'
                        || V_GCC.SEGMENT4
                        || '.'
                        || V_GCC.SEGMENT5
                        || '.'
                        || V_GCC.SEGMENT6,
                        V_STRING);

                    IF V_STRING IS NOT NULL THEN
                        RAISE E_GEN_CCID_EXCEPTION;
                    ELSE
                        V_REC.P_CCID := GET_CC_ID (V_GCC);
                    END IF;
                END IF;

                IF V.ENTERED_AMOUNT >= 0 THEN
                    V_REC.P_DR := V.ENTERED_AMOUNT;
                    V_REC.P_CR := 0;
                ELSIF V.ENTERED_AMOUNT < 0 THEN
                    V_REC.P_DR := 0;
                    V_REC.P_CR := -1 * V.ENTERED_AMOUNT;
                END IF;

                IF V.ACCT_AMOUNT >= 0 THEN
                    V_REC.P_DR_ACC := V.ACCT_AMOUNT;
                    V_REC.P_CR_ACC := 0;
                ELSIF V.ACCT_AMOUNT < 0 THEN
                    V_REC.P_DR_ACC := 0;
                    V_REC.P_CR_ACC := -1 * V.ACCT_AMOUNT;
                END IF;

                IMP_GI_CURR (V_REC);
                --貸方
                V_GCC.SEGMENT4 := '2892';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := V.D_SEGMENT6;
                V_REC.P_CCID := GET_CC_ID (V_GCC);

                IF V_REC.P_CCID = -1 THEN
                    MK_GL_PUB.CREATE_GL_ACCOUNT (
                        V_REC.P_SET_OF_BOOKS_ID,
                           V_GCC.SEGMENT1
                        || '.'
                        || V_GCC.SEGMENT2
                        || '.'
                        || V_GCC.SEGMENT3
                        || '.'
                        || V_GCC.SEGMENT4
                        || '.'
                        || V_GCC.SEGMENT5
                        || '.'
                        || V_GCC.SEGMENT6,
                        V_STRING);

                    IF V_STRING IS NOT NULL THEN
                        RAISE E_GEN_CCID_EXCEPTION;
                    ELSE
                        V_REC.P_CCID := GET_CC_ID (V_GCC);
                    END IF;
                END IF;

                -- 借貸互轉(沖銷原始方)
                IF V.ENTERED_AMOUNT >= 0 THEN
                    V_REC.P_DR := 0;
                    V_REC.P_CR := V.ENTERED_AMOUNT;
                ELSIF V.ENTERED_AMOUNT < 0 THEN
                    V_REC.P_DR := -1 * V.ENTERED_AMOUNT;
                    V_REC.P_CR := 0;
                END IF;

                IF V.ACCT_AMOUNT >= 0 THEN
                    V_REC.P_DR_ACC := 0;
                    V_REC.P_CR_ACC := V.ACCT_AMOUNT;
                ELSIF V.ACCT_AMOUNT < 0 THEN
                    V_REC.P_DR_ACC := -1 * V.ACCT_AMOUNT;
                    V_REC.P_CR_ACC := 0;
                END IF;

                IMP_GI_CURR (V_REC);
            ELSE
                V_REC.P_ATTRIBUTE3 := NULL;
                V_REC.P_ATTRIBUTE14 := '25成衣運輸費用';
                --借方
                V_GCC.SEGMENT4 := '7888';
                V_GCC.SEGMENT5 := '10';
                V_GCC.SEGMENT6 := '000';
                V_REC.P_CCID := GET_CC_ID (V_GCC);

                IF V_REC.P_CCID = -1 THEN
                    MK_GL_PUB.CREATE_GL_ACCOUNT (
                        V_REC.P_SET_OF_BOOKS_ID,
                           V_GCC.SEGMENT1
                        || '.'
                        || V_GCC.SEGMENT2
                        || '.'
                        || V_GCC.SEGMENT3
                        || '.'
                        || V_GCC.SEGMENT4
                        || '.'
                        || V_GCC.SEGMENT5
                        || '.'
                        || V_GCC.SEGMENT6,
                        V_STRING);

                    IF V_STRING IS NOT NULL THEN
                        RAISE E_GEN_CCID_EXCEPTION;
                    ELSE
                        V_REC.P_CCID := GET_CC_ID (V_GCC);
                    END IF;
                END IF;

                IF V.ENTERED_AMOUNT >= 0 THEN
                    V_REC.P_DR := V.ENTERED_AMOUNT;
                    V_REC.P_CR := 0;
                ELSIF V.ENTERED_AMOUNT < 0 THEN
                    V_REC.P_DR := 0;
                    V_REC.P_CR := -1 * V.ENTERED_AMOUNT;
                END IF;

                IF V.ACCT_AMOUNT >= 0 THEN
                    V_REC.P_DR_ACC := V.ACCT_AMOUNT;
                    V_REC.P_CR_ACC := 0;
                ELSIF V.ACCT_AMOUNT < 0 THEN
                    V_REC.P_DR_ACC := 0;
                    V_REC.P_CR_ACC := -1 * V.ACCT_AMOUNT;
                END IF;

                IMP_GI_CURR (V_REC);
                --貸方
                V_GCC.SEGMENT4 := '2892';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := V.D_SEGMENT6;
                V_REC.P_CCID := GET_CC_ID (V_GCC);

                IF V_REC.P_CCID = -1 THEN
                    MK_GL_PUB.CREATE_GL_ACCOUNT (
                        V_REC.P_SET_OF_BOOKS_ID,
                           V_GCC.SEGMENT1
                        || '.'
                        || V_GCC.SEGMENT2
                        || '.'
                        || V_GCC.SEGMENT3
                        || '.'
                        || V_GCC.SEGMENT4
                        || '.'
                        || V_GCC.SEGMENT5
                        || '.'
                        || V_GCC.SEGMENT6,
                        V_STRING);

                    IF V_STRING IS NOT NULL THEN
                        RAISE E_GEN_CCID_EXCEPTION;
                    ELSE
                        V_REC.P_CCID := GET_CC_ID (V_GCC);
                    END IF;
                END IF;

                -- 借貸互轉(沖銷原始方)
                IF V.ENTERED_AMOUNT >= 0 THEN
                    V_REC.P_DR := 0;
                    V_REC.P_CR := V.ENTERED_AMOUNT;
                ELSIF V.ENTERED_AMOUNT < 0 THEN
                    V_REC.P_DR := -1 * V.ENTERED_AMOUNT;
                    V_REC.P_CR := 0;
                END IF;

                IF V.ACCT_AMOUNT >= 0 THEN
                    V_REC.P_DR_ACC := 0;
                    V_REC.P_CR_ACC := V.ACCT_AMOUNT;
                ELSIF V.ACCT_AMOUNT < 0 THEN
                    V_REC.P_DR_ACC := -1 * V.ACCT_AMOUNT;
                    V_REC.P_CR_ACC := 0;
                END IF;

                IMP_GI_CURR (V_REC);
            END IF;
        END LOOP;

        -- Run Journal Import
        V_REQ_ID :=
            APPS.ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE (V_REC.P_SET_OF_BOOKS_ID,
                                                                  V_REC.P_USER_ID,
                                                                  V_REC.P_GROUP_ID,
                                                                  V_REC.P_USER_JE_SOURCE_NAME);
        DBMS_OUTPUT.PUT_LINE (
            V_REC.P_SET_OF_BOOKS_ID || '-' || V_REC.P_USER_ID || '-' || V_REC.P_GROUP_ID || '-' || V_REC.P_USER_JE_SOURCE_NAME);

        IF V_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('產區成衣空運費拋轉TPV管帳>>Failure!! GROUP ID:' || V_REC.P_GROUP_ID);
            RETURN '產區成衣空運費拋轉TPV管帳>>Failure!! GROUP ID:' || V_REC.P_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('產區成衣空運費拋轉TPV管帳>>Success!! Concurrent ID:' || V_REQ_ID);
            RETURN '產區成衣空運費拋轉TPV管帳>>Success!! Concurrent ID:' || V_REQ_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN E_GEN_CCID_EXCEPTION THEN
            RETURN V_STRING;
        WHEN E_TOO_MANY_CUSTOMERS THEN
            RETURN 'E' || G_ERR_STRING;
        WHEN OTHERS THEN
            RETURN 'E' || G_ERR_STRING || SQLERRM;
    END IMP_RTWEX_FEE_TPE;

    --樣品中心OH匯入
    FUNCTION IMP_SAMPLE_OH (P_SOB_ID     IN NUMBER,
                            P_PERIOD     IN VARCHAR2,
                            P_SOB_CODE      VARCHAR2,
                            P_TYPE          VARCHAR2,
                            P_INS_FLAG      VARCHAR2 DEFAULT NULL)
        RETURN VARCHAR2 IS
        CURSOR C_1 (C_SOB_ID      NUMBER,
                    C_PERIOD      VARCHAR2,
                    C_STATUS      VARCHAR2,
                    C_SOB_CODE    VARCHAR2) IS
            SELECT GSOB.SHORT_NAME,
                   GJH.NAME,
                   GJH.CURRENCY_CODE,
                   GJH.DEFAULT_EFFECTIVE_DATE,
                   GJL.*,
                   GCCK.SEGMENT1,
                   GCCK.SEGMENT2,
                   GCCK.SEGMENT3,
                   GCCK.SEGMENT4,
                   GCCK.SEGMENT5,
                   GCCK.SEGMENT6,
                   GCCK.CONCATENATED_SEGMENTS                                                                   GL_ACCT,
                   MOAM.SOURCE_CCID,
                   MOAM.TARGET_CCID,
                   RATE_CONVERSION (GJH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AC, GJH.DEFAULT_EFFECTIVE_DATE) AS EXCHANGE_RATE,
                   NVL (GJL.ACCOUNTED_DR, 0)                                                                    ED_DR,
                   NVL (GJL.ACCOUNTED_CR, 0)                                                                    ED_CR,
                   NVL (GJL.ACCOUNTED_DR, 0)                                                                    ACCT_DR,
                   NVL (GJL.ACCOUNTED_CR, 0)                                                                    ACCT_CR
              FROM GL_JE_HEADERS             GJH,
                   GL_JE_LINES               GJL,
                   GL_CODE_COMBINATIONS_KFV  GCCK,
                   MK_OVERSEA_ACCT_MAPPING   MOAM,
                   GL_SETS_OF_BOOKS          GSOB
             WHERE 1 = 1
               AND ( (P_TYPE = 'FAC')
                 OR (P_TYPE = 'TPE'
                 AND GJH.NAME NOT LIKE G_PREFIX || '%'))
               --            AND GJH.NAME = 'Adj#08-013'
               AND GJH.SET_OF_BOOKS_ID = C_SOB_ID
               AND GJH.PERIOD_NAME = C_PERIOD
               --            AND GJH.STATUS = NVL (C_STATUS, GJH.STATUS)
               AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
               AND GJL.CODE_COMBINATION_ID = GCCK.CODE_COMBINATION_ID
               AND GCCK.SEGMENT3 IN ('31101', '37400', 'S2000')
               AND (GCCK.SEGMENT4 LIKE '55%'
                 OR GCCK.SEGMENT4 LIKE '62%'
                 OR GCCK.SEGMENT4 LIKE '61%')
               --               AND GCCK.SEGMENT4 || '.' || GCCK.SEGMENT5 NOT IN ('6144.00', '5515.03', '5533.01')--Jimbo Marked by Jimmy Ask
               AND GCCK.SEGMENT4 || '.' || GCCK.SEGMENT5 NOT IN ('6144.00', '5533.01')
               AND GJL.CODE_COMBINATION_ID = MOAM.SOURCE_CCID
               AND MOAM.SOB_CODE = C_SOB_CODE
               AND NVL (MOAM.DISABLED, 'N') = 'N'
               AND GJH.SET_OF_BOOKS_ID = GSOB.SET_OF_BOOKS_ID;

        CURSOR C_2 (
            C_SOB_ID      NUMBER,
            C_PERIOD      VARCHAR2,
            C_STATUS      VARCHAR2,
            C_SOB_CODE    VARCHAR2) IS
              SELECT GSOB.SHORT_NAME,
                     GJH.NAME,
                     GJH.CURRENCY_CODE,
                     GJH.PERIOD_NAME,
                     GJH.DEFAULT_EFFECTIVE_DATE,
                     GJH.SET_OF_BOOKS_ID,
                     GJL.DESCRIPTION,
                     MOAM.TARGET_CCID,
                     RATE_CONVERSION (GJH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AC, GJH.DEFAULT_EFFECTIVE_DATE) AS EXCHANGE_RATE,
                     SUM (NVL (GJL.ACCOUNTED_DR, 0)) - SUM (NVL (GJL.ACCOUNTED_CR, 0))                          ENTERED_DR,
                     0                                                                                          ENTERED_CR,
                     SUM (NVL (GJL.ACCOUNTED_DR, 0)) - SUM (NVL (GJL.ACCOUNTED_CR, 0))                          ACCOUNTED_DR,
                     0                                                                                          ACCOUNTED_CR,
                     (  SUM (
                              NVL (GJL.ACCOUNTED_DR, 0)
                            * RATE_CONVERSION (GJH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AC, GJH.DEFAULT_EFFECTIVE_DATE))
                      - SUM (
                              NVL (GJL.ACCOUNTED_CR, 0)
                            * RATE_CONVERSION (GJH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AC, GJH.DEFAULT_EFFECTIVE_DATE)))
                         ACCT_DR,
                     0                                                                                          ACCT_CR
                FROM GL_JE_HEADERS           GJH,
                     GL_JE_LINES             GJL,
                     GL_CODE_COMBINATIONS_KFV GCCK,
                     MK_OVERSEA_ACCT_MAPPING MOAM,
                     GL_SETS_OF_BOOKS        GSOB
               WHERE 1 = 1
                 AND ( (P_TYPE = 'FAC')
                   OR (P_TYPE = 'TPE'
                   AND GJH.NAME NOT LIKE G_PREFIX || '%'))
                 --              AND GJH.NAME = 'Adj#08-013'
                 AND GJH.SET_OF_BOOKS_ID = C_SOB_ID
                 AND GJH.PERIOD_NAME = C_PERIOD
                 --              AND GJH.STATUS = NVL (C_STATUS, GJH.STATUS)
                 AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
                 AND GJL.CODE_COMBINATION_ID = GCCK.CODE_COMBINATION_ID
                 AND GCCK.SEGMENT3 IN ('31101', '37400', 'S2000')
                 AND (GCCK.SEGMENT4 LIKE '55%'
                   OR GCCK.SEGMENT4 LIKE '62%'
                   OR GCCK.SEGMENT4 LIKE '61%')
                 --               AND GCCK.SEGMENT4 || '.' || GCCK.SEGMENT5 NOT IN ('6144.00', '5515.03', '5533.01')--Jimbo Marked by Jimmy Ask
                 AND GCCK.SEGMENT4 || '.' || GCCK.SEGMENT5 NOT IN ('6144.00', '5533.01')
                 AND GJL.CODE_COMBINATION_ID = MOAM.SOURCE_CCID
                 AND MOAM.SOB_CODE = C_SOB_CODE
                 AND NVL (MOAM.DISABLED, 'N') = 'N'
                 AND GJH.SET_OF_BOOKS_ID = GSOB.SET_OF_BOOKS_ID
            GROUP BY GSOB.SHORT_NAME,
                     GJH.NAME,
                     GJH.JE_HEADER_ID,
                     GJH.CURRENCY_CODE,
                     GJH.PERIOD_NAME,
                     GJH.DEFAULT_EFFECTIVE_DATE,
                     GJH.SET_OF_BOOKS_ID,
                     GJL.DESCRIPTION,
                     MOAM.TARGET_CCID;

        CURSOR C_3 (
            C_SOB_ID      NUMBER,
            C_PERIOD      VARCHAR2,
            C_STATUS      VARCHAR2,
            C_SOB_CODE    VARCHAR2) IS
              SELECT GSOB.SHORT_NAME,
                     GJH.NAME,
                     GJH.CURRENCY_CODE,
                     GJH.PERIOD_NAME,
                     GJH.DEFAULT_EFFECTIVE_DATE,
                     GJH.SET_OF_BOOKS_ID,
                     GCCK.SEGMENT1,
                     RATE_CONVERSION (GJH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AC, GJH.DEFAULT_EFFECTIVE_DATE) AS EXCHANGE_RATE,
                     SUM (NVL (GJL.ACCOUNTED_DR, 0)) - SUM (NVL (GJL.ACCOUNTED_CR, 0))                          ENTERED_DR,
                     0                                                                                          ENTERED_CR,
                     SUM (NVL (GJL.ACCOUNTED_DR, 0)) - SUM (NVL (GJL.ACCOUNTED_CR, 0))                          ACCOUNTED_DR,
                     0                                                                                          ACCOUNTED_CR,
                     (  SUM (
                              NVL (GJL.ACCOUNTED_DR, 0)
                            * RATE_CONVERSION (GJH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AC, GJH.DEFAULT_EFFECTIVE_DATE))
                      - SUM (
                              NVL (GJL.ACCOUNTED_CR, 0)
                            * RATE_CONVERSION (GJH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AC, GJH.DEFAULT_EFFECTIVE_DATE)))
                         ACCT_DR,
                     0                                                                                          ACCT_CR
                FROM GL_JE_HEADERS           GJH,
                     GL_JE_LINES             GJL,
                     GL_CODE_COMBINATIONS_KFV GCCK,
                     MK_OVERSEA_ACCT_MAPPING MOAM,
                     GL_SETS_OF_BOOKS        GSOB
               WHERE 1 = 1
                 AND ( (P_TYPE = 'FAC')
                   OR (P_TYPE = 'TPE'
                   AND GJH.NAME NOT LIKE G_PREFIX || '%'))
                 --              AND GJH.NAME = 'Adj#08-013'
                 AND GJH.SET_OF_BOOKS_ID = C_SOB_ID
                 AND GJH.PERIOD_NAME = C_PERIOD
                 --              AND GJH.STATUS = NVL (C_STATUS, GJH.STATUS)
                 AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
                 AND GJL.CODE_COMBINATION_ID = GCCK.CODE_COMBINATION_ID
                 AND GCCK.SEGMENT3 IN ('31101', '37400', 'S2000')
                 AND (GCCK.SEGMENT4 LIKE '55%'
                   OR GCCK.SEGMENT4 LIKE '62%'
                   OR GCCK.SEGMENT4 LIKE '61%')
                 --               AND GCCK.SEGMENT4 || '.' || GCCK.SEGMENT5 NOT IN ('6144.00', '5515.03', '5533.01')--Jimbo Marked by Jimmy Ask
                 AND GCCK.SEGMENT4 || '.' || GCCK.SEGMENT5 NOT IN ('6144.00', '5533.01')
                 AND GJL.CODE_COMBINATION_ID = MOAM.SOURCE_CCID
                 AND MOAM.SOB_CODE = C_SOB_CODE
                 AND NVL (MOAM.DISABLED, 'N') = 'N'
                 AND GJH.SET_OF_BOOKS_ID = GSOB.SET_OF_BOOKS_ID
            GROUP BY GSOB.SHORT_NAME,
                     GJH.NAME,
                     GJH.JE_HEADER_ID,
                     GJH.CURRENCY_CODE,
                     GJH.PERIOD_NAME,
                     GJH.DEFAULT_EFFECTIVE_DATE,
                     GJH.SET_OF_BOOKS_ID,
                     GCCK.SEGMENT1;

        CURSOR C_4 (
            C_SOB_ID      NUMBER,
            C_PERIOD      VARCHAR2,
            C_STATUS      VARCHAR2,
            C_SOB_CODE    VARCHAR2) IS
              SELECT GSOB.SHORT_NAME,
                     GJH.NAME,
                     GJH.CURRENCY_CODE,
                     GJH.PERIOD_NAME,
                     GJH.DEFAULT_EFFECTIVE_DATE,
                     GJH.SET_OF_BOOKS_ID,
                     RATE_CONVERSION (GJH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AC, GJH.DEFAULT_EFFECTIVE_DATE) AS EXCHANGE_RATE,
                     GCCK.SEGMENT1,
                     GCCK.SEGMENT2,
                     GCCK.SEGMENT3,
                     SUM (NVL (GJL.ACCOUNTED_DR, 0)) - SUM (NVL (GJL.ACCOUNTED_CR, 0))                          ENTERED_DR,
                     0                                                                                          ENTERED_CR,
                     SUM (NVL (GJL.ACCOUNTED_DR, 0)) - SUM (NVL (GJL.ACCOUNTED_CR, 0))                          ACCOUNTED_DR,
                     0                                                                                          ACCOUNTED_CR,
                     (  SUM (
                              NVL (GJL.ACCOUNTED_DR, 0)
                            * RATE_CONVERSION (GJH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AC, GJH.DEFAULT_EFFECTIVE_DATE))
                      - SUM (
                              NVL (GJL.ACCOUNTED_CR, 0)
                            * RATE_CONVERSION (GJH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AC, GJH.DEFAULT_EFFECTIVE_DATE)))
                         ACCT_DR,
                     0                                                                                          ACCT_CR
                FROM GL_JE_HEADERS           GJH,
                     GL_JE_LINES             GJL,
                     GL_CODE_COMBINATIONS_KFV GCCK,
                     MK_OVERSEA_ACCT_MAPPING MOAM,
                     GL_SETS_OF_BOOKS        GSOB
               WHERE 1 = 1
                 AND ( (P_TYPE = 'FAC')
                   OR (P_TYPE = 'TPE'
                   AND GJH.NAME NOT LIKE G_PREFIX || '%'))
                 --              AND GJH.NAME = 'Adj#08-013'
                 AND GJH.SET_OF_BOOKS_ID = C_SOB_ID
                 AND GJH.PERIOD_NAME = C_PERIOD
                 --              AND GJH.STATUS = NVL (C_STATUS, GJH.STATUS)
                 AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
                 AND GJL.CODE_COMBINATION_ID = GCCK.CODE_COMBINATION_ID
                 AND GCCK.SEGMENT3 IN ('31101', '37400', 'S2000')
                 AND (GCCK.SEGMENT4 LIKE '55%'
                   OR GCCK.SEGMENT4 LIKE '62%'
                   OR GCCK.SEGMENT4 LIKE '61%')
                 --               AND GCCK.SEGMENT4 || '.' || GCCK.SEGMENT5 NOT IN ('6144.00', '5515.03', '5533.01')--Jimbo Marked by Jimmy Ask
                 AND GCCK.SEGMENT4 || '.' || GCCK.SEGMENT5 NOT IN ('6144.00', '5533.01')
                 AND GJL.CODE_COMBINATION_ID = MOAM.SOURCE_CCID
                 AND MOAM.SOB_CODE = C_SOB_CODE
                 AND NVL (MOAM.DISABLED, 'N') = 'N'
                 AND GJH.SET_OF_BOOKS_ID = GSOB.SET_OF_BOOKS_ID
            GROUP BY GSOB.SHORT_NAME,
                     GJH.NAME,
                     GJH.JE_HEADER_ID,
                     GJH.CURRENCY_CODE,
                     GJH.PERIOD_NAME,
                     GJH.DEFAULT_EFFECTIVE_DATE,
                     GJH.SET_OF_BOOKS_ID,
                     GCCK.SEGMENT1,
                     GCCK.SEGMENT2,
                     GCCK.SEGMENT3;

        CURSOR C_ACCT (C_SOB_ID      NUMBER,
                       C_PERIOD      VARCHAR2,
                       C_STATUS      VARCHAR2,
                       C_SOB_CODE    VARCHAR2) IS
              SELECT GCCK.SEGMENT1,
                     GCCK.SEGMENT2,
                     GCCK.SEGMENT3,
                     GCCK.SEGMENT4,
                     GCCK.SEGMENT5,
                     GCCK.SEGMENT6,
                     GCCK.CONCATENATED_SEGMENTS GL_ACCT,
                     MOAM.TARGET_CCID
                FROM GL_JE_HEADERS           GJH,
                     GL_JE_LINES             GJL,
                     GL_CODE_COMBINATIONS_KFV GCCK,
                     (SELECT *
                        FROM MK_OVERSEA_ACCT_MAPPING
                       WHERE 1 = 1
                         AND NVL (DISABLED, 'N') <> 'Y') MOAM
               WHERE 1 = 1
                 AND ( (P_TYPE = 'FAC')
                   OR (P_TYPE = 'TPE'
                   AND GJH.NAME NOT LIKE G_PREFIX || '%'))
                 --              AND GJH.NAME = 'Adj#08-013'
                 AND GJH.SET_OF_BOOKS_ID = C_SOB_ID
                 AND GJH.PERIOD_NAME = C_PERIOD
                 --              AND GJH.STATUS = NVL (C_STATUS, GJH.STATUS)
                 AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
                 AND GJL.CODE_COMBINATION_ID = GCCK.CODE_COMBINATION_ID
                 AND GCCK.SEGMENT3 IN ('31101', '37400', 'S2000')
                 AND (GCCK.SEGMENT4 LIKE '55%'
                   OR GCCK.SEGMENT4 LIKE '62%'
                   OR GCCK.SEGMENT4 LIKE '61%')
                 --               AND GCCK.SEGMENT4 || '.' || GCCK.SEGMENT5 NOT IN ('6144.00', '5515.03', '5533.01')--Jimbo Marked by Jimmy Ask
                 AND GCCK.SEGMENT4 || '.' || GCCK.SEGMENT5 NOT IN ('6144.00', '5533.01')
                 AND GJL.CODE_COMBINATION_ID = MOAM.SOURCE_CCID(+)
                 AND MOAM.SOB_CODE(+) = C_SOB_CODE
                 AND MOAM.TARGET_CCID IS NULL
            GROUP BY GCCK.SEGMENT1,
                     GCCK.SEGMENT2,
                     GCCK.SEGMENT3,
                     GCCK.SEGMENT4,
                     GCCK.SEGMENT5,
                     GCCK.SEGMENT6,
                     GCCK.CONCATENATED_SEGMENTS,
                     MOAM.TARGET_CCID;

        LN_ORG_ID                  NUMBER;
        LC_USER_NAME               VARCHAR2 (100);
        LC_USER_JE_SOURCE_NAME     VARCHAR2 (255);
        LC_USER_JE_CATEGORY_NAME   VARCHAR2 (255);
        LC_PERIOD_NAME             VARCHAR2 (255);
        LC_BASE_CURRENCY_CODE      VARCHAR2 (15);
        LC_BATCH_NAME              VARCHAR2 (255);
        LN_SET_OF_BOOKS_ID         NUMBER;
        LN_GROUP_ID                NUMBER;
        LC_JOURNAL_ENTRY_NAME      VARCHAR2 (255);
        LN_REQ_ID                  NUMBER;
        LD_ACCOUNTING_DATE         DATE;
        LN_CR_ACCT_ID              NUMBER;
        X_JE_HEADER_ID             NUMBER;
        V_REC                      R_REC;
        V_GCC                      GL_CODE_COMBINATIONS%ROWTYPE;
        V_STAGE                    VARCHAR2 (30);
        V_ERROR_FLAG               VARCHAR2 (1);
        E_ACCT_ERROR               EXCEPTION;
        R_SOB                      GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE            VARCHAR2 (30) := 'SAMPLE OH';
        V_DESCRIPTION              VARCHAR2 (30) := 'SAMPLE OH';
        V_STRING                   VARCHAR2 (3000);
        E_GEN_CCID_EXCEPTION       EXCEPTION;
    BEGIN
        G_MSG := 'START:' || P_SOB_ID;
        R_SOB := GET_SOB (P_SOB_ID);

        G_MSG := '1.0';
        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        V_ERROR_FLAG := 'N';

        BEGIN
            SELECT USER_ID
              INTO G_USER_ID
              FROM MKFND_USER_V
             WHERE USER_NAME = G_USER_NAME;
        EXCEPTION
            WHEN OTHERS THEN
                G_MSG := 'User Error(' || G_USER_NAME || '):' || SQLERRM;
                RETURN G_MSG;
        END;

        V_ERROR_FLAG := 'N';
        G_MSG := '2.0';

        --科目設定檢查
        FOR V_ACCT IN C_ACCT (C_SOB_ID => P_SOB_ID, C_PERIOD => P_PERIOD, C_STATUS => G_STATUS, C_SOB_CODE => P_SOB_CODE) LOOP
            IF V_ERROR_FLAG = 'Y' THEN
                G_MSG := G_MSG || CHR (10) || '(10) 樣品中心費用拋TPV管帳>>' || V_ACCT.GL_ACCT || '尚未設定';
            ELSE
                G_MSG := '(10) 樣品中心費用拋TPV管帳>>' || V_ACCT.GL_ACCT || '尚未設定';
            END IF;

            V_ERROR_FLAG := 'Y';
        END LOOP;

        G_MSG := '3.0';

        IF V_ERROR_FLAG = 'Y' THEN
            RAISE E_ACCT_ERROR;
        END IF;

        G_MSG := '4.0';

        IF NVL (P_INS_FLAG, 'Y') = 'N' THEN
            G_MSG := V_ERROR_FLAG || CHR (10) || '(10) 樣品中心費用拋TPV管帳 檢查完成';
            RETURN G_MSG;
        ELSE
            --Pre Setting
            PRE_SETTING (P_SOB_ID,
                         P_PERIOD,
                         LN_SET_OF_BOOKS_ID,
                         LC_PERIOD_NAME,
                         LC_USER_JE_SOURCE_NAME,
                         LC_USER_JE_CATEGORY_NAME,
                         LC_BASE_CURRENCY_CODE,
                         LD_ACCOUNTING_DATE,
                         LN_GROUP_ID,
                         LC_BATCH_NAME);
            V_REC.P_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
            V_REC.P_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);

            --產區管帳
            ----借
            IF P_TYPE = 'FAC' THEN
                FOR V IN C_4 (C_SOB_ID => LN_SET_OF_BOOKS_ID, C_PERIOD => LC_PERIOD_NAME, C_STATUS => G_STATUS, C_SOB_CODE => P_SOB_CODE) LOOP
                    --               V_REC.P_BATCH_NAME              := LC_BATCH_NAME;
                    --               V_REC.P_JOURNAL_ENTRY_NAME      := LC_JOURNAL_ENTRY_NAME;
                    V_REC.P_PERIOD_NAME := LC_PERIOD_NAME;
                    V_REC.P_USER_JE_SOURCE_NAME := LC_USER_JE_SOURCE_NAME;
                    V_REC.P_USER_JE_CATEGORY_NAME := LC_USER_JE_CATEGORY_NAME;
                    V_REC.P_CURRENCY_CODE := LC_BASE_CURRENCY_CODE;
                    --               V_REC.P_CURRENCY_CONVERSION_DATE   := V.DEFAULT_EFFECTIVE_DATE;
                    --               V_REC.P_EXCHANGE_RATE              := V.EXCHANGE_RATE;
                    V_GCC.SEGMENT1 := V.SEGMENT1;
                    V_GCC.SEGMENT2 := V.SEGMENT2;
                    V_GCC.SEGMENT3 := V.SEGMENT3;
                    V_GCC.SEGMENT4 := '2891';
                    V_GCC.SEGMENT5 := '00';
                    V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V.SHORT_NAME, 'FAM');
                    V_REC.P_SET_OF_BOOKS_ID := LN_SET_OF_BOOKS_ID;
                    V_REC.P_CCID := GET_CC_ID (V_GCC);

                    IF V_REC.P_CCID = -1 THEN
                        MK_GL_PUB.CREATE_GL_ACCOUNT (
                            V_REC.P_SET_OF_BOOKS_ID,
                               V_GCC.SEGMENT1
                            || '.'
                            || V_GCC.SEGMENT2
                            || '.'
                            || V_GCC.SEGMENT3
                            || '.'
                            || V_GCC.SEGMENT4
                            || '.'
                            || V_GCC.SEGMENT5
                            || '.'
                            || V_GCC.SEGMENT6,
                            V_STRING);

                        IF V_STRING IS NOT NULL THEN
                            RAISE E_GEN_CCID_EXCEPTION;
                        ELSE
                            V_REC.P_CCID := GET_CC_ID (V_GCC);
                        END IF;
                    END IF;

                    V_REC.P_DESCRIPTION := V_DESCRIPTION;                                                                   --V.DESCRIPTION;
                    V_REC.P_DATE := LD_ACCOUNTING_DATE;
                    V_REC.P_USER_ID := G_USER_ID;
                    V_REC.P_GROUP_ID := LN_GROUP_ID;
                    V_REC.P_DR := V.ENTERED_DR;
                    V_REC.P_CR := V.ENTERED_CR;                                                                              --V.ENTERED_CR;
                    --               V_REC.P_DR_ACC                     := V.ACCOUNTED_DR;
                    --               V_REC.P_CR_ACC                     := V.ACCOUNTED_CR;                                                                      --V.ACCT_CR;
                    IMP_GI (V_REC);
                END LOOP;

                ----貸
                FOR V IN C_1 (C_SOB_ID => LN_SET_OF_BOOKS_ID, C_PERIOD => LC_PERIOD_NAME, C_STATUS => G_STATUS, C_SOB_CODE => P_SOB_CODE) LOOP
                    --               V_REC.P_BATCH_NAME              := LC_BATCH_NAME;
                    --               V_REC.P_JOURNAL_ENTRY_NAME      := G_PREFIX || '樣品中心' || V.NAME;
                    V_REC.P_PERIOD_NAME := LC_PERIOD_NAME;
                    V_REC.P_USER_JE_SOURCE_NAME := LC_USER_JE_SOURCE_NAME;
                    V_REC.P_USER_JE_CATEGORY_NAME := LC_USER_JE_CATEGORY_NAME;
                    V_REC.P_CURRENCY_CODE := LC_BASE_CURRENCY_CODE;
                    --               V_REC.P_CURRENCY_CONVERSION_DATE   := V.DEFAULT_EFFECTIVE_DATE;
                    --               V_REC.P_EXCHANGE_RATE              := V.EXCHANGE_RATE;
                    V_REC.P_CCID := V.SOURCE_CCID;
                    V_REC.P_DESCRIPTION := V.DESCRIPTION;
                    V_REC.P_DATE := LD_ACCOUNTING_DATE;
                    V_REC.P_USER_ID := G_USER_ID;
                    V_REC.P_SET_OF_BOOKS_ID := LN_SET_OF_BOOKS_ID;
                    V_REC.P_GROUP_ID := LN_GROUP_ID;
                    V_REC.P_DR := V.ED_CR;
                    V_REC.P_CR := V.ED_DR;
                    --               V_REC.P_DR_ACC                     := V.ACCT_CR;
                    --               V_REC.P_CR_ACC                     := V.ACCT_DR;
                    V_REC.P_ATTRIBUTE1 := V.ATTRIBUTE1;
                    V_REC.P_ATTRIBUTE2 := V.ATTRIBUTE2;
                    V_REC.P_ATTRIBUTE3 := V.ATTRIBUTE3;
                    V_REC.P_ATTRIBUTE4 := V.ATTRIBUTE4;
                    V_REC.P_ATTRIBUTE5 := V.ATTRIBUTE5;
                    V_REC.P_ATTRIBUTE6 := V.ATTRIBUTE6;
                    V_REC.P_ATTRIBUTE7 := V.ATTRIBUTE7;
                    V_REC.P_ATTRIBUTE8 := V.ATTRIBUTE8;
                    V_REC.P_ATTRIBUTE9 := V.ATTRIBUTE9;
                    V_REC.P_ATTRIBUTE10 := V.ATTRIBUTE10;
                    V_REC.P_ATTRIBUTE11 := V.ATTRIBUTE11;
                    V_REC.P_ATTRIBUTE12 := V.ATTRIBUTE12;
                    V_REC.P_ATTRIBUTE13 := V.ATTRIBUTE13;
                    V_REC.P_ATTRIBUTE14 := V.ATTRIBUTE14;
                    V_REC.P_ATTRIBUTE15 := V.ATTRIBUTE15;
                    IMP_GI (V_REC);
                END LOOP;

                -- RUN JOURNAL IMPORT
                LN_REQ_ID := APPS.ATK_GL_COMMON_PKG.INSERT_GL_CONTROL (LN_SET_OF_BOOKS_ID, G_USER_ID, LN_GROUP_ID);

                IF LN_REQ_ID = -1 THEN
                    g_msg := '樣品中心拋管帳>>Failure!! GROUP ID:' || LN_GROUP_ID;
                ELSE
                    g_msg := '樣品中心拋管帳>>Success!! Concurrent ID:' || LN_REQ_ID;
                END IF;

                DBMS_OUTPUT.put_line (g_msg);

                COMMIT;
            ELSIF P_TYPE = 'TPE' THEN
                --台北管帳
                --Pre Setting
                BEGIN
                    SELECT ORGANIZATION_ID
                      INTO LN_ORG_ID
                      FROM ORG_ORGANIZATION_DEFINITIONS
                     WHERE 1 = 1
                       AND SET_OF_BOOKS_ID = G_TPV_SOB_ID;
                EXCEPTION
                    WHEN OTHERS THEN
                        LN_ORG_ID := NULL;
                END;

                SELECT TO_DATE (P_PERIOD, 'MON-YY') INTO LD_ACCOUNTING_DATE FROM DUAL;

                --取得 GROUP_ID,BATCH_NAME
                APPS.ATK_GL_COMMON_PKG.GET_COMMON_INFO (LN_ORG_ID,                                                                      --in
                                                        LD_ACCOUNTING_DATE,                                                             --in
                                                        G_USER_NAME,                                                                    --in
                                                        LC_USER_JE_SOURCE_NAME,
                                                        LC_USER_JE_CATEGORY_NAME,
                                                        LC_PERIOD_NAME,
                                                        LC_BASE_CURRENCY_CODE,
                                                        LC_BATCH_NAME,
                                                        LN_SET_OF_BOOKS_ID,
                                                        LN_GROUP_ID);

                --            BEGIN
                --               SELECT    G_PREFIX
                --                      || '樣品中心'
                --                      || TO_CHAR (LD_ACCOUNTING_DATE, 'yyyymmdd')
                --                      || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 13, 3)), '000')) + 1, 3, '0')
                --                 INTO LC_BATCH_NAME
                --                 FROM GL_JE_BATCHES
                --                WHERE SET_OF_BOOKS_ID = LN_SET_OF_BOOKS_ID
                --                  AND SUBSTR (NAME, 1, 15) LIKE G_PREFIX || '樣品中心' || TO_CHAR (LD_ACCOUNTING_DATE, 'yyyymmdd') || '%';
                --            EXCEPTION
                --               WHEN OTHERS THEN
                --                  DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
                --            END;
                ----借
                FOR V IN C_2 (C_SOB_ID => P_SOB_ID, C_PERIOD => LC_PERIOD_NAME, C_STATUS => G_STATUS, C_SOB_CODE => P_SOB_CODE) LOOP
                    --               V_REC.P_BATCH_NAME                 := LC_BATCH_NAME;
                    --               V_REC.P_JOURNAL_ENTRY_NAME         := LC_JOURNAL_ENTRY_NAME;
                    V_REC.P_PERIOD_NAME := LC_PERIOD_NAME;
                    V_REC.P_USER_JE_SOURCE_NAME := LC_USER_JE_SOURCE_NAME;
                    V_REC.P_USER_JE_CATEGORY_NAME := LC_USER_JE_CATEGORY_NAME;
                    V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;
                    V_REC.P_CURRENCY_CONVERSION_DATE := V.DEFAULT_EFFECTIVE_DATE;
                    V_REC.P_EXCHANGE_RATE := V.EXCHANGE_RATE;
                    V_REC.P_CCID := V.TARGET_CCID;
                    V_REC.P_DESCRIPTION := V.DESCRIPTION;
                    V_REC.P_DATE := LD_ACCOUNTING_DATE;
                    V_REC.P_USER_ID := G_USER_ID;
                    V_REC.P_SET_OF_BOOKS_ID := LN_SET_OF_BOOKS_ID;
                    V_REC.P_GROUP_ID := LN_GROUP_ID;
                    V_REC.P_DR := V.ENTERED_DR;
                    V_REC.P_CR := 0;
                    V_REC.P_DR_ACC := V.ACCT_DR;
                    V_REC.P_CR_ACC := 0;
                    IMP_GI_CURR (V_REC);
                END LOOP;

                ----貸
                FOR V IN C_3 (C_SOB_ID => P_SOB_ID, C_PERIOD => LC_PERIOD_NAME, C_STATUS => G_STATUS, C_SOB_CODE => P_SOB_CODE) LOOP
                    --               V_REC.P_BATCH_NAME                 := LC_BATCH_NAME;
                    --               V_REC.P_JOURNAL_ENTRY_NAME         := LC_JOURNAL_ENTRY_NAME;
                    V_REC.P_PERIOD_NAME := LC_PERIOD_NAME;
                    V_REC.P_USER_JE_SOURCE_NAME := LC_USER_JE_SOURCE_NAME;
                    V_REC.P_USER_JE_CATEGORY_NAME := LC_USER_JE_CATEGORY_NAME;
                    V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;
                    V_REC.P_CURRENCY_CONVERSION_DATE := V.DEFAULT_EFFECTIVE_DATE;
                    V_REC.P_EXCHANGE_RATE := V.EXCHANGE_RATE;
                    V_GCC.SEGMENT1 := '15';                                                                                --V_REC.SEGMENT1;
                    V_GCC.SEGMENT2 := '01';                                                                                --V_REC.SEGMENT2;
                    V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (P_SOB_ID));
                    --                    SELECT DEPT_CODE
                    --                      INTO V_GCC.SEGMENT3
                    --                      FROM MK_GL_DEPTS
                    --                     WHERE 1 = 1
                    --                       AND PARENT_ID IS NULL
                    --                       AND SOB_ID = P_SOB_ID
                    --                       AND ACTIVE_FLAG = 'Y'
                    --                       AND SYSDATE BETWEEN ENABLE_DATE AND NVL (DISABLE_DATE, SYSDATE);
                    V_GCC.SEGMENT4 := '2891';
                    V_GCC.SEGMENT5 := '00';
                    V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V.SHORT_NAME, 'TPM', V.SEGMENT1);
                    V_REC.P_SET_OF_BOOKS_ID := LN_SET_OF_BOOKS_ID;
                    V_REC.P_CCID := GEN_CC_ID (V_GCC, V_REC.P_SET_OF_BOOKS_ID);
                    V_REC.P_DESCRIPTION := V_DESCRIPTION;
                    V_REC.P_DATE := LD_ACCOUNTING_DATE;
                    V_REC.P_USER_ID := G_USER_ID;
                    V_REC.P_GROUP_ID := LN_GROUP_ID;
                    V_REC.P_DR := 0;
                    V_REC.P_CR := V.ENTERED_DR;
                    V_REC.P_DR_ACC := 0;
                    V_REC.P_CR_ACC := V.ACCT_DR;
                    IMP_GI_CURR (V_REC);
                END LOOP;

                -- RUN JOURNAL IMPORT
                DBMS_OUTPUT.PUT_LINE (LN_SET_OF_BOOKS_ID || '-' || G_USER_ID || '-' || LN_GROUP_ID);
                LN_REQ_ID := APPS.ATK_GL_COMMON_PKG.INSERT_GL_CONTROL (LN_SET_OF_BOOKS_ID, G_USER_ID, LN_GROUP_ID);

                IF LN_REQ_ID = -1 THEN
                    g_msg := '樣品中心 Failure!! GROUP ID:' || LN_GROUP_ID;
                ELSE
                    g_msg := '樣品中心 Success!! Concurrent ID:' || LN_REQ_ID;
                END IF;

                DBMS_OUTPUT.put_line (g_msg);

                COMMIT;
            END IF;

            RETURN G_MSG;
        END IF;
    EXCEPTION
        WHEN E_GEN_CCID_EXCEPTION THEN
            RETURN 'CC_ID ERROR:' || V_STRING;
        WHEN E_ACCT_ERROR THEN
            RETURN '樣品中心 E_ACCT_ERROR' || G_MSG;
        WHEN OTHERS THEN
            G_MSG := '樣品中心 Error: ' || SQLERRM;
            RETURN G_MSG;
    END IMP_SAMPLE_OH;

    --海外OH匯入TPV-GL
    FUNCTION IMP_OVERSEA_OH (P_SOB_ID     IN NUMBER,
                             P_PERIOD     IN VARCHAR2,
                             P_SOB_CODE   IN VARCHAR2,
                             P_TYPE       IN VARCHAR2,
                             P_INS_FLAG      VARCHAR2 DEFAULT NULL)
        RETURN VARCHAR2 IS
        CURSOR JOURNAL (P_SOB_ID IN NUMBER, P_PERIOD IN VARCHAR2) IS
              SELECT JH.NAME, JH.JE_HEADER_ID
                FROM GL_JE_HEADERS          JH,
                     GL_JE_LINES            JL,
                     GL_CODE_COMBINATIONS_V GCC,
                     MK_OVERSEA_ACCT_MAPPING MM
               WHERE 1 = 1
                 AND JH.NAME NOT LIKE G_PREFIX || '%'
                 AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
                 AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                 AND JL.CODE_COMBINATION_ID = MM.SOURCE_CCID(+)
                 AND MM.SOB_CODE(+) = P_SOB_CODE
                 AND NVL (MM.DISABLED, 'N') = 'N'
                 AND JH.SET_OF_BOOKS_ID = P_SOB_ID
                 AND GCC.SEGMENT3 IN ('37402',
                                      '37052',
                                      '31102',
                                      '31161',
                                      '32161',
                                      '26161',
                                      'H2330',
                                      'H2340',
                                      'H2350',
                                      '36361',
                                      '25561',
                                      'H2370',
                                      'H2360')
                 AND JH.PERIOD_NAME = P_PERIOD
                 AND (GCC.SEGMENT4 LIKE ('55%')
                   OR GCC.SEGMENT4 LIKE ('54%')
                   OR GCC.SEGMENT4 LIKE ('62%')
                   OR SEGMENT4 LIKE ('61%'))
                 AND GCC.SEGMENT4 || '.' || GCC.SEGMENT5 NOT IN ('6144.00', '5515.03', '5533.01')
            --              AND JH.STATUS = NVL (G_STATUS, JH.STATUS)
            GROUP BY JH.NAME, JH.JE_HEADER_ID
            ORDER BY 1;

        CURSOR DR (
            C_SOB_ID          IN NUMBER,
            C_PERIOD          IN VARCHAR2,
            C_JE_HEADER_ID       NUMBER,
            C_STATUS             VARCHAR2,
            C_SOB_CODE           VARCHAR2,
            c_currency_code      VARCHAR2) IS
            --管帳借方
            SELECT GSOB.SHORT_NAME,
                   JH.NAME,
                   JH.JE_HEADER_ID,
                   JL.CODE_COMBINATION_ID,
                   JH.CURRENCY_CODE,
                   JH.PERIOD_NAME,
                   JH.DEFAULT_EFFECTIVE_DATE,
                   JH.SET_OF_BOOKS_ID,
                   GCC.SEGMENT4,
                   SEGMENT1,
                   SEGMENT2,
                   SEGMENT3,
                   SEGMENT5,
                   SEGMENT6,
                   SEGMENT1 || '.' || SEGMENT2 || '.' || SEGMENT3 || '.' || GCC.SEGMENT4 || '.' || SEGMENT5 || '.' || SEGMENT6 AS GL_ACCT,
                   RATE_CONVERSION (JH.CURRENCY_CODE, c_currency_code, G_CONVERSION_TYPE_AC, JH.DEFAULT_EFFECTIVE_DATE)
                       AS EXCHANGE_RATE,
                   NVL (JL.ACCOUNTED_DR, 0) - NVL (JL.ACCOUNTED_CR, 0)
                       AS ENTERED_DR,
                   (    NVL (JL.ACCOUNTED_DR, 0)
                      * RATE_CONVERSION (JH.CURRENCY_CODE, c_currency_code, G_CONVERSION_TYPE_AC, JH.DEFAULT_EFFECTIVE_DATE)
                    -   NVL (JL.ACCOUNTED_CR, 0)
                      * RATE_CONVERSION (JH.CURRENCY_CODE, c_currency_code, G_CONVERSION_TYPE_AC, JH.DEFAULT_EFFECTIVE_DATE))
                       AS ACCOUNTED_DR,
                   JL.DESCRIPTION,
                   JL.ATTRIBUTE1,
                   JL.ATTRIBUTE2,
                   JL.ATTRIBUTE3,
                   JL.ATTRIBUTE4,
                   JL.ATTRIBUTE5,
                   JL.ATTRIBUTE6,
                   JL.ATTRIBUTE7,
                   JL.ATTRIBUTE8,
                   JL.ATTRIBUTE9,
                   JL.ATTRIBUTE10,
                   JL.ATTRIBUTE11,
                   JL.ATTRIBUTE12,
                   JL.ATTRIBUTE13,
                   JL.ATTRIBUTE14,
                   JL.ATTRIBUTE15,
                   MM.SOURCE_CCID,
                   MM.TARGET_CCID
              FROM GL_JE_HEADERS            JH,
                   GL_JE_LINES              JL,
                   GL_CODE_COMBINATIONS_V   GCC,
                   MK_OVERSEA_ACCT_MAPPING  MM,
                   GL_SETS_OF_BOOKS         GSOB
             WHERE 1 = 1
               AND JH.NAME NOT LIKE G_PREFIX || '%'
               AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
               AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
               AND JL.CODE_COMBINATION_ID = MM.SOURCE_CCID(+)
               AND MM.SOB_CODE(+) = C_SOB_CODE
               AND NVL (MM.DISABLED, 'N') = 'N'
               AND JH.SET_OF_BOOKS_ID = C_SOB_ID
               AND GCC.SEGMENT3 IN ('37402',
                                    '37052',
                                    '31102',
                                    '31161',
                                    '32161',
                                    '26161',
                                    'H2330',
                                    'H2340',
                                    'H2350',
                                    '36361',
                                    '25561',
                                    'H2370',
                                    'H2360')
               AND JH.PERIOD_NAME = C_PERIOD
               AND (GCC.SEGMENT4 LIKE ('55%')
                 OR GCC.SEGMENT4 LIKE ('54%')
                 OR GCC.SEGMENT4 LIKE ('62%')
                 OR SEGMENT4 LIKE ('61%'))
               AND GCC.SEGMENT4 || '.' || GCC.SEGMENT5 NOT IN ('6144.00', '5515.03', '5533.01')
               AND (MM.DISABLED = 'N'
                 OR SOURCE_CCID IS NULL)
               AND JH.JE_HEADER_ID = NVL (C_JE_HEADER_ID, JH.JE_HEADER_ID)
               --            AND JH.STATUS = NVL (C_STATUS, JH.STATUS)
               AND JH.SET_OF_BOOKS_ID = GSOB.SET_OF_BOOKS_ID;

        CURSOR CR (
            C_SOB_ID          IN NUMBER,
            C_PERIOD          IN VARCHAR2,
            C_JE_HEADER_ID       NUMBER,
            C_STATUS             VARCHAR2,
            C_SOB_CODE           VARCHAR2,
            c_currency_code      VARCHAR2) IS
              SELECT GSOB.SHORT_NAME,
                     JH.NAME,
                     JH.JE_HEADER_ID,
                     JH.CURRENCY_CODE,
                     JH.PERIOD_NAME,
                     JH.SET_OF_BOOKS_ID,
                     JH.DEFAULT_EFFECTIVE_DATE,
                     GCC.SEGMENT1,
                     SUM (NVL (JL.ACCOUNTED_DR, 0)) - SUM (NVL (JL.ACCOUNTED_CR, 0))                                    AS ENTERED_CR,
                     RATE_CONVERSION (JH.CURRENCY_CODE, c_currency_code, G_CONVERSION_TYPE_AC, JH.DEFAULT_EFFECTIVE_DATE) AS EXCHANGE_RATE,
                     (  SUM (
                              NVL (JL.ACCOUNTED_DR, 0)
                            * RATE_CONVERSION (JH.CURRENCY_CODE, c_currency_code, G_CONVERSION_TYPE_AC, JH.DEFAULT_EFFECTIVE_DATE))
                      - SUM (
                              NVL (JL.ACCOUNTED_CR, 0)
                            * RATE_CONVERSION (JH.CURRENCY_CODE, c_currency_code, G_CONVERSION_TYPE_AC, JH.DEFAULT_EFFECTIVE_DATE)))
                         AS ACCOUNTED_CR
                FROM GL_JE_HEADERS          JH,
                     GL_JE_LINES            JL,
                     GL_CODE_COMBINATIONS_V GCC,
                     MK_OVERSEA_ACCT_MAPPING MM,
                     GL_SETS_OF_BOOKS       GSOB
               WHERE 1 = 1
                 AND JH.NAME NOT LIKE G_PREFIX || '%'
                 AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
                 AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                 AND JL.CODE_COMBINATION_ID = MM.SOURCE_CCID(+)
                 AND MM.SOB_CODE(+) = C_SOB_CODE
                 AND NVL (MM.DISABLED, 'N') = 'N'
                 AND JH.SET_OF_BOOKS_ID = C_SOB_ID
                 AND GCC.SEGMENT3 IN ('37402',
                                      '37052',
                                      '31102',
                                      '31161',
                                      '32161',
                                      '26161',
                                      'H2330',
                                      'H2340',
                                      'H2350',
                                      '36361',
                                      '25561',
                                      '25961',
                                      'H2370',
                                      'H2360')
                 AND (GCC.SEGMENT4 LIKE ('55%')
                   OR GCC.SEGMENT4 LIKE ('54%')
                   OR GCC.SEGMENT4 LIKE ('62%')
                   OR SEGMENT4 LIKE ('61%'))
                 AND GCC.SEGMENT4 || '.' || GCC.SEGMENT5 NOT IN ('6144.00', '5515.03', '5533.01')
                 AND (MM.DISABLED = 'N'
                   OR SOURCE_CCID IS NULL)
                 AND JH.PERIOD_NAME = P_PERIOD
                 --              AND JH.STATUS = NVL (C_STATUS, JH.STATUS)
                 AND JH.JE_HEADER_ID = NVL (C_JE_HEADER_ID, JH.JE_HEADER_ID)
                 AND JH.SET_OF_BOOKS_ID = GSOB.SET_OF_BOOKS_ID
            GROUP BY GSOB.SHORT_NAME,
                     JH.NAME,
                     JH.JE_HEADER_ID,
                     JH.CURRENCY_CODE,
                     JH.PERIOD_NAME,
                     JH.SET_OF_BOOKS_ID,
                     JH.DEFAULT_EFFECTIVE_DATE,
                     GCC.SEGMENT1;

        V_REC                      R_REC;
        V_GCC                      GL_CODE_COMBINATIONS%ROWTYPE;
        LN_ORG_ID                  NUMBER;
        LC_USER_NAME               VARCHAR2 (100);
        LC_USER_JE_SOURCE_NAME     VARCHAR2 (255);
        LC_USER_JE_CATEGORY_NAME   VARCHAR2 (255);
        LC_PERIOD_NAME             VARCHAR2 (255);
        LC_BASE_CURRENCY_CODE      VARCHAR2 (15);
        LC_BATCH_NAME              VARCHAR2 (255);
        LN_SET_OF_BOOKS_ID         NUMBER;
        LN_GROUP_ID                NUMBER;
        LC_JOURNAL_ENTRY_NAME      VARCHAR2 (255);
        LN_REQ_ID                  NUMBER;
        LD_ACCOUNTING_DATE         DATE;
        LN_CR_ACCT_ID              NUMBER;
        X_JE_HEADER_ID             NUMBER;
        V_ERROR_FLAG               VARCHAR2 (1);
        E_ACCT_ERROR               EXCEPTION;
        R_SOB                      GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE            VARCHAR2 (30) := 'OVERSEA OH';
        V_DESCRIPTION              VARCHAR2 (30) := 'OVERSEA OH';
        V_STRING                   VARCHAR2 (3000);
        E_GEN_CCID_EXCEPTION       EXCEPTION;
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);

        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        --Check account 是否有setup
        FOR J_REC IN JOURNAL (P_SOB_ID, P_PERIOD) LOOP
            FOR DR_REC IN DR (P_SOB_ID,
                              P_PERIOD,
                              J_REC.JE_HEADER_ID,
                              G_STATUS,
                              P_SOB_CODE,
                              r_sob.currency_code) LOOP
                IF DR_REC.SOURCE_CCID IS NULL THEN
                    IF V_ERROR_FLAG = 'Y' THEN
                        G_MSG := G_MSG || CHR (10) || '(10) 海外費用拋TPV管帳>>' || DR_REC.GL_ACCT || '尚未設定';
                    ELSE
                        G_MSG := '(10) 海外費用拋TPV管帳>>' || DR_REC.GL_ACCT || '尚未設定';
                    END IF;

                    V_ERROR_FLAG := 'Y';
                END IF;
            END LOOP;
        END LOOP;

        IF V_ERROR_FLAG = 'Y' THEN
            RAISE E_ACCT_ERROR;
        END IF;

        BEGIN
            SELECT USER_ID
              INTO G_USER_ID
              FROM FND_USER
             WHERE USER_NAME = G_USER_NAME;
        EXCEPTION
            WHEN OTHERS THEN
                G_MSG := 'User Error(' || G_USER_NAME || '):' || SQLERRM;
                RETURN G_MSG;
        END;

        IF P_INS_FLAG = 'N' THEN
            G_MSG := '海外費用拋TPV管帳>> 檢查完成 ';
            RETURN G_MSG;
        ELSE
            --產區管帳
            --Pre Setting
            PRE_SETTING (P_SOB_ID,
                         P_PERIOD,
                         LN_SET_OF_BOOKS_ID,
                         LC_PERIOD_NAME,
                         LC_USER_JE_SOURCE_NAME,
                         LC_USER_JE_CATEGORY_NAME,
                         LC_BASE_CURRENCY_CODE,
                         LD_ACCOUNTING_DATE,
                         LN_GROUP_ID,
                         LC_BATCH_NAME);
            V_REC.P_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
            V_REC.P_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD, R_SOB.SHORT_NAME);
            LC_BATCH_NAME := V_REC.P_BATCH_NAME;
            LC_JOURNAL_ENTRY_NAME := V_REC.P_JOURNAL_ENTRY_NAME;

            --         BEGIN
            --            SELECT    G_PREFIX
            --                   || '海外費用'
            --                   || TO_CHAR (LD_ACCOUNTING_DATE, 'yyyymmdd')
            --                   || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 13, 3)), '000')) + 1, 3, '0')
            --              INTO LC_BATCH_NAME
            --              FROM GL_JE_BATCHES
            --             WHERE SET_OF_BOOKS_ID = LN_SET_OF_BOOKS_ID
            --               AND SUBSTR (NAME, 1, 15) LIKE G_PREFIX || '海外費用' || TO_CHAR (LD_ACCOUNTING_DATE, 'yyyymmdd') || '%';
            --         EXCEPTION
            --            WHEN OTHERS THEN
            --               DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
            --         END;
            ----借
            IF P_TYPE = 'FAC' THEN
                FOR V IN DR (C_SOB_ID          => LN_SET_OF_BOOKS_ID,
                             C_PERIOD          => LC_PERIOD_NAME,
                             C_JE_HEADER_ID    => NULL,
                             C_STATUS          => G_STATUS,
                             C_SOB_CODE        => P_SOB_CODE,
                             c_currency_code   => LC_BASE_CURRENCY_CODE) LOOP
                    --               V_REC.P_BATCH_NAME              := LC_BATCH_NAME;
                    --               V_REC.P_JOURNAL_ENTRY_NAME      := LC_JOURNAL_ENTRY_NAME;
                    V_REC.P_PERIOD_NAME := LC_PERIOD_NAME;
                    V_REC.P_USER_JE_SOURCE_NAME := LC_USER_JE_SOURCE_NAME;
                    V_REC.P_USER_JE_CATEGORY_NAME := LC_USER_JE_CATEGORY_NAME;
                    V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;
                    --               V_REC.P_CURRENCY_CONVERSION_DATE   := V.DEFAULT_EFFECTIVE_DATE;
                    --               V_REC.P_EXCHANGE_RATE              := V.EXCHANGE_RATE;
                    V_GCC.SEGMENT1 := V.SEGMENT1;
                    V_GCC.SEGMENT2 := V.SEGMENT2;
                    V_GCC.SEGMENT3 := V.SEGMENT3;
                    V_GCC.SEGMENT4 := '2891';
                    V_GCC.SEGMENT5 := '00';
                    V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V.SHORT_NAME, 'FAM');
                    V_REC.P_SET_OF_BOOKS_ID := LN_SET_OF_BOOKS_ID;
                    V_REC.P_CCID := GET_CC_ID (V_GCC);

                    IF V_REC.P_CCID = -1 THEN
                        MK_GL_PUB.CREATE_GL_ACCOUNT (
                            V_REC.P_SET_OF_BOOKS_ID,
                               V_GCC.SEGMENT1
                            || '.'
                            || V_GCC.SEGMENT2
                            || '.'
                            || V_GCC.SEGMENT3
                            || '.'
                            || V_GCC.SEGMENT4
                            || '.'
                            || V_GCC.SEGMENT5
                            || '.'
                            || V_GCC.SEGMENT6,
                            V_STRING);

                        IF V_STRING IS NOT NULL THEN
                            RAISE E_GEN_CCID_EXCEPTION;
                        ELSE
                            V_REC.P_CCID := GET_CC_ID (V_GCC);
                        END IF;
                    END IF;

                    V_REC.P_DESCRIPTION := V_DESCRIPTION;                                                                   --V.DESCRIPTION;
                    V_REC.P_DATE := LD_ACCOUNTING_DATE;
                    V_REC.P_USER_ID := G_USER_ID;
                    V_REC.P_GROUP_ID := LN_GROUP_ID;
                    --marked by Jimbo 2023/03/27 cause VPV got USD Journal so use accounted as input.
                    v_rec.p_dr := v.accounted_dr;
                    v_rec.p_cr := 0;
                    --                    V_REC.P_DR := V.ENTERED_DR;
                    --                    V_REC.P_CR := 0;
                    --               V_REC.P_DR_ACC                     := V.ENTERED_DR;
                    --               V_REC.P_CR_ACC                     := 0;
                    IMP_GI (V_REC);
                END LOOP;

                ----貸
                FOR V IN DR (C_SOB_ID          => LN_SET_OF_BOOKS_ID,
                             C_PERIOD          => LC_PERIOD_NAME,
                             C_JE_HEADER_ID    => NULL,
                             C_STATUS          => G_STATUS,
                             C_SOB_CODE        => P_SOB_CODE,
                             c_currency_code   => LC_BASE_CURRENCY_CODE) LOOP
                    --               V_REC.P_BATCH_NAME              := LC_BATCH_NAME;
                    --               V_REC.P_JOURNAL_ENTRY_NAME      := LC_JOURNAL_ENTRY_NAME;
                    V_REC.P_PERIOD_NAME := LC_PERIOD_NAME;
                    V_REC.P_USER_JE_SOURCE_NAME := LC_USER_JE_SOURCE_NAME;
                    V_REC.P_USER_JE_CATEGORY_NAME := LC_USER_JE_CATEGORY_NAME;
                    V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;
                    --               V_REC.P_CURRENCY_CONVERSION_DATE   := V.DEFAULT_EFFECTIVE_DATE;
                    --               V_REC.P_EXCHANGE_RATE              := V.EXCHANGE_RATE;
                    V_REC.P_CCID := V.SOURCE_CCID;
                    V_REC.P_DESCRIPTION := V.DESCRIPTION;
                    V_REC.P_DATE := LD_ACCOUNTING_DATE;
                    V_REC.P_USER_ID := G_USER_ID;
                    V_REC.P_SET_OF_BOOKS_ID := LN_SET_OF_BOOKS_ID;
                    V_REC.P_GROUP_ID := LN_GROUP_ID;
                    --marked by Jimbo 2023/03/27 cause VPV got USD Journal so use accounted as input.
                    v_rec.p_dr := 0;
                    v_rec.p_cr := v.accounted_dr;
                    --                    V_REC.P_DR := 0;
                    --                    V_REC.P_CR := V.ENTERED_DR;
                    --               V_REC.P_DR_ACC                     := 0;
                    --               V_REC.P_CR_ACC                     := V.ENTERED_DR;
                    V_REC.P_ATTRIBUTE1 := V.ATTRIBUTE1;
                    V_REC.P_ATTRIBUTE2 := V.ATTRIBUTE2;
                    V_REC.P_ATTRIBUTE3 := V.ATTRIBUTE3;
                    V_REC.P_ATTRIBUTE4 := V.ATTRIBUTE4;
                    V_REC.P_ATTRIBUTE5 := V.ATTRIBUTE5;
                    V_REC.P_ATTRIBUTE6 := V.ATTRIBUTE6;
                    V_REC.P_ATTRIBUTE7 := V.ATTRIBUTE7;
                    V_REC.P_ATTRIBUTE8 := V.ATTRIBUTE8;
                    V_REC.P_ATTRIBUTE9 := V.ATTRIBUTE9;
                    V_REC.P_ATTRIBUTE10 := V.ATTRIBUTE10;
                    V_REC.P_ATTRIBUTE11 := V.ATTRIBUTE11;
                    V_REC.P_ATTRIBUTE12 := V.ATTRIBUTE12;
                    V_REC.P_ATTRIBUTE13 := V.ATTRIBUTE13;
                    V_REC.P_ATTRIBUTE14 := V.ATTRIBUTE14;
                    V_REC.P_ATTRIBUTE15 := V.ATTRIBUTE15;
                    IMP_GI (V_REC);
                END LOOP;

                -- RUN JOURNAL IMPORT
                LN_REQ_ID := ATK_GL_COMMON_PKG.INSERT_GL_CONTROL (LN_SET_OF_BOOKS_ID, G_USER_ID, LN_GROUP_ID);

                IF LN_REQ_ID = -1 THEN
                    G_MSG := '樣品中心拋管帳>>Failure!! GROUP ID:' || LN_GROUP_ID;
                ELSE
                    G_MSG := '樣品中心拋管帳>>Success!! Concurrent ID:' || LN_REQ_ID;
                END IF;

                COMMIT;
            ELSIF P_TYPE = 'TPE' THEN
                --TPV管帳
                SELECT ORGANIZATION_ID
                  INTO LN_ORG_ID
                  FROM ORG_ORGANIZATION_DEFINITIONS
                 WHERE ORGANIZATION_CODE = 'TPV';

                SELECT TO_DATE (P_PERIOD, 'MON-YY') INTO LD_ACCOUNTING_DATE FROM DUAL;

                BEGIN
                    --取得 GROUP_ID,BATCH_NAME
                    APPS.ATK_GL_COMMON_PKG.GET_COMMON_INFO (LN_ORG_ID,
                                                            LD_ACCOUNTING_DATE,
                                                            G_USER_NAME,
                                                            LC_USER_JE_SOURCE_NAME,
                                                            LC_USER_JE_CATEGORY_NAME,
                                                            LC_PERIOD_NAME,
                                                            LC_BASE_CURRENCY_CODE,
                                                            LC_BATCH_NAME,
                                                            LN_SET_OF_BOOKS_ID,
                                                            LN_GROUP_ID);
                    LC_BATCH_NAME := V_REC.P_BATCH_NAME;
                    LC_JOURNAL_ENTRY_NAME := V_REC.P_JOURNAL_ENTRY_NAME;

                    --               BEGIN
                    --                  SELECT    G_PREFIX
                    --                         || '海外費用'
                    --                         || TO_CHAR (LD_ACCOUNTING_DATE, 'yyyymmdd')
                    --                         || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 13, 3)), '000')) + 1, 3, '0')
                    --                    INTO LC_BATCH_NAME
                    --                    FROM GL_JE_BATCHES
                    --                   WHERE SET_OF_BOOKS_ID = 22
                    --                     AND SUBSTR (NAME, 1, 15) LIKE G_PREFIX || '海外費用' || TO_CHAR (LD_ACCOUNTING_DATE, 'yyyymmdd') || '%';
                    --               --dbms_output.put_line (LC_BATCH_NAME);
                    --
                    --               EXCEPTION
                    --                  WHEN OTHERS THEN
                    --                     DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
                    --               END;
                    --貸方(固定碼)
                    --         IF P_SOB_ID = 84 THEN                                                                                       --15.01.09910.2891.00.629 柬 (CAM)
                    --            LN_CR_ACCT_ID   := 118511;
                    --         ELSIF P_SOB_ID = 385 THEN                                                                                --15.01.09909.2891.00.650 越TPL (VTP)
                    --            LN_CR_ACCT_ID   := 118514;
                    --         ELSIF P_SOB_ID = 404 THEN                                                                                   --15.01.09905.2891.00.639 印 (STL)
                    --            LN_CR_ACCT_ID   := 118577;
                    --         ELSIF P_SOB_ID = 285 THEN                                                                                   --15.01.09905.2891.00.639 印 (IGI)
                    --            LN_CR_ACCT_ID   := 118577;
                    --         ELSIF P_SOB_ID = 444 THEN                                                                                        --15.01.09903.2891.00.678 嘉義
                    --            LN_CR_ACCT_ID   := 118466;
                    --         ELSIF P_SOB_ID = 264 THEN                                                                                   --15.01.09910.2891.00.629  柬(MOH)
                    --            LN_CR_ACCT_ID   := 118511;
                    --         ELSIF P_SOB_ID = 384 THEN                                                                                   --15.01.09915.2891.00.640  北越(MK)
                    --            LN_CR_ACCT_ID   := 118513;
                    --         END IF;
                    -- 15.01.09901.2891.00.619 菲
                    FOR J_REC IN JOURNAL (P_SOB_ID, P_PERIOD) LOOP
                        FOR DR_REC IN DR (P_SOB_ID,
                                          P_PERIOD,
                                          J_REC.JE_HEADER_ID,
                                          G_STATUS,
                                          P_SOB_CODE,
                                          LC_BASE_CURRENCY_CODE) LOOP
                            --DR INSERT GL INTERFACE
                            --                            atk_gl_common_pkg.insert_gl_interface_all_curr
                            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                                          LC_JOURNAL_ENTRY_NAME,
                                                          LC_PERIOD_NAME,
                                                          LC_USER_JE_SOURCE_NAME,
                                                          LC_USER_JE_CATEGORY_NAME,
                                                          DR_REC.CURRENCY_CODE,
                                                          DR_REC.DEFAULT_EFFECTIVE_DATE,
                                                          DR_REC.EXCHANGE_RATE,
                                                          DR_REC.TARGET_CCID,
                                                          DR_REC.DESCRIPTION,
                                                          LD_ACCOUNTING_DATE,
                                                          G_USER_ID,
                                                          LN_SET_OF_BOOKS_ID,
                                                          LN_GROUP_ID,
                                                          DR_REC.ENTERED_DR,
                                                          0,
                                                          DR_REC.ACCOUNTED_DR,
                                                          0,
                                                          DR_REC.ATTRIBUTE1,
                                                          DR_REC.ATTRIBUTE2,
                                                          DR_REC.ATTRIBUTE3,
                                                          DR_REC.ATTRIBUTE4,
                                                          DR_REC.ATTRIBUTE5,
                                                          DR_REC.ATTRIBUTE6,
                                                          DR_REC.ATTRIBUTE7,
                                                          DR_REC.ATTRIBUTE8,
                                                          DR_REC.ATTRIBUTE9,
                                                          DR_REC.ATTRIBUTE10,
                                                          DR_REC.ATTRIBUTE11,
                                                          DR_REC.ATTRIBUTE12,
                                                          DR_REC.ATTRIBUTE13,
                                                          DR_REC.ATTRIBUTE14,
                                                          DR_REC.ATTRIBUTE15);
                        END LOOP;

                        FOR CR_REC IN CR (P_SOB_ID,
                                          P_PERIOD,
                                          J_REC.JE_HEADER_ID,
                                          G_STATUS,
                                          P_SOB_CODE,
                                          LC_BASE_CURRENCY_CODE) LOOP
                            V_GCC.SEGMENT1 := '15';                                                                        --V_REC.SEGMENT1;
                            V_GCC.SEGMENT2 := '01';                                                                        --V_REC.SEGMENT2;
                            V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (P_SOB_ID));
                            --                            SELECT DEPT_CODE
                            --                              INTO V_GCC.SEGMENT3
                            --                              FROM MK_GL_DEPTS
                            --                             WHERE 1 = 1
                            --                               AND PARENT_ID IS NULL
                            --                               AND SOB_ID = P_SOB_ID
                            --                               AND ACTIVE_FLAG = 'Y'
                            --                               AND SYSDATE BETWEEN ENABLE_DATE AND NVL (DISABLE_DATE, SYSDATE);
                            V_GCC.SEGMENT4 := '2891';
                            V_GCC.SEGMENT5 := '00';
                            V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (CR_REC.SHORT_NAME, 'TPM', CR_REC.SEGMENT1);
                            V_REC.P_CCID := GET_CC_ID (V_GCC);

                            IF V_REC.P_CCID = -1 THEN
                                MK_GL_PUB.CREATE_GL_ACCOUNT (
                                    LN_SET_OF_BOOKS_ID,
                                       V_GCC.SEGMENT1
                                    || '.'
                                    || V_GCC.SEGMENT2
                                    || '.'
                                    || V_GCC.SEGMENT3
                                    || '.'
                                    || V_GCC.SEGMENT4
                                    || '.'
                                    || V_GCC.SEGMENT5
                                    || '.'
                                    || V_GCC.SEGMENT6,
                                    V_STRING);

                                IF V_STRING IS NOT NULL THEN
                                    RAISE E_GEN_CCID_EXCEPTION;
                                ELSE
                                    V_REC.P_CCID := GET_CC_ID (V_GCC);
                                END IF;
                            END IF;

                            -- CR INSERT GL INTERFACE
                            --                            atk_gl_common_pkg.insert_gl_interface_all_curr
                            INSERT_GL_INTERFACE_ALL_CURR (LC_BATCH_NAME,
                                                          LC_JOURNAL_ENTRY_NAME,
                                                          LC_PERIOD_NAME,
                                                          LC_USER_JE_SOURCE_NAME,
                                                          LC_USER_JE_CATEGORY_NAME,
                                                          CR_REC.CURRENCY_CODE,
                                                          CR_REC.DEFAULT_EFFECTIVE_DATE,
                                                          CR_REC.EXCHANGE_RATE,
                                                          V_REC.P_CCID,                                                     --ln_cr_acct_id,
                                                          V_DESCRIPTION,
                                                          LD_ACCOUNTING_DATE,
                                                          G_USER_ID,
                                                          LN_SET_OF_BOOKS_ID,
                                                          LN_GROUP_ID,
                                                          0,
                                                          CR_REC.ENTERED_CR,
                                                          0,
                                                          CR_REC.ACCOUNTED_CR,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL,
                                                          NULL);
                        END LOOP;
                    END LOOP;
                END;

                -- RUN JOURNAL IMPORT
                LN_REQ_ID := ATK_GL_COMMON_PKG.INSERT_GL_CONTROL (LN_SET_OF_BOOKS_ID, G_USER_ID, LN_GROUP_ID);

                IF LN_REQ_ID = -1 THEN
                    G_MSG := '海外費用 Failure!! GROUP ID:' || LN_GROUP_ID;
                ELSE
                    G_MSG := '海外費用 Success!! Concurrent ID:' || LN_REQ_ID;
                END IF;

                COMMIT;
            ELSE
                G_MSG := '海外費用 Wrong Type!';
            END IF;
        END IF;

        RETURN G_MSG;
    EXCEPTION
        WHEN E_GEN_CCID_EXCEPTION THEN
            RETURN V_STRING;
        WHEN E_ACCT_ERROR THEN
            RETURN '海外費用:' || G_MSG;
        WHEN OTHERS THEN
            RETURN '海外費用 Error:' || SQLERRM;
    END IMP_OVERSEA_OH;

    FUNCTION IMP_GQC_FEE_FAC (P_PERIOD_NAME VARCHAR2, P_SOB_ID NUMBER)
        RETURN VARCHAR2 AS
        CURSOR C IS
            SELECT GB.SHORT_NAME,
                   MK_GL_PUB.SOB_TAX2MGMT (GB.SHORT_NAME) D_SHORT_NAME,
                   GB.SET_OF_BOOKS_ID,
                   JH.JE_HEADER_ID,
                   JH.NAME,
                   JH.CURRENCY_CODE,
                   JH.PERIOD_NAME,
                   JH.STATUS,
                   JH.DEFAULT_EFFECTIVE_DATE,
                   JL.CODE_COMBINATION_ID                 AS CCID,
                   JL.ACCOUNTED_DR                        ENTERED_DR,
                   JL.ACCOUNTED_CR                        ENTERED_CR,
                   JL.DESCRIPTION,
                   JL.ATTRIBUTE1,
                   JL.ATTRIBUTE2,
                   JL.ATTRIBUTE3,
                   JL.ATTRIBUTE4,
                   JL.ATTRIBUTE5,
                   JL.ATTRIBUTE6,
                   JL.ATTRIBUTE7,
                   JL.ATTRIBUTE8,
                   JL.ATTRIBUTE9,
                   JL.ATTRIBUTE10,
                   JL.ATTRIBUTE11,
                   JL.ATTRIBUTE12,
                   JL.ATTRIBUTE13,
                   JL.ATTRIBUTE14,
                   JL.ATTRIBUTE15,
                   JC.USER_JE_CATEGORY_NAME,
                   JS.USER_JE_SOURCE_NAME,
                   GCC.SEGMENT1,
                   GCC.SEGMENT2,
                   GCC.SEGMENT3,
                   GCC.SEGMENT4,
                   GCC.SEGMENT5,
                   GCC.SEGMENT6
              FROM GL_JE_HEADERS           JH,
                   GL_JE_LINES             JL,
                   GL_CODE_COMBINATIONS_V  GCC,
                   GL_JE_CATEGORIES_VL     JC,
                   GL_JE_SOURCES_VL        JS,
                   GL_SETS_OF_BOOKS        GB
             WHERE 1 = 1
               AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
               AND JH.JE_CATEGORY = JC.JE_CATEGORY_NAME
               AND JH.JE_SOURCE = JS.JE_SOURCE_NAME
               AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
               AND GCC.SEGMENT3 IN ('31363', '25563', '26163')
               --                   AND gcc.segment3 IN ('26162',
               --                                        '25162',
               --                                        '25562',
               --                                        '31361')                                                                                        --GU
               AND (GCC.SEGMENT4 LIKE '5%'
                 OR GCC.SEGMENT4 LIKE '6%')
               AND JH.PERIOD_NAME = P_PERIOD_NAME
               --            AND JH.STATUS = NVL (G_STATUS, JH.STATUS)
               AND JH.SET_OF_BOOKS_ID = GB.SET_OF_BOOKS_ID
               AND GB.SET_OF_BOOKS_ID = P_SOB_ID
               AND GB.SHORT_NAME IN ('IPV', 'MPV')
               --            AND GB.SHORT_NAME IN ('ISL-US', 'IGI', 'CAM')
               AND GB.ATTRIBUTE1 = 'M';

        V_REC                  R_REC;
        V_REQ_ID               VARCHAR2 (300);                                       --ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE%TYPE;
        V_GCC                  GL_CODE_COMBINATIONS%ROWTYPE;
        V_STRING               VARCHAR2 (3000);
        V_SHORT_NAME           GL_SETS_OF_BOOKS.SHORT_NAME%TYPE;
        R_SOB                  GL_SETS_OF_BOOKS%ROWTYPE;
        --        v_txn_type_code   VARCHAR2 (30) := 'GQC';
        V_TXN_TYPE_CODE        VARCHAR2 (30) := 'MDQC';
        V_STEP                 VARCHAR2 (30);
        E_GEN_CCID_EXCEPTION   EXCEPTION;
    BEGIN
        G_ERR_STRING := NULL;
        V_STEP := '0';
        R_SOB := GET_SOB (P_SOB_ID);
        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        V_STEP := '1';
        V_REC.P_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        V_REC.P_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        V_STEP := '2';
        -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 共用變數
        --      ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      V_REC.P_BATCH_NAME              := G_PREFIX || 'INSPECT GQC' || '-' || P_PERIOD_NAME || '-' || 'Dos-Accounting' || '/' || 'Transfer';
        --
        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'INSPECT GQC-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 21, 2)), '00')) + 1, 2, '0')
        --           INTO V_REC.P_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE 1 = 1
        --            AND JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = MK_GL_PUB.SOB_TAX2MGMT (P_SOB_ID)
        --            AND SUBSTR (NAME, 1, 20) LIKE
        --                   G_PREFIX || 'INSPECT GQC' || '-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --      END;
        V_REC.P_USER_JE_SOURCE_NAME := 'Dos-Accounting';
        V_REC.P_USER_JE_CATEGORY_NAME := 'Transfer';
        V_REC.P_GROUP_ID := GL_INTERFACE_CONTROL_PKG.GET_UNIQUE_ID;

        FOR V IN C LOOP
            -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 逐筆變數
            --      V_REC.P_JOURNAL_ENTRY_NAME      := '';                                                                                              --pre_cursor
            V_REC.P_PERIOD_NAME := V.PERIOD_NAME;
            --         V_REC.P_USER_JE_SOURCE_NAME     := V.USER_JE_SOURCE_NAME;                                                                        --pre_cursor
            --         V_REC.P_USER_JE_CATEGORY_NAME   := V.USER_JE_CATEGORY_NAME;                                                                      --pre_cursor
            V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;
            V_REC.P_CCID := V.CCID;
            V_REC.P_DESCRIPTION := V.DESCRIPTION;
            --         V_REC.P_DATE              := V.DEFAULT_EFFECTIVE_DATE;                                                                               --統一日期即可
            V_REC.P_DATE := TO_DATE (P_PERIOD_NAME, 'MON-RR');
            V_REC.P_USER_ID := NVL (G_USER_ID, P_USER_ID);
            V_SHORT_NAME := V.D_SHORT_NAME;
            V_REC.P_SET_OF_BOOKS_ID := V.SET_OF_BOOKS_ID;
            --      V_REC.P_GROUP_ID                := GL_INTERFACE_CONTROL_PKG.GET_UNIQUE_ID;                                                          --pre_cursor
            -- 借貸沿用
            V_REC.P_DR := NVL (V.ENTERED_DR, 0);
            V_REC.P_CR := NVL (V.ENTERED_CR, 0);
            V_REC.P_DR_ACC := NVL (V.ENTERED_DR, 0);
            V_REC.P_CR_ACC := NVL (V.ENTERED_CR, 0);
            V_REC.P_ATTRIBUTE1 := V.ATTRIBUTE1;
            V_REC.P_ATTRIBUTE2 := V.ATTRIBUTE2;
            V_REC.P_ATTRIBUTE3 := V.ATTRIBUTE3;
            V_REC.P_ATTRIBUTE4 := V.ATTRIBUTE4;
            V_REC.P_ATTRIBUTE5 := V.ATTRIBUTE5;
            V_REC.P_ATTRIBUTE6 := V.ATTRIBUTE6;
            V_REC.P_ATTRIBUTE7 := V.ATTRIBUTE7;
            V_REC.P_ATTRIBUTE8 := V.ATTRIBUTE8;
            V_REC.P_ATTRIBUTE9 := V.ATTRIBUTE9;
            V_REC.P_ATTRIBUTE10 := V.ATTRIBUTE10;
            V_REC.P_ATTRIBUTE11 := V.ATTRIBUTE11;
            V_REC.P_ATTRIBUTE12 := V.ATTRIBUTE12;
            V_REC.P_ATTRIBUTE13 := V.ATTRIBUTE13;
            V_REC.P_ATTRIBUTE14 := V.ATTRIBUTE14;
            V_REC.P_ATTRIBUTE15 := V.ATTRIBUTE15;
            /*
            BOOK  SITE D/C  ACCT
            ----- ---- ---  -------------------------
              ISU STL  Dr.  xx.xx.26162.2891.00.635
                        Cr.  xx.xx.26162.xxxxx.xx.xxx
              IGI GLR1 Dr.  xx.xx.25162.2891.00.635
                        Cr.  xx.xx.25162.xxxxx.xx.xxx
              IGI GLD1 Dr.  xx.xx.25562.2891.00.635
                        Cr.  xx.xx.25562.xxxxx.xx.xxx
              CAM MK2  Dr.  xx.xx.31361.2891.00.628
                        Cr.  xx.xx.31361.xxxxx.xx.xxx
            */
            --借方
            V_GCC.SEGMENT1 := V.SEGMENT1;
            V_GCC.SEGMENT2 := V.SEGMENT2;
            V_GCC.SEGMENT3 := V.SEGMENT3;
            -- 指定產區管帳帳本會科
            V_GCC.SEGMENT4 := '2891';
            V_GCC.SEGMENT5 := '00';

            -- 依產區決定專案代碼
            --         IF V.SHORT_NAME = 'ISL-US' THEN                                                                                                         --ISU
            --            V_GCC.SEGMENT6   := '635';                                                                                                   --TPV-IND-SMG
            --         ELSIF V.SHORT_NAME = 'IGI' THEN
            --            V_GCC.SEGMENT6   := '635';                                                                                                   --TPV-IND-SMG
            --         ELSIF V.SHORT_NAME = 'CAM' THEN
            --            V_GCC.SEGMENT6   := '628';                                                                                                       --TPV-CAB
            --         END IF;
            IF V.SHORT_NAME = 'MPV' THEN
                V_GCC.SEGMENT6 := '628';
            ELSIF V.SHORT_NAME = 'IPV' THEN
                V_GCC.SEGMENT6 := '635';
            END IF;

            V_REC.P_CCID := GET_CC_ID (V_GCC);

            IF V_REC.P_CCID = -1 THEN
                MK_GL_PUB.CREATE_GL_ACCOUNT (
                    V_REC.P_SET_OF_BOOKS_ID,
                       V_GCC.SEGMENT1
                    || '.'
                    || V_GCC.SEGMENT2
                    || '.'
                    || V_GCC.SEGMENT3
                    || '.'
                    || V_GCC.SEGMENT4
                    || '.'
                    || V_GCC.SEGMENT5
                    || '.'
                    || V_GCC.SEGMENT6,
                    V_STRING);

                IF V_STRING IS NOT NULL THEN
                    RAISE E_GEN_CCID_EXCEPTION;
                END IF;

                V_REC.P_CCID := GET_CC_ID (V_GCC);
            END IF;

            IMP_GI (V_REC);
            V_STEP := '7';
            -- 產生產區管帳貸方
            V_REC.P_CCID := V.CCID;
            -- 借貸互轉(沖銷原始方)
            V_REC.P_DR := NVL (V.ENTERED_CR, 0);
            V_REC.P_CR := NVL (V.ENTERED_DR, 0);
            -- 產生產區管帳借方
            IMP_GI (V_REC);
        END LOOP;

        -- Run Journal Import
        V_STRING := V_REC.P_SET_OF_BOOKS_ID || '-' || V_REC.P_USER_ID || '-' || V_REC.P_GROUP_ID || '-' || V_REC.P_USER_JE_SOURCE_NAME;
        V_REQ_ID :=
            ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE (V_REC.P_SET_OF_BOOKS_ID,
                                                             V_REC.P_USER_ID,
                                                             V_REC.P_GROUP_ID,
                                                             V_REC.P_USER_JE_SOURCE_NAME);

        IF V_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('FAC MDQC Failure!! GROUP ID:' || V_REC.P_GROUP_ID);
            RETURN 'FAC GQC Failure!! GROUP ID:' || V_REC.P_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('FAC MDQC Success!! Concurrent ID:' || V_REQ_ID);
            RETURN 'FAC GQC Success!! Concurrent ID:' || V_REQ_ID;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN E_GEN_CCID_EXCEPTION THEN
            RETURN 'Exception:' || V_STRING;
        WHEN OTHERS THEN
            IF G_ERR_STRING IS NOT NULL THEN
                RETURN G_ERR_STRING;
            ELSIF V_STRING IS NULL THEN
                RETURN 'FAC MDQC Error:' || V_STEP || '-' || SQLERRM;
            ELSIF V_REQ_ID IS NULL THEN
                RETURN 'FAC MDQC Error:' || V_STRING || '-' || SQLERRM;
            ELSE
                RETURN 'FAC MDQC Error:' || V_REQ_ID || '-' || SQLERRM;
            END IF;
    END IMP_GQC_FEE_FAC;

    ----------------------------------------------------------------------------------------------------------------------------------------------------
    FUNCTION IMP_GQC_FEE_TPE (P_PERIOD_NAME VARCHAR2, P_SOB_ID NUMBER DEFAULT NULL)
        RETURN VARCHAR2 AS
        CURSOR C IS
              SELECT A.*,
                     B.*,
                     A.ENTERED_DR * B.PERCENTAGE                                  ENTERED_DR_P,
                     A.ENTERED_CR * B.PERCENTAGE                                  ENTERED_CR_P,
                     (NVL (A.ENTERED_DR, 0) - NVL (A.ENTERED_CR, 0)) * B.PERCENTAGE ENTERED_AMOUNT_P,
                     A.ACCT_DR * B.PERCENTAGE                                     ACCT_DR_P,
                     A.ACCT_CR * B.PERCENTAGE                                     ACCT_CR_P,
                     (NVL (A.ACCT_DR, 0) - NVL (A.ACCT_CR, 0)) * B.PERCENTAGE     ACCT_AMOUNT_P
                FROM (  SELECT GB.SHORT_NAME,
                               --                               DECODE (gcc.segment3,  '26162', 'STL',  '25162', 'GLR',  '25562', 'GLD',  '31361', 'CAM',  'XXX') site_code,
                               DECODE (GCC.SEGMENT3,  '31363', 'CAM',  '25563', 'GLD',  '26163', 'STL',  'XXX') SITE_CODE,
                               GB.SET_OF_BOOKS_ID,
                               JH.CURRENCY_CODE,
                               JH.PERIOD_NAME,
                               JH.STATUS,
                               SUM (JL.ACCOUNTED_DR)                                                        ENTERED_DR,
                               SUM (JL.ACCOUNTED_CR)                                                        ENTERED_CR,
                               SUM (NVL (JL.ACCOUNTED_DR, 0) - NVL (JL.ACCOUNTED_CR, 0))                    ENTERED_AMOUNT,
                               RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')))
                                   RATE,
                                 SUM (JL.ACCOUNTED_DR)
                               * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')))
                                   ACCT_DR,
                                 SUM (JL.ACCOUNTED_CR)
                               * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')))
                                   ACCT_CR,
                                 SUM (NVL (JL.ACCOUNTED_DR, 0) - NVL (JL.ACCOUNTED_CR, 0))
                               * RATE_CONVERSION (JH.CURRENCY_CODE, 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')))
                                   ACCT_AMOUNT,
                               GCC.SEGMENT1,
                               GCC.SEGMENT2
                          FROM GL_JE_HEADERS       JH,
                               GL_JE_LINES         JL,
                               GL_CODE_COMBINATIONS_V GCC,
                               GL_JE_CATEGORIES_VL JC,
                               GL_JE_SOURCES_VL    JS,
                               GL_SETS_OF_BOOKS    GB
                         WHERE 1 = 1
                           AND JH.NAME NOT LIKE G_PREFIX || '%'
                           AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
                           AND JH.JE_CATEGORY = JC.JE_CATEGORY_NAME
                           AND JH.JE_SOURCE = JS.JE_SOURCE_NAME
                           AND JL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                           AND GCC.SEGMENT3 IN ('31363', '25563', '26163')
                           --                               AND gcc.segment3 IN ('26162',
                           --                                                    '25162',
                           --                                                    '25562',
                           --                                                    '31361')                                                                            --GU
                           --                        AND GCC.SEGMENT4 = '2891'
                           AND (GCC.SEGMENT4 LIKE '5%'
                             OR GCC.SEGMENT4 LIKE '6%')
                           AND JH.PERIOD_NAME = P_PERIOD_NAME
                           --                        AND JH.STATUS = NVL (G_STATUS, JH.STATUS)
                           AND JH.SET_OF_BOOKS_ID = NVL (P_SOB_ID, JH.SET_OF_BOOKS_ID)
                           AND JH.SET_OF_BOOKS_ID = GB.SET_OF_BOOKS_ID
                           --                        AND GB.SHORT_NAME IN ('ISL-US', 'IGI', 'CAM')
                           AND GB.SHORT_NAME IN ('IPV', 'MPV')
                      GROUP BY GB.SHORT_NAME, --                               DECODE (gcc.segment3,  '26162', 'STL',  '25162', 'GLR',  '25562', 'GLD',  '31361', 'CAM',  'XXX'),
                               DECODE (GCC.SEGMENT3,  '31363', 'CAM',  '25563', 'GLD',  '26163', 'STL',  'XXX'),
                               GB.SET_OF_BOOKS_ID,
                               JH.CURRENCY_CODE,
                               JH.PERIOD_NAME,
                               JH.STATUS,
                               GCC.SEGMENT1,
                               GCC.SEGMENT2) A,
                     (  SELECT AR.CUSTOMER_NAME || '-' || SUBSTR (MCD.L3, 3, 1) CUST_NAME,
                               SUM (QUANTITY_PC / 12)                       DZ,
                               SUM (SUM (QUANTITY_PC / 12)) OVER ()         TOTAL_DZ,
                               RATIO_TO_REPORT (SUM (QUANTITY_PC / 12)) OVER () PERCENTAGE
                          FROM MIC_AR_TRX_V AR, MK_CUSTOMER_DEPT_ALL MCD
                         WHERE 1 = 1
                           AND AR.CUST_CODE = MCD.CUST_CODE
                           AND AR.SUB_GROUP = MCD.SUBGROUP
                           AND TO_CHAR (AR.GL_DATE, 'MON-RR') = P_PERIOD_NAME
                           AND AR.CUSTOMER_NAME = 'GU'
                      GROUP BY AR.CUSTOMER_NAME || '-' || SUBSTR (MCD.L3, 3, 1)) B
               WHERE 1 = 1
            ORDER BY A.SEGMENT1, A.SEGMENT2;

        V_REC                  R_REC;
        V_REQ_ID               VARCHAR2 (300);                                       --ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE%TYPE;
        V_GCC                  GL_CODE_COMBINATIONS%ROWTYPE;
        V_ORG                  ORG_ORGANIZATION_DEFINITIONS%ROWTYPE;
        V_ACCOUNT_CATEGORY     GL_JE_LINES.ATTRIBUTE14%TYPE := '01驗貨費';
        R_SOB                  GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE        VARCHAR2 (30) := 'MDQC';
        V_STRING               VARCHAR2 (3000);
        E_GEN_CCID_EXCEPTION   EXCEPTION;
    BEGIN
        R_SOB := GET_SOB (P_SOB_ID);

        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        --      指定帳本
        SELECT *
          INTO V_ORG
          FROM ORG_ORGANIZATION_DEFINITIONS
         WHERE ORGANIZATION_CODE = 'TPV';

        --取得  GROUP_ID,BATCH_NAME
        APPS.ATK_GL_COMMON_PKG.GET_COMMON_INFO (V_ORG.ORGANIZATION_ID,
                                                TO_DATE (P_PERIOD_NAME, 'MON-RR'),
                                                V_REC.P_USER_ID,
                                                V_REC.P_USER_JE_SOURCE_NAME,
                                                V_REC.P_USER_JE_CATEGORY_NAME,
                                                V_REC.P_PERIOD_NAME,
                                                V_REC.P_CURRENCY_CODE,
                                                V_REC.P_BATCH_NAME,
                                                V_REC.P_SET_OF_BOOKS_ID,
                                                V_REC.P_GROUP_ID);
        -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 共用變數
        V_REC.P_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        V_REC.P_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        ---    BATCH NAME 需大於 50 個字, 否則 BATCH NAME 將會使用 ORACLE DEFAULT.
        --      V_REC.P_BATCH_NAME              := G_PREFIX || 'INSPECT GQC' || '-' || P_PERIOD_NAME || '-' || 'Dos-Accounting' || '/' || 'Transfer';
        G_ERR_STRING := 'Step.1';
        --      BEGIN
        --         SELECT    G_PREFIX
        --                || 'INSPECT GQC-'
        --                || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')), 'YYYYMMDD')
        --                || LPAD (TO_NUMBER (NVL (MAX (SUBSTR (NAME, 21, 2)), '00')) + 1, 2, '0')
        --           INTO V_REC.P_JOURNAL_ENTRY_NAME
        --           FROM GL_JE_HEADERS
        --          WHERE 1 = 1
        --            AND JE_SOURCE = '3'                                                                                                       --Dos-Accounting
        --            AND SET_OF_BOOKS_ID = V_REC.P_SET_OF_BOOKS_ID
        --            AND SUBSTR (NAME, 1, 20) LIKE
        --                   G_PREFIX || 'INSPECT GQC' || '-' || TO_CHAR (LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')), 'YYYYMMDD') || '%';
        --      EXCEPTION
        --         WHEN OTHERS THEN
        --            DBMS_OUTPUT.PUT_LINE ('Get sqlno Error!');
        --      END;
        V_REC.P_USER_JE_SOURCE_NAME := 'Dos-Accounting';
        V_REC.P_USER_JE_CATEGORY_NAME := 'Transfer';
        V_REC.P_GROUP_ID := GL_INTERFACE_CONTROL_PKG.GET_UNIQUE_ID;

        FOR V IN C LOOP
            -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 逐筆變數
            V_REC.P_PERIOD_NAME := V.PERIOD_NAME;
            V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;
            V_REC.P_DATE := TO_DATE (P_PERIOD_NAME, 'MON-RR');
            V_REC.P_CURRENCY_CONVERSION_DATE := TO_DATE (P_PERIOD_NAME, 'MON-RR');
            V_REC.P_EXCHANGE_RATE := V.RATE;
            V_REC.P_USER_ID := NVL (P_USER_ID, G_USER_ID);
            --         V_REC.P_SET_OF_BOOKS_ID   := V.SET_OF_BOOKS_ID;
            V_REC.P_DESCRIPTION := '摘要: GU' || ROUND (V.PERCENTAGE, 2) * 100 || '% ' || V.SITE_CODE || ' MDQC分攤)';
            V_REC.P_ATTRIBUTE3 := V.CUST_NAME;
            V_REC.P_ATTRIBUTE14 := V_ACCOUNT_CATEGORY;
            /*
            BOOK  SITE D/C  ACCT
            ----- ---- ---  -------------------------
              ISU STL  Dr.  15.01.00000.2178.28.000(摘要：GU?% STL GQC分攤)(GU-? / 01驗貨費 )
                        Cr.  15.01.09917.2891.00.639(摘要：GU?% STL GQC分攤)(GU-? / 01驗貨費 )
              IGI GLR1 Dr.  15.01.00000.2178.28.000(摘要：GU?% GLR GQC分攤)(GU-? / 01驗貨費 )
                        Cr.  15.01.09917.2891.00.639(摘要：GU?% GLR GQC分攤)(GU-? / 01驗貨費 )
              IGI GLD1 Dr.  15.01.00000.2178.28.000(摘要：GU?% GLD GQC分攤)(GU-? / 01驗貨費 )
                        Cr.  15.01.09917.2891.00.639(摘要：GU?% GLD GQC分攤)(GU-? / 01驗貨費 )
              CAM MK2  Dr.  15.01.00000.2178.28.000(摘要：GU?% CAM GQC分攤)(GU-? / 01驗貨費 )
                        Cr.  15.01.09910.2891.00.629(摘要：GU?% CAM GQC分攤)(GU-? / 01驗貨費 )
            */
            --TPV管帳帳本會科
            --借方
            V_GCC.SEGMENT1 := '15';
            V_GCC.SEGMENT2 := '01';
            V_GCC.SEGMENT3 := '00000';
            V_GCC.SEGMENT4 := '2178';
            V_GCC.SEGMENT5 := '28';
            V_GCC.SEGMENT6 := '000';
            V_REC.P_CCID := GET_CC_ID (V_GCC);

            IF V_REC.P_CCID = -1 THEN
                MK_GL_PUB.CREATE_GL_ACCOUNT (
                    V_REC.P_SET_OF_BOOKS_ID,
                       V_GCC.SEGMENT1
                    || '.'
                    || V_GCC.SEGMENT2
                    || '.'
                    || V_GCC.SEGMENT3
                    || '.'
                    || V_GCC.SEGMENT4
                    || '.'
                    || V_GCC.SEGMENT5
                    || '.'
                    || V_GCC.SEGMENT6,
                    V_STRING);

                IF V_STRING IS NOT NULL THEN
                    RAISE E_GEN_CCID_EXCEPTION;
                ELSE
                    V_REC.P_CCID := GET_CC_ID (V_GCC);
                END IF;
            END IF;

            IF V.ENTERED_AMOUNT_P >= 0 THEN
                V_REC.P_DR := V.ENTERED_AMOUNT_P;
                V_REC.P_CR := 0;
            ELSIF V.ENTERED_AMOUNT_P < 0 THEN
                V_REC.P_DR := 0;
                V_REC.P_CR := -1 * V.ENTERED_AMOUNT_P;
            END IF;

            IF V.ACCT_AMOUNT_P >= 0 THEN
                V_REC.P_DR_ACC := V.ACCT_AMOUNT_P;
                V_REC.P_CR_ACC := 0;
            ELSIF V.ENTERED_AMOUNT < 0 THEN
                V_REC.P_DR_ACC := 0;
                V_REC.P_CR_ACC := -1 * V.ACCT_AMOUNT_P;
            END IF;

            IMP_GI_CURR (V_REC);
            --TPV管帳帳本會科
            --貸方
            V_REC.P_ATTRIBUTE3 := NULL;
            V_REC.P_ATTRIBUTE14 := NULL;
            V_GCC.SEGMENT1 := '15';
            V_GCC.SEGMENT2 := '01';
            V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (MK_GL_PUB.GET_SHORT_NAME (P_SOB_ID));
            V_GCC.SEGMENT4 := '2891';
            V_GCC.SEGMENT5 := '00';
            V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V.SHORT_NAME, 'TPM', V.SEGMENT1);
            V_REC.P_CCID := GET_CC_ID (V_GCC);

            IF V_REC.P_CCID = -1 THEN
                MK_GL_PUB.CREATE_GL_ACCOUNT (
                    V_REC.P_SET_OF_BOOKS_ID,
                       V_GCC.SEGMENT1
                    || '.'
                    || V_GCC.SEGMENT2
                    || '.'
                    || V_GCC.SEGMENT3
                    || '.'
                    || V_GCC.SEGMENT4
                    || '.'
                    || V_GCC.SEGMENT5
                    || '.'
                    || V_GCC.SEGMENT6,
                    V_STRING);

                IF V_STRING IS NOT NULL THEN
                    RAISE E_GEN_CCID_EXCEPTION;
                ELSE
                    V_REC.P_CCID := GET_CC_ID (V_GCC);
                END IF;
            END IF;

            -- 借貸互轉(沖銷原始方)
            IF V.ENTERED_AMOUNT_P >= 0 THEN
                V_REC.P_DR := 0;
                V_REC.P_CR := V.ENTERED_AMOUNT_P;
            ELSIF V.ENTERED_AMOUNT < 0 THEN
                V_REC.P_DR := -1 * V.ENTERED_AMOUNT_P;
                V_REC.P_CR := 0;
            END IF;

            IF V.ACCT_AMOUNT_P >= 0 THEN
                V_REC.P_DR_ACC := 0;
                V_REC.P_CR_ACC := V.ACCT_AMOUNT_P;
            ELSIF V.ENTERED_AMOUNT < 0 THEN
                V_REC.P_DR_ACC := -1 * V.ACCT_AMOUNT_P;
                V_REC.P_CR_ACC := 0;
            END IF;

            -- 產生產區管帳貸方
            IMP_GI_CURR (V_REC);
        END LOOP;

        -- Run Journal Import
        V_REQ_ID :=
            ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE (V_REC.P_SET_OF_BOOKS_ID,
                                                             V_REC.P_USER_ID,
                                                             V_REC.P_GROUP_ID,
                                                             V_REC.P_USER_JE_SOURCE_NAME);

        IF V_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE ('TPV MDQC Failure!! GROUP ID:' || V_REC.P_GROUP_ID);
            COMMIT;
            RETURN 'TPV MDQC Failure!! GROUP ID:' || V_REC.P_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE ('TPV MDQC Success!! Concurrent ID:' || V_REQ_ID);
            COMMIT;
            RETURN 'TPV MDQC Success!! Concurrent ID:' || V_REQ_ID;
        END IF;
    EXCEPTION
        WHEN E_GEN_CCID_EXCEPTION THEN
            RETURN V_STRING;
        WHEN OTHERS THEN
            RETURN 'TPV MDQC Error(' || V_REQ_ID || '):' || G_ERR_STRING || '-' || SQLERRM;
    END IMP_GQC_FEE_TPE;

    FUNCTION imp_dks_reclass_fac (P_PERIOD_NAME VARCHAR2, P_SOB_ID NUMBER)
        RETURN VARCHAR2 IS
        CURSOR c (c_period_name VARCHAR2, c_sob_id NUMBER) IS
              SELECT CASE WHEN mcd.subgroup LIKE '%CALIA%' THEN 'CALIA' ELSE 'OTHERS' END subgroup,
                     TO_CHAR (AR.GL_DATE, 'MON-RR')                                     period_name,
                     mk_gl_pub.GET_MGMT_SOB_ID (gsob.set_of_books_id)                   set_of_books_id,
                     aaa.maker_id,
                     pv.vendor_name,
                     mgd.company_code                                                   segment1,
                     '01'                                                               segment2,
                     mgd.dept_code                                                      segment3,
                     gsob.currency_code,
                     ROUND (SUM (quantity_pc) / 12, 2)                                  dz,
                     ROUND (SUM (quantity_pc) / 12, 2) * 0.06                           USD_amt,
                     SUM (mk_gl_pub.rate_conversion ('USD',
                                                     GSOB.CURRENCY_CODE,
                                                     g_conversion_type_av,
                                                     ar.gl_date,
                                                     ROUND (quantity_pc / 12, 2) * 0.06))
                         SOB_amt
                FROM MIC_AR_TRX_V           AR,
                     MK_CUSTOMER_DEPT_ALL   MCD,
                     acp_assort_shipping_all aasa,
                     (SELECT ASA.SHIP_CPO_ID,
                             ASA.OE_FOLDERID,
                             ASA.PO_FOLDERID,
                             ABMH.BVI_HEADER_ID,
                             ABMH.ABMH_ID,
                             ABMH.MAKER_ID,
                             ASA.STATUS,
                             ABML.SHIP_QTY AS EST_MAKER_QTY
                        FROM ACP_ASSORT_SHIPPING_ALL ASA, ACP_BVI_MAKERS_L ABML, ACP_BVI_MAKERS_H ABMH
                       WHERE ASA.SHIP_CPO_ID = ABML.SHIP_HEADER_ID
                         AND ABML.ABMH_ID = ABMH.ABMH_ID) aaa,
                     po_vendors             pv,
                     mk_gl_depts            mgd,
                     gl_sets_of_books       gsob
               WHERE 1 = 1
                 AND AR.CUST_CODE = MCD.CUST_CODE
                 AND AR.SUB_GROUP = MCD.SUBGROUP
                 AND TO_CHAR (AR.GL_DATE, 'MON-RR') = c_period_name
                 AND mcd.cust_code = 'DKS'
                 AND (ar.cpo_num || ',' || ar.oe_folderid) = (aasa.ship_cpo_num || ',' || aasa.oe_folderid)
                 AND aasa.oe_folderid = aaa.oe_folderid
                 AND aasa.po_folderid = aaa.po_folderid
                 AND aaa.maker_id = pv.vendor_id
                 AND pv.vendor_id = mgd.vendor_id(+)
                 AND mgd.sob_id = gsob.set_of_books_id(+)
                 AND gsob.set_of_books_id = c_sob_id
            GROUP BY CASE WHEN mcd.subgroup LIKE '%CALIA%' THEN 'CALIA' ELSE 'OTHERS' END,
                     TO_CHAR (AR.GL_DATE, 'MON-RR'),
                     gsob.set_of_books_id,
                     aaa.maker_id,
                     pv.vendor_name,
                     mgd.company_code,
                     mgd.dept_code,
                     gsob.currency_code;

        V_REC                  R_REC;
        V_REQ_ID               VARCHAR2 (300);                                       --ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE%TYPE;
        V_GCC                  GL_CODE_COMBINATIONS%ROWTYPE;
        V_STRING               VARCHAR2 (3000);
        V_SHORT_NAME           GL_SETS_OF_BOOKS.SHORT_NAME%TYPE;
        R_SOB                  GL_SETS_OF_BOOKS%ROWTYPE;
        V_TXN_TYPE_CODE        VARCHAR2 (300) := 'RECLASS ADJ DKS貼紙&穿繩';
        V_STEP                 VARCHAR2 (30);
        E_GEN_CCID_EXCEPTION   EXCEPTION;
        v_prefix               VARCHAR2 (3000);
        v_num                  NUMBER := 0;
        v_pieces               UTL_HTTP.HTML_PIECES;
    BEGIN
        G_ERR_STRING := NULL;
        R_SOB := GET_SOB (P_SOB_ID);
        --      LC_BASE_CURRENCY_CODE   := R_SOB.CURRENCY_CODE;
        V_REC.P_BATCH_NAME := GET_BATCH_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        V_REC.P_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME (V_TXN_TYPE_CODE, P_PERIOD_NAME, R_SOB.SHORT_NAME);
        V_REC.P_USER_JE_SOURCE_NAME := 'Dos-Accounting';
        V_REC.P_USER_JE_CATEGORY_NAME := 'Transfer';
        V_REC.P_GROUP_ID := GL_INTERFACE_CONTROL_PKG.GET_UNIQUE_ID;
        DBMS_OUTPUT.put_line ('before Loop!');

        FOR V IN C (c_period_name => p_period_name, c_sob_id => p_sob_id) LOOP
            IF v.segment3 IS NULL THEN
                v_num := v_num + 1;
                v_pieces (v_num) := v.vendor_name || ' 未在[產區廠別會計科目設定]建立';
                --                DBMS_OUTPUT.put_line (v_num || '-' || v_pieces (v_num));
                CONTINUE;
            ELSIF v.currency_code IS NULL THEN
                CONTINUE;
            ELSE
                DBMS_OUTPUT.put_line (v.segment3);
            END IF;

            -- Generate ATK_GL_COMMON_PKG.INSERT_GL_INTERFACE_ALL 逐筆變數
            --      V_REC.P_JOURNAL_ENTRY_NAME      := '';                                                                                              --pre_cursor
            V_REC.P_PERIOD_NAME := v.period_name;
            --         V_REC.P_USER_JE_SOURCE_NAME     := V.USER_JE_SOURCE_NAME;                                                                        --pre_cursor
            --         V_REC.P_USER_JE_CATEGORY_NAME   := V.USER_JE_CATEGORY_NAME;                                                                      --pre_cursor
            V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;

            --            V_REC.P_CCID := V.CCID;

            --            v_rec.p_description := 'DKS貼紙人力重分類';

            --         V_REC.P_DATE              := V.DEFAULT_EFFECTIVE_DATE;                                                                               --統一日期即可
            V_REC.P_DATE := TO_DATE (v.period_name, 'MON-RR');
            V_REC.P_USER_ID := NVL (G_USER_ID, P_USER_ID);
            V_REC.P_SET_OF_BOOKS_ID := V.SET_OF_BOOKS_ID;
            --      V_REC.P_GROUP_ID                := GL_INTERFACE_CONTROL_PKG.GET_UNIQUE_ID;                                                          --pre_cursor
            -- 借貸沿用
            V_REC.P_DR := NVL (V.sob_amt, 0);
            V_REC.P_CR := 0;
            V_REC.P_DR_ACC := NVL (V.sob_amt, 0);
            V_REC.P_CR_ACC := 0;
            --            V_REC.P_ATTRIBUTE1 := V.ATTRIBUTE1;
            --            V_REC.P_ATTRIBUTE2 := V.ATTRIBUTE2;
            V_REC.P_ATTRIBUTE3 := 'DKS';
            --            V_REC.P_ATTRIBUTE4 := V.ATTRIBUTE4;
            --            V_REC.P_ATTRIBUTE5 := V.ATTRIBUTE5;
            --            V_REC.P_ATTRIBUTE6 := V.ATTRIBUTE6;
            --            V_REC.P_ATTRIBUTE7 := V.ATTRIBUTE7;
            --            V_REC.P_ATTRIBUTE8 := V.ATTRIBUTE8;
            --            V_REC.P_ATTRIBUTE9 := V.ATTRIBUTE9;
            --            V_REC.P_ATTRIBUTE10 := V.ATTRIBUTE10;
            --            V_REC.P_ATTRIBUTE11 := V.ATTRIBUTE11;
            --            V_REC.P_ATTRIBUTE12 := V.ATTRIBUTE12;
            --            V_REC.P_ATTRIBUTE13 := V.ATTRIBUTE13;
            --            V_REC.P_ATTRIBUTE14 := V.ATTRIBUTE14;
            --            V_REC.P_ATTRIBUTE15 := V.ATTRIBUTE15;
            /*
            BOOK  SITE D/C  ACCT
            ----- ---- ---  -------------------------
                       Dr.  xx.xx.xxxxx.5111.16.000
                        Cr.  xx.xx.xxxxx.5411.02.000
            */
            --借方
            V_GCC.SEGMENT1 := V.SEGMENT1;
            V_GCC.SEGMENT2 := V.SEGMENT2;
            V_GCC.SEGMENT3 := V.SEGMENT3;
            -- 指定產區管帳帳本會科
            V_GCC.SEGMENT4 := '5111';
            V_GCC.SEGMENT5 := '16';
            V_GCC.segment6 := '000';

            V_REC.P_CCID := GET_CC_ID (V_GCC);

            IF V_REC.P_CCID = -1 THEN
                MK_GL_PUB.CREATE_GL_ACCOUNT (
                    V_REC.P_SET_OF_BOOKS_ID,
                       V_GCC.SEGMENT1
                    || '.'
                    || V_GCC.SEGMENT2
                    || '.'
                    || V_GCC.SEGMENT3
                    || '.'
                    || V_GCC.SEGMENT4
                    || '.'
                    || V_GCC.SEGMENT5
                    || '.'
                    || V_GCC.SEGMENT6,
                    V_STRING);

                IF V_STRING IS NOT NULL THEN
                    RAISE E_GEN_CCID_EXCEPTION;
                END IF;

                V_REC.P_CCID := GET_CC_ID (V_GCC);
            END IF;

            v_rec.p_description := 'DKS貼紙人力重分類';
            IMP_GI (V_REC);

            IF v.subgroup = 'CALIA' THEN
                v_rec.p_description := 'DKS-CALIA穿繩人力重分類';
                IMP_GI (V_REC);
            END IF;

            -- 借貸互轉(沖銷原始方)
            V_GCC.SEGMENT4 := '5411';
            V_GCC.SEGMENT5 := '02';
            --            V_GCC.segment6 := '000';

            V_REC.P_CCID := GET_CC_ID (V_GCC);
            V_REC.P_DR := 0;
            V_REC.P_CR := NVL (V.SOB_AMT, 0);
            V_REC.P_DR_ACC := 0;
            V_REC.P_CR_ACC := NVL (V.sob_amt, 0);
            -- 產生產區管帳借方

            v_rec.p_description := 'DKS貼紙人力重分類';
            IMP_GI (V_REC);

            IF v.subgroup = 'CALIA' THEN
                v_rec.p_description := 'DKS-CALIA穿繩人力重分類';
                IMP_GI (V_REC);
            END IF;
        END LOOP;

        DBMS_OUTPUT.put_line ('v_num:' || v_num);
        v_prefix := r_sob.short_name || '-' || V_TXN_TYPE_CODE || ':';

        IF v_num = 0 THEN
            -- Run Journal Import
            V_STRING := V_REC.P_SET_OF_BOOKS_ID || '-' || V_REC.P_USER_ID || '-' || V_REC.P_GROUP_ID || '-' || V_REC.P_USER_JE_SOURCE_NAME;
            V_REQ_ID :=
                ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE (V_REC.P_SET_OF_BOOKS_ID,
                                                                 V_REC.P_USER_ID,
                                                                 V_REC.P_GROUP_ID,
                                                                 V_REC.P_USER_JE_SOURCE_NAME);

            IF V_REQ_ID = -1 THEN
                DBMS_OUTPUT.PUT_LINE (v_prefix || ' Failure!! GROUP ID:' || V_REC.P_GROUP_ID);
                RETURN v_prefix || ' Failure!! GROUP ID:' || V_REC.P_GROUP_ID;
            ELSE
                DBMS_OUTPUT.PUT_LINE (v_prefix || ' Success!! Concurrent ID:' || V_REQ_ID);
                RETURN v_prefix || ' Success!! Concurrent ID:' || V_REQ_ID;
            END IF;
        ELSE
            --            v_num := v_num - 1;
            DBMS_OUTPUT.put_line ('else1');
            v_string := 'Error Alert Sended.' || V_NUM || ')';
            DBMS_OUTPUT.put_line ('else2');

            FOR i IN 1 .. v_num - 1 LOOP
                DBMS_OUTPUT.put_line (i || '-' || v_pieces (i));
            END LOOP;

            mk_dev_pub.send_error_alert (v_pieces);
            DBMS_OUTPUT.put_line ('else3');
            RETURN v_string;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN E_GEN_CCID_EXCEPTION THEN
            RETURN v_prefix || ' Exception:' || V_STRING;
        WHEN OTHERS THEN
            IF G_ERR_STRING IS NOT NULL THEN
                RETURN G_ERR_STRING;
            ELSIF V_STRING IS NULL THEN
                RETURN v_prefix || ' Error1:' || V_STEP || '-' || SQLERRM;
            ELSIF V_REQ_ID IS NULL THEN
                RETURN v_prefix || ' Error2:' || V_STRING || '-' || SQLERRM;
            ELSE
                RETURN v_prefix || ' Error3:' || V_REQ_ID || '-' || SQLERRM;
            END IF;
    END imp_dks_reclass_fac;

    --   FUNCTION GET_GL_LINES (P_SOB_ID GL_SETS_OF_BOOKS.SET_OF_BOOKS_ID%TYPE)
    --      RETURN HDR_CT IS
    --   BEGIN
    --      RETURN NULL;
    --   END GET_GL_LINES;
    FUNCTION GET_GCC_BY_TYPE (P_TYPE           VARCHAR2,
                              P_DRCR_TYPE      VARCHAR2,
                              P_FROM_SOB_ID    GL_SETS_OF_BOOKS.SET_OF_BOOKS_ID%TYPE,
                              P_SEGMENT1       GL_CODE_COMBINATIONS.SEGMENT1%TYPE,
                              P_SEGMENT3       GL_CODE_COMBINATIONS.SEGMENT3%TYPE)
        RETURN GL_CODE_COMBINATIONS%ROWTYPE IS
        V_GCC   GL_CODE_COMBINATIONS%ROWTYPE;
        V_SOB   GL_SETS_OF_BOOKS%ROWTYPE;
    BEGIN
        V_GCC := NULL;
        V_SOB := GET_SOB (P_FROM_SOB_ID);

        IF P_TYPE = '策略人力' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := '00000';
                V_GCC.SEGMENT4 := '6210';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := '036';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        ELSIF P_TYPE = '部門薪資' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := '03201';
                V_GCC.SEGMENT4 := '6110';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := '000';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        ELSIF P_TYPE = '社會責任專案' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := '00000';
                V_GCC.SEGMENT4 := '6221';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := '092';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        ELSIF P_TYPE = '工安專案' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := '00000';
                V_GCC.SEGMENT4 := '6224';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := '092';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        ELSIF P_TYPE = '文件中心' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := P_SEGMENT3;
                V_GCC.SEGMENT4 := '1253';
                V_GCC.SEGMENT5 := '09';
                V_GCC.SEGMENT6 := '000';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        ELSIF P_TYPE = '特工廠策略成本' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := '00000';
                V_GCC.SEGMENT4 := '6235';
                V_GCC.SEGMENT5 := '05';
                V_GCC.SEGMENT6 := '000';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        ELSIF P_TYPE = '北越GQC' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := '00000';
                V_GCC.SEGMENT4 := '2178';
                V_GCC.SEGMENT5 := '28';
                V_GCC.SEGMENT6 := '000';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        ELSIF P_TYPE = '銷售費用' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := '00000';
                V_GCC.SEGMENT4 := '2178';
                V_GCC.SEGMENT5 := '28';
                V_GCC.SEGMENT6 := '000';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        ELSIF P_TYPE = '供應鏈' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := 'C5000';
                V_GCC.SEGMENT4 := '6110';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := '000';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        ELSIF P_TYPE = '防疫專案' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := '00000';
                V_GCC.SEGMENT4 := '6288';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := '112';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        ELSIF P_TYPE = '印尼樣品中心' THEN
            IF P_DRCR_TYPE = 'DR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := 'S4000';
                V_GCC.SEGMENT4 := '6144';
                V_GCC.SEGMENT5 := '49';
                V_GCC.SEGMENT6 := '000';
            ELSIF P_DRCR_TYPE = 'CR' THEN
                V_GCC.SEGMENT1 := '15';
                V_GCC.SEGMENT2 := '01';
                V_GCC.SEGMENT3 := MK_GL_PUB.SOB2SEG3 (V_SOB.SHORT_NAME);
                V_GCC.SEGMENT4 := '2891';
                V_GCC.SEGMENT5 := '00';
                V_GCC.SEGMENT6 := MK_GL_PUB.SOB2SEG6 (V_SOB.SHORT_NAME, 'TPM', P_SEGMENT1);
            END IF;
        END IF;

        RETURN V_GCC;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN NULL;
    END GET_GCC_BY_TYPE;

    PROCEDURE GET_FROM_GCC (IN_TYPE IN VARCHAR2, OUT_SEGMENT4 OUT VARCHAR2, OUT_SEGMENT5 OUT VARCHAR2) IS
    BEGIN
        IF IN_TYPE = '策略人力' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '11';
        ELSIF IN_TYPE = '部門薪資' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '12';
        ELSIF IN_TYPE = '社會責任專案' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '13';
        ELSIF IN_TYPE = '工安專案' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '14';
        ELSIF IN_TYPE = '文件中心' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '15';
        ELSIF IN_TYPE = '特工廠策略成本' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '16';
        ELSIF IN_TYPE = '北越GQC' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '17';
        ELSIF IN_TYPE = '銷售費用' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '17';
        ELSIF IN_TYPE = '供應鏈' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '18';
        ELSIF IN_TYPE = '防疫專案' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '19';
        ELSIF IN_TYPE = '印尼樣品中心' THEN
            OUT_SEGMENT4 := '2891';
            OUT_SEGMENT5 := '20';
        END IF;
    END GET_FROM_GCC;

    FUNCTION IS_SEPERATE_BY (IN_TYPE IN VARCHAR2)
        RETURN BOOLEAN IS
    BEGIN
        IF IN_TYPE IN ('策略人力',
                       '部門薪資',
                       '社會責任專案',
                       '工安專案',
                       '特工廠策略成本',
                       '供應鏈',
                       '防疫專案',
                       '印尼樣品中心',
                       '銷售費用') THEN
            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    END IS_SEPERATE_BY;

    FUNCTION GET_PERCENTAGE_BY (IN_TYPE IN VARCHAR2, IN_PERIOD_NAME IN VARCHAR2, IN_VALUE IN VARCHAR2)
        RETURN NUMBER
        RESULT_CACHE RELIES_ON (IN_TYPE, IN_PERIOD_NAME, IN_VALUE) IS
        V_PERCENTAGE   NUMBER;
    BEGIN
        IF IN_TYPE = '文件中心' THEN
            BEGIN
                SELECT PERCENTAGE
                  INTO V_PERCENTAGE
                  FROM (  SELECT AR.ORIGIN_DISTRICT, RATIO_TO_REPORT (SUM (QUANTITY_PC / 12)) OVER () PERCENTAGE
                            FROM MIC_AR_TRX_V AR, MK_CUSTOMER_DEPT_ALL MCD
                           WHERE 1 = 1
                             AND AR.CUST_CODE = MCD.CUST_CODE
                             AND AR.SUB_GROUP = MCD.SUBGROUP
                             AND TO_CHAR (AR.GL_DATE, 'MON-RR') = IN_PERIOD_NAME
                        --                         AND TO_CHAR (AR.GL_DATE, 'MON-RR') = TO_CHAR (ADD_MONTHS (TO_DATE (IN_PERIOD_NAME, 'MON-RR'), -1), 'MON-RR')
                        GROUP BY AR.ORIGIN_DISTRICT)
                 WHERE 1 = 1
                   AND ORIGIN_DISTRICT = IN_VALUE;
            END;
        ELSIF IN_TYPE = '北越GQC' THEN
            BEGIN
                SELECT PERCENTAGE
                  INTO V_PERCENTAGE
                  FROM (  SELECT AR.CUSTOMER_NAME || '-' || SUBSTR (MCD.L3, 3, 1) CUST_NAME,
                                 RATIO_TO_REPORT (SUM (QUANTITY_PC / 12)) OVER () PERCENTAGE
                            FROM MIC_AR_TRX_V AR, MK_CUSTOMER_DEPT_ALL MCD
                           WHERE 1 = 1
                             AND AR.CUST_CODE = MCD.CUST_CODE
                             AND AR.SUB_GROUP = MCD.SUBGROUP
                             AND TO_CHAR (AR.GL_DATE, 'MON-RR') = IN_PERIOD_NAME --                         AND TO_CHAR (AR.GL_DATE, 'MON-RR') = TO_CHAR (ADD_MONTHS (TO_DATE (IN_PERIOD_NAME, 'MON-RR'), -1), 'MON-RR')
                             AND AR.CUSTOMER_NAME = 'GU'
                        GROUP BY AR.CUSTOMER_NAME || '-' || SUBSTR (MCD.L3, 3, 1))
                 WHERE 1 = 1
                   AND CUST_NAME = IN_VALUE;
            END;
        END IF;

        RETURN V_PERCENTAGE;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE (IN_TYPE || '/' || IN_VALUE || '/' || IN_PERIOD_NAME || '-無實打比例!');
            RETURN 0;
    END GET_PERCENTAGE_BY;

    FUNCTION TRANSFER_SOB (P_FROM_SOB_ID    GL_SETS_OF_BOOKS.SET_OF_BOOKS_ID%TYPE,
                           P_TO_SOB_ID      GL_SETS_OF_BOOKS.SET_OF_BOOKS_ID%TYPE,
                           P_PERIOD_NAME    VARCHAR2,
                           P_TYPE           VARCHAR2)
        RETURN VARCHAR2 IS
        CURSOR C (C_FROM_SOB_ID    GL_SETS_OF_BOOKS.SET_OF_BOOKS_ID%TYPE,
                  C_PERIOD_NAME    VARCHAR2,
                  C_SEGMENT4       VARCHAR2,
                  C_SEGMENT5       VARCHAR2) IS
            SELECT GJH.*,
                   GJL.ENTERED_DR,
                   GJL.ENTERED_CR,
                   GJL.ACCOUNTED_DR,
                   GJL.ACCOUNTED_CR,
                   GJL.DESCRIPTION LINE_DESCRIPTION,
                   GJL.ATTRIBUTE3  CUSTOMER,
                   GCC.SEGMENT1,
                   GSOB.SHORT_NAME
              FROM GL_JE_HEADERS         GJH,
                   GL_JE_LINES           GJL,
                   GL_CODE_COMBINATIONS  GCC,
                   GL_SETS_OF_BOOKS      GSOB
             WHERE 1 = 1
               AND GJH.SET_OF_BOOKS_ID = C_FROM_SOB_ID
               AND GJH.PERIOD_NAME = C_PERIOD_NAME
               AND GJH.JE_HEADER_ID = GJL.JE_HEADER_ID
               AND GJL.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
               AND GCC.SEGMENT4 = C_SEGMENT4
               AND GCC.SEGMENT5 = C_SEGMENT5
               AND GJH.SET_OF_BOOKS_ID = GSOB.SET_OF_BOOKS_ID;

        CURSOR C_VALUE (C_TYPE VARCHAR2) IS
            SELECT DECODE (MGD.SHORT_CODE,  'PH', 'PHL',  'IND', 'SMG',  MGD.SHORT_CODE) C_NAME, MGD.DEPT_CODE C_CODE
              FROM MK_GL_DEPTS MGD
             WHERE 1 = 1
               AND MGD.PARENT_ID IS NULL
               AND C_TYPE IN ('文件中心')
            UNION
              SELECT MCDA.CUSTOMER || '-' || SUBSTR (MCDA.L3, 3, 1) C_NAME, NULL C_CODE
                FROM MK_CUSTOMER_DEPT_ALL MCDA
               WHERE 1 = 1
                 AND C_TYPE IN ('北越GQC')
                 AND MCDA.CUSTOMER = 'GU'
            GROUP BY MCDA.CUSTOMER || '-' || SUBSTR (MCDA.L3, 3, 1);

        V_REC                  R_REC;
        V_ORG                  ORG_ORGANIZATION_DEFINITIONS%ROWTYPE;
        V_SOB                  GL_SETS_OF_BOOKS%ROWTYPE;
        V_SEGMENT4             GL_CODE_COMBINATIONS.SEGMENT4%TYPE;
        V_SEGMENT5             GL_CODE_COMBINATIONS.SEGMENT5%TYPE;
        V_GCC                  GL_CODE_COMBINATIONS%ROWTYPE;
        V_REQ_ID               VARCHAR2 (300);                                       --ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE%TYPE;
        V_ACCOUNT_CATEGORY     GL_JE_LINES.ATTRIBUTE14%TYPE := '01驗貨費';
        E_ERROR_RATE           EXCEPTION;
        V_MESSAGE              VARCHAR2 (32767);
        V_RATE                 NUMBER;
        V_STRING               VARCHAR2 (3000);
        E_GEN_CCID_EXCEPTION   EXCEPTION;
    BEGIN
        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID             => 36361,
                                         RESP_ID             => 56282,
                                         RESP_APPL_ID        => 101,
                                         SECURITY_GROUP_ID   => NULL,
                                         SERVER_ID           => NULL);

        BEGIN
            SELECT *
              INTO V_ORG
              FROM ORG_ORGANIZATION_DEFINITIONS
             WHERE 1 = 1
               AND SET_OF_BOOKS_ID = P_TO_SOB_ID;
        EXCEPTION
            WHEN OTHERS THEN
                V_ORG := NULL;
        END;

        V_SOB := GET_SOB (P_TO_SOB_ID);
        GET_FROM_GCC (P_TYPE, V_SEGMENT4, V_SEGMENT5);
        G_ERR_STRING := '1';
        DBMS_OUTPUT.PUT_LINE (G_ERR_STRING);
        V_REC.P_DATE := TO_DATE (P_PERIOD_NAME, 'MON-RR');
        V_REC.P_USER_ID := G_USER_ID;
        APPS.ATK_GL_COMMON_PKG.GET_COMMON_INFO (V_ORG.ORGANIZATION_ID,
                                                V_REC.P_DATE,
                                                V_REC.P_USER_ID,
                                                V_REC.P_USER_JE_SOURCE_NAME,
                                                V_REC.P_USER_JE_CATEGORY_NAME,
                                                V_REC.P_PERIOD_NAME,
                                                V_REC.P_CURRENCY_CODE,
                                                V_REC.P_BATCH_NAME,
                                                V_REC.P_SET_OF_BOOKS_ID,
                                                V_REC.P_GROUP_ID);

        FOR V IN C (C_FROM_SOB_ID => P_FROM_SOB_ID, C_PERIOD_NAME => P_PERIOD_NAME, C_SEGMENT4 => V_SEGMENT4, C_SEGMENT5 => V_SEGMENT5) LOOP
            V_REC.P_CURRENCY_CONVERSION_DATE := V_REC.P_DATE;
            V_RATE := RATE_CONVERSION (V.CURRENCY_CODE, V_SOB.CURRENCY_CODE, G_CONVERSION_TYPE_AV, LAST_DAY (V_REC.P_DATE));

            IF V_RATE = 0 THEN
                RAISE E_ERROR_RATE;
            END IF;

            G_ERR_STRING := '2.1';
            DBMS_OUTPUT.PUT_LINE (G_ERR_STRING);
            V_REC.P_EXCHANGE_RATE := V_RATE;
            V_REC.P_DESCRIPTION := V.LINE_DESCRIPTION;
            V_REC.P_CURRENCY_CODE := V.CURRENCY_CODE;
            --         V_REC.P_PERIOD_NAME                := V.PERIOD_NAME;
            --         V_REC.P_USER_JE_SOURCE_NAME        := 'Dos-Accounting';
            --         V_REC.P_USER_JE_CATEGORY_NAME      := 'Transfer';
            --         V_REC.P_SET_OF_BOOKS_ID            := P_TO_SOB_ID;
            --         V_REC.P_GROUP_ID                   := NULL;
            V_REC.P_JOURNAL_ENTRY_NAME := GET_JOURNAL_NAME ('MPL ADJ' || P_TYPE, P_PERIOD_NAME, V.SHORT_NAME);
            V_REC.P_BATCH_NAME := GET_BATCH_NAME ('MPL ADJ' || P_TYPE, P_PERIOD_NAME, V.SHORT_NAME);
            --         V_REC.P_DR_ACC                     := NULL;
            --         V_REC.P_CR_ACC                     := NULL;
            V_REC.P_ATTRIBUTE1 := NULL;
            V_REC.P_ATTRIBUTE2 := NULL;
            V_REC.P_ATTRIBUTE3 := NULL;
            V_REC.P_ATTRIBUTE4 := NULL;
            V_REC.P_ATTRIBUTE5 := NULL;
            V_REC.P_ATTRIBUTE6 := NULL;
            V_REC.P_ATTRIBUTE7 := NULL;
            V_REC.P_ATTRIBUTE8 := NULL;
            V_REC.P_ATTRIBUTE9 := NULL;
            V_REC.P_ATTRIBUTE10 := NULL;
            V_REC.P_ATTRIBUTE11 := NULL;
            V_REC.P_ATTRIBUTE12 := NULL;
            V_REC.P_ATTRIBUTE13 := NULL;
            V_REC.P_ATTRIBUTE14 := NULL;
            V_REC.P_ATTRIBUTE15 := NULL;
            G_ERR_STRING := '2.2';
            DBMS_OUTPUT.PUT_LINE (G_ERR_STRING);

            IF NOT IS_SEPERATE_BY (P_TYPE) THEN
                DBMS_OUTPUT.PUT_LINE ('IS NOT SEPERATE_BY');

                IF P_TYPE = '銷售費用' THEN
                    V_REC.P_ATTRIBUTE3 := V.CUSTOMER;
                    V_REC.P_ATTRIBUTE14 := '06其他';
                    V_REC.P_DESCRIPTION := V.LINE_DESCRIPTION;
                END IF;

                --借方
                V_GCC :=
                    GET_GCC_BY_TYPE (P_TYPE,
                                     'DR',
                                     P_FROM_SOB_ID,
                                     V.SEGMENT1,
                                     NULL);
                V_REC.P_CCID := GET_CC_ID (V_GCC);

                IF V_REC.P_CCID = -1 THEN
                    MK_GL_PUB.CREATE_GL_ACCOUNT (
                        V_REC.P_SET_OF_BOOKS_ID,
                           V_GCC.SEGMENT1
                        || '.'
                        || V_GCC.SEGMENT2
                        || '.'
                        || V_GCC.SEGMENT3
                        || '.'
                        || V_GCC.SEGMENT4
                        || '.'
                        || V_GCC.SEGMENT5
                        || '.'
                        || V_GCC.SEGMENT6,
                        V_STRING);

                    IF V_STRING IS NOT NULL THEN
                        RAISE E_GEN_CCID_EXCEPTION;
                    ELSE
                        V_REC.P_CCID := GET_CC_ID (V_GCC);
                    END IF;
                END IF;

                --                v_rec.p_description := NULL;
                DBMS_OUTPUT.PUT_LINE ('借-V_REC.P_CCID:' || V_REC.P_CCID);
                V_REC.P_DR := NVL (V.ACCOUNTED_DR, 0);
                V_REC.P_CR := NVL (V.ACCOUNTED_CR, 0);
                V_REC.P_DR_ACC := V_REC.P_DR * V_REC.P_EXCHANGE_RATE;
                V_REC.P_CR_ACC := V_REC.P_CR * V_REC.P_EXCHANGE_RATE;
                IMP_GI_CURR (V_REC);
                --貸方
                V_GCC :=
                    GET_GCC_BY_TYPE (P_TYPE,
                                     'CR',
                                     P_FROM_SOB_ID,
                                     V.SEGMENT1,
                                     NULL);
                V_REC.P_CCID := GET_CC_ID (V_GCC);

                IF V_REC.P_CCID = -1 THEN
                    MK_GL_PUB.CREATE_GL_ACCOUNT (
                        V_REC.P_SET_OF_BOOKS_ID,
                           V_GCC.SEGMENT1
                        || '.'
                        || V_GCC.SEGMENT2
                        || '.'
                        || V_GCC.SEGMENT3
                        || '.'
                        || V_GCC.SEGMENT4
                        || '.'
                        || V_GCC.SEGMENT5
                        || '.'
                        || V_GCC.SEGMENT6,
                        V_STRING);

                    IF V_STRING IS NOT NULL THEN
                        RAISE E_GEN_CCID_EXCEPTION;
                    ELSE
                        V_REC.P_CCID := GET_CC_ID (V_GCC);
                    END IF;
                END IF;

                --                v_rec.p_description := v.line_description;
                DBMS_OUTPUT.PUT_LINE ('貸-V_REC.P_CCID:' || V_REC.P_CCID);
                V_REC.P_DR := NVL (V.ACCOUNTED_CR, 0);
                V_REC.P_CR := NVL (V.ACCOUNTED_DR, 0);
                V_REC.P_DR_ACC := V_REC.P_DR * V_REC.P_EXCHANGE_RATE;
                V_REC.P_CR_ACC := V_REC.P_CR * V_REC.P_EXCHANGE_RATE;
                IMP_GI_CURR (V_REC);
            ELSE
                DBMS_OUTPUT.PUT_LINE ('IS SEPERATE_BY');

                FOR V_VALUE IN C_VALUE (C_TYPE => P_TYPE) LOOP
                    IF P_TYPE = '北越GQC' THEN
                        V_REC.P_ATTRIBUTE3 := V_VALUE.C_NAME;
                        V_REC.P_ATTRIBUTE14 := V_ACCOUNT_CATEGORY;
                        V_REC.P_DESCRIPTION :=
                               '摘要: GU'
                            || ROUND (GET_PERCENTAGE_BY (P_TYPE, P_PERIOD_NAME, V_VALUE.C_NAME), 2) * 100
                            || '% '
                            || V_VALUE.C_NAME
                            || ' GQC分攤)';
                    ELSE
                        V_REC.P_ATTRIBUTE3 := NULL;
                        V_REC.P_ATTRIBUTE14 := NULL;
                        V_REC.P_DESCRIPTION := NULL;
                    END IF;

                    --借方
                    V_GCC :=
                        GET_GCC_BY_TYPE (P_TYPE,
                                         'DR',
                                         P_FROM_SOB_ID,
                                         V.SEGMENT1,
                                         V_VALUE.C_CODE);
                    V_REC.P_CCID := GET_CC_ID (V_GCC);

                    IF V_REC.P_CCID = -1 THEN
                        MK_GL_PUB.CREATE_GL_ACCOUNT (
                            V_REC.P_SET_OF_BOOKS_ID,
                               V_GCC.SEGMENT1
                            || '.'
                            || V_GCC.SEGMENT2
                            || '.'
                            || V_GCC.SEGMENT3
                            || '.'
                            || V_GCC.SEGMENT4
                            || '.'
                            || V_GCC.SEGMENT5
                            || '.'
                            || V_GCC.SEGMENT6,
                            V_STRING);

                        IF V_STRING IS NOT NULL THEN
                            RAISE E_GEN_CCID_EXCEPTION;
                        ELSE
                            V_REC.P_CCID := GET_CC_ID (V_GCC);
                        END IF;
                    END IF;

                    V_REC.P_DR := V.ACCOUNTED_DR * GET_PERCENTAGE_BY (P_TYPE, P_PERIOD_NAME, V_VALUE.C_NAME);
                    V_REC.P_CR := V.ACCOUNTED_CR * GET_PERCENTAGE_BY (P_TYPE, P_PERIOD_NAME, V_VALUE.C_NAME);
                    V_REC.P_DR_ACC := V_REC.P_DR * V_REC.P_EXCHANGE_RATE;
                    V_REC.P_CR_ACC := V_REC.P_CR * V_REC.P_EXCHANGE_RATE;
                    DBMS_OUTPUT.PUT_LINE ('借方:');
                    DBMS_OUTPUT.PUT_LINE ('V_REC.P_DR:' || V_REC.P_DR);
                    DBMS_OUTPUT.PUT_LINE ('V_REC.P_CR:' || V_REC.P_CR);
                    DBMS_OUTPUT.PUT_LINE ('V_REC.P_DR_ACC:' || V_REC.P_DR_ACC);
                    DBMS_OUTPUT.PUT_LINE ('V_REC.P_CR_ACC:' || V_REC.P_CR_ACC);
                    IMP_GI_CURR (V_REC);
                    --貸方
                    V_GCC :=
                        GET_GCC_BY_TYPE (P_TYPE,
                                         'CR',
                                         P_FROM_SOB_ID,
                                         V.SEGMENT1,
                                         V_VALUE.C_CODE);
                    V_REC.P_CCID := GET_CC_ID (V_GCC);

                    IF V_REC.P_CCID = -1 THEN
                        MK_GL_PUB.CREATE_GL_ACCOUNT (
                            V_REC.P_SET_OF_BOOKS_ID,
                               V_GCC.SEGMENT1
                            || '.'
                            || V_GCC.SEGMENT2
                            || '.'
                            || V_GCC.SEGMENT3
                            || '.'
                            || V_GCC.SEGMENT4
                            || '.'
                            || V_GCC.SEGMENT5
                            || '.'
                            || V_GCC.SEGMENT6,
                            V_STRING);

                        IF V_STRING IS NOT NULL THEN
                            RAISE E_GEN_CCID_EXCEPTION;
                        ELSE
                            V_REC.P_CCID := GET_CC_ID (V_GCC);
                        END IF;
                    END IF;

                    V_REC.P_DR := V.ACCOUNTED_CR * GET_PERCENTAGE_BY (P_TYPE, P_PERIOD_NAME, V_VALUE.C_NAME);
                    V_REC.P_CR := V.ACCOUNTED_DR * GET_PERCENTAGE_BY (P_TYPE, P_PERIOD_NAME, V_VALUE.C_NAME);
                    V_REC.P_DR_ACC := V_REC.P_DR * V_REC.P_EXCHANGE_RATE;
                    V_REC.P_CR_ACC := V_REC.P_CR * V_REC.P_EXCHANGE_RATE;
                    DBMS_OUTPUT.PUT_LINE ('貸方:');
                    DBMS_OUTPUT.PUT_LINE ('V_REC.P_DR:' || V_REC.P_DR);
                    DBMS_OUTPUT.PUT_LINE ('V_REC.P_CR:' || V_REC.P_CR);
                    DBMS_OUTPUT.PUT_LINE ('V_REC.P_DR_ACC:' || V_REC.P_DR_ACC);
                    DBMS_OUTPUT.PUT_LINE ('V_REC.P_CR_ACC:' || V_REC.P_CR_ACC);
                    IMP_GI_CURR (V_REC);
                END LOOP;
            END IF;
        END LOOP;

        G_ERR_STRING := '3';
        DBMS_OUTPUT.PUT_LINE (G_ERR_STRING);
        DBMS_OUTPUT.PUT_LINE ('V_REC.P_GROUP_ID:' || V_REC.P_GROUP_ID);
        DBMS_OUTPUT.PUT_LINE ('V_REC.P_SET_OF_BOOKS_ID:' || V_REC.P_SET_OF_BOOKS_ID);
        DBMS_OUTPUT.PUT_LINE ('V_REC.P_USER_ID:' || V_REC.P_USER_ID);
        DBMS_OUTPUT.PUT_LINE ('V_REC.P_GROUP_ID:' || V_REC.P_GROUP_ID);
        DBMS_OUTPUT.PUT_LINE ('V_REC.P_USER_JE_SOURCE_NAME:' || V_REC.P_USER_JE_SOURCE_NAME);
        --       Run Journal Import
        V_REQ_ID :=
            ATK_GL_COMMON_PKG.INSERT_GL_CONTROL_PASS_SOURCE (V_REC.P_SET_OF_BOOKS_ID,
                                                             V_REC.P_USER_ID,
                                                             V_REC.P_GROUP_ID,
                                                             V_REC.P_USER_JE_SOURCE_NAME);

        IF V_REQ_ID = -1 THEN
            DBMS_OUTPUT.PUT_LINE (P_TYPE || ' Failure!! GROUP ID:' || V_REC.P_GROUP_ID);
            COMMIT;
            RETURN P_TYPE || ' Failure!! GROUP ID:' || V_REC.P_GROUP_ID;
        ELSE
            DBMS_OUTPUT.PUT_LINE (P_TYPE || ' Success!! Concurrent ID:' || V_REQ_ID);
            COMMIT;
            RETURN P_TYPE || ' Success!! Concurrent ID:' || V_REQ_ID;
        END IF;
    EXCEPTION
        WHEN E_GEN_CCID_EXCEPTION THEN
            RETURN V_STRING;
        WHEN E_ERROR_RATE THEN
            V_MESSAGE := '請維護Average Rate!謝謝';
            RETURN V_MESSAGE;
        WHEN OTHERS THEN
            RETURN P_TYPE || ' Error(' || V_REQ_ID || '):' || G_ERR_STRING || '-' || SQLERRM;
    END TRANSFER_SOB;

    FUNCTION OH_RUN (P_SOB_ID IN NUMBER, P_PERIOD_NAME IN VARCHAR2, P_INS_FLAG IN VARCHAR2)
        RETURN VARCHAR2 IS
    BEGIN
        IF P_INS_FLAG = 'Y' THEN
            G_MSG := IMP_SAMPLE_OH (P_SOB_ID, P_PERIOD_NAME, 'FM', P_INS_FLAG);
            G_MSG := G_MSG || CHR (10) || IMP_OVERSEA_OH (P_SOB_ID, P_PERIOD_NAME, 'FM', P_INS_FLAG);
            G_MSG := G_MSG || CHR (10) || IMP_GQC_FEE_FAC (P_PERIOD_NAME, P_SOB_ID);
            G_MSG := G_MSG || CHR (10) || IMP_GQC_FEE_TPE (P_PERIOD_NAME, P_SOB_ID);
        ELSE
            G_MSG :=
                   IMP_SAMPLE_OH (P_SOB_ID, P_PERIOD_NAME, 'FM', P_INS_FLAG)
                || CHR (10)
                || IMP_OVERSEA_OH (P_SOB_ID, P_PERIOD_NAME, 'FM', P_INS_FLAG);
        END IF;

        RETURN G_MSG;
    END OH_RUN;

    FUNCTION RUN (P_MSOB_ID NUMBER, P_PERIOD_NAME VARCHAR2, P_TYPE VARCHAR2)
        RETURN VARCHAR2 IS
        CURSOR C (C_MSOB_ID NUMBER) IS
                SELECT SOB_ID
                  FROM MK_GL_DEPTS
                 WHERE SOB_ID <> C_MSOB_ID
            START WITH PARENT_ID IS NULL
                   AND SOB_ID = C_MSOB_ID
            CONNECT BY PRIOR DEPT_ID = PARENT_ID
              GROUP BY SOB_ID;

        V_MESSAGE      VARCHAR2 (32767);
        V_RATE         NUMBER;
        E_ERROR_RATE   EXCEPTION;
        V_SHORT_NAME   VARCHAR2 (30);
    BEGIN
        V_RATE := RATE_CONVERSION ('USD', 'TWD', G_CONVERSION_TYPE_AV, LAST_DAY (TO_DATE (P_PERIOD_NAME, 'MON-RR')));

        IF V_RATE = 0 THEN
            RAISE E_ERROR_RATE;
        END IF;

        --全部都分以管帳作為拋帳條件，
        --to產區管
        IF P_TYPE = 'FAC' THEN
            V_MESSAGE := 'AD Sample:' || IMP_AD_SAMPLE_FAC (P_SOB_ID => P_MSOB_ID, P_PERIOD => P_PERIOD_NAME);
            V_MESSAGE :=
                   V_MESSAGE
                || CHR (10)
                || '樣品中心:'
                || IMP_SAMPLE_OH (P_SOB_ID     => P_MSOB_ID,
                                  P_PERIOD     => P_PERIOD_NAME,
                                  P_SOB_CODE   => 'FM',
                                  P_TYPE       => 'FAC',
                                  P_INS_FLAG   => 'Y');
            V_MESSAGE :=
                   V_MESSAGE
                || CHR (10)
                || '海外OH:'
                || IMP_OVERSEA_OH (P_SOB_ID     => P_MSOB_ID,
                                   P_PERIOD     => P_PERIOD_NAME,
                                   P_SOB_CODE   => 'FM',
                                   P_TYPE       => 'FAC',
                                   P_INS_FLAG   => 'Y');
            V_MESSAGE :=
                V_MESSAGE || CHR (10) || '特殊機台:' || IMP_FA_SPECIAL_EXP_FAC (P_PERIOD => P_PERIOD_NAME, P_SOB_ID => P_MSOB_ID);
            V_MESSAGE := V_MESSAGE || CHR (10) || IMP_INSPECTION_FEE_FAC (P_SOB_ID => P_MSOB_ID, P_PERIOD => P_PERIOD_NAME);
            V_MESSAGE := V_MESSAGE || CHR (10) || ':' || IMP_GQC_FEE_FAC (P_PERIOD_NAME, P_MSOB_ID);

            FOR V IN C (C_MSOB_ID => P_MSOB_ID) LOOP
                V_MESSAGE := V_MESSAGE || CHR (10) || ':' || IMP_SAE_FEE_FAC (P_PERIOD_NAME, V.SOB_ID);
            END LOOP;

            FOR V IN C (C_MSOB_ID => P_MSOB_ID) LOOP
                v_message := v_message || CHR (10) || imp_dks_reclass_fac (p_period_name, v.sob_id);
            END LOOP;
        --to台北管
        ELSIF P_TYPE = 'TPE' THEN
            BEGIN
                SELECT SHORT_NAME
                  INTO V_SHORT_NAME
                  FROM GL_SETS_OF_BOOKS
                 WHERE 1 = 1
                   AND SET_OF_BOOKS_ID = P_MSOB_ID;
            EXCEPTION
                WHEN OTHERS THEN
                    V_SHORT_NAME := NULL;
            END;

            IF V_SHORT_NAME = 'TPV' THEN
                V_MESSAGE := V_MESSAGE || CHR (10) || 'AD Sample:' || IMP_AD_SAMPLE_TPE (P_SOB_ID => P_MSOB_ID, P_PERIOD => P_PERIOD_NAME);
            ELSIF V_SHORT_NAME IS NULL THEN
                NULL;
            ELSE
                V_MESSAGE := V_MESSAGE || CHR (10) || 'AD Sample:' || IMP_AD_SAMPLE_TPE (P_SOB_ID => P_MSOB_ID, P_PERIOD => P_PERIOD_NAME);
                V_MESSAGE :=
                       V_MESSAGE
                    || CHR (10)
                    || '樣品中心:'
                    || IMP_SAMPLE_OH (P_SOB_ID     => P_MSOB_ID,
                                      P_PERIOD     => P_PERIOD_NAME,
                                      P_SOB_CODE   => 'FM',
                                      P_TYPE       => 'TPE',
                                      P_INS_FLAG   => 'Y');
                V_MESSAGE :=
                       V_MESSAGE
                    || CHR (10)
                    || '海外OH:'
                    || IMP_OVERSEA_OH (P_SOB_ID     => P_MSOB_ID,
                                       P_PERIOD     => P_PERIOD_NAME,
                                       P_SOB_CODE   => 'FM',
                                       P_TYPE       => 'TPE',
                                       P_INS_FLAG   => 'Y');
                V_MESSAGE := V_MESSAGE || '特殊機台:' || IMP_FA_SPECIAL_EXP_TPE (P_PERIOD => P_PERIOD_NAME, P_SOB_ID => P_MSOB_ID);

                FOR V IN C (C_MSOB_ID => P_MSOB_ID) LOOP
                    V_MESSAGE := V_MESSAGE || CHR (10) || ':' || IMP_INSPECTION_FEE_TPE (P_SOB_ID => V.SOB_ID, P_PERIOD => P_PERIOD_NAME);
                END LOOP;

                V_MESSAGE := V_MESSAGE || CHR (10) || ':' || IMP_GQC_FEE_TPE (P_PERIOD_NAME, P_MSOB_ID);

                FOR V IN C (C_MSOB_ID => P_MSOB_ID) LOOP
                    V_MESSAGE := V_MESSAGE || CHR (10) || ':' || IMP_SAE_FEE_TPE (P_PERIOD_NAME, V.SOB_ID);
                END LOOP;

                FOR V IN C (C_MSOB_ID => P_MSOB_ID) LOOP
                    V_MESSAGE := V_MESSAGE || CHR (10) || ':' || IMP_RTWEX_FEE_TPE (P_PERIOD_NAME, V.SOB_ID);
                END LOOP;
            END IF;
        END IF;

        RETURN V_MESSAGE;
    EXCEPTION
        WHEN E_ERROR_RATE THEN
            V_MESSAGE := '請維護Average Rate!謝謝';
            RETURN V_MESSAGE;
    END RUN;
END MK_GL_TRANSFER_ENGINE_PKG;
/
