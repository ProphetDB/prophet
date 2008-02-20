use warnings;
use strict;
use Test::More 'no_plan';
use File::Temp qw'tempdir';
use lib 't/lib';

use_ok('SVN::PropDB::Handle');
my $REPO= tempdir(CLEANUP => 0).'/repo-'.$$;
ok(! -d $REPO);
`svnadmin create $REPO`;
ok(-d $REPO, "The repo exists ater svnadmin create");
my $cxn = SVN::PropDB::Handle->new( repository => "$REPO", db_root => '/_propdb-test');
isa_ok($cxn, 'SVN::PropDB::Handle', "Got the cxn");
use_ok('TestApp::Bug');

my $record = TestApp::Bug->new(handle => $cxn);


isa_ok($record, 'TestApp::Bug');
isa_ok($record, 'SVN::PropDB::Record');



my $uuid  = $record->create(props => { name => 'Jesse', age => 31});
ok($uuid);

my $kuuid  = $record->create(props => { name => 'Bob', age => 31});
ok(!$kuuid);