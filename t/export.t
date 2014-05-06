use Prophet::Test::Syntax;

with 'Prophet::Test';

test export => sub {
    my $self = shift;
    require Prophet::Record;

    my $alice = Prophet::Record->new( handle => $self->cxn, type => 'Bug' );
    ok my $uuid =
      $alice->create( props => { status => 'new', from => 'alice' } ),
      'created a record as alice';

    diag 'Bob syncs from alice';

    # my $record_id;

    # as_bob {
    # diag $self->repo_uri_for('bob');
    # diag $self->repo_uri_for('alice');

    #     ok( run_command( 'clone', '--from', repo_uri_for('alice'), '--force' ),
    #         'Sync ran ok!' );
    #     ok( run_command(qw(create --type Dummy -- --ignore yes)),
    #         'Created a dummy record' );

    #     # check our local replicas
    #     my $out = run_command(qw(search --type Bug --regex .));
    #     like( $out, qr/new/, 'We have the one record from alice' );
    #     if ( $out =~ /'uuid': '(.*?)'\s./ ) {
    #         $record_id = $1;
    #     }
    #     diag($record_id);

    #     ok(
    #         run_command(
    #             'update',   '--type',
    #             'Bug',      '--uuid',
    #             $record_id, '--',
    #             '--status' => 'stalled'
    #         ),
    #         'update record'
    #     );
    #     $out =
    #       run_command( 'show', '--type', 'Bug', '--uuid', $record_id, '--batch' );
    #     my $alice_uuid = replica_uuid_for('alice');
    #     my $expected   = qr/id: (\d+) \($record_id\)
    # creator: alice\@example.com
    # from: alice
    # original_replica: $alice_uuid
    # status: stalled
    # /;
    #     like( $out, $expected, 'content is correct' );

    #     my $path = tempdir( CLEANUP => !$ENV{PROPHET_DEBUG} );

    #     ok( run_command( 'export', '--path', $path ), 'export ok' );

    #     my $cli = Prophet::CLI->new;
    #     ok( -d $path, 'found db-uuid root ' . $path );
    #     ok( -e File::Spec->catdir( $path => 'replica-uuid' ),
    #         'found replica uuid file' );
    #     lives_and {
    #         is(
    #             Prophet::Util->slurp(
    #                 File::Spec->catdir( $path => 'replica-uuid' )
    #             ),
    #             replica_uuid()
    #         );
    #     };

    #     ok( -e Prophet::Util->catfile( $path => 'changesets.idx' ),
    #         'found changesets index' );
    #     my $latest =
    #       Prophet::Util->slurp(
    #         Prophet::Util->catfile( $path => 'latest-sequence-no' ) );
    #     is( $latest, $cli->handle->latest_sequence_no );
    #     use_ok('Prophet::Replica::prophet');
    #     diag("Checking changesets in $path");
    #     my $changesets = Prophet::Replica->get_handle(
    #         {
    #             url        => 'prophet:file://' . $path,
    #             app_handle => Prophet::CLI->new->app_handle
    #         }
    #     )->fetch_changesets( after => 0 );
    #     my @changesets = grep { $_->has_changes } @$changesets;
    #     is( $#changesets, 2, "We found a total of 3 changesets" );

    #     # XXX: compare the changeset structure
    #     is(
    #         lc( $changesets->[-1]->{source_uuid} ),
    #         lc( $changesets->[-1]->{original_source_uuid} )
    #     );

    # };
};

run_me;
done_testing;
