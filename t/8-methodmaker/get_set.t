#!/usr/local/bin/perl

package X;

use Class::MakeMethods::Emulator::MethodMaker
  get_set => [qw/ a b /],
  get_set => 'c',
  get_set => [
	      [ undef, undef, 'get_*', 'set_*' ] => qw/ d e /,
	      -noclear       => 'f',
	      -eiffel        => 'g',
	      -java          => 'H',
	      -compatibility => 'i',
	     ];

sub new { bless {}, shift; }

package main;
use lib qw ( ./t );
use Test;

my $o = new X;

TEST { 1 };
TEST { ! defined $o->a };
TEST { $o->a(123) };
TEST { $o->a == 123 };
TEST { ! defined $o->clear_a };
TEST { ! defined $o->a };
TEST { $o->a(456) };
TEST { $o->a == 456 };
TEST { ! defined $o->a (undef) };
TEST { ! defined $o->a };
TEST { defined *X::clear_a{CODE} };

TEST { ! $o->can ('d') };
TEST { ! $o->can ('clear_e') };
TEST { ! defined $o->get_d };
TEST { ! defined $o->set_d ('foo') };
TEST { $o->get_d eq 'foo' };
TEST { ! defined $o->set_d (undef) };
TEST { ! defined $o->get_d };

TEST { $o->can ('f') and ! $o->can ('clear_f') and
	 ! $o->can ('set_f') and ! $o->can ('get_f') };
TEST { $o->can ('g') and ! $o->can ('clear_g') and
	 $o->can ('set_g') and ! $o->can ('get_g') };
TEST { ! $o->can ('h') and ! $o->can ('clear_h') and
	 $o->can ('setH') and $o->can ('getH') };
TEST { $o->can ('i') and $o->can ('clear_i') and
	 ! $o->can ('set_i') and ! $o->can ('get_i') };

exit 0;

