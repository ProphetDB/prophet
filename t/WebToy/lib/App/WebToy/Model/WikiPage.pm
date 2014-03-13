package App::WebToy::Model::WikiPage;
use Moo;
extends 'Prophet::Record';
has type => ( default => 'wikipage' );

sub declared_props {qw(title content tags mood)}

sub default_prop_content {
    'This page has no content yet';
}


1;

