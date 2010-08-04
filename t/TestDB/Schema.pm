package TestDB::Schema;
use strict;
use DBIx::Skinny::Schema;

install_table mock_basic => schema {
    pk 'id';
    columns qw/
        id
        name
        delete_fg
    /;
};

1;

