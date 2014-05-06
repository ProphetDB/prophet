package App::Record;
use Moo;
extends 'Prophet::Record';

package App::Record::Thingy;
use Moo;
extends 'App::Record';

sub type {'foo'}

package main;
use Prophet::Test::Syntax;
with 'Prophet::Test';

test history => sub {
    my $self = shift;
    $self->cxn;

    my $rec =
      App::Record::Thingy->new( handle => $self->app->handle, type => 'foo' );

    ok $rec->create( props => { foo => 'bar', point => '123' } );
    is $rec->prop('foo'),   'bar';
    is $rec->prop('point'), '123';
    ok $rec->set_props( props => { foo => 'abc' } );
    is $rec->prop('foo'), 'abc';
    ok $rec->set_props( props => { foo => 'def' } );
    is $rec->prop('foo'), 'def';

    my @history = $rec->changesets;
    is scalar @history, 3;
};

run_me;
done_testing;
