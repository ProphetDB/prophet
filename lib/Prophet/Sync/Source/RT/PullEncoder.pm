use warnings;
use strict;

package Prophet::Sync::Source::RT::PullEncoder;
use base qw/Class::Accessor/;
use Params::Validate qw(:all);
use UNIVERSAL::require;
use RT::Client::REST       ();
use RT::Client::REST::User ();
use RT::Client::REST::Ticket;

use Memoize;

__PACKAGE__->mk_accessors(qw/sync_source/);

our $DEBUG = $Prophet::Handle::DEBUG;





sub run {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, transactions => 1} );
    
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
                {   original_source_uuid => $self->sync_source->uuid,
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
            $self->translate_prop_names($changeset);

            unshift @changesets, $changeset unless $changeset->is_empty;
        } else {
            warn "not handling txn type $txn->{Type} for $txn->{id} (Ticket $args{ticket}{id}) yet";
            die YAML::Dump($txn);
        }


    }
    return \@changesets;
}

sub _recode_txn_CommentEmailRecord { return; }

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
            node_uuid   => $self->sync_source->uuid_for_url( $self->sync_source->rt_url . "/ticket/" . $args{'create_state'}->{'id'} ),
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
            node_uuid   => $self->sync_source->uuid_for_url( $self->sync_source->rt_url . "/ticket/" . $args{'create_state'}->{'id'} ),
            change_type => 'add_file'
        }
    );

    $args{'create_state'}->{'id'} =~ s/^ticket\///g;
    $args{'create_state'}->{ $self->sync_source->uuid . '-id' } = delete $args{'create_state'}->{'id'};

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
    my $self      = shift;
    my %args      = validate( @_, { ticket => 1, txn => 1, create_state => 1, changeset => 1 } );
    my $new_state = $args{'create_state'}->{ $args{'txn'}->{'Field'} };
    $args{'create_state'}->{ $args{'txn'}->{'Field'} } = $self->warp_list_to_old_value(
        $args{'create_state'}->{ $args{'txn'}->{'Field'} },
        $args{'txn'}->{'NewValue'},
        $args{'txn'}->{'OldValue'}
    );

    my $change = Prophet::Change->new(
        {   node_type   => 'ticket',
            node_uuid   => $self->sync_source->uuid_for_url( $self->sync_source->rt_url . "/ticket/" . $args{'create_state'}->{'id'} ),
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
            node_uuid   => $self->sync_source->uuid_for_url( $self->sync_source->rt_url . "/transaction/" . $args{'txn'}->{'id'} ),
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
            node_uuid   => $self->sync_source->uuid_for_url( $self->sync_source->rt_url . "/ticket/" . $args{'create_state'}->{'id'} ),
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
            node_uuid   => $self->sync_source->uuid_for_url( $self->url . "/ticket/" . $args{'create_state'}->{'id'} ),
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

    my $user = RT::Client::REST::User->new( rt => $self->sync_source->rt, id => $id )->retrieve;
    return $attr eq 'name' ? $user->name : $user->email_address;

}

memoize 'resolve_user_id_to';


sub warp_list_to_old_value {
    my $self         = shift;
    my $ticket_value = shift || '';
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
    resolved        => 'completed',
    due             => 'due',
    creator         => 'creator',
    timeworked      => 'time_worked',
    timeleft        => 'time_left',
    lastupdated     => '_delete',
    created         => '_delete',            # we should be porting the create date as a metaproperty

);

sub translate_prop_names {
    my $self      = shift;
    my $changeset = shift;

    for my $change ( $changeset->changes ) {
        next unless $change->node_type eq 'ticket';

        my @new_props;
        for my $prop ( $change->prop_changes ) {
            next if ( ( $PROP_MAP{ lc( $prop->name ) } || '' ) eq '_delete' );
            $prop->name( $PROP_MAP{ lc( $prop->name ) } ) if $PROP_MAP{ lc( $prop->name ) };

            if ( $prop->name eq 'id' ) {
                $prop->old_value( $prop->old_value . '@' . $changeset->original_source_uuid )
                    if ( $prop->old_value || '' ) =~ /^\d+$/;
                $prop->old_value( $prop->new_value . '@' . $changeset->original_source_uuid )
                    if ( $prop->new_value || '' ) =~ /^\d+$/;

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
