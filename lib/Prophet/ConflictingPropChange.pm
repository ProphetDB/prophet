package Prophet::ConflictingPropChange;

# ABSTRACT: Conflicting property changes

use Moo;
use Prophet::Types qw/Maybe Str/;

=attr name

The property name for the conflict in question

=cut

has name => (
    is  => 'rw',
    isa => Str,
);

=attr source_old_value

The inital (old) state from the change being merged in

=cut

has source_old_value => (
    is  => 'rw',
    isa => Maybe [Str],
);

=attr target_value

The current target-replica value of the property being merged.

=cut

has target_value => (
    is  => 'rw',
    isa => Maybe [Str],
);

=attr source_new_value

The final (new) state of the property from the change being merged in.

=cut

has source_new_value => (
    is  => 'rw',
    isa => Maybe [Str],
);

sub as_hash {
    my $self    = shift;
    my $hashref = {};

    for (qw(name source_old_value target_value source_new_value)) {
        $hashref->{$_} = $self->$_;
    }
    return $hashref;
}

1;

=head1 DESCRIPTION

Objects of this class describe a case when a property change can not be
cleanly applied to a replica because the old value for the property locally did
not match the "begin state" of the change being applied.
