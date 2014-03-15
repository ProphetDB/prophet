package Prophet::Web::Result;
use Moo;

use Prophet::Web::FunctionResult;
use Prophet::Types qw/Bool HashRef Str/;

has success => ( isa => Bool, is => 'rw');
has message => ( isa => Str, is => 'rw');
has functions => (
    is      => 'rw',
    isa     => HashRef,
    default => sub { {} },
);

sub get    { $_[0]->functions->{ $_[1] } }
sub set    { $_[0]->functions->{ $_[1] } = $_[2] }
sub exists { exists $_[0]->functions->{ $_[1] } }
sub items  { keys %{ $_[0]->functions } }

1;

