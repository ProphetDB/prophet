use Prophet::Test::Syntax;

with 'Prophet::Test';

# tests for info command

test repo_info => sub {
  TODO: {
        todo_skip 'rework info into an api method', 1;
        my $alice_resolution_db_uuid;
        as_alice {
            my $cli = Prophet::CLI->new();
            $cli->handle->initialize;

            my $db_uuid      = $cli->handle->db_uuid;
            my $replica_uuid = $cli->handle->uuid;
            $alice_resolution_db_uuid =
              $cli->handle->resolution_db_handle->db_uuid;
            my $resolution_replica_uuid =
              $cli->handle->resolution_db_handle->uuid;

            my $output     = run_command('info');
            my $exp_output = qr{Records Database
----------------
Location:      file:///.*
Database UUID: $db_uuid
Replica UUID:  $replica_uuid
Changesets:    0
Known types:

Resolutions Database
--------------------
Location:      file://.*
Database UUID: $alice_resolution_db_uuid
Replica UUID:  $resolution_replica_uuid
Changesets:    0
};
            like( $output, $exp_output, 'info command output' );
        };

        # regression test for 7A041904-66AB-11DD-AE9D-77633178437E
        as_bob {
            my $cli = Prophet::CLI->new();
            $cli->handle->initialize;

            my $bob_resolution_db_uuid =
              $cli->handle->resolution_db_handle->db_uuid;

            my ( undef, $error ) =
              run_command( 'pull', '--from', repo_uri_for('alice') );
            my $exp_error = <<"END_ERROR";
You are trying to merge two different databases! This is NOT
recommended. If you really want to do this,  add '--force' to
your commandline.

Local database:  $bob_resolution_db_uuid
Remote database: $alice_resolution_db_uuid
END_ERROR
            is( $error, $exp_error,
                'local/remote database correct in merge warning' );
        };
    }
};

run_me;
done_testing;

