=head1 NAME

Class::MakeMethods::Standard::Inheritable - Inheritable data

=head1 SYNOPSIS

  package MyClass;
  use Class::MakeMethods::Standard::Inheritable (
    scalar => [ 'foo', 'bar' ],
    array => 'my_list',
    hash => 'my_index',
  );
  
  package MySubClass;
  @ISA = 'MyClass';
  ...
  
  MyClass->foo( 'Foozle' );
  print MyClass->foo();
  
  MyClass->my_list(0 => 'Foozle', 1 => 'Bang!');
  print MyClass->my_list(1);
  
  MyClass->my_index('broccoli' => 'Blah!', 'foo' => 'Fiddle');
  print MyClass->my_index('foo');
  ...
  
  my $obj = MyClass->new(...);
  print $obj->foo();     # all instances default to same value
  
  $obj->foo( 'Foible' ); # until you set a value for an instance
  print $obj->foo();     # it now has its own value
  
  print MySubClass->foo();    # intially same as superclass
  MySubClass->foo('Foobar');  # but overridable per subclass
  print $subclass_obj->foo(); # and shared by its instances
  $subclass_obj->foo('Fosil');# until you override them... 


=head1 DESCRIPTION

The Standard::Inheritable suclass of MakeMethods provides basic accessors for class-specific data.

=head2 Calling Conventions

When you C<use> this package, the method names you provide
as arguments cause subroutines to be generated and installed in
your module.

See L<Class::MakeMethods::Standard/"Calling Conventions"> for more information.

=head2 Declaration Syntax

To declare methods, pass in pairs of a method-type name followed
by one or more method names. 

Valid method-type names for this package are listed in L<"METHOD
GENERATOR TYPES">.

See L<Class::MakeMethods::Standard/"Declaration Syntax"> and L<Class::MakeMethods::Standard/"Parameter Syntax"> for more information.

=cut

package Class::MakeMethods::Standard::Inheritable;

use strict;
use Class::MakeMethods::Standard '-isasubclass';

########################################################################

=head1 METHOD GENERATOR TYPES

=head2 scalar - Class-specific Accessor

For each method name passed, uses a closure to generate a subroutine with the following characteristics:

=over 4

=item *

May be called as a class or instance method, on the declaring class or any subclass. 

=item *

If called without any arguments returns the current value for the callee. If the callee has not had a value defined for this method, searches up from instance to class, and from class to superclass, until a callee with a value is located.

=item *

If called with an argument, stores that as the value associated with the callee, whether instance or class, and returns it, 

=back

Sample declaration and usage:

  package MyClass;
  use Class::MakeMethods::Standard::Inheritable (
    scalar => 'foo',
  );
  ...
  
  # Store value
  MyClass->foo('Foozle');
  
  # Retrieve value
  print MyClass->foo;

=cut

sub _inh_find_vself {
  my $self = shift;
  my $data = shift;

  return $self if ( exists $data->{$self} );
   
  my $v_self;
  my @isa_search = ( ref($self) || $self );
  while ( scalar @isa_search ) {
    $v_self = shift @isa_search;
    return $v_self if ( exists $data->{$v_self} );
    no strict 'refs';
    unshift @isa_search, @{"$v_self\::ISA"};
  }
  return;
}

sub scalar {
  my $class = shift;
  map { 
    my $method = $_;
    my $name = $method->{name};
    $name => sub {
      my $self = shift;
      if ( scalar(@_) == 0 ) {
	my $v_self = _inh_find_vself($self, $method->{data});
	return $v_self ? $method->{data}{$v_self} : ();
      } else {
	my $value = shift;
	if ( defined $value ) {
	  $method->{data}{$self} = $value;
	} else {
	  delete $method->{data}{$self};
	  undef;
	}
      }
    }
  } $class->get_declarations(@_)
}

########################################################################

=head2 array - Class-specific Ref Accessor

For each method name passed, uses a closure to generate a subroutine with the following characteristics:

=over 4

=item *

May be called as a class method, or on any instance or subclass, Must be called on a hash-based instance.

=item * 

The class value will be a reference to an array (or undef).

=item *

If called without any arguments, returns the current array-ref value (or undef).


=item *

If called with a single non-ref argument, uses that argument as an index to retrieve from the referenced array, and returns that value (or undef).

=item *

If called with a single array ref argument, uses that list to return a slice of the referenced array.

=item *

If called with a list of argument pairs, each with a non-ref index and an associated value, stores the value at the given index in the referenced array. If the class value was previously undefined, a new array is autovivified. The current value in each position will be overwritten, and later arguments with the same index will override earlier ones. Returns the current array-ref value.

=item *

If called with a list of argument pairs, each with the first item being a reference to an array of up to two numbers, loops over each pair and uses those numbers to splice the value array. 

The first controlling number is the position at which the splice will begin. Zero will start before the first item in the list. Negative numbers count backwards from the end of the array. 

The second number is the number of items to be removed from the list. If it is omitted, or undefined, or zero, no items are removed. If it is a positive integer, that many items will be returned.

If both numbers are omitted, or are both undefined, they default to containing the entire value array.

If the second argument is undef, no values will be inserted; if it is a non-reference value, that one value will be inserted; if it is an array-ref, its values will be copied.

The method returns the items that removed from the array, if any.

=back

Sample declaration and usage:
  
  package MyClass;
  use Class::MakeMethods::Standard::Inheritable (
    array => 'bar',
  );
  ...
  
  # Set values by position
  MyClass->bar(0 => 'Foozle', 1 => 'Bang!');
  
  # Positions may be overwritten, and in any order
  MyClass->bar(2 => 'And Mash', 1 => 'Blah!');
  
  # Retrieve value by position
  print MyClass->bar(1);
  
  # Direct access to referenced array
  print scalar @{ MyClass->bar() };

There are also calling conventions for slice and splice operations:

  # Retrieve slice of values by position
  print join(', ', MyClass->bar( [0, 2] ) );
  
  # Insert an item at position in the array
  MyClass->bar([3], 'Potatoes' );  
  
  # Remove 1 item from position 3 in the array
  MyClass->bar([3, 1], undef );  
  
  # Set a new value at position 2, and return the old value 
  print MyClass->bar([2, 1], 'Froth' );
  
  # Use of undef allows you to clear and set contents of list
  print MyClass->bar([undef, undef], [ 'Spume', 'Frost' ] );  

B<NOTE: THIS METHOD GENERATOR HAS NOT BEEN WRITTEN YET.> 

=cut

sub array { }

########################################################################

=head2 hash - Class-specific Ref Accessor

For each method name passed, uses a closure to generate a subroutine with the following characteristics:

=over 4

=item *

May be called as a class method, or on any instance or subclass, Must be called on a hash-based instance.

=item * 

The class value will be a reference to a hash (or undef).

=item *

If called without any arguments returns the current hash-ref value for the callee. If the callee has not had a value defined for this method, searches up from instance to class, and from class to superclass, until a callee with a value is located.

=item *

If called with one argument, uses that argument as an index to retrieve from the callee's hash-ref, and returns that value (or undef). If the callee has not had a value defined for this method, searches up from instance to class, and from class to superclass, until a callee with a value is located. If the single argument is an array ref, then a slice of the referenced hash is returned.

=item *

If called with a list of key-value pairs, stores the value under the given key in the hash associated with the callee, whether instance or class. If the callee did not previously have a hash-ref value associated with it, searches up instance to class, and from class to superclass, until a callee with a value is located, and copies that hash before making the assignments. The current value under each key will be overwritten, and later arguments with the same key will override earlier ones. Returns the current hash-ref value.

=back

Sample declaration and usage:

  package MyClass;
  use Class::MakeMethods::Standard::Inheritable (
    hash => 'baz',
  );
  ...
  
  # Set values by key
  MyClass->baz('foo' => 'Foozle', 'bar' => 'Bang!');
  
  # Values may be overwritten, and in any order
  MyClass->baz('broccoli' => 'Blah!', 'foo' => 'Fiddle');
  
  # Retrieve value by key
  print MyClass->baz('foo');
  
  # Retrive slice of values by position
  print join(', ', MyClass->baz( ['foo', 'bar'] ) );
  
  # Direct access to referenced hash
  print keys %{ MyClass->baz() };
  
  # Reset the hash contents to empty
  @{ MyClass->baz() } = ();

B<NOTE: THIS METHOD GENERATOR IS INCOMPLETE.> 

=cut

sub hash {
  my $class = shift;
  map { 
    my $method = $_;
    my $name = $method->{name};
    $name => sub {
      my $self = shift;
      if ( scalar(@_) == 0 ) {
	my $v_self = _inh_find_vself($self, $method->{data});
	my $value = $v_self ? $method->{data}{$v_self} : ();
	if ( $method->{auto_init} and ! $value ) {
	  $method->{data}{$self} = {};
	} else {
	  $value;
	}
      } elsif ( scalar(@_) == 1 ) {
	my $v_self = _inh_find_vself($self, $method->{data});
	return unless $v_self;
	my $index = shift;
	ref($index) ? @{$method->{data}{$v_self}}{ @$index } 
		    :   $method->{data}{$v_self}->{ $index };
      } elsif ( scalar(@_) % 2 ) {
	Carp::croak "Odd number of items in assigment to $method->{name}";
      } else {
	if ( ! exists $method->{data}{$self} ) {
	  my $v_self = _inh_find_vself($self, $method->{data});
	  $method->{data}{$self} = { $v_self ? %$v_self : () };
	}
	while ( scalar(@_) ) {
	  my $key = shift();
	  $method->{data}{$self}->{ $key } = shift();
	}
	return $method->{data}{$self};
      }
    } 
  } $class->get_declarations(@_)
} 

########################################################################

=head2 object - Class-specific Ref Accessor

For each method name passed, uses a closure to generate a subroutine with the following characteristics:

=over 4

=item *

May be called as a class method, or on any instance or subclass, Must be called on a hash-based instance.

=item * 

The class value will be a reference to an object (or undef).

=item *

If called without any arguments returns the current value for the callee. If the callee has not had a value defined for this method, searches up from instance to class, and from class to superclass, until a callee with a value is located.

=item *

If called with an argument, stores that as the value associated with the callee, whether instance or class, and returns it, 

=back

Sample declaration and usage:

  package MyClass;
  use Class::MakeMethods::Standard::Inheritable (
    object => 'foo',
  );
  ...
  
  # Store value
  MyClass->foo( Foozle->new() );
  
  # Retrieve value
  print MyClass->foo;

B<NOTE: THIS METHOD GENERATOR HAS NOT BEEN WRITTEN YET.> 

=cut

sub object { }

########################################################################

=head1 SEE ALSO

See L<Class::MakeMethods> and L<Class::MakeMethods::Standard> for
an overview of the method-generation framework this is based on.

See L<Class::MakeMethods::Guide> for a getting-started guide,
annotated examples of usage, and a listing of the method generation
classes included in this distribution.

See L<Class::MakeMethods::ReadMe> for distribution, installation,
version and support information.

=cut

1;
