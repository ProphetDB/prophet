#!/usr/bin/env perl
package App::Settings::CLI;
use Moo;
extends 'Prophet::CLI';

use App::Settings;

has '+app_class' => ( default => 'App::Settings', );


1;

