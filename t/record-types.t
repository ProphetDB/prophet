use Prophet::Test::Syntax;

with 'Prophet::Test';

# regression test: bad things happen when you're allowed to e.g., update
# a record of type comment when your context's type is set to ticket

test 'record types' => sub {
    my $self = shift;
    use_ok 'Prophet::Record';
    my $record =
      new_ok 'Prophet::Record' => [ handle => $self->cxn, type => 'ticket' ];

    ok my $ticket_uuid = $record->create( props => { status => 'new' } ),
      'Created ticket record';

    $record =
      new_ok 'Prophet::Record' => [ handle => $self->cxn, type => 'comment' ];

    ok my $comment_uuid = $record->create( props => { content => 'yay!' } ),
      'Created comment record';

  TODO: {
        local $TODO = 'These are supposed to fail';

        my ( $ticket, $comment );

        like(
            exception {
                $ticket = $self->load_record( 'ticket', $comment_uuid );
            },
            qr/Failed to load ticket/,
            'Failed to load ticket from comment id',
        );

        like(
            exception {
                $comment = $self->load_record( 'comment', $ticket_uuid );
            },
            qr/Failed to load comment/,
            'Failed to load comment from ticket id',
        );
    }

};

run_me;
done_testing;
