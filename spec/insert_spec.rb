describe 'ddbcli' do
  context 'insert' do
    before do
      ddbcli(<<-'EOS')
CREATE TABLE `employees` (
  `emp_no` NUMBER HASH,
  `birth_date` STRING RANGE
) read=2 write=2;
      EOS
    end

    it 'insert array' do
      ddbcli(<<-'EOS')
        insert into employees (
          emp_no,
          birth_date,
          num,
          str,
          bin,
          num_array,
          str_array,
          bin_array
        ) values (
          1,
          '1977-11-11',
          2,
          'XXX',
          x'cafebabe',
          (1, 2, 3),
          ("A", "B", "C"),
          (x"aa", x"bb", x"cc")
        )
      EOS

      out = ddbcli('select all * from employees')
      out = JSON.parse(out)

      expect(out).to eq(
[{"bin"=>"yv66vg==",
  "bin_array"=>["qg==", "uw==", "zA=="],
  "birth_date"=>"1977-11-11",
  "emp_no"=>1,
  "num"=>2,
  "num_array"=>[1, 2, 3],
  "str"=>"XXX",
  "str_array"=>["A", "B", "C"]}]
      )
    end

    it 'insert list/map/bool/null' do
      ddbcli(<<-'EOS')
        insert into employees (
          emp_no,
          birth_date,
          bool1,
          bool2,
          null_val,
          list,
          map
        ) values (
          1,
          '1977-11-11',
          true,
          false,
          null,
          [1, "2", 3, ["FOO", "BAR"], {foo: "foo", bar: 100}],
          {foo: "foo", "bar": [1, 2, 3, {zoo: "zoo"}]}
        )
      EOS

      out = ddbcli('select all * from employees')
      out = JSON.parse(out)

      expect(out).to eq(
[{"birth_date"=>"1977-11-11",
  "bool1"=>true,
  "bool2"=>false,
  "emp_no"=>1,
  "list"=>[1, "2", 3, ["FOO", "BAR"], {"bar"=>100, "foo"=>"foo"}],
  "map"=>{"bar"=>[1, 2, 3, {"zoo"=>"zoo"}], "foo"=>"foo"},
  "null_val"=>nil}]
      )
    end

    it 'insert error (1)' do
      sql = <<-'EOS'
        insert into employees (
          emp_no,
          birth_date,
          num,
          str
        ) values (
          1,
          '1977-11-11',
          2
        )
      EOS

      expect {
        ddbcli(sql)
      }.to raise_error(%|// number of attribute name and value are different: ["emp_no", "birth_date", "num", "str"] != [1, "1977-11-11", 2]\n\n|)
    end

    it 'insert error (2)' do
      sql = <<-'EOS'
        insert into employees (
          emp_no,
          birth_date,
          num,
          str
        ) values (
          1,
          '1977-11-11',
          2,
          'XXX',
          'YYY'
        )
      EOS

      expect {
        ddbcli(sql)
      }.to raise_error(%|// number of attribute name and value are different: ["emp_no", "birth_date", "num", "str"] != [1, "1977-11-11", 2, "XXX", "YYY"]\n\n|)
    end
  end
end
