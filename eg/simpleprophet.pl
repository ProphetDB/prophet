#!/usr/bin/env perl

# PODNAME: simpleprophet.pl
# ABSTRACT: simple example of a Prophet-backed script

use v5.14.2;
use Prophet::App;
use Prophet::Search;
use Prophet::Record;
use Getopt::Long;
use Data::Printer;

my $opt = {};

my $prophet;

GetOptions($opt,
    'replica|r=s',
    'init',
    'add',
    'list',
    'clone',
    'src=s',
    'type=s',
    'name=s',
    'age=i',
) or die "Error in command line arguments\n";

if (!$opt->{replica}) {
    die "Can't do anything without a replica path\n";
}

$prophet = Prophet::App->new(local_replica_url => $opt->{replica},);

if ($opt->{init}) {
    say 'Initialising ' . $opt->{repo};
    $prophet->handle->initialize;
}

if ($opt->{add}) {

    my $record = Prophet::Record->new(
        handle => $prophet->handle,
        type   => $opt->{type},
    );

    my $uuid = $record->create(
        props => {
            name => $opt->{name},
            age  => $opt->{age},
        },
    );
}

if ($opt->{list}) {

    my $search = Prophet::Search->new(
        app_handle => $prophet,
        type       => $opt->{type},
        regex      => '.',
    );

    my $results = $search->run;
    for my $record (@$results) {
        say $record->uuid;
        my $props = $record->get_props;
        for my $key (keys %$props) {
            say "\t$key: $props->{$key}";
        }
    }
}


if ($opt->{clone}) {
    die "Not yet\n";
}
