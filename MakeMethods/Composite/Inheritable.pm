=head1 NAME

Class::MakeMethods::Composite::Inheritable - Inheritable data

=head1 SYNOPSIS

  package MyClass;
  use Class::MakeMethods::Composite::Inheritable (
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

The Composite::Inheritable suclass of MakeMethods provides basic accessors for class-specific data.

=head2 Class::MakeMethods Calling Interface

When you C<use> this package, the method declarations you provide
as arguments cause subroutines to be generated and installed in
your module.

You can also omit the arguments to C<use> and instead make methods
at runtime by passing the declarations to a subsequent call to
C<make()>.

You may include any number of declarations in each call to C<use>
or C<make()>. If methods with the same name already exist, earlier
calls to C<use> or C<make()> win over later ones, but within each
call, later declarations superceed earlier ones.

You can install methods in a different package by passing C<-TargetClass =E<gt> I<package>> as your first arguments to C<use> or C<make>. 

See L<Class::MakeMethods> for more details.

=head2 Class::MakeMethods::Basic Declaration Syntax

The following types of Basic declarations are supported:

=over 4

=item *

I<generator_type> => "I<method_name>"

=item *

I<generator_type> => "I<name_1> I<name_2>..."

=item *

I<generator_type> => [ "I<name_1>", "I<name_2>", ...]

=back

See the "METHOD GENERATOR TYPES" section below for a list of the supported values of I<generator_type>.

For each method name you provide, a subroutine of the indicated
type will be generated and installed under that name in your module.

Method names should start with a letter, followed by zero or more
letters, numbers, or underscores.

=head2 Class::MakeMethods::Composite Declaration Syntax

The Composite syntax also provides several ways to optionally
associate a hash of additional parameters with a given method
name. 

=over 4

=item *

I<generator_type> => [ "I<name_1>" => { I<param>=>I<value>... }, ... ]

A hash of parameters to use just for this method name. 

(Note: to prevent confusion with self-contained definition hashes,
described below, parameter hashes following a method name must not
contain the key 'name'.)

=item *

I<generator_type> => [ [ "I<name_1>", "I<name_2>", ... ] => { I<param>=>I<value>... } ]

Each of these method names gets a copy of the same set of parameters.

=item *

I<generator_type> => [ { "name"=>"I<name_1>", I<param>=>I<value>... }, ... ]

By including the reserved parameter C<name>, you create a self-contained declaration with that name and any associated hash values.

=back

Basic declarations, as described above, are given an empty parameter hash.

=cut

package Class::MakeMethods::Composite::Inheritable;

use strict;
use Class::MakeMethods::Composite '-isasubclass';
use Carp;

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

=item * 

If called with multiple arguments, stores a reference to a new array with those arguments as contents, and returns that array reference.

=back

Sample declaration and usage:

  package MyClass;
  use Class::MakeMethods::Composite::Inheritable (
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

use vars qw( %ScalarFragments );

sub scalar {
  (shift)->_build_composite( \%ScalarFragments, @_ );
}

%ScalarFragments = (
  '' => [
    '+init' => sub {
	my ($method) = @_;
	$method->{target_class} ||= $Class::MethodMaker::CONTEXT{TargetClass};
      },
    'do' => sub {
	my $method = pop @_;
	my $self = shift @_;	
	if ( scalar(@_) == 0 ) {
	my $v_self = _inh_find_vself($self, $method->{data});
	  return $v_self ? $method->{data}{$v_self} : ();
	} else {
	  my $value = (@_ == 1 ? $_[0] : [@_]);
	  if ( defined $value ) {
	    $method->{data}{$self} = $value;
	  } else {
	    delete $method->{data}{$self};
	    undef;
	  }
	}
      },
  ],
  'rw' => [],
  'p' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	unless ( UNIVERSAL::isa((caller(1))[0], $method->{target_class}) ) {
	  croak "Method $method->{name} is protected";
	}
      },
  ],
  'pp' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	unless ( (caller(1))[0] eq $method->{target_class} ) {
	  croak "Method $method->{name} is private";
	}
      },
  ],
  'pw' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	unless ( @_ == 0 or UNIVERSAL::isa((caller(1))[0], $method->{target_class}) ) {
	  croak "Method $method->{name} is write-protected";
	}
      },
  ],
  'ppw' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	unless ( @_ == 0 or (caller(1))[0] eq $method->{target_class} ) {
	  croak "Method $method->{name} is write-private";
	}
      },
  ],
  'r' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	@{ $method->{args} } = ();
      },
  ],
  'ro' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	unless ( @_ == 0 ) {
	  croak("Method $method->{name} is read-only");
	}
      },
  ],
  'wo' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	if ( @_ == 0 ) {
	  croak("Method $method->{name} is write-only");
	}
      },
  ],
  'return_original' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	my $v_self = _inh_find_vself($self);
	$method->{scratch}{return_original} = 
					$v_self ? $method->{data}{$v_self} : ();
      },
    '+post' => sub { 
	my $method = pop @_;
	$method->{result} = \{ $method->{scratch}{return_original} };
      },
  ],
);

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
  use Class::MakeMethods::Composite::Inheritable (
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

sub array { };

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
  use Class::MakeMethods::Composite::Inheritable (
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

use vars qw( %HashFragments );

sub hash {
  (shift)->_build_composite( \%HashFragments, @_ );
}

%HashFragments = (
  '' => [
    '+init' => sub {
	my ($method) = @_;
	$method->{hash_key} ||= $_->{name};
      },
    'do' => sub {
	my $method = pop @_;
	my $self = shift @_;
	
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
      },
  ],
);


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
  use Class::MakeMethods::Composite::Inheritable (
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


See L<Class::MakeMethods> and L<Class::MakeMethods::Composite> for
an overview of the method-generation framework this is based on.

See L<Class::MakeMethods::Guide> for a getting-started guide,
annotated examples of usage, and a listing of the method generation
classes included in this distribution.

See L<Class::MakeMethods::ReadMe> for distribution, installation,
version and support information.

=cut

1;
