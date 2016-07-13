--沒做日結的情形下改日結資料,不會造成取額度的問題

SELECT *
FROM   erp_fs_daily_result_credit
WHERE  result_date = TO_DATE('20160401', 'YYYYMMDD');

UPDATE erp_fs_daily_result_credit
SET    result_date = TRUNC(SYSDATE), actual_date = TRUNC(SYSDATE) - 1
WHERE  result_date = TO_DATE('2016/3/31', 'yyyy/mm/dd');

UPDATE erp_fs_daily_result_qty
SET    result_date = TRUNC(SYSDATE), actual_date = TRUNC(SYSDATE) - 1
WHERE  result_date = TO_DATE('2016/3/31', 'yyyy/mm/dd');

SELECT *
FROM   fsman.erp_fs_sys_para
WHERE  sys_para_code = 'M05_DATE';

UPDATE fsman.erp_fs_sys_para
SET    sys_para_val                = '20160331'
WHERE  sys_para_code = 'M05_DATE';

--HPS未提供配量的情形下,改目前的配量檔即可

UPDATE erp_fs_mobi_useqty_headers
SET    creation_date = SYSDATE, last_update_date = SYSDATE;

UPDATE erp_fs_mobi_useqty_lines
SET    creation_date = SYSDATE, last_update_date = SYSDATE;

--ERPFS02018 - 委外手機訂單資料批次上傳HPS         FS_M02_LIB2.ERPFS02018      排程為每日的0758/0950/1155/1320/1435/1550
--SOURCE

SELECT a.*
FROM   erp_fs_order_headers a
WHERE      TRUNC(a.confirm_date) = TRUNC(TO_DATE('2016/04/01 00:00:00', 'YYYY/MM/DD HH24:MI:SS'))
       AND a.order_status = 'C'
       AND a.hps_tran_date IS NULL
       AND a.hps_order_seq IS NULL
       AND (   NVL(recycle_flag, 'N') = 'N'
            OR (    NVL(recycle_flag, 'N') = 'Y'
                AND recycle_memo = 'BrightStar判退'))
       AND a.order_class_code IN (SELECT b.order_class_code
                                  FROM   erp_fs_order_class b,
                                         erp_fs_order_cust_group c
                                  WHERE      b.order_cust_group_code = c.order_cust_group_code
                                         AND c.ord_proc_sys = '1');

--(   HPS拋TWMS為0655/0805/1005/1205/1335/1605/2200)

--ERPFS02191 - FS訂單拋轉至TWMS
--FS_M02_LIB_TWMS.FS_TWMS_ORD_TRANSFER           排程為每日的1430/1550/1930
--FS_M02_LIB_TWMS.FS_TWMS_ORD_TRANSFER
--SOURCE

SELECT erp_fs_order_headers_pk,
       recycle_flag
FROM   erp_fs_order_headers
WHERE      order_date = TO_DATE('20160401', 'YYYYMMDD')
       AND order_status = 'C'
       AND order_class_code IN DECODE(
                                  recycle_flag,
                                  'Y', order_class_code,
                                  (SELECT b.order_class_code
                                   FROM   erp_fs_order_class b,
                                          erp_fs_order_cust_group c
                                   WHERE      b.order_cust_group_code = c.order_cust_group_code
                                          AND c.ord_proc_sys = '2'
                                          AND b.class_type = '1'
                                          AND b.finish_flag = 'Y'
                                          AND c.tran2twms = 'Y')
                               );

--ERPFS02192 - 轉回TWMS出貨資訊前置作業
--FS_M02_LIB_TWMS.TWMS_SHIP_LIST
--        排程為翌日的凌晨0005
--SOURCE

SELECT *
FROM   erp_fs_order_headers
WHERE      1 = 1
       AND order_date = TO_DATE('20160401', 'YYYYMMDD')
       AND order_status = 'H'
       AND (   order_class_code IN (SELECT b.order_class_code
                                    FROM   erp_fs_order_class b,
                                           erp_fs_order_cust_group c
                                    WHERE      b.order_cust_group_code = c.order_cust_group_code
                                           AND c.ord_proc_sys = '2'
                                           AND b.class_type = '1'
                                           AND b.finish_flag = 'Y'
                                           AND c.tran2twms = 'Y')
            OR (    NVL(recycle_flag, 'N') = 'Y'
                AND NVL(recycle_memo, '00') <> 'BrightStar判退'));

--ERPFS02194 - 轉回TWMS出貨資訊
--FS_M02_LIB_TWMS.FS_TWMS_ORD_GET_RESULT
--       排程為翌日的凌晨0010
--SOURCE

SELECT *
FROM   fsman.erp_fs_headers_interface
WHERE      1 = 1
       AND TRUNC(source_time) = NVL(TO_DATE('20160401', 'YYYYMMDD'), TRUNC(source_time))
       --         AND    RHI_ID = NVL( PI_RHI_ID, RHI_ID )
       AND status = '2';


--ERPFS02023 - 手機日結產生銷貨資料作業(最後一次)
--FS_M02_LIB2.ERPFS02023
--                                              排程為每日的1215/1415/1615/1815/1945/2115,翌日0015/0415


--20160401000001

--後台訂購單

SELECT *
FROM   fsman.erp_fs_order_lines

--update fsman.erp_fs_order_lines
--set recycle_code = '20160401'
WHERE      1 = 1
       AND erp_fs_order_headers_pk = (SELECT erp_fs_order_headers_pk
                                      FROM   erp_fs_order_headers
                                      WHERE  order_number = '20160401000002');
                                      
         SELECT     efpc.*,(select recycle_code
                             from erp_fs_order_lines
                             where 1=1
                             and erp_fs_order_lines_pk = efpc.erp_fs_order_lines_pk) OLD_PROD_CDE         
             FROM   fsman.erp_fs_order_comp_lines efpc
            WHERE   erp_fs_order_headers_pk = (SELECT erp_fs_order_headers_pk
                                      FROM   erp_fs_order_headers
                                      WHERE  order_number = '20160401000002')
--         ORDER BY   erp_fs_order_lines_pk;                                      

SELECT   h.erp_fs_order_headers_pk,
         h.order_number,
         h.order_date,
         h.order_status,
         h.bc_id,
         h.sub_bc_id,
         h.ship_status,
         h.close_date,
         l.order_seq,
         l.mobi_item_code,
         l.ship_price,
         l.unit_price,
         l.order_num,
         l.ship_status,
         l.ship_num,
         l.final_cancel_num,
         l.ship_date
FROM     fsman.erp_fs_order_headers h,
         fsman.erp_fs_order_lines l,
         fsman.erp_fs_order_comp_lines c
WHERE        h.erp_fs_order_headers_pk = l.erp_fs_order_headers_pk
         AND l.erp_fs_order_lines_pk = c.erp_fs_order_lines_pk(+)
         AND h.order_number = '20160401000002'
ORDER BY h.bc_id,
         h.order_number;

--出貨介面

SELECT l.*
FROM   fsman.erp_fs_headers_interface h,
       fsman.erp_fs_lines_interface l
WHERE      h.rhi_id = (SELECT erp_fs_order_headers_pk
                       FROM   erp_fs_order_headers
                       WHERE      1 = 1
                      AND order_number = '20160401000002') * -1
       AND h.rhi_id = l.rhi_id;

--後台銷貨單

SELECT   h.*,
         l.*,
         c.*
FROM     fsman.erp_fs_sell_headers h,
         fsman.erp_fs_sell_lines l,
         fsman.erp_fs_sell_comp_lines c
WHERE        h.erp_fs_sell_headers_pk = l.erp_fs_sell_headers_pk
         AND l.erp_fs_sell_lines_pk = c.erp_fs_sell_lines_pk(+)
         AND h.erp_fs_order_headers_pk IN (SELECT erp_fs_order_headers_pk
                                           FROM   erp_fs_order_headers h
                                           WHERE  h.order_number = '20160401000001')
ORDER BY h.bc_id,
         h.erp_fs_order_headers_pk;

--拋帳

SELECT line_type,
       currency_code,
       term_name,
       orig_system_bill_customer_ref,
       conversion_type,
       conversion_date,
       conversion_rate,
       trx_date,
       gl_date,
       quantity,
       unit_selling_price,
       amount,
       comments,
       description,
       insert_flag,
       data_source,
       user_type,
       discount_flag,
       worksheet_batch,
       item_type,
       sales_order,
       tax_adjust,
       set_of_books_id,
       org_id
FROM   tccar.erp_ar_fs_interface_temp
WHERE  worksheet_batch LIKE '%20160401000001';

SELECT *
FROM   erp_fs_order_headers
WHERE      1 = 1
       AND order_date = TO_DATE('20160401', 'YYYYMMDD')
       --       AND order_status = 'H'
       AND (   order_class_code IN (SELECT b.order_class_code
                                    FROM   erp_fs_order_class b,
                                           erp_fs_order_cust_group c
                                    WHERE      b.order_cust_group_code = c.order_cust_group_code
                                           AND c.ord_proc_sys = '2'
                                           AND b.class_type = '1'
                                           AND b.finish_flag = 'Y'
                                           AND c.tran2twms = 'Y')
            OR (    NVL(recycle_flag, 'N') = 'Y'
                AND NVL(recycle_memo, '00') <> 'BrightStar判退'));