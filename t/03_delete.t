use t::Utils;
use TestDB;
use TestModel;
use Test::More;

TestDB->setup_test_db;
model('MockBasic')->insert({ id => 1, name => 'perl' });

subtest 'row object delete' => sub {
    my $row = model('MockBasic')->single({ id => 1 });
    ok $row;

    $row->delete;

    my $new_row = model('MockBasic')->single({ id => 1 });
    ok !$new_row;

    done_testing;
};

model('MockBasic')->insert({ id => 1, name => 'perl' });
model('MockBasic')->insert({ id => 2, name => 'ruby' });

subtest 'table delete' => sub {
    is model('MockBasic')->search({ })->iter->count, 2;

    model('MockBasic')->delete({ name => 'perl' }, {});

    is model('MockBasic')->search({ })->iter->count, 1;

    done_testing;
};

done_testing;
