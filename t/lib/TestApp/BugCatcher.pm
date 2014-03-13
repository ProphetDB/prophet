package TestApp::BugCatcher;
use Moo;
extends 'Prophet::Record';

has type => (
    is      => 'bare',
    default => 'bugcatcher',
);

__PACKAGE__->register_reference( bugs => 'TestApp::Bugs', by => 'bugcatcher' );
__PACKAGE__->register_reference( net => 'TestApp::ButterflyNet' );

1;
