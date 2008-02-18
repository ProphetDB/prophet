
use warnings;
use strict;
package SVN::PropDB::Record;
use Params::Validate;
use base qw'Class::Accessor';
__PACKAGE__->mk_accessors(qw'handle props uuid type');
my $UUIDGEN = Data::UUID->new();

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    my %args = validate(@_, { handle => 1, type => 1});
    $self->$_($args{$_}) for keys(%args);
    return $self;
}

sub create {
    my $self = shift;
    my %args = validate(@_, {  props => 1});

    $self->uuid($UUIDGEN->create_str);
    $self->handle->create_node( props => $args{'props'}, uuid => $self->uuid, type => $self->type);

    return $self->uuid;
}


sub load {
    my $self = shift;
    my %args = validate(@_, { uuid => 1});
    #my %props = $self->handle->get_node_props( uuid => $args{uuid});
    $self->uuid($args{uuid});
    #$self->props(\%props);

}

sub set_prop {
    my $self = shift;
    my %args = validate(@_, { name => 1, value => 1});
    $self->handle->set_node_props(type => $self->type, uuid => $self->uuid, props =>{$args{name}=> $args{value}});
}

sub get_props {
    my $self = shift;
    return $self->handle->get_node_props(uuid => $self->uuid, type => $self->type);
}

sub prop {
    my $self = shift;
    my %args = validate(@_, {name => 1});
    return $self->get_props->{$args{'name'}};
}


sub delete_prop {
    my $self = shift;
    my %args = validate(@_, { name => 1});
    $self->handle->delete_node_prop(uuid => $self->uuid, name => $args{'name'});
}

sub delete {
    my $self = shift;
    $self->handle->delete_node(type => $self->type, uuid => $self->uuid);

}


1;
