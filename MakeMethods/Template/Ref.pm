=head1 NAME

B<Class::MakeMethods::Template::Ref> - Universal copy and compare methods

=head1 SYNOPSIS

  package MyObject;
  use Class::MakeMethods::Template::Ref (
    'Hash:new'      => [ 'new' ],
    clone           => [ 'clone' ]
  );
  
  package main;

  my $obj = MyObject->new( foo => ["Foozle", "Bozzle"] );
  my $clone = $obj->clone();
  print $obj->{'foo'}[1];

=cut

package Class::MakeMethods::Template::Ref;

use Class::MakeMethods::Template '-isasubclass';

use strict;
require 5.00;
use Carp;

######################################################################

=head1 DESCRIPTION

The following types of methods are provided via the Class::MakeMethods interface:

=head2 clone

Produce a deep copy of an instance of almost any underlying datatype. 

Parameters:

init_method 
  
If defined, this method is called on the new object with any arguments passed in.

=cut

sub clone {
  {
    'params' => { 'init_method' => '' },
    'interface' => {
      default => 'clone',
      clone => { '*'=>'clone',  },
    },
    'behavior' => {
      'clone' => sub { my $m_info = $_[0]; sub {
	  my $callee = shift; 
	  ref $callee or croak "Can only copy instances, not a class.\n";
	  
	  my $self = _clone( $callee );
	  
	  my $init_method = $m_info->{'init_method'};
	  if ( $init_method ) {
	    $self->$init_method( @_ );
	  } elsif ( scalar @_ ) {
	    croak "No init_method";
	  }
	  return $self;
	}},
    },
  } 
}

######################################################################

=head2 prototype

Create new instances by making a deep copy of a static prototypical instance. 

Parameters:

init_method 
  
If defined, this method is called on the new object with any arguments passed in.
=cut

sub prototype {
  ( {
    'interface' => {
      default => { '*'=>'set_or_new',  },
    },
    'behavior' => {
      'set_or_new' => sub { my $m_info = $_[0]; sub {
	my $class = shift;
	
	# set
	$m_info->{'instance'} = shift 
	    if ( scalar @_ == 1 and UNIVERSAL::isa( $_[0], $class ) );
	
	# get
	croak "Prototype is not defined" unless $m_info->{'instance'};
	my $self = Ref::copyref($m_info->{'instance'});
	
	my $init_method = $m_info->{'init_method'};
	if ( $init_method ) {
	  $self->$init_method( @_ );
	} elsif ( scalar @_ ) {
	  croak "No init_method";
	}
	return $self;
      }},
      'set' => sub { my $m_info = $_[0]; sub {
	my $class = shift;
	$m_info->{'instance'} = shift 
      }},
      'new' => sub { my $m_info = $_[0]; sub {
	my $class = shift;
	
	croak "Prototype is not defined" unless $m_info->{'instance'};
	my $self = _clone($m_info->{'instance'});
	
	my $init_method = $m_info->{'init_method'};
	if ( $init_method ) {
	  $self->$init_method( @_ );
	} elsif ( scalar @_ ) {
	  croak "No init_method";
	}
	return $self;
      }},
    },
  } )
}

######################################################################

=head2 compare

Compare one object to another. 

B<Templates>

=over 4

=item *

default

Three-way (sorting-style) comparison.

=item *

equals

Are these two objects equivalent?

=item *

identity

Are these two references to the exact same object?

=back

=cut

sub compare {
  {
    'params' => { 'init_method' => '' },
    'interface' => {
      default => { '*'=>'compare',  },
      equals => { '*'=>'equals',  },
      identity => { '*'=>'identity',  },
    },
    'behavior' => {
      'compare' => sub { my $m_info = $_[0]; sub {
	  my $callee = shift; 
	  _compare( $callee, shift );
	}},
      'equals' => sub { my $m_info = $_[0]; sub {
	  my $callee = shift; 
	  _compare( $callee, shift ) == 0;
	}},
      'identity' => sub { my $m_info = $_[0]; sub {
	  $_[0] eq $_[1]
	}},
    },
  } 
}

######################################################################

=head2 INTERNALS

The following functions are used by the above method types.

=head2 _clone()

Make a recursive copy of a reference.

=cut

use vars qw( %CopiedItems );

# $deep_copy = _clone( $value_or_ref );
sub _clone {
  local %CopiedItems = ();
  __clone( @_ );
}

# $copy = __clone( $value_or_ref );
sub __clone {
  my $source = shift;
  
  my $ref_type = ref $source;
  return $source if (! $ref_type);
  
  return $CopiedItems{ $source } if ( exists $CopiedItems{ $source } );
  
  my $class_name;
  if ( "$source" =~ /^\Q$ref_type\E\=([A-Z]+)\(0x[0-9a-f]+\)$/ ) {
    $class_name = $ref_type;
    $ref_type = $1;
  }
  
  my $copy;
  if ($ref_type eq 'SCALAR') {
    $copy = \( $$source );
  } elsif ($ref_type eq 'REF') {
    $copy = \( __clone ($$source) );
  } elsif ($ref_type eq 'HASH') {
    $copy = { map { __clone ($_) } %$source };
  } elsif ($ref_type eq 'ARRAY') {
    $copy = [ map { __clone ($_) } @$source ];
  } else {
    $copy = $source;
  }
  
  bless $copy, $class_name if $class_name;
  
  $CopiedItems{ $source } = $copy;
  
  return $copy;
}

######################################################################

=head2 _compare()

Attempt to recursively compare two references.

If they are not the same, try to be consistent about returning a
positive or negative number so that it can be used for sorting.
The sort order is kinda arbitrary.

=cut

use vars qw( %ComparedItems );

# $positive_zero_or_negative = _compare( $A, $B );
sub _compare {
  local %ComparedItems = ();
  __compare( @_ );
}

# $positive_zero_or_negative = __compare( $A, $B );
sub __compare { 
  my($A, $B, $ignore_class) = @_;

  # If they're both simple scalars, use string comparison
  return $A cmp $B unless ( ref($A) or ref($B) );
  
  # If either one's not a reference, put that one first
  return 1 unless ( ref($A) );
  return - 1 unless ( ref($B) );
  
  # Check to see if we've got two references to the same structure
  return 0 if ("$A" eq "$B");
  
  # If we've already seen these items repeatedly, we may be running in circles
  return undef if ($ComparedItems{ $A } ++ > 2 and $ComparedItems{ $B } ++ > 2);
  
  # Check the ref values, which may be data types or class names
  my $ref_A = ref($A);
  my $ref_B = ref($B);
  return $ref_A cmp $ref_B if ( ! $ignore_class and $ref_A ne $ref_B );
  
  # Extract underlying data types
  my $type_A = ("$A" =~ /^\Q$ref_A\E\=([A-Z]+)\(0x[0-9a-f]+\)$/) ? $1 : $ref_A;
  my $type_B = ("$B" =~ /^\Q$ref_B\E\=([A-Z]+)\(0x[0-9a-f]+\)$/) ? $1 : $ref_B;
  return $type_A cmp $type_B if ( $type_A ne $type_B );
  
  if ($type_A eq 'HASH') {  
    my @kA = sort keys %$A;
    my @kB = sort keys %$B;
    return ( $#kA <=> $#kB ) if ( $#kA != $#kB );
    foreach ( 0 .. $#kA ) {
      return ( compare($kA[$_], $kB[$_]) or 
		compare($A->{$kA[$_]}, $B->{$kB[$_]}) or next );
    }
    return 0;
  } elsif ($type_A eq 'ARRAY') {
    return ( $#$A <=> $#$B ) if ( $#$A != $#$B );
    foreach ( 0 .. $#$A ) {
      return ( compare($A->[$_], $B->[$_]) or next );
    }
    return 0;
  } elsif ($type_A eq 'SCALAR' or $type_A eq 'REF') {
    return compare($$A, $$B);
  } else {
    return ("$A" cmp "$B")
  }
}

######################################################################

=head1  SEE ALSO

See L<Class::MakeMethods> for a reference to the internals of the Class::MakeMethods framework.

See L<Ref> for the original version of the clone and compare functions used above.

See L<Clone> (v0.09 on CPAN as of 2000-09-21) for a clone method with an XS implementation.

The Perl6 RFP #67 proposes including clone functionality in the core.

See L<Data::Compare> (v0.01 on CPAN as of 1999-04-24) for a Compare method which checks two references for similarity, but it does not provide positive/negative values for ordering purposes.

See L<Class::MakeMethods::ReadMe> for distribution and support information.

=head1 LICENSE

Copyright 1998, 2000, 2001 Evolution Online Systems, Inc.

  M. Simon Cavalletto, simonm@evolution.com

Derived in part from Ref.pm, Copyright 1994, David Muir Sharnoff.

=cut

######################################################################

1;
