package Prophet::CLI::Command::Log;
{
  $Prophet::CLI::Command::Log::VERSION = '0.751';
}
use Any::Moose;
extends 'Prophet::CLI::Command';

sub usage_msg {
    my $self = shift;
    my $cmd  = $self->cli->get_script_name;

    return <<"END_USAGE";
usage: ${cmd}log --all              Show all entries
       ${cmd}log 0..LATEST~5        Show first entry up until the latest
       ${cmd}log LATEST~10          Show last ten entries
       ${cmd}log LATEST             Show last entry
END_USAGE
}

# Default: last 20 entries.
# prophet log --all                    # show it all (overrides everything else)
# prophet log --range 0..LATEST~5      # shows the first until 5 from the latest
# prophet log --range LATEST~10        # shows last 10 entries
# prophet log --range LATEST           # shows the latest entry

# syntactic sugar in dispatcher:
#  prophet log 0..LATEST~5 => prophet log --range 0..LATEST~5
#  prophet log LATEST~10   => prophet log --range LATEST~10

sub run {
    my $self   = shift;
    my $handle = $self->handle;

    $self->print_usage if $self->has_arg('h');

    # --all overrides any other args
    if ( $self->has_arg('all') ) {
        $self->set_arg( 'range', '0..' . $handle->latest_sequence_no );
    }

    my ( $start, $end ) =
        $self->has_arg('range')
      ? $self->parse_range_arg()
      : ( $handle->latest_sequence_no - 20, $handle->latest_sequence_no );

    # parse_range returned undef
    die "Invalid range specified.\n" if !defined($start) || !defined($end);

    $start = 0 if $start < 0;

    die "START must be before END in START..END.\n" if $end - $start < 0;

    $handle->traverse_changesets(
        reverse  => 1,
        after    => $start - 1,
        until    => $end,
        callback => sub {
            my %args = (@_);
            $self->handle_changeset( $args{changeset} );

        },
    );

}


sub parse_range_arg {
    my $self  = shift;
    my $range = $self->arg('range');

    # split on .. (denotes range)
    my @start_and_end = split( /\.\./, $range, 2 );
    my ( $start, $end );
    if ( @start_and_end == 1 ) {

        # only one delimiter was specified -- this will be the
        # START; END defaults to the latest
        $end   = $self->handle->latest_sequence_no;
        $start = $self->_parse_delimiter( $start_and_end[0] );
    } elsif ( @start_and_end == 2 ) {

        # both delimiters were specified
        # parse the first one as START
        $start = $self->_parse_delimiter( $start_and_end[0] );

        # parse the second one as END
        $end = $self->_parse_delimiter( $start_and_end[1] );
    } else {

        # something wrong was specified
        return;
    }
    return ( $start, $end );
}


sub _parse_delimiter {
    my ( $self, $delim ) = @_;

    if ( $delim =~ m/^\d+$/ ) {

        # a sequence number was specified, just use it
        return $delim;
    } else {

        # try to parse what was given as LATEST~#
        # if it's just LATEST, we want only the last change
        my $offset;
        $offset = 0 if $delim eq 'LATEST';
        ( undef, $offset ) = split( /~/, $delim, 2 ) if $delim =~ m/^LATEST~/;
        return unless defined $offset && $offset =~ m/^\d+$/;

        return $self->handle->latest_sequence_no - $offset;
    }
    return;
}

sub handle_changeset {
    my $self      = shift;
    my $changeset = shift;
    print $changeset->as_string(
        change_header => sub {
            my $change = shift;
            $self->change_header($change);
        }
    );

}

sub change_header {
    my $self   = shift;
    my $change = shift;
    return
        " # "
      . $change->record_type . " "
      . $self->app_handle->handle->find_or_create_luid(
        uuid => $change->record_uuid )
      . " ("
      . $change->record_uuid . ")\n";

}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;

__END__

=pod

=head1 NAME

Prophet::CLI::Command::Log

=head1 VERSION

version 0.751

=head1 METHODS

=head2 parse_range_arg

Parses the string in the 'range' arg into start and end sequence numbers and
returns them in that order.

Returns undef if the string is malformed.

=head2 _parse_delimiter($delim)

Takes a delimiter string and parses into a sequence number. If it is not either
an integer number or of the form LATEST~#, returns undef (invalid delimiter).

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
