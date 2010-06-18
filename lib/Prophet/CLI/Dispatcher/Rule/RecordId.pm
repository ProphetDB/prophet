package Prophet::CLI::Dispatcher::Rule::RecordId;
use Any::Moose;
extends 'Path::Dispatcher::Rule::Regex';
with 'Prophet::CLI::Dispatcher::Rule';

use Prophet::CLIContext;

has '+regex' => (
    default => sub { qr/^$Prophet::CLIContext::ID_REGEX$/i },
);

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;
