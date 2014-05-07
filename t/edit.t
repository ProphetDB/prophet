use Prophet::Test::Syntax;
with 'Prophet::Test';

use Prophet::Record;

test 'edit record' => sub {
    my $self = shift;

    my $record = $self->create_record('Robot Master');

    $self->update_record(
        'Robot Master',
        $record->uuid,
        {
            name     => 'Shadow Man',
            weapon   => 'Shadow Blade',
            weakness => 'Top Spin',
            strength => undef,
        },
    );

    my $shadow_man = $self->load_record( 'Robot Master', $record->uuid );
    is $shadow_man->uuid, $record->uuid, 'correct uuid';
    is $shadow_man->prop('name'),     'Shadow Man',   'correct name';
    is $shadow_man->prop('weapon'),   'Shadow Blade', 'correct weapon';
    is $shadow_man->prop('weakness'), 'Top Spin',     'correct weakness';
    is $shadow_man->prop('strength'), undef,          'strength not set';
};

run_me;
done_testing;
