#!/usr/local/bin/perl

package Y;

sub new { bless {}, shift; }
sub foo { $_[0]->{foo} = $_[1] if $#_; $_[0]->{foo} }

package X;

use lib qw ( ./t-mm );
use Test;
use Tie::RefHash;

use Class::MakeMethods::Emulator::MethodMaker
  tie_hash => [
	       a => {
		     'tie'	=> qw/ Tie::RefHash /,
		     'args' => [],
		    },
	       b => {
		     'tie'	=> qw/ Tie::RefHash /,
		     'args' => [],
		    },
	      ];

sub new { bless {}, shift; }
my $o = new X;

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
  my @l = sort keys %{$o->a};
  $l[0] eq 'a' and
  $l[1] eq 'bar' and
  $l[2] eq 'c' and
  $l[3] eq 'foo'
};

TEST {
  my @l = sort $o->a_keys;
  $l[0] eq 'a' and
  $l[1] eq 'bar' and
  $l[2] eq 'c' and
  $l[3] eq 'foo'
};

TEST {
  my @l = sort $o->a_values;
  $l[0] eq 'b' and
  $l[1] eq 'baz' and
  $l[2] eq 'baz2' and
  $l[3] eq 'd'
};

TEST { $o->b_tally(qw / a b c a b a d / ); };
TEST {
  my %h = $o->b;
  $h{'a'} == 3 and
  $h{'b'} == 2 and
  $h{'c'} == 1 and
  $h{'d'} == 1
};

# Test use of tie...
TEST {
  my $y1 = new Y;
  my $y2 = new Y;
  $y2->foo ("test");
  $o->b ( $y1 => $y2 );
  $o->b ($y1)->foo eq "test";
};

exit 0;

