create or replace PACKAGE javaPojoGen authid current_user
AS

   /**
   * javaPojoGen
   * Generated by: Oscar Salvador Magallanes
   * Website: github.com/osalvador/OsalvadorCodeGenerators
   * Version: 0.1
   */

   --Global public data structures
   SUBTYPE dbo_name_t IS VARCHAR2 (30); -- Max size for a DB object name

   TYPE dbo_name_aat IS TABLE OF dbo_name_t;

    TYPE column_rt
    IS
      RECORD (
         table_name        user_tab_columns.table_name%TYPE
       , column_name       user_tab_columns.column_name%TYPE
       , db_column_name    user_tab_columns.column_name%TYPE
       , nullable          user_tab_columns.nullable%TYPE
       , constraint_type   user_constraints.constraint_type%TYPE
       , data_type         user_tab_columns.data_type%TYPE
      );

   --Collection types (record)
   TYPE column_tt IS TABLE OF column_rt;

   TYPE constraint_tt IS TABLE OF user_constraints%ROWTYPE;

   /**
   * Create PL/SQL Table API
   *
   * @param     p_table_name              must be NOT NULL
   * @param     p_unique_key              If the table has no primary key, it indicates the column that will be used as a unique key
   */
   FUNCTION create_java_pojo ( p_table_name               IN VARCHAR2                                
                             , p_unique_key               IN VARCHAR2 DEFAULT NULL
                             , p_template                 IN VARCHAR2 DEFAULT 'pojo-template')
      RETURN CLOB;

   --Public functions but for internal use.
   FUNCTION get_all_columns (p_tab_name VARCHAR2)
      RETURN column_tt;

   FUNCTION get_pk_columns (p_tab_name VARCHAR2, p_unque_key VARCHAR2 DEFAULT NULL)
      RETURN column_tt;

   FUNCTION get_non_pk_columns (p_tab_name VARCHAR2, p_unque_key VARCHAR2 DEFAULT NULL)
      RETURN column_tt;

   FUNCTION to_camel_case (p_stirng VARCHAR2)
      RETURN VARCHAR2;

    FUNCTION to_java_type (p_data_type VARCHAR2)
        RETURN VARCHAR2;
    
    FUNCTION upper_first (p_string VARCHAR2)
        RETURN VARCHAR2;
    
    FUNCTION get_java_imports (p_columns in column_tt)
        RETURN VARCHAR2;
        

/************************
*  POJO Template        *
*************************/

$if false $then
<%@ template
    name=pojo-template
%>
<%! col      javaPojoGen.column_tt := javaPojoGen.get_all_columns ('${table_name}'); %>
<%! pk       javaPojoGen.column_tt := javaPojoGen.get_pk_columns ('${table_name}', '${unque_key}'); %>
<%! c pls_integer; %>
<%! procedure sep (p_cont in pls_integer, p_delimiter in varchar2)
    as
    begin
         if p_cont > 1
         then
               teplsql.p(p_delimiter);
         end if;
    end; %>
<%! function uf (p_in in varchar2) return varchar2
    as
    begin
        return javaPojoGen.upper_first(p_in);
    end;%>
<%= javaPojoGen.get_java_imports(col) %>
\\n
public class ${className} {

    /**
    * class ${className}
    * Generated with: javaPojoGen
    * Website: github.com/osalvador/OsalvadorCodeGenerators
    * Created On: ${date}
    */

    // Attributes
    <% for i in 1 .. col.last loop %>
    private <%= col(i).data_type%> <%= col(i).COLUMN_NAME%>;
    <% end loop; %>

    // Empty Constructor
    public ${className}(){}
        
    // Getters and Setters
    <% for i in 1 .. col.last loop %>
    public <%= col(i).data_type%> get<%= uf(col(i).COLUMN_NAME) %>(){
        return <%= col(i).COLUMN_NAME%>;
    }    
    public void set<%= uf(col(i).COLUMN_NAME) %>(<%= col(i).data_type%> <%= col(i).COLUMN_NAME%>) {
        this.<%= col(i).COLUMN_NAME%> = <%= col(i).COLUMN_NAME%>;
    }
    
    <% end loop; %>     
    
    @Override
    public String toString() {
        return "${className}{" +
                <% c := col.last+1; for i in 1 .. col.last loop %>
                "<%= col(i).COLUMN_NAME%>=" + <%= col(i).COLUMN_NAME%> + "<%sep(c-i,',');%>"+ 
                <% end loop; %>
                '}';
    }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        ${className} that = (${className}) o;
        <% for i in 1 .. pk.last loop %>
        if (!get<%=uf(pk(i).COLUMN_NAME) %>().equals(that.get<%=uf(pk(i).COLUMN_NAME) %>())) return false;
        <% end loop; %>
        return true;        
    }

    @Override
    public int hashCode() {
        int result = 1;
        <% for i in 1 .. pk.last loop %>
        result = 31 * result + get<%=uf(pk(i).COLUMN_NAME) %>().hashCode();
        <% end loop; %>
        return result;
    }
    
}
$end


/************************
*  JavaBean Template    *
*************************/ 
$if false $then
<%@ template
    name=bean-template
%>
<%! col      javaPojoGen.column_tt := javaPojoGen.get_all_columns ('${table_name}'); %>
<%! pk       javaPojoGen.column_tt := javaPojoGen.get_pk_columns ('${table_name}', '${unque_key}'); %>
<%! c pls_integer; %>
<%! procedure sep (p_cont in pls_integer, p_delimiter in varchar2)
    as
    begin
         if p_cont > 1
         then
               teplsql.p(p_delimiter);
         end if;
    end; %>
<%! function uf (p_in in varchar2) return varchar2
    as
    begin
        return javaPojoGen.upper_first(p_in);
    end;%>
import java.io.Serializable;
<%= javaPojoGen.get_java_imports(col) %>
\\n
public class ${className} implements Serializable {

    /**
    * class ${className}
    * Generated with: javaPojoGen
    * Website: github.com/osalvador/OsalvadorCodeGenerators
    * Created On: ${date}
    */

    // Attributes
    <% for i in 1 .. col.last loop %>
    private <%= col(i).data_type%> <%= col(i).COLUMN_NAME%>;
    <% end loop; %>

    // Constructors
    public ${className}(){}
    
    public ${className}(<% c := pk.last+1; for i in 1 .. pk.last loop %>
<%=  pk(i).data_type%> <%=pk(i).COLUMN_NAME %><%sep(c-i,',');%><% end loop; %>) {
<% c := pk.last+1; for i in 1 .. pk.last loop %>
        this.<%=pk(i).COLUMN_NAME %> = <%=pk(i).COLUMN_NAME %>;
<% end loop; %>        
    }
    
    
    // Getters and Setters
    <% for i in 1 .. col.last loop %>
    public <%= col(i).data_type%> get<%= uf(col(i).COLUMN_NAME) %>(){
        return <%= col(i).COLUMN_NAME%>;
    }    
    public void set<%= uf(col(i).COLUMN_NAME) %>(<%= col(i).data_type%> <%= col(i).COLUMN_NAME%>) {
        this.<%= col(i).COLUMN_NAME%> = <%= col(i).COLUMN_NAME%>;
    }
    
    <% end loop; %>     
    
    @Override
    public String toString() {
        return "${className}{" +
                <% c := col.last+1; for i in 1 .. col.last loop %>
                "<%= col(i).COLUMN_NAME%>=" + <%= col(i).COLUMN_NAME%> + "<%sep(c-i,',');%>"+ 
                <% end loop; %>
                '}';
    }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        ${className} that = (${className}) o;
        <% for i in 1 .. pk.last loop %>
        if (!get<%=uf(pk(i).COLUMN_NAME) %>().equals(that.get<%=uf(pk(i).COLUMN_NAME) %>())) return false;
        <% end loop; %>
        return true;        
    }

    @Override
    public int hashCode() {
        int result = 1;
        <% for i in 1 .. pk.last loop %>
        result = 31 * result + get<%=uf(pk(i).COLUMN_NAME) %>().hashCode();
        <% end loop; %>
        return result;
    }
    
}
$end



/************************
*  JPA Entity Template    *
*************************/ 
$if false $then
<%@ template
    name=jpa-entity-template
%>
<%! col  javaPojoGen.column_tt := javaPojoGen.get_all_columns ('${table_name}'); %>
<%! pk   javaPojoGen.column_tt := javaPojoGen.get_pk_columns ('${table_name}', '${unque_key}'); %>
<%! npk  javaPojoGen.column_tt := javaPojoGen.get_non_pk_columns ('${table_name}', '${unque_key}'); %>
<%! c pls_integer; %>
<%! procedure sep (p_cont in pls_integer, p_delimiter in varchar2)
    as
    begin
         if p_cont > 1
         then
               teplsql.p(p_delimiter);
         end if;
    end; %>
<%! function uf (p_in in varchar2) return varchar2
    as
    begin
        return javaPojoGen.upper_first(p_in);
    end;%>
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;
import java.io.Serializable;
<%= javaPojoGen.get_java_imports(col) %>
\\n
@Entity
@Table(name="${table_name}")
public class ${className}Entity implements Serializable {

    /**
    * class ${className}Entity
    * Generated with: javaPojoGen
    * Website: github.com/osalvador/OsalvadorCodeGenerators
    * Created On: ${date}
    */

    // Attributes    
    <% for i in 1 .. pk.last loop %>
    @Id
    @Column(name="<%= pk(i).db_column_name%>")
    private <%= pk(i).data_type%> <%= pk(i).COLUMN_NAME%>;
    <% end loop; %>
    
    <% for i in 1 .. nvl(npk.last,0) loop %>
    @Column(name="<%= npk(i).db_column_name%>")
    private <%= npk(i).data_type%> <%= npk(i).COLUMN_NAME%>;
    <% end loop; %>

    // Constructors
    private ${className}Entity(){}
    
    public ${className}Entity(<% c := pk.last+1; for i in 1 .. pk.last loop %>
<%=  pk(i).data_type%> <%=pk(i).COLUMN_NAME %><%sep(c-i,',');%><% end loop; %>) {
<% for i in 1 .. pk.last loop %>
        this.<%=pk(i).COLUMN_NAME %> = <%=pk(i).COLUMN_NAME %>;
<% end loop; %>
    }
    
    
    // Getters and Setters
    <% for i in 1 .. col.last loop %>
    public <%= col(i).data_type%> get<%= uf(col(i).COLUMN_NAME) %>(){
        return <%= col(i).COLUMN_NAME%>;
    }    
    public void set<%= uf(col(i).COLUMN_NAME) %>(<%= col(i).data_type%> <%= col(i).COLUMN_NAME%>) {
        this.<%= col(i).COLUMN_NAME%> = <%= col(i).COLUMN_NAME%>;
    }
    
    <% end loop; %>     
    
    @Override
    public String toString() {
        return "${className}Entity{" +
                <% c := col.last+1; for i in 1 .. col.last loop %>
                "<%= col(i).COLUMN_NAME%>=" + <%= col(i).COLUMN_NAME%> + "<%sep(c-i,',');%>"+ 
                <% end loop; %>
                '}';
    }
    
    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        ${className}Entity that = (${className}Entity) o;
        <% for i in 1 .. pk.last loop %>
        if (!get<%=uf(pk(i).COLUMN_NAME) %>().equals(that.get<%=uf(pk(i).COLUMN_NAME) %>())) return false;
        <% end loop; %>
        return true;        
    }

    @Override
    public int hashCode() {
        int result = 1;
        <% for i in 1 .. pk.last loop %>
        result = 31 * result + get<%=uf(pk(i).COLUMN_NAME) %>().hashCode();
        <% end loop; %>
        return result;
    }
    
}
$end


/****************************
*  JdbcTemplate DAO Template*
****************************/ 
$if false $then
<%@ template
    name=jdbctemplate-dao-interface-template
%>
<%! pk   javaPojoGen.column_tt := javaPojoGen.get_pk_columns ('${table_name}', '${unque_key}'); %>
<%! c pls_integer; %>
<%! procedure sep (p_cont in pls_integer, p_delimiter in varchar2)
    as
    begin
         if p_cont > 1
         then
               teplsql.p(p_delimiter);
         end if;
    end; %>
import java.util.List;
<%= javaPojoGen.get_java_imports(pk) %>
\\n
/**
 * Interface for a Data Access Object that can be used for a single specific type domain object ${className}.
 * 
 * @author osalvador
 * 
 */
public interface ${className}Dao {

    /*
    * class ${className}Dao
    * Generated with: javaPojoGen
    * Website: github.com/osalvador/OsalvadorCodeGenerators
    * Created On: ${date}
	*/
	
	/**
	 * Get a list of all ${className}.
	 */
	public List<${className}> findAll();

	/**
	 * Get the ${className} with the specified id
     <% c := pk.last+1; for i in 1 .. pk.last loop %>
     * @param <%=pk(i).COLUMN_NAME %> primary key value 
     <% end loop; %>
	 */
	public ${className} find(<% c := pk.last+1; for i in 1 .. pk.last loop %>
<%=  pk(i).data_type%> <%=pk(i).COLUMN_NAME %><%sep(c-i,',');%> <% end loop; %>);


    /**
     * Get the ${className} with the specified item
     * @param item the specified item
     */
    public ${className} find(${className} item);

	/**
	 * Returns the total number of results.
	 */
	public long count();
	
	/**
	 * Add the specified ${className} as a new entry in the database.
     * @param item the specified item to create    
	 */
	public void create(${className} item);
	
	/**
	 * Update the corresponding ${className} in the database with the properties of the specified object.
     * @param item the specified item to update    
	 */
	public void update(${className} item);
	
	/**
	 * Remove the specified ${className} from the database.
     * @param item the specified item to delete    
	 */
	public void delete(${className} item);
	
}
$end




/******************************************************
*  JdbcTemplate DAO Implementation Template           *
******************************************************/ 
$if false $then
<%@ template
    name=jdbctemplate-dao-implement-template
%>
<%! col  javaPojoGen.column_tt := javaPojoGen.get_all_columns ('${table_name}'); %>
<%! pk   javaPojoGen.column_tt := javaPojoGen.get_pk_columns ('${table_name}', '${unque_key}'); %>
<%! c pls_integer; %>
<%! procedure sep (p_cont in pls_integer, p_delimiter in varchar2)
    as
    begin
         if p_cont > 1
         then
               teplsql.p(p_delimiter);
         end if;
    end; %>
<%! function uf (p_in in varchar2) return varchar2
    as
    begin
        return javaPojoGen.upper_first(p_in);
    end;%>
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

import javax.sql.DataSource;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
<%= javaPojoGen.get_java_imports(pk) %>
\\n
/**
 * Implementation of <code>${className}Dao</code> using Spring JdbcTemplate.
 *
 * @author osalvador
 *
 */
@Repository
public class ${className}DaoImpl implements ${className}Dao {
    
    /**
    * class ${className}Dao
    * Generated with: javaPojoGen
    * Website: github.com/osalvador/OsalvadorCodeGenerators
    * Created On: ${date}
	*/

    // Uncomment if you use a logging solution
    // private static Logger logger = Logger.getLogger(${className}DaoImpl.class);

    private static final String QUERY_ALL_COLUMNS =
            "SELECT <%= lower(col(1).db_column_name) %>\n" +
            <% c := col.last+2; for i in 2 .. col.last loop %>
            "     <%sep(c-i,',');%> <%= lower(col(i).db_column_name)%>\n" +
            <% end loop; %>
            "FROM ${table_name}";

    private static final String WHERE_FOR_PKS =
             " WHERE <%= lower(pk(1).db_column_name) %> = ? \n" +
             <% for i in 2 .. pk.last loop %>
             "  AND <%= lower(col(i).db_column_name)%> = ? \n" +
             <% end loop; %>
             " ";    

    private JdbcTemplate jdbcTemplate;

    @Autowired
    public void setDataSource(DataSource dataSource) {
        this.jdbcTemplate = new JdbcTemplate(dataSource);
    }

    private class ItemMapper implements RowMapper<${className}> {
        public ${className} mapRow(ResultSet rs, int rowNum) throws SQLException {

            ${className} item =new ${className}();
            <% for i in 1 .. col.last loop %>
            item.set<%=uf(col(i).COLUMN_NAME) %>( rs.get<%=col(i).data_type%>(<%= i %>));
            <% end loop; %>
            
            return item;
        }
    }

    @Override
    public List<${className}> findAll() {
        return jdbcTemplate.query(QUERY_ALL_COLUMNS, new ItemMapper());
    }

    @Override
	public ${className} find(<% c := pk.last+1; for i in 1 .. pk.last loop %>
<%=  pk(i).data_type%> <%=pk(i).COLUMN_NAME %><%sep(c-i,',');%> <% end loop; %>) {                   
        return jdbcTemplate.queryForObject(QUERY_ALL_COLUMNS + WHERE_FOR_PKS, new Object[]{<% c := pk.last+1; for i in 1 .. pk.last loop %> <%= pk(i).COLUMN_NAME %><% sep(c-i,','); end loop;%>}, new ItemMapper());        
    }

    @Override
    public ${className} find(${className} item) {                
        return jdbcTemplate.queryForObject(QUERY_ALL_COLUMNS + WHERE_FOR_PKS, new Object[]{
                <% c := pk.last+1; for i in 1 .. pk.last loop %>        
                item.get<%=uf(pk(i).COLUMN_NAME) %>()<%sep(c-i,',');%>\\n
                <% end loop; %>
        }, new ItemMapper());
    }

    @Override
    public long count() {
        return jdbcTemplate.queryForObject("select count(*) from ${table_name}", long.class);
    }

    @Override
    public void create(${className} item) {

        String sqlInsert = "INSERT INTO ${table_name} \n" +
                " ( \n" +
                <% for i in 1 .. col.last loop %>
                "     <%sep(i,',');%> <%= lower(col(i).db_column_name)%> \n" +
                <% end loop; %>
                " )" +
                " VALUES (<% c := col.last+1; for i in 1 .. col.last loop %> ?<%sep(c-i,',');%><% end loop; %> )";

        jdbcTemplate.update(sqlInsert
                <% c := col.last+2; for i in 1 .. col.last loop %>        
                <%sep(c-i,',');%> item.get<%=uf(col(i).COLUMN_NAME) %>()
                <% end loop; %>
        );
    }

    @Override
    public void update(${className} item) {
    
       String sqlUpdate = "UPDATE ${table_name} \n" +
                " SET \n" +
                <% for i in 1 .. col.last loop %>
                "     <%sep(i,',');%> <%= lower(col(i).db_column_name)%> = ? \n" +
                <% end loop; %>
                WHERE_FOR_PKS;

        jdbcTemplate.update(sqlUpdate
                <% for i in 1 .. col.last loop %>        
                , item.get<%=uf(col(i).COLUMN_NAME) %>()
                <% end loop; %><% for i in 1 .. pk.last loop %>
                , item.get<%=uf(pk(i).COLUMN_NAME) %>()
                <% end loop; %>                
        );
    }

    @Override
    public void delete(${className} item) {
        jdbcTemplate.update("DELETE FROM ${table_name} " + WHERE_FOR_PKS,
                <% c := pk.last+1; for i in 1 .. pk.last loop %>        
                item.get<%=uf(pk(i).COLUMN_NAME) %>()<%sep(c-i,',');%>\\n
                <% end loop; %>
        );
    }
}
$end


END javaPojoGen;
