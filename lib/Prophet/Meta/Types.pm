package Prophet::Meta::Types;

# ABSTRACT: extra types for Prophet

use Any::Moose;
use Any::Moose 'Util::TypeConstraints';

enum 'Prophet::Type::ChangeType' => qw/add_file add_dir update_file delete/;
enum 'Prophet::Type::FileOpConflict' =>
  qw/delete_missing_file update_missing_file create_existing_file create_existing_dir/;

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

=head1 TYPES

=head2 Prophet::Type::ChangeType

A single change type: add_file, add_dir, update_file, delete.
