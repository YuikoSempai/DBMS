DO $$
    DECLARE
        t_name TEXT := 'tickets';
        s_name TEXT := 'public';
        user_name TEXT := 's100000';
        attr_delimeter TEXT := '------------------------------------------------------';
        prev_attr TEXT := '';
        pointer CURSOR FOR (
            SELECT
                patt.attnum num, -- номер аттрибута
                patt.attname master_att, -- имя аттрибута
                pt.typname, -- имя типа данных
                pcstr.contype, -- 'f', если fk --
                pcstr.confrelid, -- oid таблицы, на которую ссылается (если contype = 'f')
                patt2.attname slave_att, -- имя аттрибута
                pclass2.relname, -- имя таблицы
                con.conname constraint_name, -- имя констрейнта
                CASE
                    WHEN con.contype = 'f' THEN 'References ' || con.confrelid::regclass::text || '(' || con.confkey[1]::regclass::text || ')'
                    ELSE ''
                    END AS constraint_info
            FROM pg_class pclass -- все объекты, подобные таблицам
                     JOIN pg_attribute patt ON pclass.oid = patt.attrelid -- +аттрибуты, которые принадлежат таблицам
                     JOIN pg_type pt ON pt.oid = patt.atttypid -- +типы аттрибутов
                     JOIN pg_namespace pn ON pclass.relnamespace = pn.oid -- +пространство имен для таблицеподобной сущности
                     LEFT JOIN pg_constraint pcstr ON patt.attrelid = pcstr.conrelid AND patt.attnum = ANY(pcstr.conkey) -- +ограничения. LEFT чтобы оставить те, что без ограничений. ANY для исключения повторов
                     LEFT JOIN pg_attribute patt2 ON pcstr.confrelid = patt2.attrelid AND pcstr.confkey[1] = patt2.attnum -- +названия аттрибутов, на которые ссылаемся через fk
                     LEFT JOIN pg_class pclass2 ON pclass2.oid = patt2.attrelid -- +имя таблицы, на который ссылается наш fk
                     LEFT JOIN pg_constraint con ON con.conrelid = patt.attrelid AND con.conkey[1] = patt.attnum
            WHERE pclass.relname = t_name AND pn.nspname = s_name AND patt.attnum > 0
        );
    BEGIN
        IF LEFT(t_name, 1) = '"' AND RIGHT(t_name, 1) = '"' THEN
            t_name := BTRIM(t_name, '"');
        ELSE
            t_name := LOWER(t_name);
        END IF;

        RAISE NOTICE 'Пользователь: %', s_name;
        RAISE NOTICE 'Таблица: %', t_name;
        RAISE NOTICE '%   %   %', 'No.', RPAD('Имя столбца', 20, ' '), RPAD('Атрибуты', 20, ' ');
        RAISE NOTICE '%   %   %', '---', '--------------------', attr_delimeter;

        FOR c IN pointer
            LOOP
                IF prev_attr <> c.master_att THEN
                    RAISE NOTICE '%  %  Type: % ', RPAD(c.num::TEXT, 4, ' '), RPAD(c.master_att, 21, ' '), RPAD(c.typname, 12, ' ');
                ELSE
                    IF c.contype = 'f' THEN
                        RAISE NOTICE '% % Constr : "%" References %(%)', RPAD('.', 6, ' '),  RPAD('', 21, ' '), c.master_att, c.relname, c.slave_att;
                    else
                        RAISE NOTICE '%  %  Constr : % %', RPAD('.', 5, ' '), RPAD('', 20, ' '), c.constraint_name, c.contype;
                    end if;
                END IF;
                prev_attr = c.master_att;
            END LOOP;
        RAISE NOTICE '';
    END;
$$ LANGUAGE plpgsql;
