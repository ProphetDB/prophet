#!/usr/bin/env perl
use warnings;
use strict;
use Prophet::Test tests => 3;

# you need to run this test script from the BTDT directory

eval 'use BTDT::Test; 1;'
    or plan skip_all => 'requires 3.7 to run tests.'.$@;

my $server = BTDT::Test->make_server;
my $URL = $server->started_ok;

$URL =~ s|http://|http://gooduser\@example.com:secret@|;

ok(1, "Loaded the test script");

my $GOODUSER = BTDT::CurrentUser->new( email => 'gooduser@example.com' );
my $task = BTDT::Model::Task->new(current_user => $GOODUSER);
$task->create(
    summary => "Fly Man",
    description => '',
);

diag $task->id;
my ($ret, $out, $err);

my $sd_rt_url = "hm:$URL";

($ret, $out, $err) = run_script('sd', ['pull', $sd_rt_url]);
diag $err;

my ($yatta_uuid, $flyman_uuid);
run_output_matches('sd', ['ticket', '--list', '--regex', '.'], [qr/(.*?)(?{ $flyman_uuid = $1 }) Fly Man (.*)/]);

$task->set_summary( 'Crash Man' );

($ret, $out, $err) = run_script('sd', ['pull', $sd_rt_url]);

run_output_matches('sd', ['ticket', '--list', '--regex', '.'], ["$flyman_uuid Crash Man (.*)"]);

run_output_matches('sd', ['ticket', '--create', '--summary', 'YATTA', '--status', 'new'], [qr/Created ticket (.*)(?{ $yatta_uuid = $1 })/]);

diag $yatta_uuid;

run_output_matches('sd', ['ticket', '--list', '--regex', '.'],
                   [ sort 
                    "$yatta_uuid YATTA new",
                     "$flyman_uuid Crash Man (no status)", # XXX: or whatever status captured previously
                   ]);

($ret, $out, $err) = run_script('sd', ['push', $sd_rt_url]);
diag $err;
ok( $task->load_by_cols( summary => 'YATTA' ) );

($ret, $out, $err) = run_script('sd', ['pull', $sd_rt_url]);

run_output_matches('sd', ['ticket', '--list', '--regex', '.'],
                   [ sort
                    "$yatta_uuid YATTA new",
                     "$flyman_uuid Fly Man (no status)",
                   ]);

$task->set_summary( 'KILL' );

($ret, $out, $err) = run_script('sd', ['pull', $sd_rt_url]);

run_output_matches('sd', ['ticket', '--list', '--regex', '.'],
                   [ sort
                    "$yatta_uuid KILL new",
                     "$flyman_uuid Fly Man (no status)",
                   ]);
