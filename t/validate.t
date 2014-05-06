use Prophet::Test::Syntax;

with 'Prophet::Test';

test validate => sub {
    my $self = shift;
    use_ok 'TestApp::Bug';
    my $record = new_ok 'TestApp::Bug' => [ handle => $self->cxn ];

    isa_ok $record, 'Prophet::Record';

    ok $record->create( props => { name => 'Jesse', age => 31 } );

    like exception {
        $record->create( props => { name => 'Bob', age => 31 } );
    }, qr/validation error/i, 'Fails validation';

};

run_me;
done_testing;
