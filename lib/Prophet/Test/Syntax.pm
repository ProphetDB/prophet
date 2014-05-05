package Prophet::Test::Syntax;

use v5.14.2;
use Syntax::Collector -collect => q{
   use feature 0 ':5.14';
   use autodie 2.21;
   use Path::Tiny 0;
   use Test::Roo 1.000;
   use Test::Fatal 0.012;
   use lib 0 't/lib';
};

1;
