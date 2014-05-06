use Prophet::Test::Syntax;
with 'Prophet::Test';

use Prophet::Record;

test 'edit record' => sub {
    my $self = shift;

    my ( $luid, $uuid );

    my $record =
      Prophet::Record->new( handle => $self->cxn, type => 'Robot Master' );

    ok $uuid = $record->create( props => {} ), 'created a record';

    ok $record->set_props(
        props => {
            name     => 'Shadow Man',
            weapon   => 'Shadow Blade',
            weakness => 'Top Spin',
            strength => undef,
        },
      ),
      'edited a record';

    my $shadow_man = $self->load_record( 'Robot Master', $uuid );
    is $shadow_man->uuid, $uuid, 'correct uuid';
    is $shadow_man->prop('name'),     'Shadow Man',   'correct name';
    is $shadow_man->prop('weapon'),   'Shadow Blade', 'correct weapon';
    is $shadow_man->prop('weakness'), 'Top Spin',     'correct weakness';
    is $shadow_man->prop('strength'), undef,          'strength not set';
};

run_me;
done_testing;
