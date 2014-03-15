package Prophet::Server::ViewHelpers::ParamFromFunction;

use Template::Declare::Tags;
use Prophet::Types qw/Bool Enum InstanceOf Int Str/;

BEGIN {
    delete ${ __PACKAGE__ . "::" }{meta};
    delete ${ __PACKAGE__ . "::" }{with};
}

use Moo;

has function => (
    isa => InstanceOf ['Prophet::Server::ViewHelpers::Function'],
    is => 'ro'
);

has name          => ( isa => Str,                 is => 'rw' );
has prop          => ( isa => Str,                 is => 'ro' );
has from_function => ( isa => InstanceOf['Prophet::Server::ViewHelpers::Function'],                 is => 'rw' );
has from_result   => ( isa => Str,                 is => 'rw' );
has field         => ( isa => InstanceOf['Prophet::Web::Field'], is => 'rw' );

sub render {
    my $self = shift;

    my $unique_name = $self->_generate_name();

    my $record = $self->function->record;

    my $value =
        "function-"
      . $self->from_function->name
      . "|result-"
      . $self->from_result;

    $self->field(
        Prophet::Web::Field->new(
            name   => $unique_name,
            type   => 'hidden',
            record => $record,
            value  => $value

        )
    );

    outs_raw( $self->field->render_input );
}

sub _generate_name {
    my $self = shift;
    return
        "prophet-fill-function-"
      . $self->function->name
      . "-prop-"
      . $self->prop;
}

1;

