use Prophet::Test::Syntax;

with 'Prophet::Test';

# test coverage for Prophet::Record references (subs register_reference,
# register_collection_reference, and register_record_reference)

test references => sub {
    my $self = shift;

    use_ok 'TestApp::ButterflyNet';
    my $net = new_ok 'TestApp::ButterflyNet' => [ handle => $self->cxn ];
    ok $net->create( props => { catches => 'butterflies' } );

    use_ok 'TestApp::BugCatcher';
    my $bugcatcher = new_ok 'TestApp::BugCatcher' =>
      [ app_handle => $self->app, handle => $self->cxn ];
    ok $bugcatcher->create( props => { net => $net->uuid, name => 'Larry' } );

    use_ok 'TestApp::Bug';
    my $monarch = new_ok 'TestApp::Bug' => [ handle => $self->cxn ];
    ok $monarch->create(
        props => {
            bugcatcher => $bugcatcher->uuid,
            species    => 'monarch'
        }
    );

    my $viceroy = new_ok 'TestApp::Bug' => [ handle => $self->cxn ];
    ok $viceroy->create(
        props => {
            bugcatcher => $bugcatcher->uuid,
            species    => 'viceroy'
        }
    );

    # test collection reference
    my @got = map { $_->uuid }
      sort { $a->uuid cmp $b->uuid } @{ $bugcatcher->bugs };

    my @expected = map { $_->uuid }
      sort { $a->uuid cmp $b->uuid } ( $monarch, $viceroy );

    is_deeply \@got, \@expected, "collection's record uuids match";

    is $bugcatcher->net->uuid, $net->uuid, 'record references match';
};

run_me;
done_testing;
