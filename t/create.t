use Prophet::Test::Syntax;

with 'Prophet::Test';

test 'create record' => sub {
    my $self = shift;
    my $cxn  = $self->cxn;

    use_ok 'Prophet::Record';

    my $record =
      new_ok 'Prophet::Record' => [ handle => $cxn, type => 'Person' ];
    ok my $uuid = $record->create( props => { name => 'Jesse', age => 31 } );

    is $record->prop('age'), 31;
    $record->set_prop( name => 'age', value => 32 );
    is $record->prop('age'), 32;

    ok my $kaia = $record->create( props => { name => 'Kaia', age => 24 } );

    ok my $mao = $record->create(
        props => { name => 'Mao', age => 0.7, species => 'cat' } );

    ok my $mei = $record->create(
        props => { name => 'Mei', age => "0.7", species => 'cat' } );

    use_ok 'Prophet::Collection';

    my $people =
      new_ok 'Prophet::Collection' => [ handle => $cxn, type => 'Person' ];
    $people->matching( sub { ( shift->prop('species') || '' ) ne 'cat' } );

    is $people->count, 2;

    is_deeply [ sort map { $_->prop('name') } @$people ], [qw(Jesse Kaia)];

    my $cats =
      new_ok 'Prophet::Collection' => [ handle => $cxn, type => 'Person' ];
    $cats->matching( sub { ( shift->prop('species') || '' ) eq 'cat' } );
    is $cats->count, 2;
    for (@$cats) {
        is $_->prop('age'), "0.7";
    }
    is_deeply [ sort map { $_->prop('name') } @$cats ], [qw(Mao Mei)];

    my $cat = Prophet::Record->new( handle => $cxn, type => 'Person' );
    ok $cat->load( uuid => $mao );
    ok $cat->set_prop( name => 'age', value => '0.8' );

    my $cat2 =
      new_ok 'Prophet::Record' => [ handle => $cxn, type => 'Person' ];
    ok $cat2->load( uuid => $mei );
    ok $cat2->set_prop( name => 'age', value => '0.8' );

    # Redo our search for cats
    $cats =
      new_ok 'Prophet::Collection' => [ handle => $cxn, type => 'Person' ];
    $cats->matching( sub { ( shift->prop('species') || '' ) eq 'cat' } );
    is $cats->count, 2;
    for (@$cats) {
        is( $_->prop('age'), "0.8" );
    }

    for (@$cats) {
        ok( $_->delete );
    }

    my $records =
      new_ok 'Prophet::Collection' => [ type => 'Person', handle => $cxn ];
    $records->matching( sub {1} );
    is $records->count, 2;

};

run_me;
done_testing;
