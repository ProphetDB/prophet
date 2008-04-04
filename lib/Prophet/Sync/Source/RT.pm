use warnings;
use strict;

package Prophet::Sync::Source::RT;
use base qw/Prophet::Sync::Source/;
use Params::Validate qw(:all);
use UNIVERSAL::require;
use RT::Client::REST       ();
use RT::Client::REST::User ();
   use RT::Client::REST::Ticket;

use Memoize;
use Prophet::Handle;
use Prophet::ChangeSet;
use Prophet::Conflict;

__PACKAGE__->mk_accessors(qw/prophet_handle ressource is_resdb rt rt_url rt_queue rt_query/);

our $DEBUG = $Prophet::Handle::DEBUG;


=head1 NOTES ON PUSH

Push to rt algorithm

apply a single changeset that's part of the push:
    - for each record in that changeset:
        - pull the record's txn list from the server
        - for each txn we don't know we've already seen, look at it
            - if it is from the changeset we just pushed, then
                store the id of the new transaction and originating uuid in the push-ticket store.
                    - does that let us specify individual txns? or is it a high-water mark?
             - if it is _not_ from the changeset we just pushed, then 
                do we just ignore it?
                how do we mark an out-of-order transaction as not-pulled?
                


Changesets we want to push from SD to RT and how they map

    
what do we do with cfs rt doesn't know about?



SD::Source::RT->recode_ticket



=cut

sub record_changeset_integration {
    my ($self, $source_uuid, $source_seq) = @_;
    my $cache = App::Cache->new({ ttl => 60*60 }); # la la la
    return $cache->set($self->uuid.'-'.$source_uuid, $source_seq);
}



sub record_integration_changeset {
    warn "record_integration_changeset should be renamed to 'record_original_change";
    my ($self, $changeset) = @_;
    $self->record_changeset($changeset);

    # does the merge ticket recording & _source_metadata (book keeping for what txns in rt we just created)
    $self->record_txn_just_created($changeset);

    $self->record_changeset_integration( $changeset->original_source_uuid, $changeset->original_sequence_no );
}

sub record_txn_just_created {
    my ($self, $changeset) = @_;
    # XXX: go discover the txn_ids corresponds to $changeset;
    my @txn_ids;
    for my $change ($changeset->changes) {
        next unless $change->node_type eq 'ticket';
        next if $change->change_type eq 'add_file'; # XXX: handled separately when calling rt::client create-ticket
        my $ticket_id = $self->get_remote_id_for( $change->node_uuid) ;
        
    
        Carp::confess "No ticket id for Changeset " .YAML::Dump($change) unless ($ticket_id);
        for my $txn  ( reverse RT::Client::REST::Ticket->new(rt => $self->rt, id => $ticket_id)->transactions) {
            last if $txn->id <= $self->last_changeset_from_source();
            push @txn_ids, $txn->id;
            
        }
    }
    
    $self->_store_changeset_metadata(\@txn_ids, $changeset->original_source_uuid, $changeset->original_sequence_no);

}
    
sub _store_changeset_metadata {
    my $self = shift;
    my ($txn_ids, $uuid, $seq) = (@_);
    my $cache = App::Cache->new({ ttl => 60*60 }); # la la la
    $cache->set( $self->uuid,'-txn-'.$_, join(':', $uuid, $seq))    for @$txn_ids;
}

sub get_remote_id_for {
    my ($self, $ticket_uuid) = @_;
    # XXX: should not access CLI handle
    my $ticket = Prophet::Record->new(handle => Prophet::CLI->new->handle, type => 'ticket' );
    $ticket->load( uuid => $ticket_uuid );
    return $ticket->prop($self->uuid.'-id');
}

sub has_seen_changeset {
    my ($self, $changeset) = @_;
    my $cache = App::Cache->new({ ttl => 60*60 }); # la la la
    my $txn_id = $changeset->original_sequence_no;
    # XXX: extract the original txn id from $changeset
    return $cache->get( $self->uuid,'-txn-'.$txn_id );
}


sub record_changeset {
    my $self = shift;
    my ($changeset) = validate_pos(@_, { isa => 'Prophet::ChangeSet'});
    $self->_integrate_change($_, $changeset) for $changeset->changes;
}

sub _integrate_change {
    my $self = shift;
    my ($change, $changeset) = validate_pos(@_, { isa => 'Prophet::Change'}, {isa => 'Prophet::ChangeSet' });
    my $id;
eval {

    if ($change->node_type eq 'ticket' and $change->change_type eq 'add_file') {
    warn "==> create";
    $id =     $self->integrate_ticket_create($change, $changeset); # ALSO WANT CHANGESET
    } elsif ($change->node_type eq 'comment') {
        $self->integrate_comment($change, $changeset);
    } elsif ($change->node_type eq 'ticket') {
    warn "==> wtf ".$change->change_type;
        $self->integrate_ticket_update($change, $changeset);
    
    } else {
        die "AAAAAH I DO NOT KNOW HOW TO PUSH ".YAML::Dump($change);
    }
    
    }; warn $@ if $@;
    return $id 
}


sub integrate_ticket_update {
    my $self = shift;
   my ($change, $changeset) = validate_pos(@_, { isa => 'Prophet::Change'}, { isa => 'Prophet::ChangeSet'});
    # Figure out the remote site's ticket ID for this change's record
    my $remote_ticket_id = $self->get_remote_id_for($change->node_uuid);
    my $ticket = RT::Client::REST::Ticket->new(rt => $self->rt,
                id => $remote_ticket_id,
                %{ $self->_recode_props_for_integrate($change)})->store();

    # for each propchange in this change 
        # apply the change to the remote RT server
        # fetch transactions on this ticket from the remote RT
        # make sure our change has been applied to remote
        # record our propchange as having been applied
    
}

sub integrate_ticket_create {
   my $self = shift;
   my ($change, $changeset) = validate_pos(@_, { isa => 'Prophet::Change'}, { isa => 'Prophet::ChangeSet'});
   # Build up a ticket object out of all the record's attributes
   warn $self->rt_queue;
   my $ticket = RT::Client::REST::Ticket->new(
        rt => $self->rt,
        queue => $self->rt_queue(),
        %{ $self->_recode_props_for_integrate($change)},
    )->store(text => "Not yet pulling in ticket creation comment");   
    
    my @txn_ids = $ticket->transactions;
    $self->_store_changeset_metadata(\@txn_ids, $changeset->original_source_uuid, $changeset->original_sequence_no);
        
   # Grab the related comment
   # Create the ticket
   # fetch the ticket ID
   # record a push ticket for the RT ticket and for the 'create' comment


}

sub conflicts_from_changeset { return; }

sub accepts_changesets { 1 }

sub _recode_props_for_integrate {
    my $self = shift;
    my ($change) = validate_pos(@_, { isa => 'Prophet::Change'});
   
   my %props = map { $_->name => $_->new_value } $change->prop_changes;
   
    my %attr;
    my %cf;
    for my $key (keys %props) {
        next unless ($key =~ /^(summary|queue|status|owner|custom)/);
        if ($key =~ /^custom-(.*)/) {
            $cf{$1} = $props{$key};
        } elsif ($key eq 'summary') { 
            $attr{'subject'} = $props{summary};
        
        } else {

            $attr{$key} = $props{$key};
        }
    }
    $attr{cf} = \%cf;
    return \%attr;
}



sub integrate_comment {
    my $self = shift;
    my ($change) = validate_pos(@_, { isa => 'Prophet::Change'});
    # Figure out the remote site's ticket ID for this change's record

    my %props = map { $_->name => $_->new_value } $change->prop_changes;


    my $ticket =RT::Client::REST::Ticket->new(rt => $self->rt,
        id => $self->get_remote_id_for($props{'ticket'}));
        if ($props{'type'} eq 'comment') {
            $ticket->comment(message => $props{'content'});
        } else {
            $ticket->correspond(message => $props{'content'});

        }
        
    
    # Build a comment or correspondence object
        # apply the change to the remote RT server
        # fetch transactions on this ticket from the remote RT
        # make sure our change has been applied to remote
        # record our propchange as having been applied
    
  }
    

=head2 setup

Open a connection to the SVN source identified by C<$self->url>.

XXX TODO, make the _prophet/ directory in the replica configurable

=cut

use File::Temp 'tempdir';

sub setup {
    my $self = shift;
    my ( $server, $type, $query ) = $self->{url} =~ m/^rt:(.*?)\|(.*?)\|(.*)$/
        or die "Can't parse rt server spec";
    my $uri = URI->new($server);
    my ( $username, $password );
    if ( my $auth = $uri->userinfo ) {
        ( $username, $password ) = split /:/, $auth, 2;
        $uri->userinfo(undef);
    }
    $self->rt_url("$uri");
    $self->rt_queue($type);
    $self->rt_query($query. " AND Queue = '$type'");
    $self->rt( RT::Client::REST->new( server => $server ) );
    unless ($username) {

        # XXX belongs to some CLI callback
        use Term::ReadKey;
        local $| = 1;
        print "Username for $uri: ";
        ReadMode 1;
        $username = ReadLine 0;
        chomp $username;
        print "Password for $username @ $uri: ";
        ReadMode 2;
        $password = ReadLine 0;
        chomp $password;
        ReadMode 1;
        print "\n";
    }
    $self->rt->login( username => $username, password => $password );
    my $orz = tempdir();
    $self->{___Orz} = $orz;
    SVN::Repos::create( $orz, undef, undef, undef, undef );
    $self->ressource( __PACKAGE__->new( { url => "file://$orz", is_resdb => 1 } ) );
}

sub fetch_resolutions { warn 'no resdb' }

=head2 uuid

Return the replica SVN repository's UUID

=cut

sub uuid {
    my $self = shift;
    return $self->uuid_for_url( join( '/', $self->rt_url, $self->rt_query ) );

}

use Data::UUID 'NameSpace_DNS';

sub uuid_for_url {
    my ( $self, $url ) = @_;
    return Data::UUID->new->create_from_name_str( NameSpace_DNS, $url );
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
    for my $id ( $self->_find_matching_tickets ) {
        # XXX: _recode_transactions should ignore txn-id <= $first_rev
        push @changesets,
            @{
            $self->_recode_transactions(
                ticket       => $self->rt->show( type => 'ticket', id => $id ),
                transactions => $self->_find_matching_transactions($id)
            )
            };
    }
    my @results = map { $self->translate_prop_names($_) } sort { $a->original_sequence_no <=> $b->original_sequence_no } @changesets;

    return \@results;
}

sub _recode_transactions {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, transactions => 1 } );

    my $ticket = $args{'ticket'};

    warn "Working on " . $ticket->{id};
    my $create_state = $ticket;
    map { $create_state->{$_} = $self->date_to_iso( $create_state->{$_} ) }
        qw(Created Resolved Told LastUpdated Starts Started);

    map { $create_state->{$_} =~ s/ minutes$// } qw(TimeWorked TimeLeft TimeEstimated);
    my @changesets;
    for my $txn ( sort { $b->{'id'} <=> $a->{'id'} } @{ $args{'transactions'} } ) {
        if ( my $sub = $self->can( '_recode_txn_' . $txn->{'Type'} ) ) {
            my $changeset = Prophet::ChangeSet->new(
                {   original_source_uuid => $self->uuid,
                    original_sequence_no => $txn->{'id'},
                }
            );

            if ( ( "ticket/" . $txn->{'Ticket'} ne $ticket->{id} ) && $txn->{'Type'} !~ /^(?:Comment|Correspond)$/ ) {
                warn "Skipping a data change from a merged ticket" . $txn->{'Ticket'} . ' vs ' . $ticket->{id};
                next;
            }

            $sub->(
                $self,
                ticket       => $ticket,
                create_state => $create_state,
                txn          => $txn,
                changeset    => $changeset
            );
            unshift @changesets, $changeset unless $changeset->is_empty;
        } else {
            warn "not handling txn type $txn->{Type} for $txn->{id} (Ticket $args{ticket}{id}) yet";
            die YAML::Dump($txn);
        }

    }

    return \@changesets;

}
sub _recode_txn_CommentEmailRecord     { return; }

sub _recode_txn_EmailRecord     { return; }
sub _recode_txn_AddReminder     { return; }
sub _recode_txn_ResolveReminder { return; }
sub _recode_txn_DeleteLink      { }

sub _recode_txn_Status {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, txn => 1, create_state => 1, changeset => 1 } );

    $args{txn}->{'Type'} = 'Set';

    return $self->_recode_txn_Set(%args);
}

sub _recode_txn_Told {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, txn => 1, create_state => 1, changeset => 1 } );
    $args{txn}->{'Type'} = 'Set';
    return $self->_recode_txn_Set(%args);
}

sub _recode_txn_Set {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, txn => 1, create_state => 1, changeset => 1 } );

    my $change = Prophet::Change->new(
        {   node_type   => 'ticket',
            node_uuid   => $self->uuid_for_url( $self->rt_url . "/ticket/" . $args{'create_state'}->{'id'} ),
            change_type => 'update_file'
        }
    );

    if ( $args{txn}->{Field} eq 'Queue' ) {
        my $current_queue = $args{ticket}->{'Queue'};
        my $user          = $args{txn}->{Creator};
        if ( $args{txn}->{Description} =~ /Queue changed from (.*) to $current_queue by $user/ ) {
            $args{txn}->{OldValue} = $1;
            $args{txn}->{NewValue} = $current_queue;
        }

    } elsif ( $args{txn}->{Field} eq 'Owner' ) {
        $args{'txn'}->{NewValue} = $self->resolve_user_id_to( name => $args{'txn'}->{'NewValue'} ),
            $args{'txn'}->{OldValue}
            = $self->resolve_user_id_to( name => $args{'txn'}->{'OldValue'} )

    }

    $args{'changeset'}->add_change( { change => $change } );
    if ( $args{'create_state'}->{ $args{txn}->{Field} } eq $args{txn}->{'NewValue'} ) {
        $args{'create_state'}->{ $args{txn}->{Field} } = $args{txn}->{'OldValue'};
    } else {
        $args{'create_state'}->{ $args{txn}->{Field} } = $args{txn}->{'OldValue'};
        warn $args{'create_state'}->{ $args{txn}->{Field} } . " != "
            . $args{txn}->{'NewValue'} . "\n\n"
            . YAML::Dump( \%args );
    }
    $change->add_prop_change(
        name => $args{txn}->{'Field'},
        old  => $args{txn}->{'OldValue'},
        new  => $args{txn}->{'NewValue'}

    );

}

*_recode_txn_Steal = \&_recode_txn_Set;
*_recode_txn_Take  = \&_recode_txn_Set;
*_recode_txn_Give  = \&_recode_txn_Set;

sub _recode_txn_Create {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, txn => 1, create_state => 1, changeset => 1 } );

    my $change = Prophet::Change->new(
        {   node_type   => 'ticket',
            node_uuid   => $self->uuid_for_url( $self->rt_url . "/ticket/" . $args{'create_state'}->{'id'} ),
            change_type => 'add_file'
        }
    );

    $args{'create_state'}->{'id'} =~ s/^ticket\///g;
    $args{'create_state'}->{$self->uuid.'-id'} = delete $args{'create_state'}->{'id'};

    $args{'changeset'}->add_change( { change => $change } );
    for my $name ( keys %{ $args{'create_state'} } ) {

        $change->add_prop_change(
            name => $name,
            old  => undef,
            new  => $args{'create_state'}->{$name},
        );

    }

    $self->_recode_content_update(%args);    # add the create content txn as a seperate change in this changeset

}

sub _recode_txn_AddLink {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, txn => 1, create_state => 1, changeset => 1 } );
    my $new_state = $args{'create_state'}->{ $args{'txn'}->{'Field'} };
    $args{'create_state'}->{ $args{'txn'}->{'Field'} } = $self->warp_list_to_old_value(  $args{'create_state'}->{ $args{'txn'}->{'Field'} },
                 $args{'txn'}->{'NewValue'},    $args{'txn'}->{'OldValue'});

    my $change = Prophet::Change->new(
        {   node_type   => 'ticket',
            node_uuid   => $self->uuid_for_url( $self->rt_url . "/ticket/" . $args{'create_state'}->{'id'} ),
            change_type => 'update_file'
        }
    );
    $args{'changeset'}->add_change( { change => $change } );
    $change->add_prop_change(
        name => $args{'txn'}->{'Field'},
        old  => $args{'create_state'}->{ $args{'txn'}->{'Field'} },
        new  => $new_state
    );

    
    
    
    
    
    
}

sub _recode_content_update {
    my $self   = shift;
    my %args   = validate( @_, { ticket => 1, txn => 1, create_state => 1, changeset => 1 } );
    my $change = Prophet::Change->new(
        {   node_type   => 'comment',
            node_uuid   => $self->uuid_for_url( $self->rt_url . "/transaction/" . $args{'txn'}->{'id'} ),
            change_type => 'add_file'
        }
    );
    $change->add_prop_change(
        name => 'type',
        old  => undef,
        new  => $args{'txn'}->{'Type'}
    );

    $change->add_prop_change(
        name => 'creator',
        old  => undef,
        new  => $args{'txn'}->{'Creator'}
    );
    $change->add_prop_change(
        name => 'content',
        old  => undef,
        new  => $args{'txn'}->{'Content'}
    );
    $change->add_prop_change(
        name => 'ticket',
        old  => undef,
        new  => $args{ticket}->{uuid},
    );
    $args{'changeset'}->add_change( { change => $change } );
}

*_recode_txn_Comment    = \&_recode_content_update;
*_recode_txn_Correspond = \&_recode_content_update;

sub _recode_txn_AddWatcher {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, txn => 1, create_state => 1, changeset => 1 } );

    my $new_state = $args{'create_state'}->{ $args{'txn'}->{'Field'} };

    $args{'create_state'}->{ $args{'txn'}->{'Field'} } = $self->warp_list_to_old_value(
        $args{'create_state'}->{ $args{'txn'}->{'Field'} },

        $self->resolve_user_id_to( email => $args{'txn'}->{'NewValue'} ),
        $self->resolve_user_id_to( email => $args{'txn'}->{'OldValue'} )

    );

    my $change = Prophet::Change->new(
        {   node_type   => 'ticket',
            node_uuid   => $self->uuid_for_url( $self->rt_url . "/ticket/" . $args{'create_state'}->{'id'} ),
            change_type => 'update_file'
        }
    );
    $args{'changeset'}->add_change( { change => $change } );
    $change->add_prop_change(
        name => $args{'txn'}->{'Field'},
        old  => $args{'create_state'}->{ $args{'txn'}->{'Field'} },
        new  => $new_state
    );

}

*_recode_txn_DelWatcher = \&_recode_txn_AddWatcher;

sub _recode_txn_CustomField {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, txn => 1, create_state => 1, changeset => 1 } );

    my $new = $args{'txn'}->{'NewValue'};
    my $old = $args{'txn'}->{'OldValue'};
    my $name;
    if ( $args{'txn'}->{'Description'} =~ /^(.*) $new added by/ ) {
        $name = $1;

    } elsif ( $args{'txn'}->{'Description'} =~ /^(.*) $old delete by/ ) {
        $name = $1;
    } else {
        die "Uh. what to do with txn descriotion " . $args{'txn'}->{'Description'};
    }

    $args{'txn'}->{'Field'} = "CF-" . $name;

    my $new_state = $args{'create_state'}->{ $args{'txn'}->{'Field'} };
    $args{'create_state'}->{ $args{'txn'}->{'Field'} } = $self->warp_list_to_old_value(
        $args{'create_state'}->{ $args{'txn'}->{'Field'} },
        $args{'txn'}->{'NewValue'},
        $args{'txn'}->{'OldValue'}
    );

    my $change = Prophet::Change->new(
        {   node_type   => 'ticket',
            node_uuid   => $self->uuid_for_url( $self->url . "/ticket/" . $args{'create_state'}->{'id'} ),
            change_type => 'update_file'
        }
    );

    $args{'changeset'}->add_change( { change => $change } );
    $change->add_prop_change(
        name => $args{'txn'}->{'Field'},
        old  => $args{'create_state'}->{ $args{'txn'}->{'Field'} },
        new  => $new_state
    );
}

sub resolve_user_id_to {
    my $self = shift;
    my $attr = shift;
    my $id   = shift;
    return undef unless ($id);

    my $user = RT::Client::REST::User->new( rt => $self->rt, id => $id )->retrieve;
    return $attr eq 'name' ? $user->name : $user->email_address;

}

memoize 'resolve_user_id_to';

sub _find_matching_tickets {
    my $self = shift;

    # Find all stalled tickets
    my @tix = $self->rt->search(
        type  => 'ticket',
        query => $self->rt_query,
    );
    return @tix;

}

sub _find_matching_transactions {
    my $self   = shift;
    my $ticket = shift;
    my @txns;
    for my $txn ( $self->rt->get_transaction_ids( parent_id => $ticket ) ) {
        push @txns, $self->rt->get_transaction( parent_id => $ticket, id => $txn, type => 'ticket' );
    }
    return \@txns;
}

=head2 last_changeset_from_source $SOURCE_UUID

Returns the last changeset id seen from the source identified by $SOURCE_UUID

=cut

sub last_changeset_from_source {
    my $self = shift;
    my ($source_uuid) = validate_pos( @_, { type => SCALAR } );

    use App::Cache;
    my $cache = App::Cache->new({ ttl => 60*60 }); # la la la
#$cache->delete($self->uuid.'-'.$source_uuid) || 0;

    return $cache->get($self->uuid.'-'.$source_uuid) || 0;
}

sub _integration {
    my ($self, $source_uuid, $source_seq) = @_;

    my $cache = App::Cache->new({ ttl => 60*60 }); # la la la
    return $cache->set($self->uuid.'-'.$source_uuid, $source_seq);
}

sub warp_list_to_old_value {
    my $self         = shift;
    my $ticket_value = shift ||'';
    my $add          = shift;
    my $del          = shift;

    my @new = split( /\s*,\s*/, $ticket_value );
    my @old = grep { $_ ne $add } @new, $del;
    return join( ", ", @old );
}

our $MONNUM = {
    Jan => 1,
    Feb => 2,
    Mar => 3,
    Apr => 4,
    May => 5,
    Jun => 6,
    Jul => 7,
    Aug => 8,
    Sep => 9,
    Oct => 10,
    Nov => 11,
    Dec => 12
};

use DateTime::Format::HTTP;

sub date_to_iso {
    my $self = shift;
    my $date = shift;

    return '' if $date eq 'Not set';
    my $t = DateTime::Format::HTTP->parse_datetime($date);
    return $t->ymd . " " . $t->hms;
}


our %PROP_MAP = (
    subject         => 'summary',
    status          => 'status',
    owner           => 'owner',
    initialpriority => '_delete',
    finalpriority   => '_delete',
    told            => '_delete',
    requestors      => 'reported_by',
    admincc         => 'admin_cc',
    refersto        => 'refers_to',
    referredtoby    => 'referred_to_by',
    dependson       => 'depends_on',
    dependedonby    => 'depended_on_by',
    hasmember       => 'members',
    memberof        => 'member_of',
    priority        => 'priority_integer',
    resolved    => 'completed',
    due         => 'due',
    creator     => 'creator',
    timeworked => 'time_worked',
    timeleft  => 'time_left',
    lastupdated => '_delete',
    created     => '_delete',     # we should be porting the create date as a metaproperty

);

sub translate_prop_names {
    my $self      = shift;
    my $changeset = shift;

    for my $change ( $changeset->changes ) {
        next unless $change->node_type eq 'ticket';

        my @new_props;
        for my $prop ( $change->prop_changes ) {
            next if (( $PROP_MAP{ lc ( $prop->name ) } ||'') eq '_delete');
            $prop->name( $PROP_MAP{ lc( $prop->name ) } ) if $PROP_MAP{ lc( $prop->name ) };

            if ( $prop->name eq 'id' ) {
                    $prop->old_value( $prop->old_value . '@' . $changeset->original_source_uuid )
                        if ($prop->old_value||'') =~ /^\d+$/;
                    $prop->old_value( $prop->new_value . '@' . $changeset->original_source_uuid )
                        if ($prop->new_value||'') =~ /^\d+$/;

            }

            if ( $prop->name =~ /^cf-(.*)$/ ) {
                    $prop->name( 'custom-' . $1 );
            }

            push @new_props, $prop;

        }
        $change->prop_changes( \@new_props );

    }
    return $changeset;
}


1;