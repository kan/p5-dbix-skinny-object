package DBIx::Skinny::Object::ResultSet;
use strict;
use warnings;
use utf8;
use base 'Class::Accessor::Fast';
__PACKAGE__->mk_accessors(qw/iter pager/);

1;
