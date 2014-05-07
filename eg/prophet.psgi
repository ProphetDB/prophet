#!/usr/bin/env plackup

use v5.14.2;
use strictures;
use Plack::Builder;
use Prophet::App;
use Prophet::Server;
use Path::Tiny;

my $new_repo = 0;

unless (exists $ENV{PROPHET_REPO}) {
    my $base = Path::Tiny->tempdir( CLEANUP => 0 );
    my $repo = $base->child("repo-$$");
    $repo->mkpath && say "Created temp repo in $repo";
    $ENV{PROPHET_REPO} = $repo;
}

my $p_app = Prophet::App->new;
if ($new_repo) {
    $p_app->handle->initialize || die;
}

my $prophet = Prophet::Server->new(app_handle => $p_app);

builder {
    $prophet->psgi;
};
