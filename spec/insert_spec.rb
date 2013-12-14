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
  end
end
