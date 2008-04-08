#!/usr/bin/env perl
use warnings;
use strict;
use Prophet::Test tests => 10;

use Test::More;

BEGIN {
    unless ( $ENV{'JIFTY_APP_ROOT'} ) {
        die "You must define a JIFTY_APP_ROOT environment variable which points to your hiveminder source tree";
    }
    require File::Temp;
    $ENV{'PROPHET_REPO'} = $ENV{'SVB_REPO'} = File::Temp::tempdir( CLEANUP => 0 ) . '/_svb';
    warn $ENV{'PROPHET_REPO'};
    use Jifty;
    push @INC, File::Spec->catdir( Jifty::Util->app_root, "lib" );
}

eval 'use BTDT::Test; 1;' or die "$@";

my $server = BTDT::Test->make_server;
my $URL    = $server->started_ok;

$URL =~ s|http://|http://onlooker\@example.com:something@|;

ok( 1, "Loaded the test script" );
my $root = BTDT::CurrentUser->superuser;
my $as_root = BTDT::Model::User->new( current_user => $root );
$as_root->load_by_cols( email => 'onlooker@example.com' );
my ( $val, $msg ) = $as_root->set_accepted_eula_version( Jifty->config->app('EULAVersion') );
ok( $val, $msg );
my $GOODUSER = BTDT::CurrentUser->new( email => 'onlooker@example.com' );
$GOODUSER->user_object->set_accepted_eula_version( Jifty->config->app('EULAVersion') );
my $task = BTDT::Model::Task->new( current_user => $GOODUSER );
$task->create(
    summary     => "Fly Man",
    description => '',
);

diag $task->id;
my ( $ret, $out, $err );

my $sd_rt_url = "hm:$URL";
warn $URL;
eval { ( $ret, $out, $err ) = run_script( 'sd', [ 'pull', $sd_rt_url ] ) };
diag $err;

my ( $yatta_uuid, $flyman_uuid );
run_output_matches( 'sd', [ 'ticket', '--list', '--regex', '.' ], [qr/(.*?)(?{ $flyman_uuid = $1 }) Fly Man (.*)/] );

$task->set_summary('Crash Man');

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', $sd_rt_url ] );

run_output_matches( 'sd', [ 'ticket', '--list', '--regex', '.' ], [qr"$flyman_uuid Crash Man (.*)"] );

( $ret, $out, $err ) = run_script( 'sd', [ 'ticket', '--show', '--uuid', $flyman_uuid ] );

run_output_matches(
    'sd',
    [ 'ticket', '--create', '--summary', 'YATTA', '--status', 'new' ],
    [qr/Created ticket (.*)(?{ $yatta_uuid = $1 })/]
);

diag $yatta_uuid;

run_output_matches(
    'sd',
    [ 'ticket', '--list', '--regex', '.' ],
    [   sort "$yatta_uuid YATTA new",
        "$flyman_uuid Crash Man (no status)",    # XXX: or whatever status captured previously
    ]
);

( $ret, $out, $err ) = run_script( 'sd', [ 'push', $sd_rt_url ] );
diag $err;
ok( $task->load_by_cols( summary => 'YATTA' ) );

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', $sd_rt_url ] );

run_output_matches(
    'sd',
    [ 'ticket',                     '--list', '--regex', '.' ],
    [ sort "$yatta_uuid YATTA new", "$flyman_uuid Crash Man (no status)", ]
);

$task->set_summary('KILL');

( $ret, $out, $err ) = run_script( 'sd', [ 'pull', $sd_rt_url ] );

run_output_matches(
    'sd',
    [ 'ticket',                    '--list', '--regex', '.' ],
    [ sort "$yatta_uuid KILL new", "$flyman_uuid Crash Man (no status)", ]
);
