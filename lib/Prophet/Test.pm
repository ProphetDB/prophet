package Prophet::Test;

use v5.14.2;

use Test::Roo::Role;
use Prophet::App;

has app => (is => 'ro', default => sub { new_ok 'Prophet::App' } );

has repo_base => (
    is      => 'ro',
    default => sub {
        my $base = Path::Tiny->tempdir( CLEANUP => !$ENV{PROPHET_DEBUG} );
        diag "Replicas can be found in $base";
        return $base;
    },
);

has cxn => (is => 'lazy');

sub _build_cxn {
    my $self = shift;
    my $cxn  = $self->app->handle;
    isa_ok $cxn, 'Prophet::Replica', 'Got the cxn';
    ok $cxn->initialize, 'Replica initialzed';
    return $cxn;
}

before setup => sub {
    $ENV{PROPHET_REPO} = $_[0]->repo_base->child("repo-$$");
};

# by default, load no configuration file
$ENV{PROPHET_APP_CONFIG} = '';

{
    no warnings 'redefine';
    require Test::More;

    sub Test::More::diag {    # bad bad bad # convenient convenient convenient
        Test::More->builder->diag(@_)
          if ( $Test::Harness::Verbose || $ENV{'TEST_VERBOSE'} );
    }
}

sub import_extra {
    my $class = shift;
    my $args  = shift;

    Test::More->export_to_level(2);

    # Now, clobber Test::Builder::plan (if we got given a plan) so we
    # don't try to spit one out *again* later
    if ( $class->builder->has_plan ) {
        no warnings 'redefine';
        *Test::Builder::plan = sub { };
    }

    delete $ENV{'PROPHET_APP_CONFIG'};
    $ENV{'PROPHET_EMAIL'} = 'nobody@example.com';
}

=func in_gladiator($code)

Run the given code using L<Devel::Gladiator>.

=cut

sub in_gladiator (&) {
    my $code = shift;
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $types;
    eval { require Devel::Gladiator; };
    if ($@) {
        warn 'Devel::Gladiator not found';
        return $code->();
    }
    for ( @{ Devel::Gladiator::walk_arena() } ) {
        $types->{ ref($_) }--;
    }

    $code->();
    for ( @{ Devel::Gladiator::walk_arena() } ) {
        $types->{ ref($_) }++;
    }
    map { $types->{$_} || delete $types->{$_} } keys %$types;

}

=func repo_path_for($username)

Returns a path on disk for where $username's replica is stored.

=cut

sub repo_path_for {
    my ( $self, $username ) = @_;
    return $self->repo_base->child($username);
}

sub config_file_for {
    my ( $self, $username ) = @_;
    return $self->repo_base->child( $username, 'config' );
}

=func repo_uri_for($username)

Returns a file:// URI for $USERNAME'S replica (with the correct replica type
prefix).

=cut

sub repo_uri_for {
    my $username = shift;

    my $path = repo_path_for($username);

    return 'file://' . $path;
}

=func as_user($username, $coderef)

Run this code block as $username.  This routine sets up the %ENV hash so that
when we go looking for a repository, we get the user's repo.

=cut

our %REPLICA_UUIDS;
our %DATABASE_UUIDS;

sub as_user {
    my ( $self, $username ) = @_;

    $ENV{PROPHET_REPO}       = $self->repo_path_for($username);
    $ENV{PROPHET_EMAIL}      = $username . '@example.com';
    $ENV{PROPHET_APP_CONFIG} = $self->config_file_for($username);

    # $REPLICA_UUIDS{$username}  = replica_uuid;
    # $DATABASE_UUIDS{$username} = database_uuid;

    return;
}

=func replica_uuid_for($username)

Returns the UUID of the given user's test replica.

=cut

sub replica_uuid_for {
    my $user = shift;
    return $REPLICA_UUIDS{$user};
}

=func database_uuid_for($username)

Returns the UUID of the given user's test database.

=cut

sub database_uuid_for {
    my $user = shift;
    return $DATABASE_UUIDS{$user};
}

=func ok_added_revisions( { CODE }, $numbers_of_new_revisions, $msg)

Checks that the given code block adds the given number of changes to the test
replica. $msg is optional and will be printed with the test if given.

=cut

sub ok_added_revisions (&$$) {
    my ( $code, $num, $msg ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $last_rev = replica_last_rev();
    $code->();
    is( replica_last_rev(), $last_rev + $num, $msg );
}

=func serialize_conflict($conflict_obj)

Returns a simple, serialized version of a L<Prophet::Conflict> object suitable
for comparison in tests.

The serialized version is a hash reference containing the following keys:
  meta => { original_source_uuid => 'source_replica_uuid' }
  records => {
      'record_uuid' => {
          change_type => 'type',
          props => {
              propchange_name => {
                  source_old => 'old_val',
                  source_new => 'new_val',
                  target_old => 'target_val',
              }
          }
      },
      another_record_uuid' => {
          change_type => 'type',
          props => {
              propchange_name => {
                  source_old => 'old_val',
                  source_new => 'new_val',
                  target_old => 'target_val',
              }
          }
      },
  }

=cut

sub serialize_conflict {
    my ($conflict_obj) = validate_pos( @_, { isa => 'Prophet::Conflict' } );
    my $conflicts;
    for my $change ( @{ $conflict_obj->conflicting_changes } ) {
        $conflicts->{meta} = { original_source_uuid =>
              $conflict_obj->changeset->original_source_uuid };
        $conflicts->{records}->{ $change->record_uuid } =
          { change_type => $change->change_type, };

        for my $propchange ( @{ $change->prop_conflicts } ) {
            $conflicts->{records}->{ $change->record_uuid }->{props}
              ->{ $propchange->name } = {
                source_old => $propchange->source_old_value,
                source_new => $propchange->source_new_value,
                target_old => $propchange->target_value
              }

        }
    }
    return $conflicts;
}

=func serialize_changeset($changeset_obj)

Returns a simple, serialized version of a L<Prophet::ChangeSet> object suitable
for comparison in tests (a hash).

=cut

sub serialize_changeset {
    my ($cs) = validate_pos( @_, { isa => 'Prophet::ChangeSet' } );

    return $cs->as_hash;
}

=func load_record($type, $uuid)

Loads and returns a record object for the record with the given type and uuid.

=cut

sub load_record {
    my ( $self, $type, $uuid, $cxn ) = @_;

    require Prophet::Record;

    $cxn ||= $self->cxn;
    my $record = Prophet::Record->new( handle => $cxn, type => $type );
    $record->load( uuid => $uuid );
    return $record;
}

=func as_alice CODE, as_bob CODE, as_charlie CODE, as_david CODE

Runs CODE as alice, bob, charlie or david.

=cut

sub as_alice   { $_[0]->as_user('alice') }
sub as_bob     { $_[0]->as_user('bob') }
sub as_charlie { as_user( charlie => shift ) }
sub as_david   { as_user( david => shift ) }

# END {
#     for (qw(alice bob charlie david)) {

#         #     as_user( $_, sub { rmtree [ $ENV{'PROPHET_REPO'} ] } );
#     }
# }

1;
