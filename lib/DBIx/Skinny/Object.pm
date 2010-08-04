package DBIx::Skinny::Object;
use strict;
use warnings;
use utf8;
use base qw/DBIx::Skinny::Row Class::Data::Inheritable/;
use UNIVERSAL::require;
use String::CamelCase qw/decamelize/;
use Digest::SHA1 qw(sha1_hex);
use Data::Dumper;
use Data::Page;
use Data::Page::Navigation;
use DBIx::Skinny::Object::Cache;
use DBIx::Skinny::Object::ResultSet;
use Encode;

sub import {
    my ($class, @opts) = @_;
    my $caller = caller();

    if (scalar(@opts) == 1 and ($opts[0]||'') =~ /^-base$/i) {
        {
            no strict 'refs';
            push @{"${caller}::ISA"}, $class;
        }
        $caller->mk_classdata(lookup_columns => []);

        {
            my $code = $class->can('__register_lookups');
            no strict 'refs'; ## no critic.
            *{"$caller\::register_lookups"} = sub { $code->($caller, @_) };
        }
    }

    my $model_loader = sub {
        my $name = shift;

        my $module = "${class}::$name";
        $module->require or die $@;
        return $module;
    };

    {
        no strict 'refs'; ## no critic
        no warnings 'redefine'; ## no critic
        *{"${caller}::model"} = $model_loader;
    }
}

sub table_name {
    my $class = shift;

    $class = ref($class) if ref($class);
    my $table = $class;
    $table =~ s/^.*:://;
    return decamelize($table);
}

sub get_db {
    my ($class, $where, $opt) = @_;

    die 'this method is abstract';
}

sub get_cache {
    die 'this method is abstract';
}

sub get_cache_expire {
    die 'this method is abstract';
}

sub cache {
    my $self = shift;

    return DBIx::Skinny::Object::Cache->new(cache => $self->get_cache);
}

sub _encode_value {
    utf8::is_utf8($_[0]) ? encode('utf-8', $_[0]) : $_[0]
}

sub _get_key {
    return sha1_hex($_[0]._encode_value($_[1]));
}

sub __register_lookups (@) { ## no critic
    my ($class, @lookup_columns) = @_;

    $class = ref($class) if ref($class);

    my $code = sub {
        my ($col, $val, $opt) = @_;

        my $data = $class->cache->get_callback(
            id       => _get_key($col,$val),
            key      => "@{[$class->table_name]}_lookup",
            expiration => $class->get_cache_expire,
            callback => sub {
                my $row =
                  $class->get_db({ $col => $val }, $opt)
                  ->single( $class->table_name, { $col => $val } );
                return $row ? $row->get_columns : undef;
            }
        );
        if ( $data ) {
            return $class->get_db({ $col => $val }, $opt)->data2itr($class->table_name, [$data])->first;
        }
    };
    my $code_multi = sub {
        my ($cols, $cond, $opt) = @_;

        # cond check
        for my $col (@$cols) {
            die "reuqired $col" unless defined($cond->{$col});
            die "can't set deep condition" if ref($cond->{$col});
        }
        die "don't match condition" if scalar(keys(%$cond)) > scalar(@$cols);

        my $data = $class->cache->get_callback(
            id       => sha1_hex(join('',map {$_._encode_value($cond->{$_})} @$cols)),
            key      => "@{[$class->table_name]}_lookup",
            expiration => $class->get_cache_expire,
            callback => sub {
                my $row =
                  $class->get_db($cond, $opt)
                  ->single( $class->table_name, $cond );
                return $row ? $row->get_columns : undef;
            }
        );
        if ( $data ) {
            return $class->get_db($cond, $opt)->data2itr($class->table_name, [$data])->first;
        }
    };

    for my $column (@lookup_columns) {
        if (ref $column) {
            die "column is not arrayref" unless ref($column) eq 'ARRAY';

            no strict 'refs'; ## no critic
            *{"${class}::lookup_by_@{[join('_',@$column)]}"} = sub { $code_multi->($column, $_[1], $_[2]) };
        } else {
            no strict 'refs'; ## no critic
            *{"${class}::lookup_by_$column"} = sub { $code->($column, $_[1], $_[2]) };
        }
    }
    $class->lookup_columns(\@lookup_columns);
}

sub _delete_cache {
    my $self = shift;

    for my $column (@{$self->lookup_columns}) {
        if ( ref $column ) {
            $self->cache->delete(key => "@{[$self->table_name]}_lookup", id => sha1_hex(join('',map {$_._encode_value($self->$_)} @$column)));
        } else {
            $self->cache->delete(key => "@{[$self->table_name]}_lookup", id => _get_key($column,$self->$column));
        }
    }
}

sub new {
    my $class = shift;

    return $class->SUPER::new(@_);
}

sub load {
    my ($class, $data, $opt) = @_;

    return $class->get_db({}, $opt)->data2itr($class->table_name, [$data])->first;
}

sub single {
    my ($class, $where, $opt) = @_;
    die "search cond required" unless $where;

    my $iter = $class->get_db($where, $opt)->search( $class->table_name, $where );
    return $iter->first;
}

sub search {
    my ($class, $where, $opt) = @_;
    $where ||= {};
    $opt   ||= {};

    my $code;
    if ( $opt->{page} ) {
        $code = sub {
            my $rs = $class->get_db($where, $opt)->resultset_with_pager('MySQLFoundRows');
            $rs->from([$class->table_name]);
            if (scalar(%$where)) {
                while (my ($col, $val) = each %$where) {
                    $rs->add_where($col, $val);
                }
            }
            $rs->limit($opt->{rows});
            $rs->page($opt->{page});
            $rs->select($opt->{select}||$class->get_db($where, $opt)->schema->schema_info->{$class->table_name}->{columns});
            $rs->order($opt->{order}) if scalar($opt->{order});
            return $rs->retrieve;
        };
    } elsif ( $opt->{order} ) {
        $code = sub {
            my $iter = $class->get_db($where, $opt)->search(
                $class->table_name, 
                $where, 
                { 
                    order_by => { $opt->{order}->{column} => $opt->{order}->{desc} || 'ASC' } 
                }
            );
            return ($iter, undef);
        };
    } else {
        $code = sub {
            my $iter = $class->get_db($where, $opt)->search($class->table_name, $where);
            return ($iter, undef);
        };
    }

    my ( $iter, $pager ) = $code->();
    return DBIx::Skinny::Object::ResultSet->new({ iter => $iter, pager => $pager });
}

sub insert {
    my ($class, $data, $opt) = @_;

    my $row = $class->get_db({}, $opt)->create($class->table_name, $data);
    return $row;
}

*create = \*insert;

sub bulk_insert {
    my ($class, $data, $opt) = @_;

    $class->get_db({}, $opt)->bulk_insert($class->table_name, $data);
}

sub find_or_create {
    my ($class, $cond, $opt) = @_;

    my $row = $class->single($cond, $opt);
    return $row if $row;

    $row = $class->create($cond, $opt);
    return $class->lookup_by_id($row->id, $opt);
}

sub update {
    my $self = shift;

    if ( ref $self ) {
        # instance
        my $row = $self->SUPER::update(@_);
        $self->_delete_cache;
        return $row;
    } else {
        # class
        my ($data, $where, $opt) = @_;
        my @rows = $self->search($where, $opt)->iter->all;
        for my $row (@rows) {
            $row->update($data);
        }
    }
}

sub delete {
    my $self = shift;

    if ( ref $self ) {
        # instance
        my $result = $self->SUPER::delete(@_);
        $self->_delete_cache;
        return $result;
    } else {
        # class
        my ($where, $opt) = @_;
        my @rows = $self->search($where, $opt)->iter->all;
        for my $row (@rows) {
            $row->delete;
        }
    }
}

1;
