package Prophet::FilesystemReplica;
use Any::Moose;
extends 'Prophet::Replica';
use File::Spec;use Params::Validate qw(:all);
use JSON;
use Prophet::Util;
      

=head2 replica_exists

Returns true if the replica already exists / has been initialized.
Returns false otherwise.

=cut

sub replica_exists {
    my $self = shift;
    return $self->uuid ? 1 : 0;
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

	return $self->backend->file_exists($file);
}

sub read_file {
    my $self = shift;
    my ($file) = validate_pos( @_, 1 );
    if ( $self->fs_root ) {

        # make sure we don't try to read files outside the replica
        my $qualified_file = Cwd::fast_abs_path(
            Prophet::Util->catfile( $self->fs_root => $file ) );
        return undef
            if substr( $qualified_file, 0, length( $self->fs_root ) ) ne
                $self->fs_root;
    }
    return $self->_read_file($file);
}

sub _read_file {
    my $self = shift;
    my ($file) = (@_); # validation is too heavy to be called here
    #my ($file) = validate_pos( @_, 1 );
	$self->backend->read_file($file);
}

sub _write_file {
    my $self = shift;
    my %args = (@_); # validate is too heavy to be called here
    #    my %args = validate( @_, { path => 1, content => 1 } );

	$self->backend->write_file(%args);
}

sub read_changeset_index {
    my $self= shift;
    $self->log_debug( "Reading changeset index file '" .$self->changeset_index . "'" );
    my $chgidx = $self->_read_file( $self->changeset_index );
    return \$chgidx;
}
      
sub _write_changeset {
    my $self = shift;
    my %args = validate( @_,
        {  changeset => { isa => 'Prophet::ChangeSet' } } );

    my $changeset = $args{'changeset'};

    my $hash_changeset = $changeset->as_hash;
    # These two things should never actually get stored
    my $seqno = delete $hash_changeset->{'sequence_no'};
    my $uuid  = delete $hash_changeset->{'source_uuid'};

    my $cas_key = $self->changeset_cas->write( $hash_changeset );

    my $changeset_index_line = pack( 'Na16NH40',
        $seqno,
        $self->uuid_generator->from_string( $changeset->original_source_uuid ),
        $changeset->original_sequence_no,
        $cas_key );

	$self->backend->append_to_file($self->changeset_index => $changeset_index_line);

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
        {   after                          => 1,
            callback                       => { type => CODEREF },
            before_load_changeset_callback => { type => CODEREF, optional => 1 },
            reporting_callback             => { type => CODEREF, optional => 1 },
            until                          => 0,
            reverse                        => 0,
            load_changesets => { default => 1 }
        }
    );

    my $first_rev = ( $args{'after'} + 1 ) || 1;
    my $latest = $self->latest_sequence_no || 0;

    if ( defined $args{until} && $args{until} < $latest ) {
        $latest = $args{until};
    }


	#there's no need to iterate if we know there's nothing to read
	return if ( $first_rev > $latest); 
	
    $self->log_debug("Traversing changesets between $first_rev and $latest");
    my @range = ( $first_rev .. $latest );
    @range = reverse @range if $args{reverse};
    
	
	my $chgidx = $self->read_changeset_index;


    for my $rev (@range) {
        $self->log_debug("Fetching changeset $rev");

        if ( $args{'before_load_changeset_callback'} ) {
            my $continue = $args{'before_load_changeset_callback'}->(
                changeset_metadata => $self->_changeset_index_entry(
                    sequence_no => $rev,
                    index_file  => $chgidx
                )
            );

            next unless $continue;

        }

        my $data;
        if ( $args{load_changesets} ) {
            $data = $self->_get_changeset_via_index(
                sequence_no => $rev,
                index_file  => $chgidx
            );
            $args{callback}->( changeset => $data );
        } else {
            $data = $self->_changeset_index_entry(
                sequence_no => $rev,
                index_file  => $chgidx
            );
            $args{callback}->( changeset_metadata => $data );

        }
        $args{reporting_callback}->($data) if ( $args{reporting_callback} );

    }
}

sub _changeset_index_entry {
    my $self = shift;
    my %args = validate( @_, { sequence_no => 1, index_file => 1 } );
    my $chgidx = $args{index_file};

    my $rev    = $args{'sequence_no'};
    my $index_record = substr( $$chgidx, ( $rev - 1 ) * CHG_RECORD_SIZE, CHG_RECORD_SIZE );
    my ( $seq, $orig_uuid, $orig_seq, $key ) = unpack( 'Na16NH40', $index_record );

    $orig_uuid = $self->uuid_generator->to_string($orig_uuid);
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

sub _get_changeset_via_index {
    my $self = shift;
    my %args = validate( @_, { sequence_no => 1, index_file => 1 } );
    # XXX: deserialize the changeset content from the cas with $key
    my ( $seq, $orig_uuid, $orig_seq, $key )  =@{ $self->_changeset_index_entry(%args)};

    my $changeset = $self->_deserialize_changeset(
        content              => $self->fetch_serialized_changeset(sha1 => $key),
        original_source_uuid => $orig_uuid,
        original_sequence_no => $orig_seq,
        sequence_no          => $seq
    );

    return $changeset;
}

sub fetch_serialized_changeset {
    my $self = shift;
    my %args = validate(@_, { sha1 => 1 });
    my $casfile = $self->changeset_cas->filename($args{sha1});
    return $self->_read_file($casfile);
}



      
=head2 read_userdata_file

Returns the contents of the given file in this replica's userdata directory.
Returns C<undef> if the file does not exist.

=cut

sub read_userdata {
    my $self = shift;
    my %args = validate( @_, { path => 1 } );

    $self->_read_file( Prophet::Util->catfile( $self->userdata_dir, $args{path} ) );
}

=head2 write_userdata

Writes the given string to the given file in this replica's userdata directory.

=cut

sub write_userdata {
    my $self = shift;
    my %args = validate( @_, { path => 1, content => 1 } );

    $self->_write_file(
        path    => Prophet::Util->catfile( $self->userdata_dir, $args{path} ),
        content => $args{content},
    );
}

      
sub store_local_metadata {
    my $self = shift;
    my $key = shift;
    my $value = shift;
    $self->_write_file(
        path    =>Prophet::Util->catfile( $self->local_metadata_dir,  lc($key)),
        content => $value,
    );


}

sub fetch_local_metadata {
    my $self = shift;
    my $key = shift;
	# local metadata files used to (incorrectly) be treated as case sensitive.
	# The code below tries to make sure that we don't lose historical data as we fix this
	# If there's a new-style all-lowercase file,  read that first. If there isn't,
	# try to read an old-style sensitive file

	my $insensitive_file = Prophet::Util->catfile($self->local_metadata_dir, lc($key));
	my $sensitive_file = Prophet::Util->catfile($self->local_metadata_dir, $key);

	return	$self->_read_file($insensitive_file) || $self->_read_file($sensitive_file);

}


1;
