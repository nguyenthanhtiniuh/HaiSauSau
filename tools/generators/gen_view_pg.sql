-- CHUYEN DOI PostgreSQL: chi sinh DDL, KHONG tu dong tao/thay the view.
-- Chay toan bo file trong CUNG MOT session. Ham pg_temp tu het khi dong session.
-- Cau hinh loi goi o CUOI FILE truoc khi chay.
-- B00Lookup va cac bang lookup phai nam trong database PostgreSQL hien tai
-- (co the la foreign table). Khong tu anh xa B10THACOID.dbo sang schema bat ky.
-- LookupTable phai la ten PostgreSQL: table hoac schema.table;
-- ten co chu hoa can double quotes, vi du public."B20Customer".
-- Khong chap nhan bieu thuc SQL, ten 3 thanh phan hoac dau ngoac vuong SQL Server.

-- THAY DOI: tim dung ten cot thuc te; uu tien exact, sau do match khong phan biet hoa/thuong.
CREATE OR REPLACE FUNCTION pg_temp.gv_column(p_relation oid, p_name text)
RETURNS text LANGUAGE plpgsql AS $fn$
DECLARE
    v_names text[];
BEGIN
    SELECT array_agg(a.attname::text ORDER BY a.attnum)
    INTO v_names
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid = p_relation AND a.attnum > 0 AND NOT a.attisdropped
      AND a.attname::text = p_name;
    IF cardinality(v_names) = 1 THEN RETURN v_names[1]; END IF;
    SELECT array_agg(a.attname::text ORDER BY a.attnum)
    INTO v_names
    FROM pg_catalog.pg_attribute a
    WHERE a.attrelid = p_relation AND a.attnum > 0 AND NOT a.attisdropped
      AND lower(a.attname::text) = lower(p_name);
    IF coalesce(cardinality(v_names), 0) <> 1 THEN
        RAISE EXCEPTION 'Cot % thieu hoac mo ho trong relation %', p_name, p_relation::regclass;
    END IF;
    RETURN v_names[1];
END;
$fn$;

CREATE OR REPLACE FUNCTION pg_temp.gen_view_postgresql(
    p_tables text[],
    p_source_schema text,
    p_view_schema text,
    p_lookup_relation regclass,
    p_user_relation regclass,
    p_extension text DEFAULT '_explore',
    p_branch_data_code text DEFAULT '0',
    -- Giu ngoai le ZGTKHName cua script goc; doi thanh ARRAY[]::text[] neu khong can.
    p_omit_name_keys text[] DEFAULT ARRAY['ZGTKH']
)
RETURNS TABLE(source_table text, view_name text, script_sql text)
LANGUAGE plpgsql AS $fn$
DECLARE
    v_table text;
    v_source oid;
    v_lookup_sql text;
    v_user_sql text;
    v_key_column text;
    v_table_column text;
    v_select text;
    v_joins text;
    v_outputs text[];
    v_key text;
    v_join_column text;
    v_lookup_names text[];
    v_lookup_tables text[];
    v_lookup_table text;
    v_parts text[];
    v_lookup_oid oid;
    v_lookup_qualified text;
    v_alias text;
    v_code text;
    v_name text;
    v_output text;
    v_view text;
    v_target text;
    v_n integer;
    v_limit integer := current_setting('max_identifier_length')::integer;
    c record;
BEGIN
    IF coalesce(cardinality(p_tables), 0) = 0
       OR p_source_schema IS NULL OR p_view_schema IS NULL
       OR p_lookup_relation IS NULL OR p_extension IS NULL
       OR p_branch_data_code IS NULL THEN
        RAISE EXCEPTION 'Thieu danh sach bang, schema, lookup, extension hoac branch data code';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = p_source_schema)
       OR NOT EXISTS (SELECT 1 FROM pg_catalog.pg_namespace WHERE nspname = p_view_schema) THEN
        RAISE EXCEPTION 'Schema nguon/dich khong ton tai';
    END IF;
    SELECT format('%I.%I', n.nspname, r.relname) INTO v_lookup_sql
    FROM pg_catalog.pg_class r JOIN pg_catalog.pg_namespace n ON n.oid = r.relnamespace
    WHERE r.oid = p_lookup_relation;
    v_key_column := pg_temp.gv_column(p_lookup_relation, 'LookupKey');
    v_table_column := pg_temp.gv_column(p_lookup_relation, 'LookupTable');

    FOREACH v_table IN ARRAY p_tables LOOP
        IF v_table IS NULL OR btrim(v_table) = '' THEN
            RAISE EXCEPTION 'Ten bang khong duoc rong';
        END IF;
        v_table := btrim(v_table);
        -- Ten trong p_tables la ten catalog chinh xac, khong kem schema/double quotes.
        v_source := to_regclass(format('%I.%I', p_source_schema, v_table));
        IF v_source IS NULL THEN
            RAISE EXCEPTION 'Khong tim thay bang %.%', p_source_schema, v_table;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_class
                       WHERE oid = v_source AND relkind IN ('r', 'p', 'v', 'm', 'f')) THEN
            RAISE EXCEPTION '% khong phai relation co the SELECT', v_table;
        END IF;
        v_view := 'v' || v_table || p_extension;
        IF octet_length(v_view) > v_limit THEN
            RAISE EXCEPTION 'Ten view % vuot % bytes', v_view, v_limit;
        END IF;
        SELECT string_agg(format('    src.%I', a.attname), E',\n' ORDER BY a.attnum),
               array_agg(a.attname::text ORDER BY a.attnum)
        INTO v_select, v_outputs
        FROM pg_catalog.pg_attribute a
        WHERE a.attrelid = v_source AND a.attnum > 0 AND NOT a.attisdropped;
        IF v_select IS NULL THEN RAISE EXCEPTION 'Bang % khong co cot', v_table; END IF;
        v_joins := '';

        FOR c IN SELECT a.attname::text AS column_name, a.attnum
                 FROM pg_catalog.pg_attribute a
                 WHERE a.attrelid = v_source AND a.attnum > 0 AND NOT a.attisdropped
                 ORDER BY a.attnum
        LOOP
            v_join_column := CASE
                WHEN right(lower(c.column_name), 2) = 'id' THEN 'Id'
                WHEN right(lower(c.column_name), 4) = 'code' THEN 'Code'
                ELSE NULL END;
            v_key := CASE WHEN v_join_column IS NULL THEN c.column_name
                          ELSE left(c.column_name, length(c.column_name) - length(v_join_column)) END;

            -- THAY DOI: khong JOIN B00Command vi khong dung cac cot cua bang nay.
            -- Khong tu chon TOP 1 khi metadata co nhieu mapping.
            EXECUTE format(
                'SELECT array_agg(l.%1$I::text ORDER BY l.%1$I::text, l.%2$I::text),
                        array_agg(l.%2$I::text ORDER BY l.%1$I::text, l.%2$I::text)
                 FROM %3$s l
                 WHERE (lower(l.%1$I::text) = lower($1) OR lower(l.%1$I::text) = lower($2))
                   AND lower(l.%1$I::text) NOT IN (''docstatus'', ''branch'', ''currency'', ''unit'', ''fiscalyear'')',
                v_key_column, v_table_column, v_lookup_sql)
            INTO v_lookup_names, v_lookup_tables USING v_key, c.column_name;
            v_n := coalesce(cardinality(v_lookup_names), 0);
            IF v_n = 0 THEN CONTINUE; END IF;
            IF v_n <> 1 THEN
                RAISE EXCEPTION 'Nhieu lookup mapping cho %.%: %', v_table, c.column_name, v_lookup_names;
            END IF;
            IF v_join_column IS NULL THEN
                RAISE EXCEPTION 'Cot %.% match lookup nhung khong co hau to Id/Code; can mapping join ro rang',
                    v_table, c.column_name;
            END IF;
            v_key := v_lookup_names[1];
            v_lookup_table := replace(v_lookup_tables[1], '{=BRANCH(''DataCode'')}', p_branch_data_code);
            IF v_lookup_table IS NULL OR btrim(v_lookup_table) = '' THEN
                RAISE EXCEPTION 'LookupTable rong cho %', v_key;
            END IF;
            v_parts := parse_ident(v_lookup_table, true);
            IF cardinality(v_parts) = 1 THEN
                v_lookup_qualified := format('%I.%I', p_source_schema, v_parts[1]);
            ELSIF cardinality(v_parts) = 2 THEN
                v_lookup_qualified := format('%I.%I', v_parts[1], v_parts[2]);
            ELSE
                RAISE EXCEPTION 'LookupTable % phai la table hoac schema.table trong database hien tai', v_lookup_table;
            END IF;
            v_lookup_oid := to_regclass(v_lookup_qualified);
            IF v_lookup_oid IS NULL THEN RAISE EXCEPTION 'Khong tim thay lookup %', v_lookup_qualified; END IF;
            v_join_column := pg_temp.gv_column(v_lookup_oid, v_join_column);
            v_code := pg_temp.gv_column(v_lookup_oid, 'Code');
            v_alias := 'lk_' || c.attnum;
            v_joins := v_joins || format(E'\nLEFT JOIN %s AS %I ON src.%I = %I.%I',
                v_lookup_qualified, v_alias, c.column_name, v_alias, v_join_column);

            FOR v_n IN 1..2 LOOP
                IF v_n = 1 THEN
                    v_target := v_code;
                    v_output := v_key || 'Code';
                ELSE
                    IF EXISTS (SELECT 1 FROM unnest(p_omit_name_keys) AS x(k) WHERE lower(x.k) = lower(v_key)) THEN
                        CONTINUE;
                    END IF;
                    v_target := pg_temp.gv_column(v_lookup_oid, 'Name');
                    v_output := v_key || 'Name';
                END IF;
                IF octet_length(v_output) > v_limit THEN
                    RAISE EXCEPTION 'Ten cot sinh ra % vuot % bytes', v_output, v_limit;
                END IF;
                -- Kiem tra ca truong hop khac hoa/thuong de tranh alias gay nham lan.
                IF EXISTS (SELECT 1 FROM unnest(v_outputs) AS x(k) WHERE lower(x.k) = lower(v_output)) THEN
                    RAISE EXCEPTION 'Trung ten cot % trong view %; can quy uoc alias ro rang', v_output, v_view;
                END IF;
                v_outputs := array_append(v_outputs, v_output);
                v_select := v_select || format(E',\n    %I.%I AS %I', v_alias, v_target, v_output);
            END LOOP;
        END LOOP;

        IF strpos(lower(p_extension), '_explore') > 0 THEN
            IF p_user_relation IS NULL THEN RAISE EXCEPTION '_explore can p_user_relation'; END IF;
            SELECT format('%I.%I', n.nspname, r.relname) INTO v_user_sql
            FROM pg_catalog.pg_class r JOIN pg_catalog.pg_namespace n ON n.oid = r.relnamespace
            WHERE r.oid = p_user_relation;
            v_code := pg_temp.gv_column(p_user_relation, 'Id');
            v_name := pg_temp.gv_column(p_user_relation, 'FullName');
            FOR v_n IN 1..2 LOOP
                v_target := pg_temp.gv_column(v_source, CASE WHEN v_n = 1 THEN 'CreatedBy' ELSE 'ModifiedBy' END);
                v_output := CASE WHEN v_n = 1 THEN 'CreatedName' ELSE 'ModifiedName' END;
                v_alias := CASE WHEN v_n = 1 THEN 'usr_created' ELSE 'usr_modified' END;
                IF EXISTS (SELECT 1 FROM unnest(v_outputs) AS x(k) WHERE lower(x.k) = lower(v_output)) THEN
                    RAISE EXCEPTION 'Trung ten cot % trong view %', v_output, v_view;
                END IF;
                v_outputs := array_append(v_outputs, v_output);
                v_select := v_select || format(E',\n    %I.%I AS %I', v_alias, v_name, v_output);
                v_joins := v_joins || format(E'\nLEFT JOIN %s AS %I ON src.%I = %I.%I',
                    v_user_sql, v_alias, v_target, v_alias, v_code);
            END LOOP;
        END IF;
        source_table := format('%I.%I', p_source_schema, v_table);
        view_name := format('%I.%I', p_view_schema, v_view);
        script_sql := format(E'CREATE OR REPLACE VIEW %s AS\nSELECT\n%s\nFROM %s AS src%s;\n',
                             view_name, v_select, source_table, v_joins);
        RETURN NEXT;
    END LOOP;
END;
$fn$;

-- CAU HINH: vi du cho database da migrate ten bang thanh chu thuong, schema public.
-- Neu giu ten hoa/thuong: ARRAY['B30LCDoc'], 'dbo', 'dbo',
--                       'dbo."B00Lookup"'::regclass, 'dbo."B00UserList"'::regclass.
-- Ket qua: source_table, view_name, script_sql. Chi copy/chay script_sql sau khi review.
SELECT * FROM pg_temp.gen_view_postgresql(
    p_tables           => ARRAY['b30lcdoc'],
    p_source_schema    => 'public',
    p_view_schema      => 'public',
    p_lookup_relation  => 'public.b00lookup'::regclass,
    p_user_relation    => 'public.b00userlist'::regclass,
    p_extension        => '_explore',
    p_branch_data_code => '0'
);
