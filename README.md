# ddbcli

ddbcli is an interactive command-line client of Amazon DynamoDB.

[![Gem Version](https://badge.fury.io/rb/ddbcli.svg)](http://badge.fury.io/rb/ddbcli)
[![Build Status](https://travis-ci.org/winebarrel/ddbcli.svg?branch=master)](https://travis-ci.org/winebarrel/ddbcli)

## Installation

    $ gem install ddbcli

If you are not using RubyGems, you can use the script file that depend on only Ruby.

see https://github.com/winebarrel/ddbcli/releases

```sh
https://github.com/winebarrel/ddbcli/releases/download/x.x.x/ddbcli-x.x.x.gz
gunzip -c ddbcli-0.x.x.gz > ddbcli
chmod 755 ddbcli
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

![ddbcli demo](https://raw.githubusercontent.com/winebarrel/ddbcli/master/etc/ddbcli-demo.gif)

## Use Global Secondary Indexes

* [https://gist.github.com/winebarrel/7938971](https://gist.github.com/winebarrel/7938971)

## Use QueryFilter

* [https://gist.github.com/winebarrel/cdfc59ff6188b1e49027](https://gist.github.com/winebarrel/cdfc59ff6188b1e49027)

## Enable ctrl-r (reverse-search-history) on OS X

    $ echo 'bind "^R" em-inc-search-prev' >> ~/.editrc

## Help

```sql
##### Query #####

SHOW TABLES [LIMIT num] [LIKE '...']
  display a table list

SHOW TABLE STATUS [LIKE '...']
  display table statues

SHOW REGIONS
  display a region list

SHOW CREATE TABLE table_name
  display a CREATE TABLE statement

CREATE TABLE table_name (
     key_name {STRING|NUMBER|BINARY} HASH
  [, key_name {STRING|NUMBER|BINARY} RANGE]
  [, INDEX index1_name (attr1 {STRING|NUMBER|BINARY}) {ALL|KEYS_ONLY|INCLUDE (attr, ...)}
   , INDEX index2_name (attr2 {STRING|NUMBER|BINARY}) {ALL|KEYS_ONLY|INCLUDE (attr, ...)}
   , ...]
  [, GLOBAL INDEX index1_name (hash_attr1 {STRING|NUMBER|BINARY} [, range_attr1 {STRING|NUMBER|BINARY}]) {ALL|KEYS_ONLY|INCLUDE (attr, ...)} [READ = num WRITE = num]
   , GLOBAL INDEX index2_name (hash_attr2 {STRING|NUMBER|BINARY} [, range_attr2 {STRING|NUMBER|BINARY}]) {ALL|KEYS_ONLY|INCLUDE (attr, ...)} [READ = num WRITE = num]
   , ...]
) READ = num WRITE = num [STREAM = {true|false|NEW_IMAGE|OLD_IMAGE|NEW_AND_OLD_IMAGES|KEYS_ONLY}]
  create a table

CREATE TABLE table_name LIKE another_table_name [READ = num WRITE = num] [STREAM = {true|false|NEW_IMAGE|OLD_IMAGE|NEW_AND_OLD_IMAGES|KEYS_ONLY}]
  create a table like another table

DROP TABLE table_name [, table_name2, ...]
  delete tables

ALTER TABLE table_name {READ = num WRITE = num|STREAM = {true|false|NEW_IMAGE|OLD_IMAGE|NEW_AND_OLD_IMAGES|KEYS_ONLY}}
  update the provisioned throughput

ALTER TABLE table_name CHANGE GLOBAL INDEX index_name READ = num WRITE = num
  update GSI provisioned throughput

ALTER TABLE table_name ADD GLOBAL INDEX index_name (hash_attr1 {STRING|NUMBER|BINARY} [, range_attr1 {STRING|NUMBER|BINARY}]) {ALL|KEYS_ONLY|INCLUDE (attr, ...)} READ = num WRITE = num
  add GSI

ALTER TABLE table_name DROP GLOBAL INDEX index_name
  delete GSI

GET {*|attr1,attr2,...} FROM table_name WHERE key1 = '...' AND ...
  get items

INSERT INTO table_name (attr1, attr2, ...) VALUES ('val1', 'val2', ...), ('val3', 'val4', ...), ...
INSERT INTO table_name SELECT ...
INSERT INTO table_name SELECT ALL ...
  create items

UPDATE table_name {SET|ADD} attr1 = 'val1', ... WHERE key1 = '...' AND ...
UPDATE ALL table_name {SET|ADD} attr1 = 'val1', ... [WHERE attr1 = '...' AND ...] [LIMIT limit]
  update items
  ("UPDATE" can update only one record. Please use "UPDATE ALL", when you update more than one.)

UPDATE table_name DEL[ETE] attr1, ... WHERE key1 = '...' AND ...
UPDATE ALL table_name DEL[ETE] attr1, ... [WHERE attr1 = '...' AND ...] [LIMIT limit]
  update items (delete attribute)

DELETE FROM table_name WHERE key1 = '...' AND ..
DELETE ALL FROM table_name WHERE [WHERE attr1 = '...' AND ...] [ORDER {ASC|DESC}] [LIMIT limit]
  delete items
  ("DELETE" can delete only one record. Please use "DELETE ALL", when you update more than one.)

SELECT {*|attr1,attr2,...|COUNT(*)} FROM table_name [USE INDEX (index_name)] [WHERE key1 = '...' AND ...] [HAVING attr1 = '...' AND ...] [ORDER {ASC|DESC}] [LIMIT limit]
SELECT ALL {*|attr1,attr2,...|COUNT(*)} FROM table_name [USE INDEX (index_name)] [WHERE attr1 = '...' AND ...] [LIMIT limit]
SELECT segment/total_segments {*|attr1,attr2,...|COUNT(*)} FROM table_name [USE INDEX (index_name)] [WHERE attr1 = '...' AND ...] [LIMIT limit]
  query using the Query/Scan action
  see http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/QueryAndScan.html

DESC[RIBE] table_name
  display information about the table

USE region_or_endpoint
  change an endpoint

NEXT
  display a continuation of a result
  (NEXT statement is published after SELECT statement)


##### Type #####

String
  'London Bridge is...',  "is falling down..." ...

Number
  10, 100, 0.3 ...

Binary
  x'123456789abcd...', x"123456789abcd..." ...

Identifier
  `ABCD...` or Non-keywords

Set
  ('String', 'String', ...), (1, 2, 3, ...)

List
  ['String', (1, 2, 3), {foo: 'FOO', bar: 'BAR'}, ...]

Map
  {key1:'String', "key2":(1, 2, 3), key3: ['FOO', 'BAR'], ...}

Bool
  true, false

Null
  null


##### Operator #####

Query (SELECT)
  = | <= | < | >= | > | BEGINS_WITH | BETWEEN
  see http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Query.html#DDB-Query-request-KeyConditions

Scan (SELECT ALL), QueryFilter (HAVING)
  = | <> | != | <= | < | >= | > | IS NOT NULL | IS NULL | CONTAINS | NOT CONTAINS | BEGINS_WITH | IN | BETWEEN
  see http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Scan.html#DDB-Scan-request-ScanFilter,
      http://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_Query.html#DDB-Query-request-QueryFilter


##### Pass to Ruby/Shell #####

Ryby
  query | ruby_script

  ex) SELECT ALL * FROM employees WHERE gender = 'M' | map {|i| Time.parse(i["birth_date"]) };
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

.help                           display this message
.quit | .exit                   exit ddbcli
.consistent      (true|false)?  display ConsistentRead parameter or changes it
.iteratable      (true|false)?  display iteratable option or changes it
                                all results are displayed if true
.debug           (true|false)?  display a debug status or changes it
.retry           NUM?           display number of times of a retry or changes it
.retry_interval  SECOND?        display a retry interval second or changes it
.timeout         SECOND?        display a timeout second or changes it
.version                        display a version
```

# Test

```sh
# see https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html
java -Djava.library.path=./DynamoDBLocal_lib -jar DynamoDBLocal.jar &
bundle install
bundle exec rake
```
