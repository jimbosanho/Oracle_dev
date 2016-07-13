DECLARE
   CURSOR c IS
      SELECT *
      FROM   (SELECT     LEVEL || LPAD(a.entry_sequence, 3, '0') ord,
                         LPAD(' ', 4 * (LEVEL - 1)) || TO_CHAR(a.menu_name) u_menu_name,
                         a.menu_name menu_name,
                         a.menu_id,
                         a.user_menu_name,
                         a.entry_sequence seq,
                         a.prompt,
                         a.sub_menu_id,
                         a.function_id,
                         a.function_name,
                         a.user_function_name,
                         a.description
              FROM       (SELECT fmv.menu_id,
                                 fmv.menu_name,
                                 fmv.user_menu_name,
                                 fmev.entry_sequence,
                                 fmev.prompt,
                                 fmev.sub_menu_id,
                                 fmev.function_id,
                                 fffv.function_name,
                                 fffv.user_function_name,
                                 fmev.description
                          FROM   fnd_menus_vl fmv,
                                 fnd_menu_entries_vl fmev,
                                 fnd_form_functions_vl fffv
                          WHERE      1 = 1
                                 AND fmv.menu_id = fmev.menu_id
                                 AND fmev.function_id = fffv.function_id(+)) a
              START WITH UPPER(a.user_menu_name) = 'FS_加盟IT_M'
              CONNECT BY PRIOR a.sub_menu_id = a.menu_id) b;

   v_function_exist_flag VARCHAR2(1);
   v_form_menu_exist_flag VARCHAR2(1);
   v_menu_exist_flag VARCHAR2(1);
   v_count NUMBER := 0;
BEGIN
   FOR v IN c LOOP
      v_count                    := v_count + 1;
      DBMS_OUTPUT.put_line('      DECLARE                                                     ');
      DBMS_OUTPUT.put_line('         v_function_exist_flag VARCHAR2(1);                       ');
      DBMS_OUTPUT.put_line('         v_form_menu_exist_flag VARCHAR2(1);                      ');
      DBMS_OUTPUT.put_line('         v_menu_exist_flag VARCHAR2(1);                           ');
      DBMS_OUTPUT.put_line('         v_row_id varchar2(30);                                   ');
      DBMS_OUTPUT.put_line('         v_function_id number;                                    ');
      DBMS_OUTPUT.put_line('         v_menu_id number;                                        ');
      DBMS_OUTPUT.put_line('      BEGIN                                                       ');
      DBMS_OUTPUT.put_line('         v_function_exist_flag      := ''N'';                     ');
      DBMS_OUTPUT.put_line('         v_form_menu_exist_flag     := ''N'';                     ');
      DBMS_OUTPUT.put_line('         v_menu_exist_flag          := ''N'';                     ');
      DBMS_OUTPUT.put_line('                                                                  ');

      IF v.function_id IS NOT NULL THEN
         DBMS_OUTPUT.put_line('            --檢查Function是否存在                                ');
         DBMS_OUTPUT.put_line('            BEGIN                                                 ');
         DBMS_OUTPUT.put_line('            SELECT ''Y'',function_id                              ');
         DBMS_OUTPUT.put_line('            INTO   v_function_exist_flag,v_function_id            ');
         DBMS_OUTPUT.put_line('            FROM   fnd_form_functions_vl fffv                     ');
         DBMS_OUTPUT.put_line('            WHERE      1 = 1                                      ');
         DBMS_OUTPUT.put_line('                   AND fffv.function_name = ''' || v.function_name || ''';');
         DBMS_OUTPUT.put_line('            EXCEPTION                                             ');
         DBMS_OUTPUT.put_line('            WHEN OTHERS THEN                                      ');
         DBMS_OUTPUT.put_line('               v_function_exist_flag := ''N'';                    ');
         DBMS_OUTPUT.put_line('               v_function_id := null;                             ');
         DBMS_OUTPUT.put_line('            END;                                                  ');
         DBMS_OUTPUT.put_line('                                                                  ');
         DBMS_OUTPUT.put_line('            --檢查Function是否存在於Menu                          ');
         DBMS_OUTPUT.put_line('            BEGIN                                                 ');
         DBMS_OUTPUT.put_line('            SELECT ''Y'',fmv.menu_id                              ');
         DBMS_OUTPUT.put_line('            INTO   v_form_menu_exist_flag,v_menu_id               ');
         DBMS_OUTPUT.put_line('            FROM   fnd_menus_vl fmv,                              ');
         DBMS_OUTPUT.put_line('                   fnd_menu_entries_vl fmev,                      ');
         DBMS_OUTPUT.put_line('                   fnd_form_functions_vl fffv                     ');
         DBMS_OUTPUT.put_line('            WHERE      1 = 1                                      ');
         DBMS_OUTPUT.put_line('                   AND fmv.menu_name = ''' || v.menu_name || '''');
         DBMS_OUTPUT.put_line('                   AND fmv.menu_id = fmev.menu_id                 ');
         DBMS_OUTPUT.put_line('                   AND fmev.function_id = fffv.function_id        ');
         DBMS_OUTPUT.put_line('                   AND fffv.function_name = ''' || v.function_name || '''');
         DBMS_OUTPUT.put_line('                   AND fmev.entry_sequence = ''' || v.seq || ''';');
         DBMS_OUTPUT.put_line('            EXCEPTION                                             ');
         DBMS_OUTPUT.put_line('            WHEN OTHERS THEN                                      ');
         DBMS_OUTPUT.put_line('               v_form_menu_exist_flag := ''N'';                   ');
         DBMS_OUTPUT.put_line('            END;                                                  ');
         --      ELSE
         DBMS_OUTPUT.put_line('            --檢查menu是否存在                                    ');
         DBMS_OUTPUT.put_line('            BEGIN                                                 ');
         DBMS_OUTPUT.put_line('            SELECT ''Y'',menu_id                                  ');
         DBMS_OUTPUT.put_line('            INTO   v_menu_exist_flag,v_menu_id                    ');
         DBMS_OUTPUT.put_line('            FROM   fnd_menus_vl fmv                               ');
         DBMS_OUTPUT.put_line('            WHERE      1 = 1                                      ');
         DBMS_OUTPUT.put_line('                   AND fmv.menu_name = ''' || v.menu_name || ''';');
         DBMS_OUTPUT.put_line('            EXCEPTION                                             ');
         DBMS_OUTPUT.put_line('            WHEN OTHERS THEN                                      ');
         DBMS_OUTPUT.put_line('               v_menu_exist_flag := ''N'';                        ');
         DBMS_OUTPUT.put_line('               v_menu_id := null;                                 ');
         DBMS_OUTPUT.put_line('            END;                                                  ');
      END IF;

      DBMS_OUTPUT.put_line('      DBMS_OUTPUT.put_line(          ');
      DBMS_OUTPUT.put_line('            ''' || v.menu_name || '''              ');
      DBMS_OUTPUT.put_line('         || ''-''                    ');
      DBMS_OUTPUT.put_line('         || ''' || v.seq || '''                    ');
      DBMS_OUTPUT.put_line('         || ''-''                    ');
      DBMS_OUTPUT.put_line('         || ''' || v.function_name || '''          ');
      DBMS_OUTPUT.put_line('         || ''-''                    ');
      DBMS_OUTPUT.put_line('         || ''' || v.user_function_name || '''     ');
      DBMS_OUTPUT.put_line('         || ''-''                    ');
      DBMS_OUTPUT.put_line('         || v_menu_exist_flag        ');
      DBMS_OUTPUT.put_line('         || ''-''                    ');
      DBMS_OUTPUT.put_line('         || v_form_menu_exist_flag   ');
      DBMS_OUTPUT.put_line('         || ''-''                    ');
      DBMS_OUTPUT.put_line('         || v_function_exist_flag    ');
      DBMS_OUTPUT.put_line('      );                             ');

      --      EXIT WHEN v_count = 5;

      DBMS_OUTPUT.put_line('      IF v_form_menu_exist_flag = ''N''                ');
      DBMS_OUTPUT.put_line('      and v_function_exist_flag = ''Y'' THEN           ');
      DBMS_OUTPUT.put_line('         fnd_menu_entries_pkg.insert_row(              ');
      DBMS_OUTPUT.put_line('            x_rowid                  => v_row_id,      ');
      DBMS_OUTPUT.put_line('            x_menu_id                => v_menu_id,     ');
      DBMS_OUTPUT.put_line('            x_entry_sequence         => ''' || v.seq || ''',         ');
      DBMS_OUTPUT.put_line('            x_sub_menu_id            => NULL,          ');
      DBMS_OUTPUT.put_line('            x_function_id            => v_function_id, ');
      DBMS_OUTPUT.put_line('            x_grant_flag             => ''Y'',           ');
      DBMS_OUTPUT.put_line('            x_prompt                 => ''' || v.prompt || ''',      ');
      DBMS_OUTPUT.put_line('            x_description            => ''' || v.description || ''', ');
      DBMS_OUTPUT.put_line('            x_creation_date          => SYSDATE,       ');
      DBMS_OUTPUT.put_line('            x_created_by             => -1,            ');
      DBMS_OUTPUT.put_line('            x_last_update_date       => SYSDATE,       ');
      DBMS_OUTPUT.put_line('            x_last_updated_by        => -1,            ');
      DBMS_OUTPUT.put_line('            x_last_update_login      => -1             ');
      DBMS_OUTPUT.put_line('         );                                            ');
      DBMS_OUTPUT.put_line('      END IF;                                          ');
      DBMS_OUTPUT.put_line('      END;                                                        ');
   END LOOP;
--   fnd_menu_entries_pkg;
END;