class Parser
options no_result_var
rule
  stmt : query
         {
           [val[0], nil, nil]
         }
       | query RUBY_SCRIPT
         {
           [val[0], :ruby, val[1]]
         }
       | query SHELL_SCRIPT
         {
           [val[0], :shell, val[1]]
         }
       | query GT STRING_VALUE
         {
           [val[0], :overwrite, val[2]]
         }
       | query GTGT STRING_VALUE
         {
           [val[0], :append, val[2]]
         }
       | RUBY_SCRIPT
         {
           [struct(:NULL), :ruby, val[0]]
         }
       | SHELL_SCRIPT
         {
           [struct(:NULL), :shell, val[0]]
         }

  query : show_stmt
        | alter_stmt
        | use_stmt
        | create_stmt
        | drop_stmt
        | describe_stmt
        | select_stmt
        | scan_stmt
        | get_stmt
        | update_stmt
        | delete_stmt
        | insert_stmt
        | next_stmt

  show_stmt : SHOW TABLES limit_clause like_clause
              {
                struct(:SHOW_TABLES, :limit => val[2], :like => val[3])
              }
            | SHOW TABLE STATUS like_clause
              {
                struct(:SHOW_TABLE_STATUS, :like => val[3])
              }
            | SHOW REGIONS
              {
                struct(:SHOW_REGIONS)
              }
            | SHOW CREATE TABLE IDENTIFIER
              {
                struct(:SHOW_CREATE_TABLE, :table => val[3])
              }

  like_clause :
              | LIKE STRING_VALUE
                {
                  val[1]
                }

  alter_stmt : ALTER TABLE IDENTIFIER capacity_clause
               {
                 struct(:ALTER_TABLE, :table => val[2], :index_name => nil, :capacity => val[3], :stream => nil)
               }
             | ALTER TABLE IDENTIFIER stream_clause
               {
                 struct(:ALTER_TABLE, :table => val[2], :index_name => nil, :capacity => nil, :stream => val[3])
               }
             | ALTER TABLE IDENTIFIER capacity_clause stream_clause
               {
                 struct(:ALTER_TABLE, :table => val[2], :index_name => nil, :capacity => val[3], :stream => val[4])
               }
             | ALTER TABLE IDENTIFIER stream_clause capacity_clause
               {
                 struct(:ALTER_TABLE, :table => val[2], :index_name => nil, :capacity => val[4], :stream => val[3])
               }
             | ALTER TABLE IDENTIFIER CHANGE INDEX IDENTIFIER capacity_clause
               {
                 struct(:ALTER_TABLE, :table => val[2], :index_name => val[5], :capacity => val[6])
               }

  use_stmt : USE IDENTIFIER
             {
               struct(:USE, :endpoint_or_region => val[1])
             }

            | USE STRING
             {
               struct(:USE, :endpoint_or_region => val[1])
             }

  create_stmt : CREATE TABLE IDENTIFIER '(' create_definition ')' capacity_stream_clause
                {
                  struct(:CREATE, val[4].merge(:table => val[2], :capacity => val[6][:capacity], :stream => val[6][:stream]))
                }
              | CREATE TABLE IDENTIFIER LIKE IDENTIFIER
                {
                  struct(:CREATE_LIKE, :table => val[2], :like => val[4], :capacity => nil, :stream => nil)
                }
              | CREATE TABLE IDENTIFIER LIKE IDENTIFIER stream_clause
                {
                  struct(:CREATE_LIKE, :table => val[2], :like => val[4], :capacity => nil, :stream => val[5])
                }
              | CREATE TABLE IDENTIFIER LIKE IDENTIFIER capacity_stream_clause
                {
                  struct(:CREATE_LIKE, :table => val[2], :like => val[4], :capacity => val[5][:capacity], :stream => val[5][:stream])
                }

  capacity_stream_clause : capacity_clause
                           {
                            {:capacity => val[0], :stream => nil}
                           }
                         | capacity_clause stream_clause
                           {
                            {:capacity => val[0], :stream => val[1]}
                           }
                         | stream_clause capacity_clause
                           {
                            {:capacity => val[1], :stream => val[0]}
                           }

  stream_clause : STREAM EQ BOOL
                  {
                    val[2]
                  }
                | STREAM EQ stream_view_type
                  {
                    val[2]
                  }

  stream_view_type : NEW_IMAGE
                   | OLD_IMAGE
                   | NEW_AND_OLD_IMAGES
                   | KEYS_ONLY

  create_definition : IDENTIFIER attr_type_list HASH
                      {
                        {:hash => {:name => val[0], :type => val[1]}, :range => nil, :indices => nil}
                      }
                    | IDENTIFIER attr_type_list HASH ',' index_definition_list
                      {
                        {:hash => {:name => val[0], :type => val[1]}, :range => nil, :indices => val[4]}
                      }
                    | IDENTIFIER attr_type_list HASH ',' IDENTIFIER attr_type_list RANGE
                      {
                        {:hash => {:name => val[0], :type => val[1]}, :range => {:name => val[4], :type => val[5]}, :indices => nil}
                      }
                    | IDENTIFIER attr_type_list HASH ',' IDENTIFIER attr_type_list RANGE ',' index_definition_list
                      {
                        {:hash => {:name => val[0], :type => val[1]}, :range => {:name => val[4], :type => val[5]}, :indices => val[8]}
                      }

  attr_type_list : STRING
                   {
                     'S'
                   }
                 | NUMBER
                   {
                     'N'
                   }
                 | BINARY
                   {
                     'B'
                   }

  capacity_clause : READ EQ NUMBER_VALUE ',' WRITE EQ NUMBER_VALUE
                    {
                      {:read => val[2], :write => val[6]}
                    }
                  | WRITE EQ NUMBER_VALUE ',' READ EQ NUMBER_VALUE
                    {
                      {:read => val[6], :write => val[2]}
                    }
                  | strict_capacity_clause

  strict_capacity_clause : READ EQ NUMBER_VALUE WRITE EQ NUMBER_VALUE
                           {
                             {:read => val[2], :write => val[5]}
                           }
                         | WRITE EQ NUMBER_VALUE READ EQ NUMBER_VALUE
                           {
                             {:read => val[5], :write => val[2]}
                           }

  index_definition_list : index_definition
                          {
                            [val[0]]
                          }
                        | index_definition_list ',' index_definition
                          {
                            val[0] + [val[2]]
                          }

  index_definition : INDEX IDENTIFIER '(' IDENTIFIER attr_type_list ')' index_type_definition
                     {
                       {:name => val[1], :key => val[3], :type => val[4], :projection => val[6]}
                     }
                   | GLOBAL INDEX IDENTIFIER '(' global_index_keys ')' index_type_definition
                     {
                       {:name => val[2], :keys => val[4], :projection => val[6], :global => true}
                     }
                   | GLOBAL INDEX IDENTIFIER '(' global_index_keys ')' index_type_definition strict_capacity_clause
                     {
                       {:name => val[2], :keys => val[4], :projection => val[6], :capacity => val[7], :global => true}
                     }

  global_index_keys : IDENTIFIER attr_type_list
                      {
                        {:hash => {:key => val[0], :type => val[1]}}
                      }
                    | IDENTIFIER attr_type_list ',' IDENTIFIER attr_type_list
                      {
                        {
                          :hash => {:key => val[0], :type => val[1]},
                          :range => {:key => val[3], :type => val[4]},
                        }
                      }

  index_type_definition : ALL
                          {
                            {:type => 'ALL'}
                          }
                        | KEYS_ONLY
                          {
                            {:type => 'KEYS_ONLY'}
                          }
                        | INCLUDE '(' index_include_attr_list ')'
                          {
                            {:type => 'INCLUDE', :attrs => val[2]}
                          }

  index_include_attr_list : IDENTIFIER
                             {
                               [val[0]]
                             }
                           | index_include_attr_list ',' IDENTIFIER
                             {
                               val[0] + [val[2]]
                             }

  drop_stmt : DROP TABLE identifier_list
              {
                struct(:DROP, :tables => val[2])
              }

  describe_stmt : DESCRIBE IDENTIFIER
                  {
                    struct(:DESCRIBE, :table => val[1])
                  }
                | DESC IDENTIFIER
                  {
                    struct(:DESCRIBE, :table => val[1])
                  }

  select_stmt : SELECT attrs_to_get FROM IDENTIFIER use_index_clause select_where_clause having_clause order_clause limit_clause
                {
                  struct(:SELECT, :attrs => val[1], :table => val[3], :index => val[4], :conds => val[5], :having => val[6], :order_asc => val[7], :limit => val[8], :count => false)
                }
              | SELECT COUNT '(' '*' ')' FROM IDENTIFIER use_index_clause select_where_clause having_clause order_clause limit_clause
                {
                  struct(:SELECT, :attrs => [], :table => val[6], :index => val[7], :conds => val[8], :having => val[9], :order_asc => val[10], :limit => val[11], :count => true)
                }

  scan_stmt : SELECT ALL attrs_to_get FROM IDENTIFIER scan_where_clause limit_clause
              {
                struct(:SCAN, :attrs => val[2], :table => val[4], :conds => val[5], :limit => val[6], :count => false, :segment => nil, :total_segments => nil)
              }
            | SELECT ALL COUNT '(' '*' ')' FROM IDENTIFIER scan_where_clause limit_clause
              {
                struct(:SCAN, :attrs => [], :table => val[7], :conds => val[8], :limit => val[9], :count => true, :segment => nil, :total_segments => nil)
              }
            | SELECT NUMBER_VALUE '/' NUMBER_VALUE attrs_to_get FROM IDENTIFIER scan_where_clause limit_clause
              {
                struct(:SCAN, :attrs => val[4], :table => val[6], :conds => val[7], :limit => val[8], :count => false, :segment => val[1], :total_segments => val[3])
              }

  get_stmt : GET attrs_to_get FROM IDENTIFIER update_where_clause
             {
               struct(:GET, :attrs => val[1], :table => val[3], :conds => val[4])
             }

  attrs_to_get: '*'
                {
                  []
                }
              | attrs_list
                {
                  val[0]
                }

  attrs_list : IDENTIFIER
               {
                 [val[0]]
               }
             | attrs_list ',' IDENTIFIER
               {
                 val[0] + [val[2]]
               }

  use_index_clause :
                   | USE INDEX '(' IDENTIFIER ')'
                     {
                       val[3]
                     }

  select_where_clause :
                      | WHERE select_expr_list
                        {
                          val[1]
                        }

  select_expr_list : select_expr
                     {
                       [val[0]]
                     }
                     | select_expr_list AND select_expr
                       {
                         val[0] + [val[2]]
                       }

  select_expr : IDENTIFIER select_operator value
                {
                  [val[0], val[1].to_s.upcase.to_sym, [val[2]]]
                }
              | IDENTIFIER BETWEEN value AND value
                {
                  [val[0], val[1].to_s.upcase.to_sym, [val[2], val[4]]]
                }

  select_operator : common_operator

  common_operator : EQ
                    {
                      :EQ
                    }
                  | LE
                    {
                      :LE
                    }
                  | LT
                    {
                      :LT
                    }
                  | GE
                    {
                      :GE
                    }
                  | GT
                    {
                      :GT
                    }
                  | BEGINS_WITH

  scan_where_clause :
                    | WHERE scan_expr_list
                      {
                        val[1]
                      }

  scan_expr_list : scan_expr
                   {
                     [val[0]]
                   }
                 | scan_expr_list AND scan_expr
                   {
                     val[0] + [val[2]]
                   }

  scan_expr : IDENTIFIER scan_operator value
              {
                [val[0], val[1].to_s.upcase.to_sym, [val[2]]]
              }
            | IDENTIFIER IN value_list
              {
                [val[0], val[1].to_s.upcase.to_sym, val[2]]
              }
            | IDENTIFIER BETWEEN value AND value
              {
                [val[0], val[1].to_s.upcase.to_sym, [val[2], val[4]]]
              }
            | IDENTIFIER IS null_operator
              {
                [val[0], val[2].to_s.upcase.to_sym, []]
              }

  scan_operator : common_operator | contains_operator
                | NE
                {
                  :NE
                }

  contains_operator : CONTAINS
                    | NOT CONTAINS
                      {
                        :NOT_CONTAINS
                      }
  null_operator : NULL
                  {
                    :NULL
                  }
                | NOT NULL
                  {
                    :NOT_NULL
                  }

  order_clause :
               | ORDER ASC
                 {
                   true
                 }
               | ORDER DESC
                 {
                   false
                 }

  limit_clause :
               | LIMIT NUMBER_VALUE
                 {
                   val[1]
                 }

  having_clause :
               | HAVING scan_expr_list
                 {
                   val[1]
                 }

  update_stmt : UPDATE IDENTIFIER set_or_add attr_to_update_list update_where_clause
                {
                  struct(:UPDATE, :table => val[1], :action => val[2], :attrs => val[3], :conds => val[4])
                }
              | UPDATE ALL IDENTIFIER set_or_add attr_to_update_list scan_where_clause limit_clause
                {
                  struct(:UPDATE_ALL, :table => val[2], :action => val[3], :attrs => val[4], :conds => val[5], :limit => val[6])
                }
              | UPDATE IDENTIFIER delete_or_del identifier_list update_where_clause
                {
                  attrs = {}
                  val[3].each {|i| attrs[i] = true }
                  struct(:UPDATE, :table => val[1], :action => val[2], :attrs => attrs, :conds => val[4])
                }
              | UPDATE ALL IDENTIFIER delete_or_del identifier_list scan_where_clause limit_clause
                {
                  attrs = {}
                  val[4].each {|i| attrs[i] = true }
                  struct(:UPDATE_ALL, :table => val[2], :action => val[3], :attrs => attrs, :conds => val[5], :limit => val[6])
                }

  set_or_add : SET
               {
                 :PUT
               }
             | ADD
               {
                 :ADD
               }

  delete_or_del : DELETE
                  {
                    :DELETE
                  }
                | DEL
                  {
                    :DELETE
                  }

  attr_to_update_list : attr_to_update
                        {
                          [val[0]]
                        }
                      | attr_to_update_list ',' attr_to_update
                        {
                          val[0] + [val[2]]
                        }

  attr_to_update : IDENTIFIER EQ value
                   {
                     [val[0], val[2]]
                   }

  update_where_clause : WHERE update_expr_list
                        {
                          val[1]
                        }

  update_expr_list : update_expr
                     {
                       [val[0]]
                     }
                   | update_expr_list AND update_expr
                     {
                       val[0] + [val[2]]
                     }

  update_expr : IDENTIFIER EQ value
                {
                  [val[0], val[2]]
                }

  delete_stmt : DELETE FROM IDENTIFIER update_where_clause
                {
                  struct(:DELETE, :table => val[2], :conds => val[3])
                }
              | DELETE ALL FROM IDENTIFIER scan_where_clause limit_clause
                {
                  struct(:DELETE_ALL, :table => val[3], :conds => val[4], :limit => val[5])
                }

  insert_stmt : INSERT INTO IDENTIFIER '(' attr_to_insert_list ')' VALUES insert_value_clause
                {
                  struct(:INSERT, :table => val[2], :attrs => val[4], :values => val[7])
                }
              | INSERT INTO IDENTIFIER select_stmt
                {
                  struct(:INSERT_SELECT, :table => val[2], :select => val[3])
                }
              | INSERT INTO IDENTIFIER scan_stmt
                {
                  struct(:INSERT_SCAN, :table => val[2], :select => val[3])
                }

  attr_to_insert_list : identifier_list

  insert_value_clause : '(' insert_value_list ')'
                        {
                          [val[1]]
                        }
                      | insert_value_clause ',' '(' insert_value_list ')'
                        {
                          val[0] + [val[3]]
                        }

  insert_value_list : value
                      {
                        [val[0]]
                      }
                    | insert_value_list ',' value
                      {
                        val[0] + [val[2]]
                      }

  next_stmt : NEXT
              {
                struct(:NEXT)
              }

  value : single_value
        | value_list
        | list
        | map
        | BOOL
        | NULL

  list : '[' ']'
       | '[' list_items ']'
         {
           val[1]
         }

  list_items : value
               {
                 [val[0]]
               }
             | list_items ',' value
               {
                 val[0] + [val[2]]
               }

  map : '{' '}'
        {
          {}
        }
      | '{' map_items '}'
        {
          val[1]
        }

  map_items : map_item
            | map_items ',' map_item
              {
                val[0].merge(val[2])
              }

  map_item : IDENTIFIER ':' value
             {
               {val[0] => val[2]}
             }
           | STRING_VALUE ':' value
             {
               {val[0] => val[2]}
             }

  single_value  : NUMBER_VALUE
                | STRING_VALUE
                | BINARY_VALUE

  value_list : '(' number_list ')'
               {
                 val[1]
               }
             | '(' string_list ')'
               {
                 val[1]
               }
             | '(' binary_list ')'
               {
                 val[1]
               }

  number_list : NUMBER_VALUE
                {
                  Set[val[0]]
                }
              | number_list ',' NUMBER_VALUE
                {
                   val[0] + Set[val[2]]
                }

  string_list : STRING_VALUE
                {
                  Set[val[0]]
                }
              | string_list ',' STRING_VALUE
                {
                   val[0] + Set[val[2]]
                }

  binary_list : BINARY_VALUE
                {
                  Set[val[0]]
                }
              | binary_list ',' BINARY_VALUE
                {
                   val[0] + Set[val[2]]
                }

  identifier_list : IDENTIFIER
                    {
                      [val[0]]
                    }
                  | identifier_list ',' IDENTIFIER
                    {
                      val[0] + [val[2]]
                    }

---- header

require 'strscan'
require 'ddbcli/ddb-binary'
require 'set'

module DynamoDB

---- inner

KEYWORDS = %w(
  ADD
  ALL
  ALTER
  AND
  ASC
  BEGINS_WITH
  BETWEEN
  BINARY
  CHANGE
  CREATE
  CONTAINS
  COUNT
  DELETE
  DEL
  DESCRIBE
  DESC
  DROP
  FROM
  GET
  GLOBAL
  HASH
  HAVING
  INCLUDE
  INDEX
  INSERT
  INTO
  IN
  IS
  KEYS_ONLY
  LIKE
  LIMIT
  NEW_AND_OLD_IMAGES
  NEW_IMAGE
  NEXT
  NOT
  NUMBER
  OLD_IMAGE
  ORDER
  RANGE
  READ
  REGIONS
  SELECT
  SET
  SHOW
  STATUS
  STREAM
  STRING
  TABLES
  TABLE
  UPDATE
  VALUES
  WHERE
  WRITE
  USE
)

KEYWORD_REGEXP = Regexp.compile("(?:#{KEYWORDS.join '|'})\\b", Regexp::IGNORECASE)

def initialize(obj)
  src = obj.is_a?(IO) ? obj.read : obj.to_s
  @ss = StringScanner.new(src)
end

@@structs = {}

def struct(name, attrs = {})
  unless (clazz = @@structs[name])
    clazz = attrs.empty? ? Struct.new(name.to_s) : Struct.new(name.to_s, *attrs.keys)
    @@structs[name] = clazz
  end

  obj = clazz.new

  attrs.each do |key, val|
    obj.send("#{key}=", val)
  end

  return obj
end
private :struct

def scan
  tok = nil
  @prev_tokens = []

  until @ss.eos?
    if (tok = @ss.scan /\s+/)
      # nothing to do
    elsif (tok = @ss.scan /(?:>>|<>|!=|>=|<=|>|<|=)/)
      sym = {
        '>>' => :GTGT,
        '<>' => :NE,
        '!=' => :NE,
        '>=' => :GE,
        '<=' => :LE,
        '>'  => :GT,
        '<'  => :LT,
        '='  => :EQ,
      }.fetch(tok)
      yield [sym, tok]
    elsif (tok = @ss.check KEYWORD_REGEXP) and @ss.rest.slice(tok.length) !~ /\A\w/
      tok = @ss.scan KEYWORD_REGEXP
      yield [tok.upcase.to_sym, tok]
    elsif (tok = @ss.check /NULL/i) and @ss.rest.slice(tok.length) !~ /\A\w/
      tok = @ss.scan /NULL/i
      yield [:NULL, nil]
    elsif (tok = @ss.scan /`(?:[^`]|``)*`/)
      yield [:IDENTIFIER, tok.slice(1...-1).gsub(/``/, '`')]
    elsif (tok = @ss.scan /x'(?:[^']|'')*'/) #'
      hex = tok.slice(2...-1).gsub(/''/, "'")
      bin = DynamoDB::Binary.new([hex].pack('H*'))
      yield [:BINARY_VALUE, bin]
    elsif (tok = @ss.scan /x"(?:[^"]|"")*"/) #"
      hex = tok.slice(2...-1).gsub(/""/, '"')
      bin = DynamoDB::Binary.new([hex].pack('H*'))
      yield [:BINARY_VALUE, bin]
    elsif (tok = @ss.scan /'(?:[^']|'')*'/) #'
      yield [:STRING_VALUE, tok.slice(1...-1).gsub(/''/, "'")]
    elsif (tok = @ss.scan /"(?:[^"]|"")*"/) #"
      yield [:STRING_VALUE, tok.slice(1...-1).gsub(/""/, '"')]
    elsif (tok = @ss.scan /\d+(?:\.\d+)?/)
      yield [:NUMBER_VALUE, (tok =~ /\./ ? tok.to_f : tok.to_i)]
    elsif (tok = @ss.scan /[,\(\)\*\/\[\]\{\}:]/)
      yield [tok, tok]
    elsif (tok = @ss.scan /\|(?:.*)/)
      yield [:RUBY_SCRIPT, tok.slice(1..-1)]
    elsif (tok = @ss.scan /\|(?:.*)/)
      yield [:RUBY_SCRIPT, tok.slice(1..-1)]
    elsif (tok = @ss.scan /\!(?:.*)/)
      yield [:SHELL_SCRIPT, tok.slice(1..-1)]
    elsif (tok = @ss.scan %r|[-.0-9a-z_]*|i)
      if ['true', 'false'].include?(tok)
        yield [:BOOL, 'true' == tok]
      else
        yield [:IDENTIFIER, tok]
      end
    else
      raise_error(tok, @prev_tokens, @ss)
    end

    @prev_tokens << tok
  end

  yield [false, '']
end
private :scan

def raise_error(error_value, prev_tokens, scanner)
  errmsg = ["__#{error_value}__"]

  if prev_tokens and not prev_tokens.empty?
    toks = prev_tokens.reverse[0, 5].reverse
    toks.unshift('...') if prev_tokens.length > toks.length
    errmsg.unshift(toks.join.strip)
  end

  if scanner and not (rest = (scanner.rest || '').strip).empty?
    str = rest[0, 16]
    str += '...' if rest.length > str.length
    errmsg << str
  end

  raise Racc::ParseError, ('parse error on value: %s' % errmsg.join(' '))
end
private :raise_error

def parse
  yyparse self, :scan
end

def on_error(error_token_id, error_value, value_stack)
  raise_error(error_value, @prev_tokens, @ss)
end

def self.parse(obj)
  self.new(obj).parse
end

---- footer

end # DynamoDB
