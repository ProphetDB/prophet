use Prophet::Test::Syntax;

with 'Prophet::Test';

has test_conf => (
    is      => 'ro',
    lazy    => 1,
    default => sub {
        my $src       = path 't/test_app.conf';
        my $repo_path = path $ENV{PROPHET_REPO};
        $repo_path->mkpath;
        my $config_file = $repo_path->child('test_app.conf');
        $src->copy($config_file);
        return $config_file;
    },
);

test config => sub {
    my $self = shift;
    local $ENV{PROPHET_APP_CONFIG} = $self->test_conf;

    my $conf = new_ok 'Prophet::Config' => [
        app_handle => $self->app,
        handle     => $self->app->handle,
        confname   => 'testrc',
    ];

    ok $conf->load, 'config loaded';

    # make sure we only have the one test config file loaded
    is scalar @{ $conf->config_files }, 1, 'only test conf is loaded';

    # interrogate its config to see if we have any config options set
    my @data = $conf->dump;
    is scalar @data, 6, '3 config options are set';

    # test the aliases sub
    is $conf->aliases->{tlist}, 'ticket list', 'Got correct alias';

    # test automatic reload after setting
    $conf->set(
        key      => 'replica.sd.url',
        value    => 'http://fsck.com/sd/',
        filename => $self->test_conf,
    );
    is $conf->get( key => 'replica.sd.url' ),
      'http://fsck.com/sd/', 'automatic reload after set';

    # test the sources sub
    is $conf->sources->{sd}, 'http://fsck.com/sd/', 'Got correct alias';
    is $conf->sources( by_variable => 1 )->{'http://fsck.com/sd/'}, 'sd',
      'Got correct alias';

    # test the display_name_for_replica sub
    $conf->set(
        key      => 'replica.sd.uuid',
        value    => '32b13934-910a-4792-b5ed-c9977b212245',
        filename => $self->test_conf,
    );
    is $self->app->display_name_for_replica(
        '32b13934-910a-4792-b5ed-c9977b212245'), 'sd',
      'Got correct display name';

    my $got = $conf->dump;

    my $expect .= <<EOF;
alias.tlist=ticket list
core.config-format-version=0
replica.sd.url=http://fsck.com/sd/
replica.sd.uuid=32b13934-910a-4792-b5ed-c9977b212245
test.foo=bar
test.re=rawr
EOF
    is $got, $expect, 'config dump';
};

run_me;
done_testing;
