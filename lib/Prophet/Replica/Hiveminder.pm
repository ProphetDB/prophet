use warnings;
use strict;

package Prophet::Replica::Hiveminder;
use base qw/Prophet::ForeignReplica/;
use Params::Validate qw(:all);
use UNIVERSAL::require;

use Net::Jifty;

use URI;
use Memoize;
use Prophet::Handle;
use Prophet::ChangeSet;
use Prophet::Replica::Hiveminder::PullEncoder;
use App::Cache;

__PACKAGE__->mk_accessors(qw/hm_username hm hm_url ressource/);

our $DEBUG = $Prophet::Handle::DEBUG;


=head2 setup

Open a connection to the SVN source identified by C<$self->url>.

=cut

use File::Temp 'tempdir';

sub setup {
    my $self = shift;
    my ( $server) = $self->{url} =~ m/^hm:(.*?)$/
        or die "Can't parse hiveminder server spec";
    my $uri = URI->new($server);
    my ( $username, $password );
    if ( my $auth = $uri->userinfo ) {
        ( $username, $password ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }
    $self->hm_url("$uri");


    ( $username, $password ) = $self->prompt_for_login( $uri, $username ) unless $password;

    $self->hm( Net::Jifty->new(site => $self->hm_url,
                        cookie_name => 'JIFTY_SID_HIVEMINDER',
    
                        email => $username,
                        password => $password
                        ));
    

    $self->hm_username($username);
    my $cli = Prophet::CLI->new();
    $self->state_handle( $cli->get_handle_for_replica( $self, $self->state_db_uuid ) );
}





=head2 uuid

Return the replica SVN repository's UUID

=cut

sub uuid {
    my $self = shift;
    return $self->uuid_for_url( join( '/', $self->hm_url, $self->hm_username ) );
}



=head2 fetch_changesets { after => SEQUENCE_NO } 

Fetch all changesets from the source. 

Returns a reference to an array of L<Prophet::ChangeSet/> objects.


=cut

sub fetch_changesets {
    my $self = shift;
    my %args = validate( @_, { after => 1 } );

    my $first_rev = ( $args{'after'} + 1 ) || 1;

    my @changesets;
    my %tix;
    my $recoder = Prophet::Replica::Hiveminder::PullEncoder->new( { sync_source => $self } );
    for my $task ( @{$self->find_matching_tasks} ) {
        push @changesets, @{ $recoder->run(
                task => $task,
                transactions => $self->find_matching_transactions( task => $task->{id}, starting_transaction => $first_rev )) };
    }

    return [ sort { $a->original_sequence_no <=> $b->original_sequence_no } @changesets ];
}

sub find_matching_tasks {
    my $self  = shift;
    my $tasks = $self->hm->act(
        'TaskSearch',
        owner        => 'me',
        group        => 0,
        requestor    => 'me',
        not_complete => 1,

    )->{content}->{tasks};
    return $tasks;
}

sub prophet_has_seen_transaction {
    goto \&Prophet::Replica::RT::prophet_has_seen_transaction;
}
sub record_pushed_transaction {
    goto \&Prophet::Replica::RT::record_pushed_transaction;
}

sub record_pushed_transactions {
    # don't need this for hm
}

sub _txn_storage {
    goto \&Prophet::Replica::RT::_txn_storage;
}

# hiveminder transaction ~= prophet changeset
# hiveminder taskhistory ~= prophet change
# hiveminder taskemail ~= prophet change
sub find_matching_transactions {
    my $self = shift;
    my %args = validate( @_,   {task => 1, starting_transaction => 1 } );

    my $txns = $self->hm->search( 'TaskTransaction', task_id => $args{task} ) || [];
    my @matched;
    foreach my $txn ( @$txns) {
        next if $txn->{'id'} < $args{'starting_transaction'};        # Skip things we've pushed

        next if $self->prophet_has_seen_transaction($txn->{'id'});

        $txn->{history_entries} = $self->hm->search( 'TaskHistory', transaction_id => $txn->{'id'} );
        $txn->{email_entries} = $self->hm->search( 'TaskEmail', transaction_id => $txn->{'id'} );
        push @matched, $txn;
    }
    return \@matched;

}

sub integrate_ticket_create {
    my $self = shift;
    my ( $change, $changeset ) = validate_pos( @_, { isa => 'Prophet::Change' }, { isa => 'Prophet::ChangeSet' } );

    # Build up a ticket object out of all the record's attributes

    warn Dumper($change); use Data::Dumper;
    my $task = $self->hm->create(
        'Task',
        owner        => 'me',
        group        => 0,
        requestor    => 'me',
        complete     => 0,
        will_complete => 1,
repeat_stacking       => 0,
       %{ $self->_recode_props_for_integrate($change) }


    );

    my $txns = $self->hm->search( 'TaskTransaction', task_id => $task->{content}->{id} );

    # lalala
    $self->record_pushed_transaction( transaction => $txns->[0]->{id}, changeset => $changeset );
    return $task->{content}->{id};


#    return $ticket->id;


}

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos( @_, { isa => 'Prophet::Change' } );

    my %props = map { $_->name => $_->new_value } $change->prop_changes;
    my %attr;

    for my $key ( keys %props ) {
        # XXX: fill me in
#        next unless ( $key =~ /^(summary|queue|status|owner|custom)/ );
        $attr{$key} = $props{$key};
    }
    return \%attr;
}


require Prophet::Replica::RT;
sub _integrate_change {

    goto \&Prophet::Replica::RT::_integrate_change;

}




{ 



# XXXXXXXX
# XXXXXXXXX
# XXX todo code in this block cargo culted from the RT Replica type




sub remote_id_for_uuid {
    my ( $self, $uuid_for_remote_id ) = @_;

    # XXX: should not access CLI handle
    my $ticket = Prophet::Record->new( handle => Prophet::CLI->new->handle, type => 'ticket' );
    $ticket->load( uuid => $uuid_for_remote_id );
    return $ticket->prop( $self->uuid . '-id' );
}

sub uuid_for_remote_id {
    my ( $self, $id ) = @_;
    return $self->_lookup_remote_id($id)|| $self->uuid_for_url( $self->hm_url . "/task/$id" );
}

our $REMOTE_ID_METATYPE = "_remote_id_map";

sub _remote_id_storage {
    my $self = shift;
    return $self->state_handle->metadata_storage($REMOTE_ID_METATYPE, 'prophet-uuid');
}

sub _lookup_remote_id {
    my $self = shift;
    my ($id) = validate_pos( @_, 1 );

    return $self->_remote_id_storage->( $self->uuid_for_url( $self->hm_url . "/task/$id" ) );
}

sub _set_remote_id {
    my $self = shift;
    my %args = validate( @_,
        { uuid      => 1,
          remote_id => 1
        }
    );
    warn "==> doing set remote id $args{remote_id}.........".$self->uuid_for_url( $self->hm_url . "/task/" . $args{'remote_id'} );
    warn "====> $args{uuid}";
    return $self->_remote_id_storage->(
        $self->uuid_for_url( $self->hm_url . "/task/" . $args{'remote_id'} ),
        $args{uuid} );
}

}

sub record_pushed_ticket {
    my $self = shift;
    my %args = validate(
        @_,
        {   uuid      => 1,
            remote_id => 1
        }
    );
    $self->_set_remote_id(%args);
}



1;
