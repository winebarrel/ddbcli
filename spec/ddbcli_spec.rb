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
end
