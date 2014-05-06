use Prophet::Test::Syntax;

with 'Prophet::Test';

test 'local metadata' => sub {
    my $self = shift;

    ok $self->app->handle->store_local_metadata( foo => 'bar' );
    is $self->app->handle->fetch_local_metadata('Foo'), 'bar';
    ok $self->app->handle->store_local_metadata( Foo => 'bartwo' );
    is $self->app->handle->fetch_local_metadata('foo'), 'bartwo';
    ok $self->app->handle->store_local_metadata( foo => 'barTwo' );
    is $self->app->handle->fetch_local_metadata('foo'), 'barTwo';

};

run_me;
done_testing;
