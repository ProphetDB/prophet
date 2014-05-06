package App::Record;
use Moo;
extends 'Prophet::Record';

sub validate_prop_point {
    my ( $self, %args ) = @_;

    return 1 if $args{props}{point} =~ m/^\d+$/;
    $args{errors}{point} = 'must be numbers';
    return 0;

}

package main;
use Prophet::Test::Syntax;

with 'Prophet::Test';

test validate1 => sub {
    my $self = shift;
    use_ok 'TestApp::Bug';
    my $record = new_ok 'TestApp::Bug' => [ handle => $self->cxn ];

    isa_ok $record, 'Prophet::Record';

    ok $record->create( props => { name => 'Jesse', age => 31 } );

    like exception {
        $record->create( props => { name => 'Bob', age => 31 } );
    }, qr/validation error/i, 'Fails validation';

};

test validate2 => sub {
    my $self = shift;

    my $rec = App::Record->new( handle => $self->cxn, type => 'foo' );

    ok $rec->create( props => { foo => 'bar', point => '123' } );

    like exception {
        $rec->create( props => { foo => 'bar', point => 'orz' } ),;
    }, qr/must be numbers/, 'Fails validation';
};

run_me;
done_testing;
