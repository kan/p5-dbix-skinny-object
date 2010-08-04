package TestModel;
use strict;
use warnings;
use base 'DBIx::Skinny::Object';

use Cache::Memory;
use TestDB;

sub get_cache {
    my $cache = Cache::Memory->new(namespace => 'TestModel');

    $cache;
}

sub get_cache_expire { 300 }

sub get_db {
    my $db = TestDB->new(
        {
            dsn => 'dbi:SQLite:./t/test.db',
            uername => '',
            password => '',
            connect_options => { AutoCommit => 1 },
        }
    );
    $db->object_loader('TestModel');

    $db;
}

1;
