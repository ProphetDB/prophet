package Prophet::Server::ViewHelpers::HiddenParam;

use Template::Declare::Tags;
use Prophet::Types 'Str';

BEGIN {
    delete ${ __PACKAGE__ . "::" }{meta};
    delete ${ __PACKAGE__ . "::" }{with};
}

use Moo;

extends 'Prophet::Server::ViewHelpers::Widget';

has value => ( isa => Str, is => 'rw');

sub render {
    my $self = shift;

    my $unique_name = $self->_generate_name();

    my $record = $self->function->record;

    $self->field(
        Prophet::Web::Field->new(
            name   => $unique_name,
            id     => $unique_name,
            record => $record,
            class  => 'hidden-prop-'
              . $self->prop
              . ' function-'
              . $self->function->name,
            value => $self->value,
            type  => 'hidden'
          )

    );

    outs_raw( $self->field->render_input );

}

1;

