package Prophet::CLI::Command::Push;
{
  $Prophet::CLI::Command::Push::VERSION = '0.751';
}
use Any::Moose;
extends 'Prophet::CLI::Command::Merge';

sub usage_msg {
    my $self = shift;
    my $cmd  = $self->cli->get_script_name;

    return <<"END_USAGE";
usage: ${cmd}push --to <url|name> [--force]
END_USAGE
}

sub run {
    my $self = shift;

    Prophet::CLI->end_pager();

    $self->print_usage if $self->has_arg('h');

    $self->validate_args;

    # sub out friendly names for replica URLs if possible
    my %previous_sources_by_name_push_url =
      $self->app_handle->config->sources( variable => 'push-url' );
    my %previous_sources_by_name_url = $self->app_handle->config->sources;

    my $original_to = $self->arg('to');
    $self->set_arg(
        'to' => exists $previous_sources_by_name_push_url{ $self->arg('to') }
        ? $previous_sources_by_name_push_url{ $self->arg('to') }
        : exists $previous_sources_by_name_url{ $self->arg('to') }
        ? $previous_sources_by_name_url{ $self->arg('to') }
        : $self->arg('to')
    );

    # don't let users push to foreign replicas they haven't pulled from yet
    # without --force
    my %seen_replicas_by_url = $self->config->sources( by_variable => 1 );
    my %seen_replicas_by_pull_url = $self->config->sources(
        by_variable => 1,
        variable    => 'pull-url',
    );

    ( my $class, undef, undef ) = Prophet::Replica->_url_to_replica_class(
        url        => $self->arg('to'),
        app_handle => $self->app_handle,
    );

    die "No replica found at '" . $self->arg('to') . "'.\n" unless $class;

    die "Can't push to HTTP replicas! You probably want to publish instead.\n"
      if $class->isa("Prophet::Replica::http");

    die
      "Can't push to foreign replica that's never been pulled from! (Override with --force.)\n"
      unless $class->isa('Prophet::ForeignReplica')
      && (
        $self->has_arg('force')
        || (   exists $seen_replicas_by_url{ $self->arg('to') }
            || exists $seen_replicas_by_pull_url{ $self->arg('to') } )
      );

    # prepare to run merge command (superclass)
    $self->set_arg( from    => $self->handle->url );
    $self->set_arg( db_uuid => $self->handle->db_uuid );

    $self->SUPER::run();

    # we want to record only the replica we're pushing TO, and only if we
    # weren't using a friendly name already
    $self->record_replica_in_config( $self->arg('to'), $self->target->uuid )
      if $self->arg('to') eq $original_to;
}

sub validate_args {
    my $self = shift;

    unless ( $self->context->has_arg('to') ) {
        warn "No --to specified!\n";
        $self->print_usage;
    }
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;

1;

__END__

=pod

=head1 NAME

Prophet::CLI::Command::Push

=head1 VERSION

version 0.751

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
