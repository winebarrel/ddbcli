# ddbcli

ddbcli is an interactive command-line client of Amazon DynamoDB.

[![Gem Version](https://badge.fury.io/rb/ddbcli.png)](http://badge.fury.io/rb/ddbcli)
[![Build Status](https://drone.io/bitbucket.org/winebarrel/ddbcli/status.png)](https://drone.io/bitbucket.org/winebarrel/ddbcli/latest)

## Installation

    $ gem install ddbcli

If you are not using RubyGems, you can use the script files that depend on only Ruby.

[ddbcli-0.3.5](https://bitbucket.org/winebarrel/ddbcli/downloads/ddbcli-0.3.5)

```sh
wget https://bitbucket.org/winebarrel/ddbcli/downloads/ddbcli-0.3.5
mv ddbcli-0.3.5 ddbcli
chmod 755 ddbcli
./ddbcli # show prompt
```

## Usage

```sh
export AWS_ACCESS_KEY_ID='...'
export AWS_SECRET_ACCESS_KEY='...'
export AWS_REGION=ap-northeast-1

ddbcli -e 'show tables'
#  [
#    "employees"
#  ]

ddbcli # show prompt
```

### Use DynamoDB Local

    $ ddbcli --url localhost:8000

## Demo

![ddbcli demo](https://bitbucket.org/winebarrel/ddbcli/downloads/ddbcli-demo.gif)

## GROUP BY (Aggregate)

```
ap-northeast-1> select all gender from employees
             -> where birth_date begins_with '1960'
             -> | group_by(:gender) {|i| puts "DEBUG: 'i' contains: #{i[0, 3].inspect} ..."\; i.length };
DEBUG: 'i' contains: [{"gender"=>"M"}, {"gender"=>"M"}, {"gender"=>"M"}] ...
DEBUG: 'i' contains: [{"gender"=>"F"}, {"gender"=>"F"}, {"gender"=>"F"}] ...
{
  "M": 546,
  "F": 355
}
// 2 rows in set (0.20 sec)
```

## Use Global Secondary Indexes

* [https://gist.github.com/winebarrel/7938971](https://gist.github.com/winebarrel/7938971)

## Enable ctrl-r (reverse-search-history) on OS X

    $ echo 'bind "^R" em-inc-search-prev' >> ~/.editrc

## Help

```
##### Query #####

SHOW TABLES [LIMIT num] [LIKE '...']
  displays a table list

SHOW TABLE STATUS [LIKE '...']
  displays table statues

SHOW REGIONS
  displays a region list

SHOW CREATE TABLE table_name
  displays a CREATE TABLE statement

CREATE TABLE table_name (
     key_name {STRING|NUMBER|BINARY} HASH
  [, key_name {STRING|NUMBER|BINARY} RANGE]
  [, INDEX index1_name (attr1 {STRING|NUMBER|BINARY}) {ALL|KEYS_ONLY|INCLUDE (attr, ...)}
   , INDEX index2_name (attr2 {STRING|NUMBER|BINARY}) {ALL|KEYS_ONLY|INCLUDE (attr, ...)}
   , ...]
  [, GLOBAL INDEX index1_name (hash_attr1 {STRING|NUMBER|BINARY} [, range_attr1 {STRING|NUMBER|BINARY}]) {ALL|KEYS_ONLY|INCLUDE (attr, ...)} [READ = num WRITE = num]
   , GLOBAL INDEX index2_name (hash_attr2 {STRING|NUMBER|BINARY} [, range_attr2 {STRING|NUMBER|BINARY}]) {ALL|KEYS_ONLY|INCLUDE (attr, ...)} [READ = num WRITE = num]
   , ...]
) READ = num WRITE = num
  creates a table

CREATE TABLE table_name LIKE another_table_name [READ = num WRITE = num]
  creates a table like another table

DROP TABLE table_name [, table_name2, ...]
  deletes tables

ALTER TABLE table_name READ = num WRITE = num
  updates the provisioned throughput

GET {*|attr1,attr2,...} FROM table_name WHERE key1 = '...' AND ...
  gets items

INSERT INTO table_name (attr1, attr2, ...) VALUES ('val1', 'val2', ...), ('val3', 'val4', ...), ...
INSERT INTO table_name SELECT ...
INSERT INTO table_name SELECT ALL ...
  creates items

UPDATE table_name {SET|ADD} attr1 = 'val1', ... WHERE key1 = '...' AND ...
UPDATE ALL table_name {SET|ADD} attr1 = 'val1', ... [WHERE attr1 = '...' AND ...] [LIMIT limit]
  updates items
  ("UPDATE" can update only one record. Please use "UPDATE ALL", when you update more than one.)

DELETE FROM table_name WHERE key1 = '...' AND ..
DELETE ALL FROM table_name WHERE [WHERE attr1 = '...' AND ...] [ORDER {ASC|DESC}] [LIMIT limit]
  deletes items
  ("DELETE" can delete only one record. Please use "DELETE ALL", when you update more than one.)

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

Array
  ('String', 'String', ...), (1, 2, 3, ...)


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


##### Output to a file #####

Overwrite
  SELECT ALL * FROM employees > 'foo.json';

Append
  SELECT ALL * FROM employees >> 'foo.json';


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
```
