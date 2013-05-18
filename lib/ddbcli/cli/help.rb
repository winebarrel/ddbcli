require 'tempfile'

def print_help
  doc =<<EOS
##### Query #####

SHOW TABLES
  displays a table list

SHOW TABLE STATUS
  displays table statues

SHOW REGIONS
  displays a region list

SHOW CREATE TABLE table_name
  displays a CREATE TABLE statement

CREATE TABLES table_name (
     key_name {STRING|NUMBER|BINARY} HASH
  [, key_name {STRING|NUMBER|BINARY} RANGE]
  [, INDEX index1_name (attr1 {STRING|NUMBER|BINARY}) {ALL|KEYS_ONLY|INCLUDE (attr, ...)}
   , INDEX index2_name (attr2 {STRING|NUMBER|BINARY}) {ALL|KEYS_ONLY|INCLUDE (attr, ...)}
   , ...]
) READ = num, WRITE = num
  creates a table

CREATE TABLES table_name LIKE another_table_name [READ = num, WRITE = num]
  creates a table like another table

DROP TABLE table_name
  deletes a table

ALTER TABLE table_name READ = num, WRITE = num
  updates the provisioned throughput

GET {*|attrs} FROM table_name WHERE key1 = '...' AND ...
  gets items

INSERT INTO table_name (attr1, attr2, ...) VALUES ('val1', 'val2', ...), ('val3', 'val4', ...), ...
INSERT INTO table_name SELECT ...
INSERT INTO table_name SELECT ALL ...
  creates items

UPDATE table_name {SET|ADD} attr1 = 'val1', ... WHERE key1 = '...' AND ...
UPDATE ALL table_name {SET|ADD} attr1 = 'val1', ... [WHERE attr1 = '...' AND ...] [LIMIT limit]
  updates items

DELETE FROM table_name WHERE key1 = '...' AND ..
DELETE ALL FROM table_name WHERE [WHERE attr1 = '...' AND ...] [ORDER {ASC|DESC}] [LIMIT limit]
  deletes items

SELECT {*|attr1,attr2,...|COUNT(*)} FROM table_name [USE INDEX (index_name)] [WHERE key1 = '...' AND ...] [ORDER {ASC|DESC}] [LIMIT limit]
SELECT ALL {*|attr1,attr2,...|COUNT(*)} FROM table_name [WHERE attr1 = '...' AND ...] [LIMIT limit]
SELECT segment/total_segments {*|attr1,attr2,...|COUNT(*)} FROM table_name [WHERE attr1 = '...' AND ...] [LIMIT limit]
  queries using the Query/Scan action
  see http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/QueryAndScan.html

DESC[RIBE] table_name
  displays information about the table

USE region_or_endpoint
  changes an endpoint

NEXT
  displays a continuation of a result
  (NEXT statement is published after SELECT statement)


##### Type #####

String
  'London Bridge is...',  "is broken down..." ...

Number
  10, 100, 0.3 ...

Binary
  x'123456789abcd...', x"123456789abcd..." ...

Identifier
  `ABCD...` or Non-keywords


##### Operator #####

Query (SELECT)
  = | <= | < | >= | > | BEGINS_WITH | BETWEEN
  see http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Query.html#DDB-Query-request-KeyConditions

Scan (SELECT ALL)
  = | <> | != | <= | < | >= | > | IS NOT NULL | IS NULL | CONTAINS | NOT CONTAINS | BEGINS_WITH | IN | BETWEEN
  see http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Scan.html#DDB-Scan-request-ScanFilter


##### Pass to Ruby/Shell #####

Ryby
  query | ruby_script

  ex) SELECT ALL * FROM employees WHERE gender = 'M' | birth_date.map {|i| Time.parse(i) };
      [
        "1957-09-16 00:00:00 +0900",
        "1954-12-16 00:00:00 +0900",
        "1964-05-23 00:00:00 +0900",
        ...

Shell
  query ! shell_command

  ex) SELECT ALL * FROM employees LIMIT 10 ! sort;
      {"birth_date"=>"1957-09-16", "emp_no"=>452020,...
      {"birth_date"=>"1963-07-14", "emp_no"=>16998, ...
      {"birth_date"=>"1964-04-30", "emp_no"=>225407,...
      ...


##### Command #####

.help                           displays this message
.quit | .exit                   exits ddbcli
.consistent      (true|false)?  displays ConsistentRead parameter or changes it
.iteratable      (true|false)?  displays iteratable option or changes it
                                all results are displayed if true
.debug           (true|false)?  displays a debug status or changes it
.retry           NUM?           displays number of times of a retry or changes it
.retry_interval  SECOND?        displays a retry interval second or changes it
.timeout         SECOND?        displays a timeout second or changes it
.version                        displays a version

EOS

  Tempfile.open("ddbcli.#{$$}.#{Time.now.to_i}") do |f|
    f.puts(doc)
    f.flush

    unless system("less #{f.path}")
      puts doc
    end
  end
end
