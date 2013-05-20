package Prophet::Config;
{
  $Prophet::Config::VERSION = '0.751';
}

# ABSTRACT: Prophet's configuration object

use Any::Moose;
use File::Spec;
use Prophet::Util;
extends 'Config::GitLike';

has app_handle => (
    is       => 'ro',
    weak_ref => 1,
    isa      => 'Prophet::App',
    required => 1
);

use constant FORMAT_VERSION => 0;

# reload config after setting values
override group_set => sub {
    my $self = shift;
    my ( $filename, $args_ref, $override ) = @_;

    # Set a config format version on this config file if
    # it doesn't have one already.
    unshift @$args_ref,
      {
        key   => 'core.config-format-version',
        value => $self->FORMAT_VERSION,
      }
      unless _file_has_config_format_version($filename);

    $self->SUPER::group_set( $filename, $args_ref );
    $self->load unless $override;
};

sub _file_has_config_format_version {
    my $filename = shift;
    my $content = -f $filename ? Prophet::Util->slurp($filename) : '';

    return $content =~ 'core.config-format-version';
}

# per-replica config filename
override dir_file => sub {'config'};

# Override the replica config file with the PROPHET_APP_CONFIG
# env var if it's set. Also, don't walk up the given path if no replica
# config is found.
override load_dirs => sub {
    my $self = shift;

    $self->load_file( $self->replica_config_file )
      if -f $self->replica_config_file;
};

# If PROPHET_APP_CONFIG is set, don't load anything else
override user_file => sub {
    my $self = shift;

    return exists $ENV{PROPHET_APP_CONFIG} ? '' : $self->SUPER::user_file(@_);
};

override global_file => sub {
    my $self = shift;

    return
      exists $ENV{PROPHET_APP_CONFIG} ? '' : $self->SUPER::global_file(@_);
};


# grab all values in the 'alias' section (of the file, if given) and strip
# away the section name
sub aliases {
    my $self = shift;
    my $file = shift;

    my %new_aliases;
    if ($file) {

        # parse the given config file with parse_content and use the
        # callbacks to add to an array
        my $content = -f $file ? Prophet::Util->slurp($file) : '';
        $self->parse_content(
            content  => $content,
            callback => sub {
                my %args = @_;
                return unless defined $args{name};
                if ( $args{section} eq 'alias' ) {
                    $new_aliases{ $args{name} } = $args{value};
                }
            },

            # Most of the time this error sub won't get triggered since
            # Prophet loads the config file whenever it first tries to use
            # a value from the config file, and errors are detected at that
            # point. This always happens before this since every command
            # triggers alias processing. So this should really only explode
            # if we're running a shell and the config file has changed
            # in a bad way since we started up.
            error => sub {
                Config::GitLike::error_callback( @_, filename => $file );
            },
        );
    } else {
        my %aliases = $self->get_regexp( key => '^alias\.' );

        %new_aliases = map {
            my $alias = $_;
            $alias =~ s/^alias\.//;
            ( $alias => $aliases{$_} );
        } keys %aliases;
    }

    return wantarray ? %new_aliases : \%new_aliases;
}


# grab all the replicas we know of and return a hash of
# name => variable, or variable => name if $args{by_variable} is true
sub sources {
    my $self = shift;
    my %args = (
        by_url   => undef,
        variable => 'url',
        @_,
    );

    my %sources =
      $self->get_regexp( key => "^replica[.].*[.]$args{variable}\$" );
    my %new_sources = map {
        $_ =~ /^replica\.(.*)\.$args{variable}$/;
        $args{by_variable} ? ( $sources{$_} => $1 ) : ( $1 => $sources{$_} );
    } keys %sources;

    return wantarray ? %new_sources : \%new_sources;
}


sub replica_config_file {
    my $self = shift;

    return exists $ENV{PROPHET_APP_CONFIG}
      ? $ENV{PROPHET_APP_CONFIG}
      : Prophet::Util->catfile( $self->app_handle->handle->fs_root,
        $self->dir_file );
}

sub _file_if_exists {
    my $self = shift;
    my $file = shift || '';    # quiet warnings

    return ( -e $file ) ? $file : '';
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

__END__

=pod

=head1 NAME

Prophet::Config - Prophet's configuration object

=head1 VERSION

version 0.751

=head1 SYNOPSIS

From, for example, a class that inherits from Prophet::App:

    has config => (
        is      => 'rw',
        isa     => 'Prophet::Config',
        default => sub {
            my $self = shift;
            return Prophet::Config->new(
                app_handle => $self,
                confname => 'prophetrc',
            );
        },
    );

=head1 DESCRIPTION

This class represents the configuration of Prophet and the application built on
top of it. It's just an instance of L<Config::GitLike|Config::GitLike> with a
few small customizations and additions.

=head1 METHODS

=head2 aliases( $config_filename )

A convenience method that gets you a hash (or a hashref, depending on context)
of all currently defined aliases. (Basically, every entry in the 'alias'
section of the config file.)

If a filename is passed in, this method will only return the aliases that are
defined in that particular config file.

=head2 sources

A convenience method that gets you a hash (or a hashref, depending on context)
of all currently defined source replicas, in the format { 'name' => 'URL' }, or
{ 'URL' => 'name' } if the argument C<by_url> is passed in.

=head2 replica_config_file

The replica-specific configuration file, or the configuration file given by
C<PROPHET_APP_CONFIG> if that environmental variable is set.

=head2 new( confname => 'prophetrc', app_handle => $instance_of_prophet_app )

Initialize the configuration. Does NOT load the config for you! You need to
call L<load|Config::GitLike/"load"> for that. The configuration will also load
automatically the first time your prophet application tries to
L<get|Config::GitLike/"get"> a config variable.

Both constructor arguments are required.

=head1 CONFIG VARIABLES

The following config variables are currently used in various places in Prophet:

=over 4

=item *

<record-type>.summary-format

=item *

record.summary-format

=item *

user.email-address

=item *

alias.<alias>

=back

=head1 SEE ALSO

Most of the useful methods for getting and setting configuration variables
actually come from L<Config::GitLike|Config::GitLike>. See that module's
documentation for details.

=head1 AUTHORS

=over 4

=item *

Jesse Vincent <jesse@bestpractical.com>

=item *

Chia-Liang Kao <clkao@bestpractical.com>

=item *

Christine Spang <christine@spang.cc>

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2009 by Best Practical Solutions.

This is free software, licensed under:

  The MIT (X11) License

=head1 BUGS AND LIMITATIONS

You can make new bug reports, and view existing ones, through the
web interface at L<https://rt.cpan.org/Public/Dist/Display.html?Name=Prophet>.

=head1 CONTRIBUTORS

=over 4

=item *

Alex Vandiver <alexmv@bestpractical.com>

=item *

Casey West <casey@geeknest.com>

=item *

Cyril Brulebois <kibi@debian.org>

=item *

Florian Ragwitz <rafl@debian.org>

=item *

Ioan Rogers <ioanr@cpan.org>

=item *

Jonas Smedegaard <dr@jones.dk>

=item *

Kevin Falcone <falcone@bestpractical.com>

=item *

Lance Wicks <lw@judocoach.com>

=item *

Nelson Elhage <nelhage@mit.edu>

=item *

Pedro Melo <melo@simplicidade.org>

=item *

Rob Hoelz <rob@hoelz.ro>

=item *

Ruslan Zakirov <ruz@bestpractical.com>

=item *

Shawn M Moore <sartak@bestpractical.com>

=item *

Simon Wistow <simon@thegestalt.org>

=item *

Stephane Alnet <stephane@shimaore.net>

=item *

Unknown user <nobody@localhost>

=item *

Yanick Champoux <yanick@babyl.dyndns.org>

=item *

franck cuny <franck@lumberjaph.net>

=item *

robertkrimen <robertkrimen@gmail.com>

=item *

sunnavy <sunnavy@bestpractical.com>

=back

=cut
