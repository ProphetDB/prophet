#!/usr/bin/perl

use warnings;
use strict;
use Test::Exception;

use Prophet::Test tests => 19;

as_alice {
    run_ok( 'prophet-node-create', [qw(--type Bug --status new --from alice )], "Created a record as alice" );
    run_output_matches( 'prophet-node-search', [qw(--type Bug --regex .)], [qr/new/], " Found our record" );
};

diag('Bob syncs from alice');

my $record_id;

as_bob {

    run_ok( 'prophet-node-create', [qw(--type Dummy --ignore yes)], "Created a dummy record" );

    run_ok( 'prophet-merge', [ '--to', repo_uri_for('bob'), '--from', repo_uri_for('alice') ], "Sync ran ok!" );

    # check our local replicas
    my ( $ret, $out, $err ) = run_script( 'prophet-node-search', [qw(--type Bug --regex .)] );
    like( $out, qr/new/, "We have the one node from alice" );
    if ( $out =~ /^(.*?)\s./ ) {
        $record_id = $1;
    }
    diag($record_id);

    run_ok( 'prophet-node-update', [ '--type', 'Bug', '--uuid', $record_id, '--status' => 'stalled' ] );
    run_output_matches( 'prophet-node-show', [ '--type', 'Bug', '--uuid', $record_id ],
        [ 'id: ' . $record_id, 'status: stalled', 'from: alice' ],
        'content is correct' );
};

as_alice {
    run_ok( 'prophet-node-update', [ '--type', 'Bug', '--uuid', $record_id, '--status' => 'open' ] );
    run_output_matches( 'prophet-node-show', [ '--type', 'Bug', '--uuid', $record_id ],
        [ 'id: ' . $record_id, 'status: open', 'from: alice' ],
        'content is correct' );

};

# This conflict, we can autoresolve

as_bob {
    use_ok('Prophet::Sync::Source::SVN');

    my $source = Prophet::Sync::Source->new( { url => repo_uri_for('alice') } );
    my $target = Prophet::Sync::Source->new( { url => repo_uri_for('bob') } );

    my $conflict_obj;

    throws_ok {
        $target->import_changesets(
            from => $source,
        );
    } qr/not resolved/;

    throws_ok {
        $target->import_changesets(
            from => $source,
            resolver => sub { die "my way of death\n" },
        );
    } qr/my way of death/, 'our resolver is actually called';

    ok_added_revisions( sub {

            $target->import_changesets(
                from     => $source,
                resolver => $target->always_mine_resolver )
    }, 3, '3 revisions since the merge' );

    my @changesets = fetch_newest_changesets(3);

    my $resolution = $changesets[2];
    ok( $resolution->is_resolution, 'marked as resolution' );
    my $repo = repo_uri_for('bob');

    #    diag `svn log -v $repo`;


    check_bob_final_state_ok(@changesets);
};
as_alice {
    my $source = Prophet::Sync::Source->new( { url => repo_uri_for('bob') } );
    my $target = Prophet::Sync::Source->new( { url => repo_uri_for('alice') } );

    throws_ok {
        $target->import_changesets(
            from      => $source,
        );
    } qr/not resolved/;

    $target->import_changesets(
        from => $source,
        use_resdb => 1,
    );

    lives_and {
        ok_added_revisions( sub {
                $target->import_changesets(
                    from => $source );
        }, 0, 'no more changes to sync' );

    };
};

as_bob {
    my $source = Prophet::Sync::Source->new( { url => repo_uri_for('alice') } );
    my $target = Prophet::Sync::Source->new( { url => repo_uri_for('bob') } );

    lives_and {
        ok_added_revisions( sub {
                $target->import_changesets(
                    from => $source );
        }, 0, 'no more changes to sync' );

    };


    check_bob_final_state_ok(fetch_newest_changesets(3));


};

our $ALICE_LAST_REV_CACHE;

sub check_bob_final_state_ok {
    my (@changesets) = (@_);

    $ALICE_LAST_REV_CACHE ||= as_alice { replica_last_rev()};

    my @hashes = map { $_->as_hash} @changesets;
    is_deeply(
        \@hashes,
        [   {   changes =>{ 
                    $record_id => {
                        change_type  => 'update_file',
                        node_type    => 'Bug',
                        prop_changes => {
                            status => {
                                old_value => 'stalled',
                                new_value => 'new'
                            }
                        }
                    }
                },
                is_empty             => 0,
                is_nullification     => 1,
                is_resolution        => undef,
                sequence_no          => (replica_last_rev()-2),
                original_sequence_no => (replica_last_rev() -2),
                source_uuid          =>  replica_uuid(),
                original_source_uuid =>  replica_uuid(),
            },
            {   is_empty             => 0,
                is_nullification     => undef,
                is_resolution        => undef,
                sequence_no          => (replica_last_rev()-1),
                original_sequence_no => $ALICE_LAST_REV_CACHE,
                source_uuid          => replica_uuid(),
                original_source_uuid => as_alice{replica_uuid()},
                changes              => {
                    $record_id => {
                        node_type    => 'Bug',
                        change_type  => 'update_file',
                        prop_changes => {
                            status => { old_value => 'new', new_value => 'open' }

                            }

                    },
                    as_alice { replica_uuid() } => {
                        node_type => '_merge_tickets',
                        change_type => 'update_file',
                        prop_changes => {
                            'last-changeset' => { old_value => $ALICE_LAST_REV_CACHE-1, new_value => $ALICE_LAST_REV_CACHE
                            }
                        }

                    }
                }
            },

            {   is_empty             => 0,
                is_nullification     => undef,
                is_resolution        => 1,
                sequence_no          => replica_last_rev(),
                original_sequence_no => replica_last_rev(),
                source_uuid          => replica_uuid(),
                original_source_uuid => replica_uuid(),
                changes              => {
                    $record_id => {
                        node_type    => 'Bug',
                        change_type  => 'update_file',
                        prop_changes => {
                            status => { old_value => 'open', new_value => 'stalled' }


                            }

                    }
                }

            }
        ],
    "Bob's final state is as we expect");
}