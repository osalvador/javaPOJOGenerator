create or replace PACKAGE BODY swaggerGen
AS
   --Global private variables
   g_unque_key   dbo_name_t;

   FUNCTION create_swagger ( p_table_name               IN VARCHAR2                                
                           , p_unique_key               IN VARCHAR2 DEFAULT NULL
                           , p_template                 IN VARCHAR2 DEFAULT 'swagger')
      RETURN CLOB
   AS
      l_count        PLS_INTEGER := 0;
      l_table_name   dbo_name_t := UPPER (p_table_name);
      l_vars         teplsql.t_assoc_array;
      l_swagger_code CLOB;
   BEGIN
      /*Validations*/

      --check_table_exists
      SELECT   COUNT ( * )
        INTO   l_count
        FROM   user_tables
       WHERE   UPPER (table_name) = UPPER (l_table_name);

      IF l_count = 0
      THEN
         raise_application_error (-20000, 'Table ' || l_table_name || ' does not exist!');
      END IF;

      --Check table hash PK or p_unique_key is not null
      IF p_unique_key IS NULL
      THEN
         SELECT   COUNT ( * )
           INTO   l_count
           FROM   user_constraints
          WHERE   UPPER (table_name) = UPPER (l_table_name) AND constraint_type = 'P';

         IF l_count = 0
         THEN
            raise_application_error (-20000
                                   ,    'Table '
                                     || l_table_name
                                     || ' does not have a Primary Key'
                                     || ' and P_UNIQUE_KEY parameter is null');
         END IF;
      END IF;

      --Init variables for render template
      l_vars ('date') := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI');
      l_vars ('table_name') := l_table_name;
      l_vars ('lower_table_name') := to_camel_case(l_table_name);
      l_vars ('className') := upper_first(to_camel_case(l_table_name));
      l_vars ('unque_key') :=  REPLACE(upper(p_unique_key), ' ', '');

      --Define unique key if table don't has primary key
      g_unque_key := upper(p_unique_key);

      --Process template      
      l_swagger_code := teplsql.process (l_vars, p_template, 'SWAGGERGEN');

      return l_swagger_code;

   END create_swagger;


   FUNCTION get_all_columns (p_tab_name VARCHAR2)
      RETURN column_tt
   IS
      l_tt   column_tt;
   BEGIN
        SELECT   c.table_name
               , to_camel_case (c.column_name)
               , upper(c.column_name)
               , c.nullable
               , '' constraint_type
               , to_swagger_type(c.data_type)
               , to_swagger_format(c.data_type)
          BULK   COLLECT
          INTO   l_tt
          FROM   user_tab_columns c
         WHERE   c.table_name = UPPER (p_tab_name)
      ORDER BY   c.column_id;

      RETURN l_tt;
   END;

   FUNCTION get_pk_columns (p_tab_name VARCHAR2, p_unque_key VARCHAR2 DEFAULT NULL)
      RETURN column_tt
   IS
      l_tt   column_tt;
   BEGIN
      IF p_unque_key IS NOT NULL
      THEN

            WITH uks AS (SELECT regexp_substr(p_unque_key, '[^,]+', 1, level) uk
                        FROM dual CONNECT BY regexp_substr(p_unque_key, '[^,]+', 1, level) IS NOT NULL
            )
            SELECT   c.table_name
                   , to_camel_case (c.column_name)
                   , upper(c.column_name)
                   , 'N'
                   , 'P' constraint_type
                   , to_swagger_type(c.data_type)
                   , to_swagger_format(c.data_type)
              BULK   COLLECT
              INTO   l_tt
              FROM   user_tab_columns c
             WHERE   c.table_name = UPPER (p_tab_name)
               AND   c.column_name in (select uk from uks)
          ORDER BY   c.column_id;         

      ELSE
           SELECT   c.table_name
                  , to_camel_case (c.column_name)
                  , upper(c.column_name)
                  , c.nullable
                  , cs.constraint_type
                  , to_swagger_type(c.data_type)
                  , to_swagger_format(c.data_type)
             BULK   COLLECT
             INTO   l_tt
             FROM         user_tab_columns c
                       LEFT JOIN
                          user_cons_columns cc
                       ON c.table_name = cc.table_name AND c.column_name = cc.column_name
                    LEFT JOIN
                       user_constraints cs
                    ON cc.constraint_name = cs.constraint_name
            WHERE   c.table_name = UPPER (p_tab_name) AND cs.constraint_type = 'P'
         ORDER BY   c.column_id;          
      END IF;

      RETURN l_tt;
   END;


   FUNCTION get_non_pk_columns (p_tab_name VARCHAR2, p_unque_key VARCHAR2 DEFAULT NULL)
      RETURN column_tt
   IS
      l_tt   column_tt;
   BEGIN
      IF p_unque_key IS NOT NULL
      THEN

            WITH uks AS (SELECT regexp_substr(p_unque_key, '[^,]+', 1, level) uk
                        FROM dual CONNECT BY regexp_substr(p_unque_key, '[^,]+', 1, level) IS NOT NULL
            )
            SELECT   c.table_name
                   , to_camel_case (c.column_name)
                   , upper(c.column_name)
                   , 'N'
                   , 'P' constraint_type
                   , to_swagger_type(c.data_type)
                   , to_swagger_format(c.data_type)
              BULK   COLLECT
              INTO   l_tt
              FROM   user_tab_columns c
             WHERE   c.table_name = UPPER (p_tab_name)
               AND   c.column_name not in (select uk from uks)
          ORDER BY   c.column_id;          

      ELSE
         WITH pks
             AS (SELECT c.column_name
                   FROM user_tab_columns c
                        left join user_cons_columns cc
                               ON c.table_name = cc.table_name
                                  AND c.column_name = cc.column_name
                        left join user_constraints cs
                               ON cc.constraint_name = cs.constraint_name
                  WHERE c.table_name = UPPER (p_tab_name)
                    AND cs.constraint_type = 'P'
                  ORDER BY c.column_id)
        SELECT  c.table_name
              , to_camel_case ( c.column_name )
              , upper(c.column_name)
              , c.nullable
              , cs.constraint_type
              , to_swagger_type(c.data_type)
              , to_swagger_format(c.data_type)
          BULK   COLLECT
          INTO   l_tt               
          FROM user_tab_columns c
               left join user_cons_columns cc
                      ON c.table_name = cc.table_name
                         AND c.column_name = cc.column_name
               left join user_constraints cs
                      ON cc.constraint_name = cs.constraint_name
         WHERE c.table_name = UPPER (p_tab_name)
           AND c.column_name NOT IN (SELECT pks.column_name
                                       FROM pks)
         ORDER BY c.column_id; 

      END IF;

      RETURN l_tt;
   END;      


   FUNCTION to_camel_case (p_stirng VARCHAR2)
      RETURN VARCHAR2
    AS
        l_string VARCHAR2(2000);
    BEGIN        
        SELECT lower(substr(res, 1, 1) ) || substr(res, 2) res
        INTO l_string
        FROM ( SELECT replace(initcap(p_stirng), '_') res
               FROM dual
        );        
        return l_string;
    END;


    FUNCTION to_swagger_type (p_data_type VARCHAR2)
        RETURN VARCHAR2
    AS
        l_swagger_type   VARCHAR2(2000);
    BEGIN
        SELECT
            CASE 
                WHEN data_type = 'VARCHAR2'         THEN 'string'
                WHEN data_type = 'CHAR'             THEN 'string'
                WHEN data_type = 'CHARACTER'        THEN 'string'
                WHEN data_type = 'LONG'             THEN 'string'
                WHEN data_type = 'STRING'           THEN 'string'
                WHEN data_type = 'VARCHAR'          THEN 'string'
                WHEN data_type = 'RAW'              THEN 'string'
                WHEN data_type = 'LONG RAW'         THEN 'string'
                WHEN data_type = 'BINARY_INTEGER'   THEN 'integer'
                WHEN data_type = 'NATURAL'          THEN 'integer'
                WHEN data_type = 'NATURALN'         THEN 'integer'
                WHEN data_type = 'PLS_INTEGER'      THEN 'integer'
                WHEN data_type = 'POSITIVE'         THEN 'integer'
                WHEN data_type = 'POSITIVEN'        THEN 'integer'
                WHEN data_type = 'SIGNTYPE'         THEN 'integer'
                WHEN data_type = 'INT'              THEN 'integer'
                WHEN data_type = 'INTEGER'          THEN 'integer'
                WHEN data_type = 'SMALLINT'         THEN 'integer'
                WHEN data_type = 'DEC'              THEN 'number'
                WHEN data_type = 'DECIMAL'          THEN 'number'
                WHEN data_type = 'NUMBER'           THEN 'number'
                WHEN data_type = 'NUMERIC'          THEN 'number'
                WHEN data_type = 'DOUBLE PRECISION' THEN 'number'
                WHEN data_type = 'FLOAT'            THEN 'number'
                WHEN data_type = 'REAL'             THEN 'number'
                WHEN data_type = 'DATE'             THEN 'string'
                WHEN data_type LIKE 'TIMESTAMP%' THEN 'string'
                WHEN data_type LIKE 'INTERVAL%' THEN 'string'
                WHEN data_type = 'ROWID'            THEN 'string'
                WHEN data_type = 'UROWID'           THEN 'string'
                WHEN data_type = 'CLOB'             THEN 'string'
                WHEN data_type = 'BLOB'             THEN 'string'
                WHEN data_type = 'XMLTYPE'          THEN 'string'
                ELSE 'Datatype not suported'
            END
        INTO
            l_swagger_type
        FROM ( SELECT p_data_type data_type FROM dual);

        RETURN l_swagger_type;
    END;


   FUNCTION to_swagger_format (p_data_type VARCHAR2)
        RETURN VARCHAR2
    AS
        l_swagger_format   VARCHAR2(2000);
    BEGIN
        SELECT
            CASE 
                WHEN data_type = 'VARCHAR2'         THEN ''
                WHEN data_type = 'CHAR'             THEN ''
                WHEN data_type = 'CHARACTER'        THEN ''
                WHEN data_type = 'LONG'             THEN ''
                WHEN data_type = 'STRING'           THEN ''
                WHEN data_type = 'VARCHAR'          THEN ''
                WHEN data_type = 'RAW'              THEN 'byte'
                WHEN data_type = 'LONG RAW'         THEN 'byte'
                WHEN data_type = 'BINARY_INTEGER'   THEN 'int32'
                WHEN data_type = 'NATURAL'          THEN 'int32'
                WHEN data_type = 'NATURALN'         THEN 'int32'
                WHEN data_type = 'PLS_INTEGER'      THEN 'int32'
                WHEN data_type = 'POSITIVE'         THEN 'int32'
                WHEN data_type = 'POSITIVEN'        THEN 'int32'
                WHEN data_type = 'SIGNTYPE'         THEN 'int32'
                WHEN data_type = 'INT'              THEN 'int32'
                WHEN data_type = 'INTEGER'          THEN 'int32'
                WHEN data_type = 'SMALLINT'         THEN 'int32'
                WHEN data_type = 'DEC'              THEN ''
                WHEN data_type = 'DECIMAL'          THEN ''
                WHEN data_type = 'NUMBER'           THEN ''
                WHEN data_type = 'NUMERIC'          THEN ''
                WHEN data_type = 'DOUBLE PRECISION' THEN 'double'
                WHEN data_type = 'FLOAT'            THEN 'float'
                WHEN data_type = 'REAL'             THEN ''
                WHEN data_type = 'DATE'             THEN 'date-time'
                WHEN data_type LIKE 'TIMESTAMP%' THEN 'date-time'
                WHEN data_type LIKE 'INTERVAL%' THEN 'string'
                WHEN data_type = 'ROWID'            THEN ''
                WHEN data_type = 'UROWID'           THEN ''
                WHEN data_type = 'CLOB'             THEN ''
                WHEN data_type = 'BLOB'             THEN 'byte'
                WHEN data_type = 'XMLTYPE'          THEN ''
                ELSE 'Datatype not suported'
            END
        INTO
            l_swagger_format
        FROM ( SELECT p_data_type data_type FROM dual);

        RETURN l_swagger_format;
    END;


    FUNCTION upper_first (p_string VARCHAR2)
        RETURN VARCHAR2
    AS
        l_string varchar2(2000);
    BEGIN
        SELECT upper(substr(txt, 1, 1) ) || substr(txt, 2)
        INTO l_string
        FROM ( SELECT ( p_string ) txt FROM dual);

        RETURN l_string;
    END;



END swaggerGen;