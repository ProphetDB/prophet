package Prophet::App;

# ABSTRACT: Main Prophet application module

use v5.14.2;
use Moo;

use Path::Tiny;
use Prophet::Config;
use Prophet::UUIDGenerator;
use Params::Validate qw/validate validate_pos/;
use Prophet::Types qw/InstanceOf Str/;
use Prophet::Replica;

has handle => (
    is  => 'lazy',
    isa => InstanceOf ['Prophet::Replica'],
);

sub _build_handle {
    my $self = shift;

    return Prophet::Replica->get_handle(
        url        => $self->local_replica_url,
        app_handle => $self,
    );
}

=attr local_replica_url

Returns the URL of the current local replica. Defaults to C<$ENV{PROPHET_REPO}>

=cut

has local_replica_url => (
    is      => 'ro',
    lazy    => 1,
    isa     => Str,
    default => sub {
        $ENV{PROPHET_REPO} if $ENV{PROPHET_REPO};
    },
    coerce => sub {
        my $path = shift;
        if ( defined $path && $path !~ /^[\w\+]{2,}\:/ ) {

            # the reason why we need {2,} is to not match name on windows, e.g. C:\foo
            $path = path($path)->realpath;
            say $path;
            return "file://$path";
        }
    }
);

has config => (
    is      => 'rw',
    isa     => InstanceOf ['Prophet::Config'],
    default => sub {
        my $self = shift;
        return Prophet::Config->new(
            app_handle => $self,
            confname   => 'prophetrc',
        );
    },
    documentation => "This is the config instance for the running application",
);

use constant DEFAULT_REPLICA_TYPE => 'prophet';

=method default_replica_type

Returns a string of the the default replica type for this application.

=cut

sub default_replica_type {
    my $self = shift;
    return $ENV{'PROPHET_REPLICA_TYPE'} || DEFAULT_REPLICA_TYPE;
}

sub require {
    my $self  = shift;
    my $class = shift;
    $self->_require( module => $class );
}

sub try_to_require {
    my $self  = shift;
    my $class = shift;
    $self->_require( module => $class, quiet => 1 );
}

sub _require {
    my $self  = shift;
    my %args  = ( module => undef, quiet => undef, @_ );
    my $class = $args{'module'};

    # Quick hack to silence warnings.
    # Maybe some dependencies were lost.
    unless ($class) {
        warn sprintf( "no class was given at %s line %d\n", (caller)[ 1, 2 ] );
        return 0;
    }

    return 1 if $self->already_required($class);

    # .pm might already be there in a weird interaction in Module::Pluggable
    my $file = $class;
    $file .= ".pm"
      unless $file =~ /\.pm$/;

    $file =~ s/::/\//g;

    my $retval = eval {
        local $SIG{__DIE__} = 'DEFAULT';
        CORE::require "$file";
    };

    my $error = $@;
    if ( my $message = $error ) {
        $message =~ s/ at .*?\n$//;
        if ( $args{'quiet'} and $message =~ /^Can't locate \Q$file\E/ ) {
            return 0;
        } elsif ( $error !~ /^Can't locate $file/ ) {
            die $error;
        } else {
            warn sprintf( "$message at %s line %d\n", ( caller(1) )[ 1, 2 ] );
            return 0;
        }
    }

    return 1;
}

=method already_required class

Helper function to test whether a given class has already been require'd.

=cut

sub already_required {
    my ( $self, $class ) = @_;

    return 0 if $class =~ /::$/;    # malformed class

    my $path = join( '/', split( /::/, $class ) ) . ".pm";
    return ( $INC{$path} ? 1 : 0 );
}

sub set_db_defaults {
    my $self     = shift;
    my $settings = $self->database_settings;
    for my $name ( keys %$settings ) {
        my ( $uuid, @metadata ) = @{ $settings->{$name} };

        my $s = $self->setting(
            label   => $name,
            uuid    => $uuid,
            default => \@metadata,
        );

        $s->initialize;
    }
}

sub setting {
    my $self = shift;
    my %args = validate( @_, { uuid => 0, default => 0, label => 0 } );
    require Prophet::DatabaseSetting;

    my ( $uuid, $default );

    if ( $args{uuid} ) {
        $uuid    = $args{'uuid'};
        $default = $args{'default'};
    } elsif ( $args{'label'} ) {
        ( $uuid, $default ) =
          @{ $self->database_settings->{ $args{'label'} } };
    }
    return Prophet::DatabaseSetting->new(
        handle  => $self->handle,
        uuid    => $uuid,
        default => $default,
        label   => $args{label}
    );

}

sub database_settings { {} }    # XXX wants a better name

sub log_debug {
    my $self = shift;
    return unless ( $ENV{'PROPHET_DEBUG'} );
    $self->log(@_);
}

=method log $MSG

Logs the given message to C<STDERR> (but only if the C<PROPHET_DEBUG>
environmental variable is set).

=cut

sub log {
    my $self = shift;
    my ($msg) = validate_pos( @_, 1 );
    print STDERR $msg . "\n";    # if ($ENV{'PROPHET_DEBUG'});
}

=method log_fatal $MSG

Logs the given message and dies with a stack trace.

=cut

sub log_fatal {
    my $self = shift;

    # always skip this fatal_error function when generating a stack trace
    local $Carp::CarpLevel = $Carp::CarpLevel + 1;

    $self->log(@_);
    Carp::confess(@_);
}

sub current_user_email {
    my $self = shift;
    return
         $self->config->get( key => 'user.email-address' )
      || $ENV{'PROPHET_EMAIL'}
      || $ENV{'EMAIL'};

}

=method display_name_for_replica UUID

Returns a "friendly" id for the replica with the given uuid. UUIDs are for
computers, friendly names are for people. If no name is found, the friendly
name is just the UUID.

=cut

# friendly names are replica subsections in the config file

use Memoize;
memoize('display_name_for_replica');

sub display_name_for_replica {
    my $self = shift;
    my $uuid = shift;

    return 'Unknown replica!' unless $uuid;
    my %possibilities =
      $self->config->get_regexp( key => '^replica\..*\.uuid$' );

    # form a hash of uuid -> name
    my %sources_by_uuid = map {
        my $uuid = $possibilities{$_};
        $_ =~ /^replica\.(.*)\.uuid$/;
        my $name = $1;
        ( $uuid => $name );
    } keys %possibilities;
    return exists $sources_by_uuid{$uuid} ? $sources_by_uuid{$uuid} : $uuid;
}

1;
