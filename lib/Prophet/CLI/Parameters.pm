#!/usr/bin/env perl
package Prophet::CLI::Parameters;
use Moo::Role;

sub cli {
    return $Prophet::CLI::Dispatcher::cli;
}

sub context {
    my $self = shift;
    $self->cli->context;
}


1;

