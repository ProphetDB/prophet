package Prophet::Web::Field;
use Moo;
use Prophet::Types qw/InstanceOf Maybe Str/;

has name   => ( is => 'rw', isa => Str );
has record => ( is => 'rw', isa => InstanceOf['Prophet::Record'] );
has prop   => ( is => 'rw', isa => Str);
#has value  => ( is => 'rw', isa => Str );
has label  => ( is => 'rw', isa => Str, default => sub {''});
has id     => ( is => 'rw', isa => Maybe[Str] );
has class  => ( is => 'rw', isa => Maybe[Str] );
has value  => ( is => 'rw', isa => Maybe[Str] );
has type   => ( is => 'rw', isa => Maybe[Str], default => 'text');

sub _render_attr {
    my $self  = shift;
    my $attr  = shift;
    my $value = $self->$attr() || return '';
    Prophet::Util::escape_utf8( \$value );
    return $attr . '="' . $value . '"';
}

sub render_name {
    my $self = shift;
    $self->_render_attr('name');

}

sub render_id {
    my $self = shift;
    $self->_render_attr('id');
}

sub render_class {
    my $self = shift;
    $self->_render_attr('class');
}

sub render_value {
    my $self = shift;
    $self->_render_attr('value');
}

sub render {
    my $self = shift;

    my $output = <<EOF;
<label @{[$self->render_name]} @{[$self->render_class]}>@{[$self->label]}</label>
@{[$self->render_input]}


EOF

    return $output;

}

sub render_input {
    my $self = shift;

    if ( $self->type eq 'textarea' ) {
        my $value = $self->value() || '';
        Prophet::Util::escape_utf8( \$value );

        return <<EOF;
<textarea @{[$self->render_name]} @{[$self->render_id]} @{[$self->render_class]} >@{[$value]}</textarea>
EOF
    } else {

        return <<EOF;
<input type="@{[$self->type]}" @{[$self->render_name]} @{[$self->render_id]} @{[$self->render_class]} @{[$self->render_value]} />
EOF

    }

}

1;
