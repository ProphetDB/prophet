package App::WebToy::CLI;
use Moo;
extends 'Prophet::CLI';

use App::WebToy;

has 'app_class' => ( default => 'App::WebToy', );


1;

