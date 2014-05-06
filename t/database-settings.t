package MyApp::Model::Task;
use Moo;
extends 'Prophet::Record';
use Prophet::DatabaseSetting;

has '+type' => ( default => 'task' );

sub status_list {
    my $self = shift;
    return Prophet::DatabaseSetting->new(
        handle => $self->handle,
        uuid   => '5F7F1F51-7CD5-4AF7-A347-1FEE15082A5D'
    );
}

sub component_list {
    my $self = shift;
    return Prophet::DatabaseSetting->new(
        handle => $self->handle,
        uuid   => 'D4051774-6AEC-4976-A54E-F19C424879B2'
    );
}

sub default_component {
    my $self = shift;
    return Prophet::DatabaseSetting->new(
        handle => $self->handle,
        uuid   => 'B379D747-CB1D-4F69-839B-8E93E0FA3DD4'
    );
}

package main;
use Prophet::Test::Syntax;

with 'Prophet::Test';

test 'as alice' => sub {
    my $self = shift;

    # set up an app model class, "ticket"*
    my $t = new_ok 'MyApp::Model::Task' => [ handle => $self->cxn ];

    # set default values for status
    ok my $status_list = $t->status_list;

    ok my $comp_list    = $t->component_list;
    ok my $default_comp = $t->default_component;

    isa_ok $status_list, 'Prophet::DatabaseSetting';

    can_ok $status_list, 'set';
    can_ok $status_list, 'get';

    # set list of acceptable components
    ok $comp_list->set( [qw/core ui docs/] );

    # set default values for component
    ok $default_comp->set('core');

    # set list of acceptable statuses
    ok $status_list->set( 'new', 'open', 'closed' );

    # enumerate statuses
    is_deeply $status_list->get, [qw/new open closed/];

    ok $status_list->set( 'new', 'closed' );

    is_deeply $status_list->get, [qw/new closed/];

    # enumerate components
    is_deeply $t->component_list->get, [qw/core ui docs/];

    # enumerate default component
    is_deeply $t->default_component->get, ['core'],
      'The thing we got was core';

    # just for good measure, create a ticket
    ok $t->create(
        props => { type => 'Bug', status => 'new', from => 'alice' } ),
      'Created a record as alice';

    # run_output_matches( 'prophet', [qw(search --type Bug --regex .)],
    #     [qr/new/], [], " Found our record" );

};

# as_bob {
#     $bob_cli = Prophet::CLI->new();
#     my $cxn = $bob_cli->handle;
#     isa_ok( $cxn, 'Prophet::Replica', "Got the cxn " . $cxn->fs_root );

#     # pull from alice
#     run_ok(
#         'prophet',
#         [
#             'clone', '--from',
#             "file://" . $alice_cli->app_handle->handle->fs_root,
#             '--as', 'alice'
#         ]
#     );
#     run_ok(
#         'prophet',
#         [qw(create --type Bug -- --status open --from bob )],
#         "Created a record as bob"
#     );
#     run_output_matches( 'prophet', [qw(search --type Bug --regex open)],
#         [qr/open/], [], "Found our record" );

#     my $t = MyApp::Model::Task->new( handle => $bob_cli->app_handle->handle );

#     # enumerate statuses
#     is_deeply( $t->status_list->get, [qw/new closed/] );

#     # enumerate components
#     is_deeply( $t->component_list->get, [qw/core ui docs/] );

#     # enumerate default component
#     is_deeply( $t->default_component->get,
#         ['core'], "The thing we got was core" );

#     $t->default_component->set('ui');

#     is_deeply( $t->default_component->get,
#         ['ui'], "The thing we got was core" );
# };

# as_alice {
#     $alice_cli = Prophet::CLI->new();
#     my $cxn = $alice_cli->handle;
#     isa_ok( $cxn, 'Prophet::Replica', "Got the cxn " . $cxn->fs_root );

#     my $t =
#       MyApp::Model::Task->new( handle => $alice_cli->app_handle->handle );
#     is_deeply( $t->default_component->get,
#         ['core'], "The thing we got was core" );
#     run_ok(
#         'prophet',
#         [
#             'pull',                                            '--from',
#             "file://" . $bob_cli->app_handle->handle->fs_root, '--force'
#         ]
#     );
#     is_deeply( $t->default_component->get,
#         ['ui'], "The thing we got was core" );

#     #   add a status
#     $t->status_list->set(qw/new open stalled resolved/);

# };

# as_bob {
#     my $t = MyApp::Model::Task->new( handle => $bob_cli->app_handle->handle );
#     $t->status_list->set(qw/new open resolved rejected/);

# };

# as_bob {

#     #   pull from alice
#     #run_ok( 'prophet', ['pull', '--from', "file://".$alice_cli->app_handle->handle->fs_root, '--force', '--prefer', 'to'] );
#     run_ok( 'prophet',
#         [ 'pull', '--from', 'alice', '--force', '--prefer', 'to' ] );

#     # enumerate statuses
#     my $t = MyApp::Model::Task->new( handle => $bob_cli->app_handle->handle );
#   TODO: {
#         local $TODO = "we don't resolve config conflicts yet";
#         is_deeply( $t->status_list->get,
#             [qw[new open stalled resolved rejected]] );
#     }

#     # current behaviour
#     is_deeply( $t->status_list->get, [qw[new open resolved rejected]] );
# };

# as_alice {

#     #    pull from bob
#     run_ok(
#         'prophet',
#         [
#             'pull',                                            '--from',
#             "file://" . $bob_cli->app_handle->handle->fs_root, '--force'
#         ]
#     );

#     # enumerate statuses
#     my $t = MyApp::Model::Task->new( handle => $bob_cli->app_handle->handle );
#   TODO: {
#         local $TODO = "we don't resolve config conflicts yet";
#         is_deeply( $t->status_list->get,
#             [qw[new open stalled resolved rejected]] );
#     }

#     # current behaviour
#     is_deeply( $t->status_list->get, [qw[new open resolved rejected]] );
# };

run_me;
done_testing;
