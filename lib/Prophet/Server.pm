package Prophet::Server;
use Moo;

# this instead of extends silences "You inherit from non-Mouse class" warning
use base 'HTTP::Server::Simple::CGI';

use Prophet::Server::Controller;
use Prophet::Server::View;
use Prophet::Server::Dispatcher;
use Prophet::Server::Controller;
use Prophet::Web::Menu;
use Prophet::Web::Result;

use Params::Validate qw/:all/;
use File::Spec ();
use Cwd        ();
use JSON;
use HTTP::Date;

# Only define a class type constraint for CGI if it's not already defined,
# because Moose doesn't auto-define class type constraints while Mouse does.
unless ( find_type_constraint('CGI') ) {
    use Any::Moose '::Util::TypeConstraints';
    class_type('CGI');
}

has app_handle => (
    isa     => 'Prophet::App',
    is      => 'rw',
    handles => [qw/handle/]
);

has cgi        => ( isa => 'CGI|Undef',                is  => 'rw' );
has page_nav   => ( isa => 'Prophet::Web::Menu|Undef', is  => 'rw' );
has read_only  => ( isa  => 'Bool',                        is => 'rw' );
has static     => ( isa =>  'Bool',                        is => 'rw');
has view_class => ( isa => 'Str',                       is  => 'rw' );
has result     => ( isa => 'Prophet::Web::Result',      is  => 'rw' );
has port => (
    isa     => 'Str',
    is      => 'rw',
    default => sub {
        my $self = shift;
        return $self->app_handle->config->get( key => 'server.default-port' )
          || '8008';
    }
);

sub run {
    my $self      = shift;
    my $publisher = eval {
        require Net::Rendezvous::Publish;
        Net::Rendezvous::Publish->new;
    };

    eval { require Template::Declare }
      || die
      "Without Template::Declare installed, Prophet's Web UI won't work";
    eval { require File::ShareDir }
      || die "Without File::ShareDir installed, Prophet's Web UI won't work";

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
    $self->setup_template_roots();
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

sub setup_template_roots {
    my $self       = shift;
    my $view_class = ref( $self->app_handle ) . "::Server::View";

    if ( Prophet::App->try_to_require($view_class) ) {
        $self->view_class($view_class);
    } else {
        $self->view_class('Prophet::Server::View');
    }

    Template::Declare->init( roots => [ $self->view_class ] );
}

our $PROPHET_STATIC_ROOT;

sub prophet_static_root {
    my $self = shift;
    unless ($PROPHET_STATIC_ROOT) {

        $PROPHET_STATIC_ROOT = File::Spec->catdir(
            Prophet::Util->updir( $INC{'Prophet.pm'}, 2 ), "share",
            "web", "static"
        );

        eval { require File::ShareDir; 1 }
          or die "requires File::ShareDir to determine default static root";

        $PROPHET_STATIC_ROOT =
          Prophet::Util->catfile( File::ShareDir::dist_dir('Prophet'),
            'web/static' )
          if ( !-d $PROPHET_STATIC_ROOT );

        $PROPHET_STATIC_ROOT = Cwd::abs_path($PROPHET_STATIC_ROOT);

    }

    return $PROPHET_STATIC_ROOT;
}

our $APP_STATIC_ROOT;

sub app_static_root {
    my $self = shift;
    unless ($APP_STATIC_ROOT) {

        my $app_file = ref( $self->app_handle ) . ".pm";
        $app_file =~ s|::|/|g;

        $APP_STATIC_ROOT = File::Spec->catdir(
            Prophet::Util->updir( $INC{$app_file}, 3 ), "share",
            "web", "static"
        );

        my $dist = ref( $self->app_handle );
        $dist =~ s/::/-/g;

        eval { require File::ShareDir; 1 }
          or die "requires File::ShareDir to determine default static root";

        $APP_STATIC_ROOT =
          Prophet::Util->catfile( File::ShareDir::dist_dir($dist),
            'web', 'static' )
          if ( !-d $APP_STATIC_ROOT );

        $APP_STATIC_ROOT = Cwd::abs_path($APP_STATIC_ROOT);

    }
    return $APP_STATIC_ROOT;
}

# Use system-installed CSS and Javascript libraries if they exist, so distros
# have the option to not ship our embedded copies.
#
# I'm not sure if RPM-based systems have a standard location for system
# Javascript libraries, but this ought to work on Debian/Ubuntu. Patches
# welcome.
sub system_js_and_css {
    my $mapping = {
        'yui/css/reset.css' =>
          '/usr/share/javascript/yui3/cssreset/reset-min.css',
        'jquery/js/jquery-1.2.6.min.js',
        => '/usr/share/javascript/jquery/jquery.min.js',
        'jquery/js/jquery.tablesorter.min.js',
        => '/usr/share/javascript/jquery-tablesorter/jquery.tablesorter.min.js',
        'jquery/css/tablesorter/style.css',
        => '/usr/share/javascript/jquery-tablesorter/themes/blue/style.css',
    };
    return $mapping;
}

sub css {
    return
      '/static/prophet/yui/css/reset.css',
      '/static/prophet/jquery/css/superfish.css',
      '/static/prophet/jquery/css/superfish-navbar.css',
      '/static/prophet/jquery/css/jquery.autocomplete.css',
      '/static/prophet/jquery/css/tablesorter/style.css',

}

sub js {
    return
      '/static/prophet/jquery/js/jquery-1.2.6.min.js',
      '/static/prophet/jquery/js/pretty.js',
      '/static/prophet/jquery/js/hoverIntent.js',
      '/static/prophet/jquery/js/jquery.bgiframe.min.js',
      '/static/prophet/jquery/js/jquery-autocomplete.js',
      '/static/prophet/jquery/js/superfish.js',
      '/static/prophet/jquery/js/supersubs.js',
      '/static/prophet/jquery/js/jquery.tablesorter.min.js';
}

sub handle_request {
    my ( $self, $cgi ) =
      validate_pos( @_, { isa => 'Prophet::Server' }, { isa => 'CGI' } );
    $self->cgi($cgi);
    $self->log_request();
    $self->page_nav(
        Prophet::Web::Menu->new( cgi => $self->cgi, server => $self ) );
    $self->result( Prophet::Web::Result->new() );
    if ( $ENV{'PROPHET_DEVEL'} ) {
        require Module::Refresh;
        Module::Refresh->refresh();
    }

    my $controller = Prophet::Server::Controller->new(
        cgi        => $self->cgi,
        app_handle => $self->app_handle,
        result     => $self->result
    );
    $controller->handle_functions();

    my $dispatcher_class = ref( $self->app_handle ) . "::Server::Dispatcher";
    if ( !$self->app_handle->try_to_require($dispatcher_class) ) {
        $dispatcher_class = "Prophet::Server::Dispatcher";
    }

    my $d = $dispatcher_class->new( server => $self );

    my $path = Path::Dispatcher::Path->new(
        path     => $cgi->path_info,
        metadata => { method => $cgi->request_method, },
    );

    $d->run( $path, $d )
      || $self->_send_404;

}

sub log_request {
    my $self = shift;
    my $cgi  = $self->cgi;
    $self->app_handle->log_debug(
            localtime() . " ["
          . $ENV{'REMOTE_ADDR'} . "] "
          . $cgi->request_method . " "
          . $cgi->path_info );
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

sub show_template {
    my $self    = shift;
    my $p       = shift;
    my $content = $self->render_template( $p, @_ );
    if ($content) {
        return $self->send_content(
            content_type => 'text/html; charset=UTF-8',
            content      => $content,
        );
    }
    return;
}

sub render_template {
    my $self = shift;
    my $p    = shift;
    if ( Template::Declare->has_template($p) ) {
        $self->view_class->app_handle( $self->app_handle );
        $self->view_class->cgi( $self->cgi );
        $self->view_class->page_nav( $self->page_nav );
        $self->view_class->server($self);
        my $content = Template::Declare->show( $p, @_ );
        return $content;
    }
    return;
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

sub send_static_file {
    my $self     = shift;
    my $filename = shift;
    my $type     = 'text/html';

    if ( $filename =~ /.js$/ ) {
        $type = 'text/javascript';
    } elsif ( $filename =~ /.css$/ ) {
        $type = 'text/css';
    } elsif ( $filename =~ /.png$/ ) {
        $type = 'image/png';
    }

    my $system_library_mapping = $self->system_js_and_css();
    my $content;
    if ( $system_library_mapping->{$filename}
        && -f $system_library_mapping->{$filename} )
    {
        $content =
          Prophet::Util->slurp( $system_library_mapping->{$filename} );
    } else {
        for my $root ( $self->app_static_root, $self->prophet_static_root ) {
            next unless -f Prophet::Util->catfile( $root => $filename );
            my $qualified_file =
              Cwd::fast_abs_path( File::Spec->catfile( $root => $filename ) );
            next if substr( $qualified_file, 0, length($root) ) ne $root;
            $content = Prophet::Util->slurp($qualified_file);
        }
    }

    if ( defined $content ) {
        return $self->send_content(
            static       => 1,
            content      => $content,
            content_type => $type
        );
    } else {
        return $self->_send_404;
    }
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

=method make_link_relative PATH

This method does its best to convert a URI path from absolute ( starts at / )
to relative. (Starts at .).

=cut

sub make_link_relative {
    my $self = shift;
    my $link = shift;
    return URI::file->new($link)->rel( "file://" . $self->cgi->path_info() );
}


1;
