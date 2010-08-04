package DBIx::Skinny::Object::Loader;
use strict;
use warnings;
use UNIVERSAL::require;
use String::CamelCase;

sub register_method {
    +{
        'object_loader' => \&object_loader,
    },
}

sub object_loader {
    my ($self, $base_class) = @_;
    
    for my $table (keys %{$self->schema->schema_info}) {
        my $object_class = "$base_class\::" . String::CamelCase::camelize($table);
        $object_class->use or next;
        $self->attribute->{row_class_map}->{$table} = $object_class;
    }
}

1;
__END__

=head1 NAME

DBIx::Skinny::Object::Loader

=head1 SYNOPSIS

  package Proj::DB;
  use DBIx::Skinny;
  use DBIx::Skinny::Mixin modules => ['+DBIx::Skinny::Object::Loader'];

  package Proj::Model;
  use base 'DBIx::Skinny::Object';
  
  sub get_db {
      $self->load_class('Proj::DB');
      my $db = Proj::DB->new($datasource);
      $db->object_loader('Proj::Model');
      $db;
  }
  
  package main;
  use Proj::Model;
  
  my $row = model('Table')->create({ id => 1 });

