package Prophet::FilesystemReplica;
use Any::Moose 'Role';
use File::Spec;use Params::Validate qw(:all);
use LWP::UserAgent;
use LWP::ConnCache;
use JSON;
use Prophet::Util;
      
has lwp_useragent => (
    isa => 'LWP::UserAgent',
    is => 'ro',
    lazy => 1,
    default => sub {
        my $ua = LWP::UserAgent->new;
        $ua->timeout(60);
        $ua->conn_cache(LWP::ConnCache->new());
        return $ua;
    }
);

=head2 replica_exists

Returns true if the replica already exists / has been initialized.
Returns false otherwise.

=cut

sub replica_exists {
    my $self = shift;
    return $self->_replica_version ? 1 : 0;
}

sub can_initialize {
    my $self = shift;
    if ( $self->fs_root_parent && -w $self->fs_root_parent ) {
        return 1;

    }
    return 0;
}

=head2 _file_exists PATH

Returns true if PATH is a file or directory in this replica's directory structure

=cut

sub _file_exists {
    my $self = shift;
    my ($file) = validate_pos( @_, 1 );

    if ( !$self->fs_root ) {

        # HTTP Replica
        return $self->_read_file($file) ? 1 : 0;
    }

    my $path = File::Spec->catfile( $self->fs_root, $file );
    if    ( -f $path ) { return 1 }
    elsif ( -d $path ) { return 2 }
    else               { return 0 }
}

sub read_file {
    my $self = shift;
    my ($file) = validate_pos( @_, 1 );
    if ( $self->fs_root ) {

        # make sure we don't try to read files outside the replica
        my $qualified_file = Cwd::fast_abs_path(
            File::Spec->catfile( $self->fs_root => $file ) );
        return undef
            if substr( $qualified_file, 0, length( $self->fs_root ) ) ne
                $self->fs_root;
    }
    return $self->_read_file($file);
}

sub _read_file {
    my $self = shift;
    my ($file) = validate_pos( @_, 1 );
    if ( $self->fs_root ) {
        return eval {
            local $SIG{__DIE__} = 'DEFAULT';
            Prophet::Util->slurp(
                File::Spec->catfile( $self->fs_root => $file ) );
        };
    } else {    # http replica
        return $self->lwp_get( $self->url . "/" . $file );
    }

}

sub _write_file {
    my $self = shift;
    my %args = validate( @_, { path => 1, content => 1 } );

    my $file = File::Spec->catfile( $self->fs_root => $args{'path'} );
    Prophet::Util->write_file( file => $file, content => $args{content});
}

sub read_changeset_index {
    my $self = shift;
    $self->log_debug("Reading changeset index file" .$self->changeset_index);
    my $chgidx = $self->_read_file( $self->changeset_index );
    utf8::decode($chgidx) if utf8::is_utf8($chgidx); # When we get data from LWP it sometimes ends up with a charset. that is wrong here
    return \$chgidx;
}
      
sub _write_changeset {
    my $self = shift;
    my %args = validate( @_,
        { index_handle => 1, changeset => { isa => 'Prophet::ChangeSet' } } );

    my $changeset = $args{'changeset'};
    my $fh        = $args{'index_handle'};

    my $hash_changeset = $changeset->as_hash;
    # These two things should never actually get stored
    my $seqno = delete $hash_changeset->{'sequence_no'};
    my $uuid  = delete $hash_changeset->{'source_uuid'};

    my $cas_key = $self->changeset_cas->write( $hash_changeset );

    my $changeset_index_line = pack( 'Na16NH40',
        $seqno,
        Data::UUID->new->from_string( $changeset->original_source_uuid ),
        $changeset->original_sequence_no,
        $cas_key );

    print $fh $changeset_index_line || die $!;

}

use constant CHG_RECORD_SIZE => ( 4 + 16 + 4 + 20 );

sub _changeset_index_size {
    my $self = shift;
    my %args = validate( @_, { index_file => 1 } );

    return length(${$args{index_file}})/CHG_RECORD_SIZE;

}


=head2 traverse_changesets { after => SEQUENCE_NO, callback => sub { } } 

Walks through all changesets from $after to $until, calling $callback on each.

If no $until is specified, the latest changeset is assumed.

=cut

# each record is : local-replica-seq-no : original-uuid : original-seq-no : cas key
#                  4                    16              4                 20

sub traverse_changesets {
    my $self = shift;
    my %args = validate(
        @_,
        {   after    => 1,
            callback => { type => CODEREF} ,
            reporting_callback => { type => CODEREF, optional => 1 },
            until    => 0,
            reverse  => 0,
            load_changesets => { default => 1 }
        }
    );

    my $first_rev = ( $args{'after'} + 1 ) || 1;
    my $latest = $self->latest_sequence_no;

    if ( defined $args{until} && $args{until} < $latest) {
            $latest = $args{until};
    }

    my $chgidx = $self->read_changeset_index;
    $self->log_debug("Traversing changesets between $first_rev and $latest");
    my @range = ( $first_rev .. $latest );
    @range = reverse @range if $args{reverse};
    for my $rev ( @range ) {
        $self->log_debug("Fetching changeset $rev");
        my $data;
        if ( $args{load_changesets} ) {
            $data = $self->_get_changeset_index_entry(
                sequence_no => $rev,
                index_file  => $chgidx
            );
        } else {
           $data = $self->_changeset_index_entry(
                sequence_no => $rev,
                index_file  => $chgidx
            );
        }
            $args{callback}->($data);
        $args{reporting_callback}->($data) if ($args{reporting_callback});

    }
}
sub _changeset_index_entry {
    my $self = shift;
    my %args = validate( @_, { sequence_no => 1, index_file => 1 } );
    my $chgidx = $args{index_file};

    my $rev    = $args{'sequence_no'};
    my $index_record = substr( $$chgidx, ( $rev - 1 ) * CHG_RECORD_SIZE, CHG_RECORD_SIZE );
    my ( $seq, $orig_uuid, $orig_seq, $key ) = unpack( 'Na16NH40', $index_record );

    $self->log_debug( join( ",", ( $seq, $orig_uuid, $orig_seq, $key ) ) );
    $orig_uuid = Data::UUID->new->to_string($orig_uuid);
    $self->log_debug( "REV: $rev - seq $seq - originally $orig_seq from "
            . substr( $orig_uuid, 0, 6 )
            . " data key $key" );


    return [ $seq, $orig_uuid, $orig_seq, $key];
}
sub _deserialize_changeset {
    my $self = shift;
    my %args = validate(
        @_,
        {   content              => 1,
            original_sequence_no => 1,
            original_source_uuid => 1,
            sequence_no          => 1
        }
    );

    require Prophet::ChangeSet;
    my $content_struct = from_json( $args{content}, { utf8 => 1 } );
    my $changeset = Prophet::ChangeSet->new_from_hashref($content_struct);

    $changeset->source_uuid( $self->uuid );
    $changeset->sequence_no( $args{'sequence_no'} );
    $changeset->original_source_uuid( $args{'original_source_uuid'} );
    $changeset->original_sequence_no( $args{'original_sequence_no'} );
    return $changeset;
}
sub _get_changeset_index_entry {
    my $self = shift;
    my %args = validate( @_, { sequence_no => 1, index_file => 1 } );
    # XXX: deserialize the changeset content from the cas with $key
    my ( $seq, $orig_uuid, $orig_seq, $key )  =@{ $self->_changeset_index_entry(%args)};

    my $casfile = $self->changeset_cas->filename($key);

    my $changeset = $self->_deserialize_changeset(
        content              => $self->_read_file($casfile),
        original_source_uuid => $orig_uuid,
        original_sequence_no => $orig_seq,
        sequence_no          => $seq
    );

    return $changeset;
}
sub _get_changeset_index_handle {
    my $self = shift;

    open(
        my $cs_file,
        ">>" . File::Spec->catfile( $self->fs_root => $self->changeset_index )
    ) || die $!;
    return $cs_file;
}

sub lwp_get {
    my $self = shift;
    my $url  = shift;
    my $response;
    for ( 1 .. 4 ) {
        $response = $self->lwp_useragent->get($url);
        if ( $response->is_success ) {
            return $response->decoded_content;
        }
    }
    warn "Could not fetch" . $url . " - " . $response->status_line;
    return undef;
}
          
      
=head2 read_userdata_file

Returns the contents of the given file in this replica's userdata directory.
Returns C<undef> if the file does not exist.

=cut

sub read_userdata {
    my $self = shift;
    my %args = validate( @_, { path => 1 } );

    $self->_read_file(
        File::Spec->catfile( $self->userdata_dir, $args{path} ) );
}

=head2 write_userdata

Writes the given string to the given file in this replica's userdata directory.

=cut

sub write_userdata {
    my $self = shift;
    my %args = validate( @_, { path => 1, content => 1 } );

    $self->_write_file(
        path    => File::Spec->catfile( $self->userdata_dir, $args{path} ),
        content => $args{content},
    );
}

      
sub store_local_metadata {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    $self->_write_file(
        path    =>File::Spec->catfile( $self->local_metadata_dir,  $key),
        content => $value,
    );


}

sub fetch_local_metadata {
    my $self = shift;
    my $key = shift;
    $self->_read_file(File::Spec->catfile($self->local_metadata_dir, $key));

}


1;
