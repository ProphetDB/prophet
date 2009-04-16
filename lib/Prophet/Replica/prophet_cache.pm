package Prophet::Replica::prophet_cache;
use Any::Moose;

extends 'Prophet::Replica';
with 'Prophet::FilesystemReplica';
use Params::Validate ':all';
use File::Path qw/mkpath/;

has '+db_uuid' => (
    lazy    => 1,
    default => sub { shift->app_handle->handle->db_uuidl() }
);

has uuid => ( is => 'rw');

has _replica_version => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub { shift->_read_file('replica-version') || 0 }
);

has fs_root_parent => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->app_handle->handle->url =~ m{^file://(.*)/.*?$} ? $1 : undef;
    },
);


has changeset_cas => (
    is  => 'rw',
    isa => 'Prophet::ContentAddressedStore',
    lazy => 1,
    default => sub {
        my $self = shift;
        Prophet::ContentAddressedStore->new(
            { fs_root => $self->fs_root,
              root    => $self->changeset_cas_dir } );
    },
);

has '+resolution_db_handle' => (
    isa     => 'Prophet::Replica | Undef',
    lazy    => 1,
    default => sub { return shift }
);

use constant userdata_dir    => 'userdata';
use constant local_metadata_dir => 'local_metadata';
use constant scheme   => 'prophet_cache';
use constant cas_root => 'cas';
use constant changeset_cas_dir => File::Spec->catdir( __PACKAGE__->cas_root => 'changesets' );
has fs_root => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        return $self->app_handle->handle->url =~ m{^file://(.*)$} ? $1.'/remote-replica-cache/' : undef;
    },
);

use constant replica_dir => 'replica';
    
has changeset_index => (
    is => 'rw',
    lazy => 1,
    default => sub {
        my $self = shift;
        File::Spec->catdir($self->replica_dir , $self->uuid, 'changesets.idx');
    }

);    

use constant can_read_records    => 0;
use constant can_read_changesets => 1;
sub can_write_changesets { return ( shift->fs_root ? 1 : 0 ) }
use constant can_write_records    => 0;

sub initialize {
    my $self = shift;
    my %args = validate(
        @_,
        {   db_uuid    => 1,
            replica_uuid => 1,
            resdb_uuid => 0,
        }
    );
    if ( !$self->fs_root_parent ) {
        if ( $self->can_write_changesets ) {
            die
                "We can only create local prophet replicas. It looks like you're trying to create "
                . $self->url;
        } else {
            die "Prophet couldn't find a replica at \""
                . $self->fs_root_parent
                . "\"\n\n"
                . "Please check the URL and try again.\n";

        }
    }

    return if $self->replica_exists;
    for (
        $self->cas_root,
        $self->changeset_cas_dir,
        $self->replica_dir,
        File::Spec->catdir($self->replica_dir, $args{'replica_uuid'}),
        $self->userdata_dir
        )
    {
        mkpath( [ File::Spec->catdir( $self->fs_root => $_ ) ] );
    }

    $self->set_db_uuid( $self->app_handle->handle->db_uuid);
    $self->after_initialize->($self);
}

sub latest_sequence_no {
    my $self = shift;
    my $count = (-s File::Spec->catdir($self->fs_root => $self->changeset_index )) / $self->CHG_RECORD_SIZE;
    return $count;
}



sub mirror_from {
        my $self = shift;
        my %args = validate( @_, { source => 1, reporting_callback => {type => CODEREF, optional => 1 } });

    my $source = $args{source};
    if ( $source->can('read_changeset_index') ) {
        $self->_write_file(
            path    => $self->changeset_index,
            content => ${ $source->read_changeset_index }
        );

        $self->traverse_changesets(
            load_changesets => 0,
            callback =>

                sub {
                my $data = shift;
                my ( $seq, $orig_uuid, $orig_seq, $key ) = @{$data};
                return
                    if (
                    -f File::Spec->catdir( $self->fs_root,
                        $self->changeset_cas->filename($key) ) );

                my $content = $source->_read_file( $source->changeset_cas->filename($key) );
                utf8::decode($content) if utf8::is_utf8($content);
                my $newkey = $self->changeset_cas->write(
                    $content

                );

                my $existsp = File::Spec->catdir( $self->fs_root,
                    $self->changeset_cas->filename($key) );
                if ( !-f $existsp ) {
                    die "AAA couldn't find changeset $key at $existsp";

                }
                }

            ,
            after => 0,
            $args{reporting_callback} ? (reporting_callback => $args{reporting_callback}) : (),
        );
    } else {
        warn "Sorry, we only support replicas with a changeset index file";
    }
    }


1;