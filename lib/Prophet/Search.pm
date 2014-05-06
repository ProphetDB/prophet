package Prophet::Search;

use v5.14.2;
use Moo;
use Carp;
with 'Prophet::Role::Common';

use Prophet::Types qw/ArrayRef CodeRef HashRef RegexpRef Str/;
use Params::Validate;

has props => (
    is      => 'rw',
    isa     => HashRef,
    default => sub { {} },
);

has type => ( is => 'ro', isa => Str);

has regex => (
    is      => 'ro',
    isa     => RegexpRef,
    coerce => sub {
        if (!ref $_[0]) {
            return qr/$_[0]/;
        }
    },
);

has sort_routine => (
    is  => 'rw',
    isa => CodeRef,

    # default subs are executed immediately, hence the weird syntax for coderefs
    default => sub {
        sub {
            my $records = shift;
            return ( sort { $a->luid <=> $b->luid } @$records );
          }
    },
    documentation =>
      'A subroutine which takes a arrayref to a list of records and returns them sorted in some way.',
);

has group_routine => (
    is      => 'rw',
    isa     => CodeRef,
    default => sub {
        sub {
            my $records = shift;
            return [ { label => '', records => $records } ];
          }
    },
    documentation =>
      'A subroutine which takes an arrayref to a list of records and returns an array of hashrefs  { label => $label, records => \@array}'
);

=method _get_record_object [{ type => 'type' }]

Tries to determine a record class from either the given type argument or the
current object's C<$type> attribute.

Returns a new instance of the record class on success, or throws a fatal error
with a stack trace on failure.

=cut

sub _get_record_object {
    my $self = shift;
    my %args = validate( @_, { type => { default => $self->type }, } );

    my $constructor_args = {
        app_handle => $self->app_handle,
        handle     => $self->handle,
        type       => $args{type},
    };

    if ( $args{type} ) {
        my $class = $self->_type_to_record_class( $args{type} );
        return $class->new($constructor_args);
    } elsif ( my $class = $self->record_class ) {
        Prophet::App->require($class);
        return $class->new($constructor_args);
    } else {
        $self->fatal_error(
            "I couldn't find that record. (You didn't specify a record type.)"
        );
    }
}

=method _type_to_record_class $type

Takes a type and tries to figure out a record class name from it. Returns
C<'Prophet::Record'> if no better class name is found.

=cut

sub _type_to_record_class {
    my $self = shift;

    my $try = $self->app_handle->app_class . "::Model::" . ucfirst( lc($self->type) );
    Prophet::App->try_to_require($try);    # don't care about fails
    return $try if ( $try->isa('Prophet::Record') );

    $try = $self->app_handle->app_class . "::Record";
    Prophet::App->try_to_require($try);    # don't care about fails
    return $try if ( $try->isa('Prophet::Record') );
    return 'Prophet::Record';
}

sub default_match {1}

sub get_collection_object {
    my $self = shift;
    my %args = validate( @_, { type => { default => $self->type }, } );

    my $class =
      $self->_get_record_object( type => $args{type} )->collection_class;
    Prophet::App->require($class);

    my $records = $class->new(
        app_handle => $self->app_handle,
        handle     => $self->handle,
        type       => $args{type} || $self->type,
    );

    return $records;
}

sub get_search_callback {
    my $self = shift;

    return sub {
        my $item      = shift;
        my $props     = $item->get_props;
        my $did_limit = 0;

        if ( keys %{$self->props} > 0 ) {
            $did_limit = 1;
            for my $prop ( keys %{$self->props} ) {
                my $ok  = 0;

                if (exists $props->{$prop}) {
                        if ($props->{$prop} eq $self->props->{$prop}) {
                            $ok = 1;
                        }
                }
                return 0 if !$ok;
            }
        }

        # if they specify a regex, it must match
        if ($self->regex) {
            my $regex = $self->regex;
            $did_limit = 1;
            my $ok = 0;

            for ( values %$props ) {
                if (/$regex/) {
                    $ok = 1;
                    last;
                }
            }
            return 0 if !$ok;
        }

        return $self->default_match($item) if !$did_limit;

        return 1;
    };
}

# TODO don't use a cmp prop, try to autodetermine comparator like smartmatch
sub _compare {
    my $self = shift;
    my ( $expected, $cmp, $got ) = @_;

    $cmp = '' if !defined($cmp);
    $got = '' if !defined($got);    # avoid undef warnings

    if ( $cmp eq '=' ) {
        return 0 unless $got eq $expected;
    } elsif ( $cmp eq '=~' ) {
        return 0 unless $got =~ $expected;
    } elsif ( $cmp eq '!=' || $cmp eq '<>' || $cmp eq 'ne' ) {
        return 0 if $got eq $expected;
    } elsif ( $cmp eq '!~' ) {
        return 0 if $got =~ $expected;
    } else {
        return 0 if $got eq $expected;
    }

    return 1;
}

sub run {
    my $self = shift;

    my $records   = $self->get_collection_object;
    my $search_cb = $self->get_search_callback;
    $records->matching($search_cb);

    return $records;
}

=method sort_by_prop $prop, $records, $sort_undef_last

Given a property name and an arrayref to a list of records, returns a list of
the records sorted by their C<created> property, in ascending order.

If $sort_undef_last is true, records which don't have a property defined are
sorted *after* all other records; otherwise, they are sorted before.

=cut

sub sort_by_prop {
    my ( $self, $prop, $records, $sort_undef_last ) = @_;

    no warnings 'uninitialized';    # some records might not have this prop

    return (
        sort {
            my $prop_a = $a->prop($prop);
            my $prop_b = $b->prop($prop);
            if ( $sort_undef_last && !defined($prop_a) ) {
                return 1;
            } elsif ( $sort_undef_last && !defined($prop_b) ) {
                return -1;
            } else {
                return $prop_a cmp $prop_b;
            }
        } @{$records}
    );
}

=method group_by_prop $prop => $records

Given a property name and an arrayref to a list of records, returns a reference
to a list of hashes of the form:

    { label => $label,
      records => \@records }

=cut

sub group_by_prop {
    my $self    = shift;
    my $prop    = shift;
    my $records = shift;

    my $results = {};

    for my $record (@$records) {
        push @{ $results->{ ( $record->prop($prop) || '' ) } }, $record;
    }

    return [

        map { { label => $_, records => $results->{$_} } } keys %$results

    ];

}

sub out_group_heading {
    my $self   = shift;
    my $group  = shift;
    my $groups = shift;

    # skip headings with no records
    return unless exists $group->{records}->[0];

    return unless @$groups > 1;

    $group->{label} ||= 'none';
    print "\n"
      . $group->{label} . "\n"
      . ( "=" x length $group->{label} ) . "\n\n";

}

sub out_record {
    my $self   = shift;
    my $record = shift;
    print $record->format_summary . "\n";
}

1;
