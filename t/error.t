use Prophet::Test::Syntax;
with 'Prophet::Test';

test push_errors => sub {
    my $self = shift;

    # testing various error conditions that don't make sense to test anywhere else

    my $no_replica =
      Path::Tiny->tempdir( CLEANUP => !$ENV{PROPHET_DEBUG} )->child("repo-$$");

    my @cmds = (
        {
            cmd => [ 'push', '--to', $no_replica ],
            error   => [ "No replica found at '$no_replica'.", ],
            comment => 'push to nonexistant replica',
        },
        {
            cmd   => [ 'push', '--to', 'http://foo.com/bar' ],
            error => [
                    "Can't push to HTTP replicas! You probably want to publish"
                  . " instead.",
            ],
            comment => 'push to HTTP replica',
        },
    );
  TODO: {
        todo_skip 'change push API', 2;
        for my $item (@cmds) {
            my $exp_error =
              defined $item->{error}
              ? ( join "\n", @{ $item->{error} } ) . "\n"
              : '';
            my ( $got_output, $got_error ) = run_command( @{ $item->{cmd} } );
            is( $got_error, $exp_error, $item->{comment} );
        }
    }
};

run_me;
done_testing;
