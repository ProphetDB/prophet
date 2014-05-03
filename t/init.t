use Prophet::Test::Syntax;

with 'Prophet::Test';

before setup => sub { $_[0]->as_alice };

test 'init repo' => sub {
    my $self = shift;

    is(
        exception { $self->app->handle->initialize },
        undef, 'repo initialized',
    );

    like(
        exception { $self->app->handle->initialize },
        qr/^This replica already exists/,
        'repo NOT initialized, already exists',
    );
};

run_me;
done_testing;
