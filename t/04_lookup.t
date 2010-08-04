use t::Utils;
use TestDB;
use TestModel;
use Test::More;
use Test::Exception;

TestDB->setup_test_db;
model('MockBasic')->insert({ id => 1, name => 'perl' });
model('MockBasic')->insert({ id => 2, name => 'ruby' });
model('MockBasic')->insert({ id => 3, name => 'python' });

subtest 'lookup mock_basic data' => sub {
    my $row = model('MockBasic')->lookup_by_id(1);

    isa_ok $row, 'TestModel::MockBasic';
    is $row->name, 'perl';

    done_testing;
};

subtest 'lookup mock_basic data error' => sub {
    throws_ok { model('MockBasic')->lookup_by_name(1) } qr/Can't locate object method/, 'no register column';

    done_testing;
};

done_testing;
