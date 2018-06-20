CREATE OR REPLACE PACKAGE BODY javaPojoGen
AS
   --Global private variables
   g_unque_key   dbo_name_t;

   FUNCTION create_java_pojo ( p_table_name               IN VARCHAR2                                
                             , p_unique_key               IN VARCHAR2 DEFAULT NULL
                             , p_template                 IN VARCHAR2 DEFAULT 'pojo-template')
      RETURN CLOB
   AS
      l_count        PLS_INTEGER := 0;
      l_table_name   dbo_name_t := LOWER (p_table_name);
      l_vars         teplsql.t_assoc_array;
      l_pojo_code    CLOB;
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
      l_vars ('className') := upper_first(to_camel_case(l_table_name));
      
      --Define unique key if table don't has primary key
      g_unque_key := p_unique_key;
      
      --Process template
      l_pojo_code := teplsql.process (l_vars, p_template, 'JAVAPOJOGEN');
      
      return l_pojo_code;
            
   END create_java_pojo;


   FUNCTION get_all_columns (p_tab_name VARCHAR2)
      RETURN column_tt
   IS
      l_tt   column_tt;
   BEGIN
        SELECT   to_camel_case(c.table_name)
               , to_camel_case (c.column_name)
               , c.nullable
               , '' constraint_type
               , to_java_type(c.data_type)
          BULK   COLLECT
          INTO   l_tt
          FROM   user_tab_columns c
         WHERE   c.table_name = UPPER (p_tab_name)
      ORDER BY   c.column_id;

      RETURN l_tt;
   END;

   FUNCTION get_pk_columns (p_tab_name VARCHAR2)
      RETURN column_tt
   IS
      l_tt   column_tt;
   BEGIN
      IF g_unque_key IS NOT NULL
      THEN
            
            SELECT   c.table_name
                   , to_camel_case (c.column_name)
                   , 'N'
                   , 'P' constraint_type
                   , to_java_type(c.data_type)
              BULK   COLLECT
              INTO   l_tt
              FROM   user_tab_columns c
             WHERE   c.table_name = UPPER (p_tab_name)
               AND   c.column_name = UPPER(g_unque_key)
          ORDER BY   c.column_id;         
         
      ELSE
           SELECT   c.table_name
                  , to_camel_case (c.column_name)
                  , c.nullable
                  , cs.constraint_type
                  , to_java_type(c.data_type)
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


    FUNCTION to_java_type (p_data_type VARCHAR2)
        RETURN VARCHAR2
    AS
        l_java_type   VARCHAR2(2000);
    BEGIN
        SELECT
            CASE /*based on https://docs.oracle.com/cd/B19306_01/java.102/b14188/datamap.htm*/
                WHEN data_type = 'VARCHAR2'         THEN 'String'
                WHEN data_type = 'CHAR'             THEN 'String'
                WHEN data_type = 'CHARACTER'        THEN 'String'
                WHEN data_type = 'LONG'             THEN 'String'
                WHEN data_type = 'STRING'           THEN 'String'
                WHEN data_type = 'VARCHAR'          THEN 'String'
                WHEN data_type = 'RAW'              THEN 'byte[]'
                WHEN data_type = 'LONG RAW'         THEN 'byte[]'
                WHEN data_type = 'BINARY_INTEGER'   THEN 'int'
                WHEN data_type = 'NATURAL'          THEN 'int'
                WHEN data_type = 'NATURALN'         THEN 'int'
                WHEN data_type = 'PLS_INTEGER'      THEN 'int'
                WHEN data_type = 'POSITIVE'         THEN 'int'
                WHEN data_type = 'POSITIVEN'        THEN 'int'
                WHEN data_type = 'SIGNTYPE'         THEN 'int'
                WHEN data_type = 'INT'              THEN 'int'
                WHEN data_type = 'INTEGER'          THEN 'int'
                WHEN data_type = 'SMALLINT'         THEN 'int'
                WHEN data_type = 'DEC'              THEN 'BigDecimal'
                WHEN data_type = 'DECIMAL'          THEN 'BigDecimal'
                WHEN data_type = 'NUMBER'           THEN 'BigDecimal'
                WHEN data_type = 'NUMERIC'          THEN 'BigDecimal'
                WHEN data_type = 'DOUBLE PRECISION' THEN 'double'
                WHEN data_type = 'FLOAT'            THEN 'double'
                WHEN data_type = 'REAL'             THEN 'float'
                WHEN data_type = 'DATE'             THEN 'Timestamp'
                WHEN data_type LIKE 'TIMESTAMP%' THEN 'java.sql.Timestamp'
                WHEN data_type LIKE 'INTERVAL%' THEN 'String'
                WHEN data_type = 'ROWID'            THEN 'java.sql.RowId'
                WHEN data_type = 'UROWID'           THEN 'java.sql.RowId'
                WHEN data_type = 'CLOB'             THEN 'java.sql.Clob'
                WHEN data_type = 'BLOB'             THEN 'java.sql.Blob'
                WHEN data_type = 'XMLTYPE'          THEN 'String'
                ELSE 'Datatype not suported'
            END
        INTO
            l_java_type
        FROM ( SELECT p_data_type data_type FROM dual);

        RETURN l_java_type;
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

END javaPojoGen;
/