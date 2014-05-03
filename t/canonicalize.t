use Prophet::Test::Syntax;
with 'Prophet::Test';

test canonicalize => sub {
    my $self = shift;
    my $cxn  = $self->cxn;

    use_ok 'TestApp::Bug';

    my $record = TestApp::Bug->new( handle => $cxn );

    isa_ok $record, 'TestApp::Bug';
    isa_ok $record, 'Prophet::Record';

    my $uuid = $record->create(
        props => { name => 'Jesse', email => 'JeSsE@bestPractical.com' } );
    ok $uuid;
    is $record->prop('email'), 'jesse@bestpractical.com';
};

run_me;
done_testing;
