describe 'ddbcli' do
  it 'version' do
    out = ddbcli(nil, ['-v'])
    expect(out).to match /ddbcli \d+\.\d+\.\d+/
  end

  it 'show tables' do
    ddbcli(<<-'EOS')
      CREATE TABLE `foo` (
        `id`  STRING HASH,
        `val` STRING RANGE
      ) read=2 write=2
    EOS

    out = ddbcli('show tables')
    out = JSON.parse(out)
    expect(out).to eq(['foo'])
  end

  it 'create table (hash only)' do
    ddbcli(<<-'EOS')
      CREATE TABLE `foo` (
        `id` NUMBER HASH
      ) read=2 write=2
    EOS

    out = ddbcli('desc foo')
    out = JSON.parse(out)
    out.delete('CreationDateTime')

    expect(out).to eq(
{"AttributeDefinitions"=>[{"AttributeName"=>"id", "AttributeType"=>"N"}],
 "TableName"=>"foo",
 "KeySchema"=>[{"AttributeName"=>"id", "KeyType"=>"HASH"}],
 "TableStatus"=>"ACTIVE",
 "ProvisionedThroughput"=>
  {"NumberOfDecreasesToday"=>0,
   "ReadCapacityUnits"=>2,
   "WriteCapacityUnits"=>2},
 "TableSizeBytes"=>0,
 "ItemCount"=>0}
    )
  end

  it 'create table (hash and range)' do
    ddbcli(<<-'EOS')
      CREATE TABLE `foo` (
        `id`  NUMBER HASH,
        `val` STRING RANGE
      ) read=2 write=2
    EOS

    out = ddbcli('desc foo')
    out = JSON.parse(out)
    out.delete('CreationDateTime')

    expect(out).to eq(
{"AttributeDefinitions"=>
  [{"AttributeName"=>"id", "AttributeType"=>"N"},
   {"AttributeName"=>"val", "AttributeType"=>"S"}],
 "TableName"=>"foo",
 "KeySchema"=>
  [{"AttributeName"=>"id", "KeyType"=>"HASH"},
   {"AttributeName"=>"val", "KeyType"=>"RANGE"}],
 "TableStatus"=>"ACTIVE",
 "ProvisionedThroughput"=>
  {"NumberOfDecreasesToday"=>0,
   "ReadCapacityUnits"=>2,
   "WriteCapacityUnits"=>2},
 "TableSizeBytes"=>0,
 "ItemCount"=>0}
    )
  end

  it 'create table with LSI' do
    ddbcli(<<-'EOS')
      CREATE TABLE `foo` (
        `id`  NUMBER HASH,
        `val` STRING RANGE,
        INDEX `idx_bar` (`val2` STRING) ALL
      ) read=2 write=2
    EOS

    out = ddbcli('desc foo')
    out = JSON.parse(out)
    out.delete('CreationDateTime')

    expect(out).to eq(
{"AttributeDefinitions"=>
  [{"AttributeName"=>"id", "AttributeType"=>"N"},
   {"AttributeName"=>"val", "AttributeType"=>"S"},
   {"AttributeName"=>"val2", "AttributeType"=>"S"}],
 "TableName"=>"foo",
 "KeySchema"=>
  [{"AttributeName"=>"id", "KeyType"=>"HASH"},
   {"AttributeName"=>"val", "KeyType"=>"RANGE"}],
 "TableStatus"=>"ACTIVE",
 "ProvisionedThroughput"=>
  {"NumberOfDecreasesToday"=>0,
   "ReadCapacityUnits"=>2,
   "WriteCapacityUnits"=>2},
 "TableSizeBytes"=>0,
 "ItemCount"=>0,
 "LocalSecondaryIndexes"=>
  [{"IndexName"=>"idx_bar",
    "KeySchema"=>
     [{"AttributeName"=>"id", "KeyType"=>"HASH"},
      {"AttributeName"=>"val2", "KeyType"=>"RANGE"}],
    "Projection"=>{"ProjectionType"=>"ALL"},
    "IndexSizeBytes"=>0,
    "ItemCount"=>0}]}
    )
  end

  it 'create table with GSI' do
    ddbcli(<<-'EOS')
      CREATE TABLE `foo` (
        `id`  NUMBER HASH,
        `val` STRING RANGE,
        GLOBAL INDEX `idx_bar` (`val2` STRING) ALL read=1 write=1
      ) read=2 write=2
    EOS

    out = ddbcli('desc foo')
    out = JSON.parse(out)
    out.delete('CreationDateTime')

    expect(out).to eq(
{"AttributeDefinitions"=>
  [{"AttributeName"=>"id", "AttributeType"=>"N"},
   {"AttributeName"=>"val", "AttributeType"=>"S"},
   {"AttributeName"=>"val2", "AttributeType"=>"S"}],
 "TableName"=>"foo",
 "KeySchema"=>
  [{"AttributeName"=>"id", "KeyType"=>"HASH"},
   {"AttributeName"=>"val", "KeyType"=>"RANGE"}],
 "TableStatus"=>"ACTIVE",
 "ProvisionedThroughput"=>
  {"NumberOfDecreasesToday"=>0,
   "ReadCapacityUnits"=>2,
   "WriteCapacityUnits"=>2},
 "TableSizeBytes"=>0,
 "ItemCount"=>0,
 "GlobalSecondaryIndexes"=>
  [{"IndexName"=>"idx_bar",
    "KeySchema"=>[{"AttributeName"=>"val2", "KeyType"=>"HASH"}],
    "Projection"=>{"ProjectionType"=>"ALL"},
    "IndexStatus"=>"ACTIVE",
    "ProvisionedThroughput"=>{"ReadCapacityUnits"=>1, "WriteCapacityUnits"=>1},
    "IndexSizeBytes"=>0,
    "ItemCount"=>0}]}
    )
  end

  it 'alter table' do
    ddbcli(<<-'EOS')
      CREATE TABLE `foo` (
        `id`  NUMBER HASH,
        `val` STRING RANGE,
        GLOBAL INDEX `idx_bar` (`val2` STRING) ALL read=1 write=1
      ) read=2 write=2
    EOS

    out = ddbcli('alter table foo read=4 write=4')

    out = ddbcli('desc foo')
    out = JSON.parse(out)
    out.delete('CreationDateTime')

    expect(out).to eq(
{"AttributeDefinitions"=>
  [{"AttributeName"=>"id", "AttributeType"=>"N"},
   {"AttributeName"=>"val", "AttributeType"=>"S"},
   {"AttributeName"=>"val2", "AttributeType"=>"S"}],
 "TableName"=>"foo",
 "KeySchema"=>
  [{"AttributeName"=>"id", "KeyType"=>"HASH"},
   {"AttributeName"=>"val", "KeyType"=>"RANGE"}],
 "TableStatus"=>"ACTIVE",
 "ProvisionedThroughput"=>
  {"NumberOfDecreasesToday"=>0,
   "ReadCapacityUnits"=>4,
   "WriteCapacityUnits"=>4},
 "TableSizeBytes"=>0,
 "ItemCount"=>0,
 "GlobalSecondaryIndexes"=>
  [{"IndexName"=>"idx_bar",
    "KeySchema"=>[{"AttributeName"=>"val2", "KeyType"=>"HASH"}],
    "Projection"=>{"ProjectionType"=>"ALL"},
    "IndexStatus"=>"ACTIVE",
    "ProvisionedThroughput"=>{"ReadCapacityUnits"=>1, "WriteCapacityUnits"=>1},
    "IndexSizeBytes"=>0,
    "ItemCount"=>0}]}
    )
  end

  it 'create table like' do
    pending('GSI does not work in DynamoDB Local')

    ddbcli(<<-'EOS')
      CREATE TABLE `foo` (
        `id`  NUMBER HASH,
        `val` STRING RANGE,
        GLOBAL INDEX `idx_bar` (`val2` STRING) ALL read=1 write=1
      ) read=2 write=2
    EOS

    ddbcli('create table foo2 like foo')

    out = ddbcli('desc foo2')
    out = JSON.parse(out)
    out.delete('CreationDateTime')

    expect(out).to eq(
{"AttributeDefinitions"=>
  [{"AttributeName"=>"id", "AttributeType"=>"N"},
   {"AttributeName"=>"val", "AttributeType"=>"S"},
   {"AttributeName"=>"val2", "AttributeType"=>"S"}],
 "TableName"=>"foo2",
 "KeySchema"=>
  [{"AttributeName"=>"id", "KeyType"=>"HASH"},
   {"AttributeName"=>"val", "KeyType"=>"RANGE"}],
 "TableStatus"=>"ACTIVE",
 "ProvisionedThroughput"=>
  {"NumberOfDecreasesToday"=>0,
   "ReadCapacityUnits"=>2,
   "WriteCapacityUnits"=>2},
 "TableSizeBytes"=>0,
 "ItemCount"=>0,
 "GlobalSecondaryIndexes"=>
  [{"IndexName"=>"idx_bar",
    "KeySchema"=>[{"AttributeName"=>"val2", "KeyType"=>"HASH"}],
    "Projection"=>{"ProjectionType"=>"ALL"},
    "IndexStatus"=>"ACTIVE",
    "ProvisionedThroughput"=>{"ReadCapacityUnits"=>1, "WriteCapacityUnits"=>1},
    "IndexSizeBytes"=>0,
    "ItemCount"=>0}]}
    )
  end
end
