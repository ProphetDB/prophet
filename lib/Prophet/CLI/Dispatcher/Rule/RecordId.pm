package Prophet::CLI::Dispatcher::Rule::RecordId;
use Moo;
extends 'Path::Dispatcher::Rule::Regex';
with 'Prophet::CLI::Dispatcher::Rule';

use Prophet::CLIContext;
use Prophet::Types qw/RegexpRef Str/;

#has '+regex' => ( default => sub {qr/^$Prophet::CLIContext::ID_REGEX$/i} );
has regex => (
    is      => 'ro',
    isa     => RegexpRef,
    default => sub {qr/^$Prophet::CLIContext::ID_REGEX$/i}
);

has type => (
    is  => 'ro',
    isa => Str,
);

sub complete {
    my $self = shift;
    my $path = shift->path;

    my $handle = $self->cli->app_handle->handle;

    my @types = $self->type || @{ $handle->list_types };

    my @ids;
    for my $type (@types) {
        push @ids,
          grep { substr( $_, 0, length($path) ) eq $path }
          map { ( $_->uuid, $_->luid ) } @{
            $handle->list_records(
                type         => $type,
                record_class => $self->cli->record_class,
            )
          };
    }
    return @ids;
}

1;

