CREATE OR REPLACE FUNCTION dbo.ufn_update_catalog_info(p_target_table REGCLASS, p_sources JSONB, IN p_printexec smallint DEFAULT 0)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
    DECLARE
        v_item JSONB;
        v_source_table REGCLASS;
        v_target_key TEXT;
        v_source_key TEXT;

        v_set_clause TEXT;
        v_diff_clause TEXT;
        v_sql TEXT;

        v_row_count BIGINT;
        v_total_count BIGINT := 0;
    BEGIN
        -- Kiểm tra danh sách bảng nguồn
        IF p_sources IS NULL OR jsonb_typeof(p_sources) <> 'array' OR jsonb_array_length(p_sources) = 0 THEN
            RAISE EXCEPTION
            'p_sources must be a non-empty JSON array';
        END IF;

        -- Duyệt từng bảng danh mục nguồn
        FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_sources) LOOP
            -- Lấy thông tin cấu hình
            v_source_table := NULLIF(v_item ->> 'source_table', '')::REGCLASS;

            v_target_key := v_item ->> 'target_key';
            v_source_key := v_item ->> 'source_key';

            -- Kiểm tra cấu hình
            IF v_source_table IS NULL OR NULLIF(v_target_key, '') IS NULL OR NULLIF(v_source_key, '') IS NULL OR jsonb_typeof(v_item -> 'column_map') <> 'object' OR v_item -> 'column_map' = '{}'::JSONB THEN
                RAISE EXCEPTION
                'Invalid source configuration: %',
                    v_item;
            END IF;

            -- Tạo danh sách SET
            SELECT string_agg(format('%I = s.%I', key, value), ', ' ORDER BY key),
                string_agg(format('%I IS DISTINCT FROM s.%I', key, value), ' OR ' ORDER BY key) INTO v_set_clause,
                v_diff_clause
            FROM jsonb_each_text(v_item -> 'column_map');

            -- Tạo câu UPDATE
            v_sql := format('UPDATE %s ' || CHR(13) || 'SET %s ' || CHR(13) || 'FROM %s AS s ' || CHR(13) || 'WHERE %s.%I = s.%I AND (%s)', 
                p_target_table, v_set_clause, v_source_table, p_target_table, v_target_key, v_source_key,
                v_diff_clause);

            -- Thực thi UPDATE
            --RAISE NOTICE '%',v_sql;

            EXECUTE v_sql;

            IF p_PrintExec = 1 THEN
                RAISE NOTICE '%',
                    v_sql;
            END IF;

            GET DIAGNOSTICS v_row_count = ROW_COUNT;

            v_total_count := v_total_count + v_row_count;
            END LOOP
            ;

            RETURN v_total_count;
        END;
$$;
