package Prophet::Role::Common;

# ABSTRACT: Common parts of a Prophet app

use v5.10.2;
use Moo::Role;
use Types::Standard 'InstanceOf';

has app_handle => (
    is        => 'ro',
    isa       => InstanceOf ['Prophet::App'],
    weak_ref  => 1,
    predicate => 1,
    required  => 1,
);

1;
