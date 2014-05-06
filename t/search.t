use Prophet::Test::Syntax;

with 'Prophet::Test';

test search => sub {
    my $self = shift;

    $self->create_record('Bug', {
        summary=>'first ticket summary',
        status=>'new',
    });

    $self->create_record('Bug', {
        summary=>'other ticket summary',
        status=>'new',
    });

    $self->create_record('Bug', {
        summary=>'bad ticket summary',
        status=>'stalled',
        cmp => 'ne',
    });

    use_ok 'Prophet::Search';

    # search for any tickets by regex
    my $search = new_ok 'Prophet::Search' => [app_handle => $self->app, type => 'Bug', regex => '.'];
    my $results = $search->run;
    isa_ok $results, 'Prophet::Collection';
    isa_ok $results->items, 'ARRAY';
    is scalar @{$results->items}, 3, '3 results returned';

    # search for status new
    $search = new_ok 'Prophet::Search' => [
        app_handle => $self->app,
        type => 'Bug',
        props => { status => 'new' },
    ];

    $results = $search->run;
    isa_ok $results, 'Prophet::Collection';
    isa_ok $results->items, 'ARRAY';
    is scalar @{$results->items}, 2, '2 results returned';

    # search for status open
    $search = new_ok 'Prophet::Search' => [
        app_handle => $self->app,
        type => 'Bug',
        props => { status => 'open' },
    ];

    $results = $search->run;
    isa_ok $results, 'Prophet::Collection';
    isa_ok $results->items, 'ARRAY';
    is scalar @{$results->items}, 0, '0 results returned';


    # search for status closed
    $search = new_ok 'Prophet::Search' => [
        app_handle => $self->app,
        type => 'Bug',
        props => { status => 'closed' },
    ];

    $results = $search->run;
    isa_ok $results, 'Prophet::Collection';
    isa_ok $results->items, 'ARRAY';
    is scalar @{$results->items}, 0, '0 results returned';

    # search for status open or new
    $search = new_ok 'Prophet::Search' => [
        app_handle => $self->app,
        type => 'Bug',
        props => { status => 'closed' },
    ];

    $results = $search->run;
    isa_ok $results, 'Prophet::Collection';
    isa_ok $results->items, 'ARRAY';
    is scalar @{$results->items}, 0, '0 results returned';

#     like( $out, $expected, 'found two tickets with status!=new' );

#     $out      = run_command(qw(search --type Bug -- status=~n));
#     $expected = qr/.*first ticket summary.*
# .*other ticket summary.*
# /;
#     like( $out, $expected, 'found two tickets with status=~n' );

#     $out      = run_command(qw(search --type Bug -- summary=~first|bad));
#     $expected = qr/.*first ticket summary.*
# .*bad ticket summary.*
# /;
#     like( $out, $expected, 'found two tickets with status=~first|stalled' );

#     $out =
#       run_command(qw(search --type Bug -- status !=new summary=~first|bad));
#     $expected = qr/bad ticket summary/;
#     like( $out, $expected, 'found two tickets with status=~first|bad' );

#     $out =
#       run_command(qw(search --type Bug -- status ne new summary =~ first|bad));
#     $expected = qr/bad ticket summary/;
#     like( $out, $expected, 'found two tickets with status=~first|bad' );

#     $out      = run_command(qw(search --type Bug -- cmp ne));
#     $expected = qr/bad ticket summary/;
#     like(
#         $out,
#         $expected,
#         "found the ticket with cmp=ne (which didn't treat 'ne' as a comparator)",
#     );

#     $out      = run_command(qw(search --type Bug --regex=new -- status=~n));
#     $expected = qr/first ticket summary/;
#     like( $out, $expected,
#         'found a ticket with regex and props working together' );

};

run_me;
done_testing;

