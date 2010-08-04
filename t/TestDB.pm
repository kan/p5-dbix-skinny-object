package TestDB;
use strict;
use warnings;
use DBIx::Skinny;
use DBIx::Skinny::Mixin modules => ['Pager', '+DBIx::Skinny::Object::Loader'];
use TestDB;

sub setup_test_db {
    unlink './t/test.db' if -f './t/test.db';
    TestDB->new(
        {
            dsn      => 'dbi:SQLite:./t/test.db',
            username => '',
            password => '',
            connect_options => { AutoCommit => 1 },
        }
    )->do(q{
        CREATE TABLE mock_basic (
            id   integer,
            name text,
            delete_fg int(1) default 0,
            primary key ( id )
        )
    });
}


1;
