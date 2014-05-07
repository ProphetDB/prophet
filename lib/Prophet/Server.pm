package Prophet::Server;
use Moo;

# use Prophet::Server::Controller;
# use Prophet::Server::View;
# use Prophet::Server::Dispatcher;
# use Prophet::Server::Controller;
use Plack::Request;
use Prophet::Types qw/Bool CodeRef InstanceOf Int/;

use Params::Validate qw/:all/;
use File::Spec ();
use Cwd        ();
use JSON;
use HTTP::Date;

with 'Prophet::Role::Common';

has psgi       => ( is => 'lazy', isa => CodeRef);
has read_only  => ( is => 'rw', isa  => Bool);
has result     => ( is => 'rw', isa => InstanceOf['Prophet::Web::Result']);
has port => (
    isa     => Int,
    is      => 'rw',
    default => sub {
        my $self = shift;
        return $self->app_handle->config->get( key => 'server.default-port' )
          || '8008';
    }
);

sub _build_psgi {
    my $self = shift;
    my $psgi = sub {
        my $env = shift;
        my $req = Plack::Request->new($env);

        my $res = $self->handle_request($req);

        if ( ref $res ne 'Plack::Response' ) {
            $res = $req->new_response(500);
        }

        $res->header( 'Server' => __PACKAGE__ );
        return $res->finalize;
    };

    return $psgi;
}

sub run {
    my $self      = shift;
    my $publisher = eval {
        require Net::Rendezvous::Publish;
        Net::Rendezvous::Publish->new;
    };

    if ($publisher) {
        $publisher->publish(
            name   => $self->database_bonjour_name,
            type   => '_prophet._tcp',
            port   => $self->port,
            domain => 'local',
        );
    } else {
        $self->app_handle->log(
                "Publisher backend is not available. Install one of the "
              . "Net::Rendezvous::Publish::Backend modules from CPAN." );
    }

    print ref($self)
      . ": Starting up local server. You can stop the server with Ctrl-c.\n";

    eval { $self->SUPER::run(@_); };

    if ($@) {
        if ( $@ =~ m/^bind to \*:(\d+): Address already in use/ ) {
            die
              "\nPort $1 is already in use! Start the server on a different port using --port.\n";
        } else {
            die "\nError while starting server:\n\n$@\n";
        }
    }
}

=method database_bonjour_name

Returns the name this database should use to announce itself via bonjour

=cut

sub database_bonjour_name {
    my $self = shift;
    return $self->handle->db_uuid;
}

sub handle_request {
    my ( $self, $req ) = @_;

    # my $controller = Prophet::Server::Controller->new(
    #     cgi        => $self->cgi,
    #     app_handle => $self->app_handle,
    #     result     => $self->result
    # );
    # $controller->handle_functions();

    # my $dispatcher_class = ref( $self->app_handle ) . "::Server::Dispatcher";
    # if ( !$self->app_handle->try_to_require($dispatcher_class) ) {
    #     $dispatcher_class = "Prophet::Server::Dispatcher";
    # }

    # my $d = $dispatcher_class->new( server => $self );

    # my $path = Path::Dispatcher::Path->new(
    #     path     => $cgi->path_info,
    #     metadata => { method => $cgi->request_method, },
    # );

    # $d->run( $path, $d )
    #   || $self->_send_404;

}

sub update_record_prop {
    my $self = shift;
    my $type = shift;
    my $uuid = shift;
    my $prop = shift;

    my $record = $self->load_record( type => $type, uuid => $uuid );
    return $self->_send_404 unless ($record);
    $record->set_props(
        props => { $prop => ( $self->cgi->param('value') || undef ) } );
    return $self->_send_redirect( to => "/records/$type/$uuid/$prop" );
}

sub update_record {
    my $self   = shift;
    my $type   = shift;
    my $uuid   = shift;
    my $record = $self->load_record( type => $type, uuid => $uuid );

    return $self->_send_404 unless ($record);

    my $ret = $record->set_props(
        props => { map { $_ => $self->cgi->param($_) } $self->cgi->param() } );
    $self->_send_redirect( to => "/records/$type/$uuid.json" );
}

sub create_record {
    my $self   = shift;
    my $type   = shift;
    my $record = $self->load_record( type => $type );
    my $uuid   = $record->create(
        props => { map { $_ => $self->cgi->param($_) } $self->cgi->param() } );
    return $self->_send_redirect( to => "/records/$type/$uuid.json" );
}

sub get_record_prop {
    my $self   = shift;
    my $type   = shift;
    my $uuid   = shift;
    my $prop   = shift;
    my $record = $self->load_record( type => $type, uuid => $uuid );
    return $self->_send_404 unless ($record);
    if ( my $val = $record->prop($prop) ) {
        return $self->send_content(
            content_type => 'text/plain',
            content      => $val
        );
    } else {
        return $self->_send_404();
    }
}

sub get_record {
    my $self   = shift;
    my $type   = shift;
    my $uuid   = shift;
    my $record = $self->load_record( type => $type, uuid => $uuid );
    return $self->_send_404 unless ($record);
    return $self->send_content(
        encode_as => 'json',
        content   => $record->get_props
    );
}

sub get_record_list {
    my $self = shift;
    my $type = shift;
    require Prophet::Collection;
    my $col = Prophet::Collection->new(
        handle => $self->handle,
        type   => $type
    );
    $col->matching( sub {1} );
    warn "Query language not implemented yet.";
    return $self->send_content(
        encode_as => 'json',
        content =>
          { map { $_->uuid => "/records/$type/" . $_->uuid . ".json" } @$col }

    );
}

sub get_record_types {
    my $self = shift;
    $self->send_content(
        encode_as => 'json',
        content   => $self->handle->list_types
    );
}

sub serve_replica {
    my $self = shift;

    my $repo_file = shift;
    return unless $self->handle->can('read_file');
    my $content = $self->handle->read_file($repo_file);
    return unless defined $content && length($content);
    $self->send_replica_content($content);
}

sub send_replica_content {
    my $self    = shift;
    my $content = shift;
    return $self->send_content(
        content_type => 'application/x-prophet',
        content      => $content
    );

}

sub load_record {
    my $self = shift;
    my %args = validate( @_, { type => 1, uuid => 0 } );
    require Prophet::Record;
    my $record =
      Prophet::Record->new( handle => $self->handle, type => $args{type} );
    if ( $args{'uuid'} ) {
        return
          unless (
            $self->handle->record_exists(
                type => $args{'type'},
                uuid => $args{'uuid'}
            )
          );
        $record->load( uuid => $args{uuid} );
    }
    return $record;
}

sub send_content {
    my $self = shift;
    my %args =
      validate( @_,
        { content => 1, content_type => 0, encode_as => 0, static => 0 } );

    if ( $args{'encode_as'} && $args{'encode_as'} eq 'json' ) {
        $args{'content_type'} = 'text/x-json';
        $args{'content'}      = to_json( $args{'content'} );
    }

    print "HTTP/1.0 200 OK\r\n";
    if ( $args{static} ) {
        print 'Cache-Control: max-age=31536000, public';
        print 'Expires: ' . HTTP::Date::time2str( time() + 31536000 );
    }
    print "Content-Type: " . $args{'content_type'} . "\r\n";
    print "Content-Length: " . length( $args{'content'} || '' ) . "\r\n\r\n";
    print $args{'content'} || '';
    return '200';
}

sub _send_401 {
    my $self = shift;
    print "HTTP/1.0 401 READONLY_SERVER\r\n";

    # TODO give an actual error page?
    return '401';
}

sub _send_404 {
    my $self = shift;
    print "HTTP/1.0 404 ENOFILE\r\n";
    return '404';
}

sub _send_redirect {
    my $self = shift;
    my %args = validate( @_, { to => 1 } );
    print "HTTP/1.0 302 Go over there\r\n";
    print "Location: " . $args{'to'} . "\r\n";
    return '302';
}

1;
