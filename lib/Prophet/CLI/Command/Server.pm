package Prophet::CLI::Command::Server;
use Moo;
extends 'Prophet::CLI::Command';

use Prophet::Types qw/InstanceOf Maybe/;

has server => (
    is      => 'rw',
    isa     => Maybe [ InstanceOf ['Prophet::Server'] ],
    default => sub {
        my $self = shift;
        return $self->setup_server();
    },
    lazy => 1,
);

sub ARG_TRANSLATIONS {
    shift->SUPER::ARG_TRANSLATIONS(), p => 'port', w => 'writable';
}

use Prophet::Server;

sub usage_msg {
    my $self = shift;
    my ( $cmd, $subcmd ) = $self->get_cmd_and_subcmd_names( no_type => 1 );

    return <<"END_USAGE";
usage: ${cmd}${subcmd} [--port <number>]
END_USAGE
}

sub run {
    my $self = shift;

    $self->print_usage if $self->has_arg('h');

    Prophet::CLI->end_pager();
    $self->server->run;
}

sub setup_server {
    my $self = shift;

    my $server_class = ref( $self->app_handle ) . "::Server";
    if ( !$self->app_handle->try_to_require($server_class) ) {
        $server_class = "Prophet::Server";
    }
    my $server;
    if ( $self->has_arg('port') ) {
        $server = $server_class->new(
            app_handle => $self->app_handle,
            port       => $self->arg('port')
        );
    } else {
        $server = $server_class->new( app_handle => $self->app_handle );
    }
    return $server;
}

1;

