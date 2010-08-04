use t::Utils;
use TestDB;
use TestModel;
use Test::More;

TestDB->setup_test_db;
model('MockBasic')->insert({ id => 1, name => 'perl' });

subtest 'row object update' => sub {
    my $row = model('MockBasic')->single({ id => 1 });
    is $row->name, 'perl';

    ok $row->update({ name => 'python' });
    is $row->name, 'python';

    my $new_row = model('MockBasic')->single({ id => 1 });
    is $new_row->name, 'python';

    done_testing;
};

model('MockBasic')->insert({ id => 2, name => 'ruby' });

subtest 'table update' => sub {
    is model('MockBasic')->search({ name => 'php' })->iter->count, 0;

    model('MockBasic')->update({ name => 'php' }, {});

    is model('MockBasic')->search({ name => 'php' })->iter->count, 2;

    done_testing;
};

done_testing;
