#!/usr/local/bin/perl

package X;

use lib qw ( ./t );
use Test;

use Class::MakeMethods::Basic::Static ( hash => [ 'a', 'c' ] );

sub new { bless {}, shift; }
my $o = new X;
my $o2 = new X;

TEST { 1 };
TEST { ! scalar keys %{$o->a} };
TEST { ! defined $o->a('foo') };
TEST { $o->a('foo', 'baz') };
TEST { $o->a('foo') eq 'baz' };
TEST { $o->a('bar', 'baz2') };
TEST {
  my @l = $o->a([qw / foo bar / ]);
  $l[0] eq 'baz' and $l[1] eq 'baz2'
};

TEST { $o->a(qw / a b c d / ) };
TEST {
  my %h = %{ $o->a };
  my @l = sort keys %h;
  $l[0] eq 'a' and
  $l[1] eq 'bar' and
  $l[2] eq 'c' and
  $l[3] eq 'foo'
};

TEST {
  my %h=('w' => 'x', 'y' => 'z');
  my $r = $o->a(%h);
};

TEST {
  my @l = sort keys %{ $o->a };
  $l[0] eq 'a' and
  $l[1] eq 'bar' and
  $l[2] eq 'c' and
  $l[3] eq 'foo' and
  $l[4] eq 'w' and
  $l[5] eq 'y'
};

TEST {
  my @l = sort values %{ $o->a };
  $l[0] eq 'b' and
  $l[1] eq 'baz' and
  $l[2] eq 'baz2' and
  $l[3] eq 'd' and
  $l[4] eq 'x' and
  $l[5] eq 'z'
};

TEST { ! defined $o->c('foo') };
TEST { defined $o->c };

TEST { $o->a eq $o2->a };

exit 0;

