=head1 NAME

Class::MakeMethods::Utility::ArraySplicer - Common array ops

=head1 SYNOPSIS

  use Class::MakeMethods::Utility::ArraySplicer;
  
  # Get one or more values
  $value = array_splicer( $array_ref, $index );
  @values = array_splicer( $array_ref, $index_array_ref );
  
  # Set one or more values
  array_splicer( $array_ref, $index => $new_value, ... );
  
  # Splice selected values in or out
  array_splicer( $array_ref, [ $start_index, $end_index], [ @values ]);

=head1 DESCRIPTION

This module provides a utility function and several associated constants which support a general purpose array-splicer interface, used by several of the Standard and Composite method generators.

=cut

########################################################################

package Class::MakeMethods::Utility::ArraySplicer;

$VERSION = 1.000;

@EXPORT_OK = qw( 
  array_splicer
  array_set array_clear array_push array_pop array_unshift array_shift
);
sub import { require Exporter and goto &Exporter::import } # lazy Exporter

use strict;

########################################################################

=head2 array_splicer

  # Get one or more values
  $value = array_splicer( $array_ref, $index );
  @values = array_splicer( $array_ref, $index_array_ref );

  # Set one or more values
  array_splicer( $array_ref, $index => $new_value, ... );

  # Splice selected values in or out
  array_splicer( $array_ref, [ $start_index, $end_index], [ @values ]);

=cut

sub array_splicer {
  my $value_ref = shift;
  if ( scalar(@_) == 0 ) {
    return $value_ref;
  } elsif ( scalar(@_) == 1 ) {
    my $index = shift;
    ref($index) ? @{$value_ref}[ @$index ] : $value_ref->[ $index ];
  } elsif ( scalar(@_) % 2 ) {
    Carp::croak 'Odd number of items in assigment to array method';
  } elsif ( ! ref $_[0] ) {
    while ( scalar(@_) ) {
      my $key = shift();
      $value_ref->[ $key ] = shift();
    }
    $value_ref;
  } elsif ( ref $_[0] eq 'ARRAY' ) {
    my @results;
    while ( scalar(@_) ) {
      my $key = shift();
      my $value = shift();
      my @values = ! ( $value ) ? () : ! ref ( $value ) ? $value : @$value;
      my $key_v = $key->[0];
      my $key_c = $key->[1];
      if ( defined $key_v ) {
	if ( $key_c ) {
	  # straightforward two-value splice
	} else {
	  # insert at position
	  $key_c = 0;
	}
      } else {
	if ( ! defined $key_c ) {
	  # target the entire list
	  $key_v = 0;
	  $key_c = scalar @$value_ref;
	} elsif ( $key_c ) {
	  # take count items off the end
	  $key_v = - $key_c
	} else {
	  # insert at the end
	  $key_v = scalar @$value_ref;
	  $key_c = 0;
	}
      }
      push @results, splice @$value_ref, $key_v, $key_c, @values
    }
    ( ! wantarray and scalar @results == 1 ) ? $results[0] : @results;
  } else {
    Carp::croak 'Unexpected arguments to array accessor method';
  }
}

########################################################################

=head2 Constants

There are also constants symbols to facilitate some common combinations of splicing arguments:

  # Reset the array contents to empty
  array_splicer( $array_ref, array_clear );
  
  # Set the array contents to provided values
  array_splicer( $array_ref, array_set, [ 'Foozle', 'Bazzle' ] );
  
  # Unshift an item onto the front of the list
  array_splicer( $array_ref, array_unshift, 'Bubbles' );
  
  # Shift it back off again
  print array_splicer( $array_ref, array_shift );
  
  # Push an item onto the end of the list
  array_splicer( $array_ref, array_push, 'Bubbles' );
  
  # Pop it back off again
  print array_splicer( $array_ref, array_pop );

=cut

use constant array_set => [];
use constant array_clear => ( [], undef );

use constant array_push => [undef];
use constant array_pop => ( [undef, 1], undef );

use constant array_unshift => [0];
use constant array_shift => ( [0, 1], undef );

########################################################################

1;
