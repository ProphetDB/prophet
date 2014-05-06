use Prophet::Test::Syntax;

with 'Prophet::Test';

# eval { require Template::Declare };
# print ref $@;
# if ($@) {
#     plan skip_all => 'Template::Declare is not installed';
# } else {
#     plan tests => 13;
# }

my $alice_published = Path::Tiny->tempdir( CLEANUP => !$ENV{PROPHET_DEBUG} );

test publish_html => sub {
    my $self = shift;

    my ( $bug_uuid, $pullall_uuid );

    use_ok 'Prophet::Record';
    my $record =
      new_ok 'Prophet::Record' => [ handle => $self->cxn, type => 'Bug' ];

    ok $bug_uuid = $record->create(
        props => {
            status  => 'new',
            from    => 'alice',
            summary => 'this is a template test',
        }
    );

    # $out      = run_command(qw(search --type Bug --regex .));
    # $expected = qr/new/;
    # like( $out, $expected, 'Found our record' );

    # ok( run_command( qw(publish --html --to), $alice_published ),
    #     'alice publish html',
    # );

    # my $dir = $alice_published;

    # my $merge_tickets = File::Spec->catdir(
    #     $dir => $Prophet::Replica::MERGETICKET_METATYPE );
    # ok( !-e $merge_tickets, "_merge_tickets template directory absent" );

    # my $bug = File::Spec->catdir( $dir => 'Bug' );
    # ok( -e $bug, "Bug template directory exists" );

    # my $index = Prophet::Util->catfile( $bug => 'index.html' );
    # ok( -e $index, "Bug/index.html exists" );

    # my $bug_template = Prophet::Util->catfile( $bug => "$bug_uuid.html" );
    # ok( -e $bug_template, "Bug/$bug_uuid.html exists" );

    # my $index_contents = Prophet::Util->slurp($index);
    # like( $index_contents, qr/$bug_uuid/, "index contains bug uuid" );
    # like(
    #     $index_contents,
    #     qr/this is a template test/,
    #     "index contains bug summary"
    # );

    # my $bug_contents = Prophet::Util->slurp($bug_template);
    # like( $bug_contents, qr/$bug_uuid/, "bug contains bug uuid" );
    # like(
    #     $bug_contents,
    #     qr/this is a template test/,
    #     "bug contains bug summary"
    # );
};

run_me;
done_testing;

