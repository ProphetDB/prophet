use Prophet::Test::Syntax;

with 'Prophet::Test';

test default => sub {
    my $self = shift;
    my $cxn  = $self->cxn;

    use_ok 'TestApp::Bug';

    my $record = TestApp::Bug->new( handle => $cxn );

    isa_ok $record, 'TestApp::Bug';
    isa_ok $record, 'Prophet::Record';

    my $uuid = $record->create(
        props => { name => 'Jesse', email => 'JeSsE@bestPractical.com' } );
    ok $uuid;
    is $record->prop('status'), 'new', 'default status';

    my $closed_record = TestApp::Bug->new( handle => $cxn );

    $uuid = $closed_record->create(
        props => {
            name   => 'Jesse',
            email  => 'JeSsE@bestPractical.com',
            status => 'closed'
        }
    );
    ok $uuid;
    is $closed_record->prop('status'), 'closed',
      'default status is overridable';

};

run_me;
done_testing;
