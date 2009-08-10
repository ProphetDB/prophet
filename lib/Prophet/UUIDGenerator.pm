package Prophet::UUIDGenerator;
use Any::Moose;
use MIME::Base64::URLSafe;

use UUID::Tiny;

# uuid_scheme: 1 - v1 and v3 uuids.
#			   2 - v4 and v5 uuids.

has uuid_scheme => (
	isa => 'Int',
	is  => 'rw'
);


sub create_str {
    my $self = shift;
	if ($self->uuid_scheme == 1 ){
		return create_UUID_as_string(UUID_V1);
	} elsif ($self->uuid_scheme == 2) {
		return create_UUID_as_string(UUID_V4);
	}
}

sub create_string_from_url {
    my $self = shift;
    my $url = shift;
    local $!;
	if ($self->uuid_scheme == 1 ){
		# Yes, DNS, not URL. We screwed up when we first defined it
		# and it can't be safely changed once defined.
		create_UUID_as_string(UUID_V3, UUID_NS_DNS, $url);
	} elsif ($self->uuid_scheme == 2) {
		create_UUID_as_string(UUID_V5, UUID_NS_URL, $url);
	}
}

sub from_string {
    my $self = shift;
    my $str = shift;
    return string_to_UUID($str);
}
 
sub to_string {
    my $self = shift;
    my $uuid = shift;
    return UUID_to_string($uuid);
}

sub from_safe_b64 {
    my $self = shift;
    my $uuid = shift;
    return urlsafe_b64decode($uuid);
}

sub to_safe_b64 {
    my $self = shift;
    my $uuid = shift;
    return urlsafe_b64encode($self->from_string($uuid));
}


=head1 NAME

Foo::Bar

=head1 METHODS

=head1 DESCRIPTION

=cut

=head1 METHODS

=cut




__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

