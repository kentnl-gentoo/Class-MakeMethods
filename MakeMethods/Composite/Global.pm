=head1 NAME

Class::MakeMethods::Composite::Global - Global data

=head1 SYNOPSIS

  package MyClass;
  use Class::MakeMethods::Composite::Global (
    scalar => [ 'foo' ],
    array  => [ 'my_list' ],
    hash   => [ 'my_index' ],
  );
  ...
  
  MyClass->foo( 'Foozle' );
  print MyClass->foo();

  print MyClass->new(...)->foo(); # same value for any instance
  print MySubclass->foo();        # ... and for any subclass
  
  MyClass->my_list(0 => 'Foozle', 1 => 'Bang!');
  print MyClass->my_list(1);
  
  MyClass->my_index('broccoli' => 'Blah!', 'foo' => 'Fiddle');
  print MyClass->my_index('foo');


=head1 DESCRIPTION

The Composite::Global suclass of MakeMethods provides basic accessors for shared data.

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

package Class::MakeMethods::Composite::Global;

$VERSION = 1.000;
use strict;
use Class::MakeMethods::Composite '-isasubclass';

########################################################################

=head1 METHOD GENERATOR TYPES

=head2 scalar - Global Accessor

For each method name passed, uses a closure to generate a subroutine with the following characteristics:

=over 4

=item *

May be called as a class method, or on any instance or subclass, and behaves identically regardless of what it was called on.

=item *

If called without any arguments returns the current value.

=item *

If called with an argument, stores that as the value, and returns it, 

=item * 

If called with multiple arguments, stores a reference to a new array with those arguments as contents, and returns that array reference.

=back

Sample declaration and usage:

  package MyClass;
  use Class::MakeMethods::Composite::Global (
    scalar => 'foo',
  );
  ...
  
  # Store value
  MyClass->foo('Foozle');
  
  # Retrieve value
  print MyClass->foo;

=cut

use vars qw( %ScalarFragments );

sub scalar {
  (shift)->_build_composite( \%ScalarFragments, @_ );
}

%ScalarFragments = (
  '' => [
    '+init' => sub {
	my ($method) = @_;
	$method->{target_class} ||= $Class::MethodMaker::CONTEXT{TargetClass};
	$method->{array_index} ||= 
		_array_index( $method->{target_class}, $name );
      },
    'do' => sub {
	my $method = pop @_;
	my $self = shift @_;
	if ( scalar(@_) == 0 ) {
	  $method->{global_data};
	} elsif ( scalar(@_) == 1 ) {
	  $method->{global_data} = shift;
	} else {
	  $method->{global_data} = [@_];
	}
      },
  ],
  'rw' => [],
  'p' => [ 
    '+pre' => sub {
	my $method = pop @_;
	unless ( UNIVERSAL::isa((caller(1))[0], $method->{target_class}) ) {
	  croak "Method $method->{name} is protected";
	}
      },
  ],
  'pp' => [ 
    '+pre' => sub {
	my $method = pop @_;
	unless ( (caller(1))[0] eq $method->{target_class} ) {
	  croak "Method $method->{name} is private";
	}
      },
  ],
  'pw' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	my $args = \@_;
	unless ( @$args == 0 or UNIVERSAL::isa((caller(1))[0], $method->{target_class}) ) {
	  croak "Method $method->{name} is write-protected";
	}
      },
  ],
  'ppw' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	my $args = \@_;
	unless ( @$args == 0 or (caller(1))[0] eq $method->{target_class} ) {
	  croak "Method $method->{name} is write-private";
	}
      },
  ],
  'r' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	@{$method->{args}} = ($self) if ( scalar @_ );
      },
  ],
  'ro' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	my $args = \@_;
	unless ( @$args == 0 ) {
	  croak("Method $method->{name} is read-only");
	}
      },
  ],
  'wo' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	my $args = \@_;
	if ( @$args == 0 ) {
	  croak("Method $method->{name} is write-only");
	}
      },
  ],
  'return_original' => [ 
    '+pre' => sub {
	my $method = pop @_;
	my $self = shift @_;
	my $args = \@_;
	$method->{scratch}{return_original} = $method->{global_data};
      },
    '+post' => sub { 
	my $method = pop @_;
	my $self = shift @_;
	my $args = \@_;
	$method->{result} = \{ $method->{scratch}{return_original} };
      },
  ],
);

########################################################################

=head2 array - Global Ref Accessor

For each method name passed, uses a closure to generate a subroutine with the following characteristics:

=over 4

=item *

May be called as a class method, or on any instance or subclass, and behaves identically regardless of what it was called on.

=item * 

The global value will be a reference to an array (or undef).

=item *

If called without any arguments, returns the current array-ref value (or undef).


=item *

If called with a single non-ref argument, uses that argument as an index to retrieve from the referenced array, and returns that value (or undef).

=item *

If called with a single array ref argument, uses that list to return a slice of the referenced array.

=item *

If called with a list of argument pairs, each with a non-ref index and an associated value, stores the value at the given index in the referenced array. If the global value was previously undefined, a new array is autovivified. The current value in each position will be overwritten, and later arguments with the same index will override earlier ones. Returns the current array-ref value.

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
  use Class::MakeMethods::Composite::Global (
    array => 'bar',
  );
  ...
  
  # Clear and set contents of list
  print MyClass->bar([ 'Spume', 'Frost' ] );  
  
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
  print join(', ', MyClass->bar( undef, [0, 2] ) );
  
  # Insert an item at position in the array
  MyClass->bar([3], 'Potatoes' );  
  
  # Remove 1 item from position 3 in the array
  MyClass->bar([3, 1], undef );  
  
  # Set a new value at position 2, and return the old value 
  print MyClass->bar([2, 1], 'Froth' );

=cut


use vars qw( %ArrayFragments );

sub array {
  (shift)->_build_composite( \%ArrayFragments, @_ );
}

%ArrayFragments = (
  '' => [
    '+init' => sub {
	my ($method) = @_;
	$method->{hash_key} ||= $_->{name};
      },
    'do' => sub {
	my $method = pop @_;
	my $self = shift @_;
	my $args = \@_;
	if ( scalar(@$args) == 0 ) {
	  if ( $method->{auto_init} and 
			! defined $method->{global_data} ) {
	    $method->{global_data} = [];
	  }
	  wantarray ? @{ $method->{global_data} } : $method->{global_data}
	} elsif ( scalar(@_) == 1 and ref $_[0] eq 'ARRAY' ) {
	  $method->{global_data} = [ @{ $_[0] } ];
	  wantarray ? @{ $method->{global_data} } : $method->{global_data}
	} else {
	  $method->{global_data} ||= [];
	  Class::MakeMethods::Composite::__array_ops( 
		$method->{global_data}, @$args );
	}
      },
  ],
);

########################################################################

=head2 hash - Global Ref Accessor

For each method name passed, uses a closure to generate a subroutine with the following characteristics:

=over 4

=item *

May be called as a class method, or on any instance or subclass, and behaves identically regardless of what it was called on.

=item * 

The global value will be a reference to a hash (or undef).

=item *

If called without any arguments, returns the contents of the hash in list context, or a hash reference in scalar context (or undef).

=item *

If called with one non-ref argument, uses that argument as an index to retrieve from the referenced hash, and returns that value (or undef).

=item *

If called with one array-ref argument, uses the contents of that array to retrieve a slice of the referenced hash.

=item *

If called with one hash-ref argument, sets the contents of the referenced hash to match that provided.

=item *

If called with a list of key-value pairs, stores the value under the given key in the referenced hash. If the global value was previously undefined, a new hash is autovivified. The current value under each key will be overwritten, and later arguments with the same key will override earlier ones. Returns the contents of the hash in list context, or a hash reference in scalar context.

=back

Sample declaration and usage:

  package MyClass;
  use Class::MakeMethods::Composite::Global (
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
	my $args = \@_;
	if ( scalar(@$args) == 0 ) {
	  if ( $method->{auto_init} and ! defined $method->{global_data} ) {
	    $method->{global_data} = {};
	  }
	  wantarray ? %{ $method->{global_data} } : $method->{global_data};
	} elsif ( scalar(@$args) == 1 ) {
	  if ( ref($_[0]) eq 'HASH' ) {
	    %{$method->{global_data}} = %{$_[0]};
	  } elsif ( ref($_[0]) eq 'ARRAY' ) {
	    return @{$method->{global_data}}{ @{$_[0]} }
	  } else {
	    return $method->{global_data}->{ $_[0] }
	  }
	} elsif ( scalar(@$args) % 2 ) {
	  croak "Odd number of items in assigment to $method->{name}";
	} else {
	  while ( scalar(@$args) ) {
	    my $key = shift @$args;
	    $method->{global_data}->{ $key} = shift @$args;
	  }
	  wantarray ? %{ $method->{global_data} } : $method->{global_data};
	}
      },
  ],
);

########################################################################

=head2 object - Global Ref Accessor

For each method name passed, uses a closure to generate a subroutine with the following characteristics:

=over 4

=item *

May be called as a class method, or on any instance or subclass, and behaves identically regardless of what it was called on.

=item * 

The global value will be a reference to an object (or undef).

=item *

If called without any arguments returns the current value.

=item *

If called with an argument, stores that as the value, and returns it, 

=back

Sample declaration and usage:

  package MyClass;
  use Class::MakeMethods::Composite::Global (
    object => 'foo',
  );
  ...
  
  # Store value
  MyClass->foo( Foozle->new() );
  
  # Retrieve value
  print MyClass->foo;

=cut

use vars qw( %ObjectFragments );

sub object {
  (shift)->_build_composite( \%ObjectFragments, @_ );
}

%ObjectFragments = (
  '' => [
    '+init' => sub {
	my ($method) = @_;
	$method->{hash_key} ||= $_->{name};
      },
    'do' => sub {
	my $method = pop @_;
	my $self = shift;
	if ( scalar @_ ) {
	  my $value = shift;
	  if ( $method->{class} and ! UNIVERSAL::isa( $value, $method->{class} ) ) {
	    croak "Wrong argument type ('$value') in assigment to $method->{name}";
	  }
	  $method->{global_data} = $value;
	} else {
	  if ( $method->{auto_init} and ! defined $method->{global_data} ) {
	    my $class = $method->{class} 
				or die "Can't auto_init without a class";
	    my $new_method = $method->{new_method} || 'new';
	    $method->{global_data} = $class->$new_method();
	  }
	  $method->{global_data};
	}
      },
  ],
);

########################################################################

=head1 SEE ALSO

See L<Class::MakeMethods> for general information about this distribution. 

See L<Class::MakeMethods::Composite> for more about this family of subclasses.

=cut

1;
