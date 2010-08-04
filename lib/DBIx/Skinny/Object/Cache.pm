package DBIx::Skinny::Object::Cache;
use strict;
use warnings;
use utf8;
use Params::Validate qw(:all);

my $REG = {
    ID         => qr/^[:-_.0-9a-zA-Z]+$/x,
    KEY        => qr/^[:-_.0-9a-zA-Z]+$/x,
    VERSION    => qr/^[:-_.0-9]+$/x,
    GROUP      => qr/^[:-_.0-9a-zA-Z]+$/x,
    NAMESPACE  => qr/^[A-Za-z0-9]*$/x,
    EXPIRATION => qr/
        \A
            (?:
                \d+    # numbers
                [
                    Ww # weeks
                    Dd # days
                    Hh # hours
                    Mm # minutes
                    Ss # seconds
                ]
            )+         # 1S, 1D12H, 1w1d1h1m1s
        \Z
    /x,
};

sub new {
    my $class = shift;
    my %args = validate(@_, {
        cache         => { isa => 'Cache' },
        version       => { type  => HASHREF, optional => 1, default => {} },
        base_version  => { regex => $REG->{VERSION}, optional => 1, default => 1 },
    });

    return bless \%args, $class;
}

sub get_callback {
    my $self = shift;
    my %args = validate(@_, {
        id         => { regex => $REG->{ID} },
        key        => { regex => $REG->{KEY} },
        version    => { regex => $REG->{VERSION},    optional => 1 },
        group      => { regex => $REG->{GROUP},      optional => 1 },
        expiration => { regex => qr/^\d+$/, optional => 1 },
        callback   => { type  => CODEREF },
    });
    $args{version} ||= ($self->{version}->{$args{key}}||0) + $self->{base_version};

    my $data = $self->get(id => $args{id}, key => $args{key}, version => $args{version});
    if (defined $data ) {
        return $data;
    } else {
        my $callback = delete $args{callback};
        $data = $callback->();
        $args{value} = $data;
        $self->set(%args);
        return $data;
    }
}

sub set {
    my $self = shift;
    my %args = validate(@_, {
        value      => 1,
        id         => { regex => $REG->{ID} },
        key        => { regex => $REG->{KEY} },
        version    => { regex => $REG->{VERSION},    optional => 1 },
        group      => { regex => $REG->{GROUP},      optional => 1 },
        expiration => { regex => qr/^\d+$/, optional => 1 },
    });
    $args{version} ||= ($self->{version}->{$args{key}}||0) + $self->{base_version};
    
    return unless defined $args{value};

    my $cache_key = join('', $args{id}, $args{key}, $args{version});

    $self->{cache}->set($cache_key, $args{value}, $args{expiration} );
}

sub get {
    my $self = shift;
    my %args = validate(@_, {
        id         => { regex => $REG->{ID} },
        key        => { regex => $REG->{KEY} },
        version    => { regex => $REG->{VERSION}, optional => 1 },
    });
    $args{version} ||= ($self->{version}->{$args{key}}||0) + $self->{base_version};
    
    my $cache_key = join('', $args{id}, $args{key}, $args{version});

    my $data = $self->{cache}->get($cache_key);
    return $data;
}

sub delete {
    my $self = shift;
    my %args = validate(@_, {
        id         => { regex => $REG->{ID} },
        key        => { regex => $REG->{KEY} },
        version    => { regex => $REG->{VERSION}, optional => 1 },
    });
    $args{version} ||= ($self->{version}->{$args{key}}||0) + $self->{base_version};
    
    my $cache_key = join('', $args{id}, $args{key}, $args{version});

    $self->{cache}->remove($cache_key);
}

1;


