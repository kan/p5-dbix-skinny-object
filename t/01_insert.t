use t::Utils;
use TestDB;
use TestModel;
use Test::More;

TestDB->setup_test_db;

subtest 'insert mock_basic data' => sub {
    my $row = model('MockBasic')->insert({ id => 1, name => 'perl' });

    isa_ok $row, 'TestModel::MockBasic';
    is $row->name, 'perl';

    done_testing;
};

done_testing;
