package TestApp::ButterflyNet;
use Moo;
extends 'Prophet::Record';

has type => (
    is      => 'bare',
    default => 'net',
);

1;
