=head1 NAME

Class::MakeMethods::Standard - Guide to subclasses


=head1 SYNOPSIS

  package MyObject;
  use Class::MakeMethods::Standard::Hash (
    new => 'new',
    scalar => [ 'foo', 'bar' ],
    array => 'my_list',
    hash => 'my_index',
  );


=head1 DESCRIPTION

This document describes the various subclasses of Class::MakeMethods
included under the Standard::* namespace, and the method types each
one provides.

The Standard subclasses provide a parameterized set of method-generation
implementations.

Subroutines are generated as closures bound to a hash containing
the method name and (optionally) additional parameters.


=head2 Calling Conventions

When you C<use> a subclass of this package, the method declarations you provide
as arguments cause subroutines to be generated and installed in
your module. You can also omit the arguments to C<use> and instead make methods
at runtime by passing the declarations to a subsequent call to
C<make()>.

You may include any number of declarations in each call to C<use>
or C<make()>. If methods with the same name already exist, earlier
calls to C<use> or C<make()> win over later ones, but within each
call, later declarations superceed earlier ones.

You can install methods in a different package by passing C<-target_class =E<gt> I<package>> as your first arguments to C<use> or C<make>. 

See L<Class::MakeMethods/"USAGE"> for more details.

=head2 Declaration Syntax

The following types of Simple declarations are supported:

=over 4

=item *

I<generator_type> => 'I<method_name>'

=item *

I<generator_type> => 'I<name_1> I<name_2>...'

=item *

I<generator_type> => [ 'I<name_1>', 'I<name_2>', ...]

=back

For a list of the supported values of I<generator_type>, see L<"SUBCLASS CATALOG"> below, or the documentation for each subclass.

For each method name you provide, a subroutine of the indicated
type will be generated and installed under that name in your module.

Method names should start with a letter, followed by zero or more
letters, numbers, or underscores.

=head2 Parameter Syntax

The Standard syntax also provides several ways to optionally
associate a hash of additional parameters with a given method
name. 

=over 4

=item *

I<generator_type> => [ 
    'I<name_1>' => { I<param>=>I<value>... }, I<...>
  ]

A hash of parameters to use just for this method name. 

(Note: to prevent confusion with self-contained definition hashes,
described below, parameter hashes following a method name must not
contain the key C<'name'>.)

=item *

I<generator_type> => [ 
    [ 'I<name_1>', 'I<name_2>', ... ] => { I<param>=>I<value>... }
  ]

Each of these method names gets a copy of the same set of parameters.

=item *

I<generator_type> => [ 
    { 'name'=>'I<name_1>', I<param>=>I<value>... }, I<...>
  ]

By including the reserved parameter C<'name'>, you create a self-contained declaration with that name and any associated hash values.

=back

Simple declarations, as described above, are given an empty parameter hash.


=cut

package Class::MakeMethods::Standard;

use strict;
use Class::MakeMethods '-isasubclass';

sub _diagnostic { &Class::MakeMethods::_diagnostic }

########################################################################

my $name_key = 'name';

sub get_declarations {
  my $class = shift;
  
  my @results;
  
  while (scalar @_) {
    my $m_name = shift @_;
    if ( ! defined $m_name or ! length $m_name ) {
      _diagnostic('make_empty') 
    }
    
    # Parse string and string-then-hash declarations
    elsif ( ! ref $m_name ) {
      if ( scalar @_ and ref $_[0] eq 'HASH' and ! exists $_[0]->{$name_key} ) {
	push @results, { $name_key => $m_name, %{ shift @_ } };
      } else {
	push @results, { $name_key => $m_name };
      }
    } 
    
    # Parse hash-only declarations
    elsif ( ref $m_name eq 'HASH' ) {
      if ( length $m_name->{$name_key} ) {
	push @results, { %$m_name };
      } else {
	_diagnostic('make_noname');
      }
    }
    
    # Normalize: If we've got an array of names, replace it with those names 
    elsif ( ref $m_name eq 'ARRAY' ) {
      my @items = @{ $m_name };
      # If array is followed by an params hash, each one gets the same params
      if ( scalar @_ and ref $_[0] eq 'HASH' and ! exists $_[0]->{$name_key} ) {
	my $params = shift;
	@items = map { $_, $params } @items
      }
      unshift @_, @items;
      next;
    }
    
    else {
      _diagnostic('make_unsupported', $m_name);
    }
    
  }
  
  return @results;
}

########################################################################

=head1 SUBCLASS CATALOG

=head2 Standard::Hash (Instances)

Methods for objects based on blessed hashes.

=over 4

=item *

new: create and copy instances

=item *

scalar: get and set scalar values in each instance

=item *

array: get and set values stored in an array refered to in each
instance

=item *

hash: get and set values in a hash refered to in each instance

=item *

object: access an object refered to by each instance

=back

=head2 Standard::Array (Instances)

Methods for manipulating positional values in arrays.

=over 4

=item *

new: create and copy instances

=item *

scalar: get and set scalar values in each instance

=item *

array: get and set values stored in an array refered to in each
instance

=item *

hash: get and set values in a hash refered to in each instance

=item *

object: access an object refered to by each instance

=back

=head2 Standard::Global (Global)

Methods for manipulating global data.

=over 4

=item *

scalar: get and set global scalar

=item *

array: get and set values stored in a global array

=item *

hash: get and set values in a global hash

=item *

object: global access to an object ref

=back


=head2 Standard::Inheritable (Any)

Methods for manipulating data which may be overridden per class or instance. Uses external data storage, so it works with objects of any underlying data type. 

=over 4

=item *

scalar: get and set scalar values for each instance or class

=back

=cut

########################################################################

=head2 Supporting functions for array methods

There are also constants symbols for some for some common combinations of splicing arguments:

  # Reset the array contents to empty
  $obj->bar( array_clear );
  
  # Set the array contents to provided values
  $obj->bar( array_set, [ 'Foozle', 'Bazzle' ] );
  
  # Unshift an item onto the front of the list
  $obj->bar( array_unshift, 'Bubbles' );
  
  # Shift it back off again
  print $obj->bar( array_shift );
  
  # Push an item onto the end of the list
  $obj->bar( array_push, 'Bubbles' );
  
  # Pop it back off again
  print $obj->bar( array_pop );

=cut

use constant array_set => [];
use constant array_clear => ( [], undef );

use constant array_push => [undef];
use constant array_pop => ( [undef, 1], undef );

use constant array_unshift => [0];
use constant array_shift => ( [0, 1], undef );

sub __array_ops {
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

=head1 SEE ALSO

See L<Class::MakeMethods> for an overview of the method-generation
framework this is based on.

See L<Class::MakeMethods::Guide> for a getting-started guide,
annotated examples of usage, and a listing of the method generation
classes included in this distribution.

See L<Class::MakeMethods::ReadMe> for distribution, installation,
version and support information.

=cut

1;