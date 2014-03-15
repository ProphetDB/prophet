package Prophet::ConflictingChange;
use Moo;
use Prophet::ConflictingPropChange;
use JSON 'to_json';
use Digest::SHA 'sha1_hex';
use Prophet::Types
  qw/ArrayRef Bool InstanceOf ProphetChangeType ProphetFileOpConflict Str/;

has record_type => (
    is  => 'rw',
    isa => Str,
);

has record_uuid => (
    is  => 'rw',
    isa => Str,
);

has source_record_exists => (
    is  => 'rw',
    isa => Bool,
);

has target_record_exists => (
    is  => 'rw',
    isa => Bool,
);

has change_type => (
    is  => 'rw',
    isa => ProphetChangeType,
);

has file_op_conflict => (
    is  => 'rw',
    isa => ProphetFileOpConflict,
);

has prop_conflicts => (
    is      => 'rw',
    isa     => ArrayRef,
    default => sub { [] },
);

sub has_prop_conflicts { scalar @{ $_[0]->prop_conflicts } }

sub add_prop_conflict {
    my $self = shift;
    push @{ $self->prop_conflicts }, @_;
}

sub as_hash {
    my $self   = shift;
    my $struct = {
        map { $_ => $self->$_() } (
            qw/record_type record_uuid source_record_exists target_record_exists change_type file_op_conflict/
        )
    };
    for ( @{ $self->prop_conflicts } ) {
        push @{ $struct->{'prop_conflicts'} }, $_->as_hash;
    }

    return $struct;
}

=method fingerprint

Returns a fingerprint of the content of this conflicting change

=cut

sub fingerprint {
    my $self = shift;

    my $struct = $self->as_hash;
    for ( @{ $struct->{prop_conflicts} } ) {
        $_->{choices} =
          [ sort grep {defined}
              ( delete $_->{source_new_value}, delete $_->{target_value} ) ];
    }

    return sha1_hex( to_json( $struct, { utf8 => 1, canonical => 1 } ) );
}

1;
