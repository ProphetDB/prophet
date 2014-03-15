package Prophet::Types;

# ABSTRACT: types for Prophet

use Type::Library -base;
use Type::Utils -all;

BEGIN { extends qw/Types::Standard Types::Path::Tiny/ }

declare 'ProphetChangeType',
  as enum( [qw/add_file add_dir update_file delete/] );

declare 'ProphetFileOpConflict',
  as enum( [qw/add_file add_dir update_file delete/] );

1;
