package Class::MakeMethods::Emulator::MethodMaker;

use Class::MakeMethods '-isasubclass';
require Class::MakeMethods::Utility::TakeName;

use strict;

=head1 NAME

B<Class::MakeMethods::Emulator::MethodMaker> - Emulate Class::MethodMaker 


=head1 SYNOPSIS

  package MyObject;
  use Class::MakeMethods::Emulator::MethodMaker( 
    new_with_init => 'new',
    get_set       => [ qw / foo bar baz / ];
  );

  ... OR ...

  package MyObject;
  use Class::MakeMethods::Emulator::MethodMaker '-take_namespace';
  use Class::MethodMaker ( 
    new_with_init => 'new',
    get_set       => [ qw / foo bar baz / ];
  );


=head1 COMPATIBILITY

This module provides emulation of Class::MethodMaker, using the Class::MakeMethods framework.

Although originally based on Class::MethodMaker, the calling convention
for Class::MakeMethods differs in a variety of ways; most notably, the names
given to various types of methods have been changed, and the format for
specifying method attributes has been standardized. This package uses
the aliasing capability provided by Class::MakeMethods, defining methods
that modify the declaration arguments as necessary and pass them off to
various subclasses of Class::MakeMethods.

There are several ways to call this emulation module:

=over 4

=item *

Direct Access

Replace occurances in your code of C<Class::MethodMaker> with C<Class::MakeMethods::Emulator::MethodMaker>.

=item *

Install Emulation

If you C<use Class::MakeMethods::Emulator::MethodMaker '-take_namespace'>, the Class::MethodMaker namespace will be aliased to this package, and calls to the original package will be transparently handled by this emulator.

To remove the emulation aliasing, call C<use Class::MakeMethods::Emulator::MethodMaker '-release_namespace'>.

B<Note:> This affects B<all> subsequent uses of Class::MethodMaker in your program, including those in other modules, and might cause unexpected effects.

=item *

The -sugar Option

Passing '-sugar' as the first argument in a use or import call will cause the 'methods' package to be declared as an alias to this one.

This allows you to write declarations in the following manner.

  use Class::MakeMethods::Emulator::MethodMaker '-sugar';

  make methods
    get_set => [ qw / foo bar baz / ],
    list    => [ qw / a b c / ];

B<Note:> This feature is deprecated in Class::MethodMaker version 0.96 and later. 

=back

=cut

my $emulation_target = 'Class::MethodMaker';

sub import {
  my $mm_class = shift;
  
  if ( scalar @_ and $_[0] =~ /^-take_namespace/ and shift ) {
    Class::MakeMethods::Utility::TakeName::namespace_capture(__PACKAGE__, $emulation_target);
  } elsif ( scalar @_ and $_[0] =~ /^-release_namespace/ and shift ) {
    Class::MakeMethods::Utility::TakeName::namespace_release(__PACKAGE__, $emulation_target);
  }
  
  if ( scalar @_ and $_[0] eq '-sugar' and shift ) {
    Class::MakeMethods::Utility::TakeName::namespace_capture(__PACKAGE__, "methods");
  }
  
  $mm_class->make( @_ ) if ( scalar @_ );
}

=head1 DESCRIPTION

B<NOTE:> The documentation below is derived from version 1.02 of
Class::MethodMaker, and has been reused with only minor revisions and
annotations. Class::MakeMethods::Emulator::MethodMaker provides support for
all of the features and examples shown below, with no changes required.

The argument to 'use' is a hash whose keys are the names of types of
generic methods defined by MethodMaker and whose values tell MethodMaker
what methods to make. More precisely, the keys are the names of
MethodMaker methods and the values are the arguments to those methods.

To override any generated methods, it is sufficient to ensure that the
overriding method is defined when MethodMaker is called. Note that the
C<use> keyword introduces a C<BEGIN> block, so you may need to define
(or at least declare) your overriding method in a C<BEGIN> block.

=head1 CONSTRUCTOR METHODS

=head2 new

Creates a basic constructor.

Takes a single string or a reference to an array of strings as its
argument.  For each string creates a simple method that creates and
returns an object of the appropriate class.

This method may be called as a class method, as usual, or as in instance
method, in which case a new object of the same class as the instance
will be created.  I<Note that C<new_hash_init> works slightly
differently with regard to being called on an instance.>

=cut

sub new 	  { return 'Template::Hash:new --with_values' }


=head2 new_with_init

Creates a basic constructor which calls a method named C<init> after
instantiating the object. The C<init> method should be defined in the
class using MethodMaker.

Takes a single string or a reference to an array of strings as its
argument.  For each string creates a simple method that creates an
object of the appropriate class, calls C<init> on that object
propagating all arguments, before returning the object.

This method may be called as a class method, as usual, or as in instance
method, in which case a new object of the same class as the instance
will be created.  I<Note that C<new_hash_init> works slightly
differently with regard to being called on an instance.>

=cut

sub new_with_init { return 'Template::Hash:new --with_init' }


=head2 new_hash_init

Creates a basic constructor which accepts a hash of slot-name/value
pairs with which to initialize the object.  The slot-names are
interpreted as the names of methods that can be called on the object
after it is created and the values are the arguments to be passed to
those methods.

Takes a single string or a reference to an array of strings as its
argument.  For each string creates a method that takes a list of
arguments that is treated as a set of key-value pairs, with each such
pair causing a call C<$self-E<gt>key ($value)>.

This method may be called as a class method, causing a new instance to
be created, or as an instance method, which will operate on the subject
instance.  This allows it to be combined with new_with_init (see above)
to provide some default values.  For example, declare a new_with_init
method, say 'new' and a new_hash_init method, for example, 'hash_init'
and then in the init method, you can call modify or add to the %args
hash and then call hash_init.

I<Note that the operation with regard to action on an instance differs
to that of C<new> and C<new_with_init> differently with regard to being
called on an instance.>

=cut

sub new_hash_init { return 'Template::Hash:new --instance_with_methods' }


=head2 copy (EXPERIMENTAL)

Produce a copy of self.  The copy is a *shallow* copy; any references
will be shared by the instance upon which the method is called and the
returned newborn.

=cut

sub copy 	  { return 'Template::Hash:new --copy_with_values' }


=head1 SCALAR ACCESSORS

=head2 get_set

Takes a single string or a reference to an array of strings as its
argument.  Each string specifies a slot, for which accessor methods are
created.  The accessor methods are, by default:

=over 4

=item   x

If an argument is provided, sets a new value for x.  This is true even
if the argument is undef (cf. no argument, which does not set.)

Returns (new) value.

Value defaults to undef.

=item   clear_x

Sets value to undef.  This is exactly equivalent to

  $foo->x (undef)

No return.

=back

This is your basic get/set method, and can be used for slots containing
any scalar value, including references to non-scalar data. Note, however,
that MethodMaker has meta-methods that define more useful sets of methods
for slots containing references to lists, hashes, and objects.

=head2 Options (EXPERIMENTAL)

There are several options available for controlling the names and types
of methods created.

The following options affect the type of methods created:

=over 4

=item	-static

The methods will refer to a class-specific, rather than
instance-specific store.  I.e., these scalars are shared across all
instances of your object in your process.

=back

The following options affect the methods created as detailed:

=over 4

=item	-java

Creates getx and setx methods, which return the value, and set the
value (no return), respectively.

=item	-eiffel

Creates x and set_x methods, analogous to -java get_x and set_x
respectively.

=item	-compatibility

Creates x (as per the default), and clear_x, which resets the slot value
to undef.  Use this to ensure backward compatibility.

=item	-noclear

Creates x (as per the default) only.

=back

Alternatively, an arrayref specifying an interface for method names may be
supplied.  Each name must contain a '*' character, which will be
replaced by the slot name, and no two patterns may be the same.  undef
may be supplied for methods that you do not want created.  Currently,
the first 4 members of such an arrayref may be used:

=over 4

=item	0

Creates a method that if supplied an argument, sets the slot to the
value of that argument; the value of the slot (after setting, if
relevant) is returned.

=item	1

Creates a method that takes no arguments, sets the slot value to
undefined, and makes no return.

=item	2

Creates a method that takes no arguments, and returns the value of the
slot.

=item	3

Creates a method that takes one argument, and sets the value of the slot
to that value.  Given undef as that argument, the value is set to undef.
If called with no arguments, the slot value is set to undef.

=back

See the examples.

=head2	Examples

Creates methods a, b, c which can be used for both getting and setting
the named slots:

  use Class::MakeMethods::Emulator::MethodMaker
    get_set => 'a',
    get_set => [qw/ b c /];

Creates get_d which returns the value in slot d (takes no arguments),
and set_d, which sets the value in slot d (no return):

  use Class::MakeMethods::Emulator::MethodMaker
    get_set => [ -java => d ];

Creates e_clear, e_get, e_set, f_clear, f_get, f_set methods:

  use Class::MakeMethods::Emulator::MethodMaker
    get_set => [[undef, '*_clear', '*_get', '*_set'] => qw/e f/ ];

=cut

my $scalar_interface = { '*'=>'get_set', 'clear_*'=>'clear' };

sub get_set 	  { 
  shift and return [ 
    ( ( $_[0] and $_[0] eq '-static' and shift ) ? 'Template::Static:scalar' 
						 : 'Template::Hash:scalar' ), 
    '-interface' => $scalar_interface, 
    map { 
      ( ref($_) eq 'ARRAY' ) 
	? ( '-interface'=>{ 
	  ( $_->[0] ? ( $_->[0] => 'get_set' ) : () ),
	  ( $_->[1] ? ( $_->[1] => 'clear' ) : () ),
	  ( $_->[2] ? ( $_->[2] => 'get' ) : () ),
	  ( $_->[3] ? ( $_->[3] => 'set_return' ) : () ),
	} ) 
	: ($_ eq '-compatibility') 
	    ? ( '-interface', $scalar_interface ) 
	    : ($_ eq '-noclear') 
		? ( '-interface', 'default' ) 
		: ( /^-/ ? "-$_" : $_ ) 
    } @_ 
  ]
}


=head2 get_concat

Like get_set except sets do not clear out the original value, but instead
concatenate the new value to the existing one. Thus these slots are only
good for plain scalars. Also, like get_set, defines clear_foo method.

The argument taken may be a hashref, in which the keys C<name> and
C<join> are recognized; C<name> being the slot name, join being a join
string t glue any given strings.

Example:

  use Class::MakeMethods::Emulator::MethodMaker
    get_concat => { name => 'words', join => "\t" };

Will, each time an argument is supplied to the C<x> method, glue this
argument onto any existing value with tab separator.  Like the C<join>
operator, the join field is applied I<between> values, not prior to the
first or after the last.

=cut

my $get_concat_interface = { 
  '*'=>'get_concat', 'clear_*'=>'clear', 
  '-params'=>{ 'join' => '', 'return_value_undefined' => undef() } 
};

my $old_get_concat_interface = { 
  '*'=>'get_concat', 'clear_*'=>'clear', 
  '-params'=>{ 'join' => '', 'return_value_undefined' => '' } 
};

sub get_concat 	  { 
  shift and return [ 'Template::Hash:string', '-interface', 
	( $_[0] eq '--noundef' ? ( shift and $old_get_concat_interface ) 
			       : $get_concat_interface ), @_ ]
}

=head2  counter

Create components containing simple counters that may be read,
incremented, or reset.  For value x, the methods are:

=over 4

=item   x

(accepts argument to set),

=item   incr_x

(accepts argument for increment size),

=item   reset_x.

The counter is implicitly initialized to zero.

=back

=cut

sub counter 	  { return 'Template::Hash:number --counter' }


=head1 OBJECT ACCESSORS

=head2 object

Creates methods for accessing a slot that contains an object of a given
class as well as methods to automatically pass method calls onto the
object stored in that slot.

    object => [
               'Foo' => 'phooey',
               'Bar' => [ qw / bar1 bar2 bar3 / ],
               'Baz' => {
                         slot => 'foo',
                         comp_mthds => [ qw / bar baz / ]
                        },
               'Fob' => [
                         {
                          slot => 'dog',
                          comp_mthds => 'bark',
                         },
                         {
                          slot => 'cat',
                          comp_mthds => 'miaow',
                         },
                        ];
              ];


The main argument should be a reference to an array. The array should
contain pairs of class => sub-argument pairs.
The sub-arguments parsed thus:

=over 4

=item   Hash Reference

See C<Baz> above.  The hash should contain the following keys:

=over 4

=item   slot

The name of the instance attribute (slot).

=item   comp_mthds

A string or array ref, naming the methods that will be forwarded directly
to the object in the slot.

=back

=item   Array Reference

As for C<String>, for each member of the array.  Also works if each
member is a hash reference (see C<Fob> above).

=item   String

The name of the instance attribute (slot).

=back

For each slot C<x>, with forwarding methods C<y> and C<z>, the following
methods are created:

=over 4

=item	x

A get/set method.

If supplied with an object of an appropriate type, will set set the slot
to that value.

Else, if the slot has no value, then an object is created by calling new
on the appropriate class, passing in any supplied arguments.

The stored object is then returned.

=item	y

Forwarded onto the object in slot C<x>, which is auto-created via C<new>
if necessary.  The C<new>, if called, is called without arguments.

=item	z

As for C<y>.

=back

So, using the example above, a method, C<foo>, is created in the class
that calls MethodMaker, which can get and set the value of those objects
in slot foo, which will generally contain an object of class Baz.  Two
additional methods are created in the class using MethodMaker, named
'bar' and 'baz' which result in a call to the 'bar' and 'baz' methods on
the Baz object stored in slot foo.

=cut

my $object_interface = { '*'=>'get_set_init', 'delete_*'=>'clear' };

sub object 	  { 
  shift and return [ 
    'Template::Hash:object', 
    '-interface' => $object_interface, 
    _object_args(@_) 
  ] 
}

sub _object_args {
  my @meta_methods;
  ! (@_ % 2) or Carp::croak("Odd number of arguments for object declaration");
  while ( scalar @_ ) {
    my ($class, $list) = (shift(), shift());
    push @meta_methods, map {
      (! ref $_) ? { name=> $_, class=>$class } 	
 	 	 : { name=> $_->{'slot'}, class=>$class, 
		    delegate=>( $_->{'forward'} || $_->{'comp_mthds'} ) }
    } ( ( ref($list) eq 'ARRAY' ) ? @$list : ($list) );
  }
  return @meta_methods;
}


=head2 object_list

Functions like C<list>, but maintains an array of referenced objects
in each slot. Forwarded methods return a list of the results returned
by C<map>ing the method over each object in the array.

Arguments are like C<object>.

=cut

my $array_interface = { 
  '*'=>'get_push', 
  '*_set'=>'set_items', 'set_*'=>'set_items', 
  map( ('*_'.$_ => $_, $_.'_*' => $_ ), 
	qw( pop push unshift shift splice clear count ref index )),
};

sub object_list { 
  shift and return [ 
    'Template::Hash:array_of_objects', 
    '-interface' => $array_interface, 
    _object_args(@_) 
  ];
}

=head2 forward

  forward => [ comp => 'method1', comp2 => 'method2' ]

Define pass-through methods for certain fields.  The above defines that
method C<method1> will be handled by component C<comp>, whilst method
C<method2> will be handled by component C<comp2>.

=cut

sub forward {
  my $class = shift;
  my @results;
  while ( scalar @_ ) { 
    my ($comp, $method) = ( shift, shift );
    push @results, { name=> $method, target=> $comp };
  }
  [ 'forward_methods', @results ]
}



=head1 REFERENCE ACCESSORS

=head2 list

Creates several methods for dealing with slots containing list
data. Takes a string or a reference to an array of strings as its
argument and for each string, x, creates the methods:

=over 4

=item   x

This method returns the list of values stored in the slot. In an array
context it returns them as an array and in a scalar context as a
reference to the array.

=item   x_push

=item   x_pop

=item   x_shift

=item   x_unshift

=item   x_splice

=item   x_clear

=item   x_count

Returns the number of elements in x.

=item	x_index

Takes a list of indices, returns a list of the corresponding values.

=item	x_set

Takes a list, treated as pairs of index => value; each given index is
set to the corresponding value.  No return.

=back

=cut

sub list { 
  shift and return [ 'Template::Hash:array', '-interface' => $array_interface, @_ ];
}


=head2 hash

Creates a group of methods for dealing with hash data stored in a
slot.

Takes a string or a reference to an array of strings and for each
string, x, creates:

=over 4

=item   x

Called with no arguments returns the hash stored in the slot, as a hash
in a list context or as a reference in a scalar context.

Called with one simple scalar argument it treats the argument as a key
and returns the value stored under that key.

Called with one array (list) reference argument, the array elements
are considered to be be keys of the hash. x returns the list of values
stored under those keys (also known as a I<hash slice>.)

Called with one hash reference argument, the keys and values of the
hash are added to the hash.

Called with more than one argument, treats them as a series of key/value
pairs and adds them to the hash.

=item   x_keys

Returns the keys of the hash.

=item   x_values

Returns the list of values.

=item   x_tally

Takes a list of arguments and for each scalar in the list increments the
value stored in the hash and returns a list of the current (after the
increment) values.

=item   x_exists

Takes a single key, returns whether that key exists in the hash.

=item   x_delete

Takes a list, deletes each key from the hash.

=item	x_clear

Resets hash to empty.

=back

=cut

my $hash_interface = { 
  '*'=>'get_push', 
  '*s'=>'get_push', 
  'add_*'=>'get_set_items', 
  'add_*s'=>'get_set_items', 
  'clear_*'=>'delete', 
  'clear_*s'=>'delete', 
  map {'*_'.$_ => $_} qw(push set keys values exists delete tally clear),
};

sub hash { 
  shift and return [ 'Template::Hash:hash', '-interface' => $hash_interface, @_ ];
}


=head2 tie_hash

Much like C<hash>, but uses a tied hash instead.

Takes a list of pairs, where the first is the name of the component, the
second is a hash reference.  The hash reference recognizes the following keys:

=over 4

=item   tie

I<Required>.  The name of the class to tie to.
I<Make sure you have C<use>d the required class>.

=item   args

I<Required>.  Additional arguments for the tie, as an array ref.

=back

The first argument can also be an arrayref, specifying multiple
components to create.

Example:

   tie_hash     => [
                    hits        => {
                                    tie => qw/ Tie::RefHash /,
                                    args => [],
                                   },
                   ],


=cut

sub tie_hash { 
  shift and return [ 'Template::Hash:tiedhash', '-interface' => $hash_interface, @_ ];
}

=head2 hash_of_lists

Creates a group of methods for dealing with list data stored by key in a
slot.

Takes a string or a reference to an array of strings and for each
string, x, creates:

=over 4

=item   x

Returns all the values for all the given keys, in order.  If no keys are
given, returns all the values (in an unspecified key order).

The result is returned as an arrayref in scalar context.  This arrayref
is I<not> part of the data structure; messing with it will not affect
the contents directly (even if a single key was provided as argument.)

If any argument is provided which is an arrayref, then the members of
that array are used as keys.  Thus, the trivial empty-key case may be
utilized with an argument of [].

=item   x_keys

Returns the keys of the hash.  As an arrayref in scalar context.

=item   x_exists

Takes a list of keys, and returns whether each key exists in the hash
(i.e., the C<and> of whether the individual keys exist).

=item   x_delete

Takes a list, deletes each key from the hash.

=item   x_push

Takes a key, and some values.  Pushes the values onto the list denoted
by the key.  If the first argument is an arrayref, then each element of
that arrayref is treated as a key and the elements pushed onto each
appropriate list.

=item   x_pop

Takes a list of keys, and pops each one.  Returns the list of popped
elements.  undef is returned in the list for each key that is has an
empty list.

=item	x_last

Like C<x_pop>, but does not actually change any of the lists.

=item   x_unshift

Like push, only the from the other end of the lists.

=item   x_shift

Like pop, only the from the other end of the lists.

=item   x_splice

Takes a key, offset, length, and a values list.  Splices the list named
by the key.  Anything from the offset argument (inclusive) may be
omitted.  See L<perlfunc/splice>.

=item	x_set

Takes a key, and a set of index->value pairs, and sets each specified
index to the corresponding value for the given key.

=item   x_clear

Takes a list of keys.  Resets each named list to empty (but does not
delete the keys.)

=item   x_count

Takes a list of keys.  Returns the sum of the number of elements for
each named list.

=item   x_index

Takes a key, and a list of indices.  Returns a list of each item at the
corresponding index in the list of the given key.  Uses undef for
indices beyond range.

=item   x_remove

Takes a key, and a list of indices.  Removes each corresponding item
from the named list.  The indices are effectively looked up at the point
of call -- thus removing indices 3, 1 from list (a, b, c, d) will
remove (d) and (b).

=item   x_sift

Takes a key, and a set of named arguments, which may be a list or a hash
ref.  Removes list members based on a grep-like approach.

=over 4

=item   filter

The filter function used (as a coderef).  Is passed two arguments, the
value compared against, and the value in the list that is potential for
grepping out.  If returns true, the value is removed.  Default:

  sub { $_[0] == $_[1] }

=item   keys

The list keys to sift through (as an arrayref).  Unknown keys are
ignored.  Default: all the known keys.

=item   values

The values to sift out (as an arrayref).  Default: C<[undef]>

=back

=back

Options:

=over 4

=item	-static

Make the corresponding storage class-specific, rather than
instance-specific.

=back

=cut

sub hash_of_lists { 
  shift and return ( $_[0] and $_[0] eq '-static' and shift ) 
	? [ 'Template::Static:hash_of_arrays', @_ ]
	: [ 'Template::Hash:hash_of_arrays', @_ ]
}


=head1 STATIC ACCESSORS

=head2 static_get_set

Like L<get_set|get_set>, takes a single string or a reference to an array of
strings as its argument. For each string, x creates two methods:

=over 4

=item   x

If an argument is provided, sets a new value for x.
Returns (new) value.
Value defaults to undef.

=item   clear_x

Sets value to undef.
No return.

=back

The difference between this and  L<get_set> is that these scalars are
shared across all instances of your object in your process.

=cut

sub static_get_set { 
  shift and return [ 'Template::Static:scalar', '-interface', $scalar_interface, @_ ] 
}


=head2  static_hash

Much like C<hash>, but uses a class-based hash instead.

=cut

sub static_hash { 
  shift and return [ 'Template::Static:hash', '-interface' => $hash_interface, @_ ];
}


=head1 GROUPED ACCESSORS

=head2 boolean

  boolean => [ qw / foo bar baz / ]

Creates methods for setting, checking and clearing flags. All flags
created with this meta-method are stored in a single vector for space
efficiency. The argument to boolean should be a string or a reference to
an array of strings. For each string x it defines several methods:

=over 4

=item   x

Returns the value of the x-flag.  If called with an argument, it first
sets the x-flag to the truth-value of the argument.

=item   set_x

Equivalent to x(1).

=item   clear_x

Equivalent to x(0).

=back

Additionally, boolean defines three class methods:

=over 4

=item   bits

Returns the vector containing all of the bit fields (remember however
that a vector containing all 0 bits is still true).

=item   boolean_fields

Returns a list of all the flags by name.

=item   bit_dump

Returns a hash of the flag-name/flag-value pairs.

=back

=cut

my $bits_interface = { 
  '*'=>'get_set', 'set_*'=>'set_true', 'clear_*'=>'set_false',
  'bit_fields'=>'bit_names', 'bits'=>'bit_string', 'bit_dump'=>'bit_hash' 
};

sub boolean 	  { 
  shift and return [ 'Template::Hash:bits', '-interface' => $bits_interface, @_ ];
}


=head2 grouped_fields

Creates get/set methods like get_set but also defines a method which
returns a list of the slots in the group.

  use Class::MakeMethods::Emulator::MethodMaker
    grouped_fields => [
      some_group => [ qw / field1 field2 field3 / ],
    ];

Its argument list is parsed as a hash of group-name => field-list
pairs. Get-set methods are defined for all the fields and a method with
the name of the group is defined which returns the list of fields in the
group.

=cut

sub grouped_fields {
  my ($class, %args) = @_;
  my @methods;
  foreach (keys %args) {
    my @slots = @{ $args{$_} };
    push @methods, 
	$_, sub { @slots },
	$class->make( 'get_set', \@slots );
  }
  return @methods;
}

=head2 struct

  struct => [  qw / foo bar baz / ];

Creates methods for setting, checking and clearing values which
are stored by position in an array. All the slots created with this
meta-method are stored in a single array.

The argument to struct should be a string or a reference to an
array of strings. For each string meta-method x, it defines two
methods: I<x> and I<clear_x>. x returns the value of the x-slot.
If called with an argument, it first sets the x-slot to the argument.
clear_x sets the slot to undef.

Additionally, struct defines three class method: I<struct>, which returns
a list of all of the struct values, I<struct_fields>, which returns
a list of all the slots by name, and I<struct_dump>, which returns a hash of
the slot-name/slot-value pairs.

B<Note:> This feature is included but not documented in Class::MethodMaker version 1. 


=cut

sub struct	  { return 'Template::Hash:struct' }


=head1 INDEXED ACCESSORS

=head2 listed_attrib

  listed_attrib => [ qw / foo bar baz / ]

Like I<boolean>, I<listed_attrib> creates x, set_x, and clear_x
methods. However, it also defines a class method x_objects which returns
a list of the objects which presently have the x-flag set to
true. N.B. listed_attrib does not use the same space efficient
implementation as boolean, so boolean should be prefered unless the
x_objects method is actually needed.

=cut

sub listed_attrib   { 
  shift and return [ 'Template::Flyweight:boolean_index', '-interface' => { 
	  '*'=>'get_set', 'set_*'=>'set_true', 'clear_*'=>'set_false',
	  '*_objects'=>'find_true', }, @_ ]
}


=head2 key_attrib

  key_attrib => [ qw / foo bar baz / ]

Creates get/set methods like get/set but also maintains a hash in which
each object is stored under the value of the field when the slot is
set. If an object has a slot set to a value which another object is
already set to the object currently set to that value has that slot set
to undef and the new object will be put into the hash under that
value. (I.e. only one object can have a given key. The method find_x is
defined which if called with any arguments returns a list of the objects
stored under those values in the hash. Called with no arguments, it
returns a reference to the hash.

=cut

sub key_attrib      { return 'Template::Hash:string_index' }

=head2 key_with_create

  key_with_create => [ qw / foo bar baz / ]

Just like key_attrib except the find_x method is defined to call the new
method to create an object if there is no object already stored under
any of the keys you give as arguments.

=cut

sub key_with_create { return 'Template::Hash:string_index --find_or_new'}


=head1 CODE ACCESSORS

=head2 code

  code => [ qw / foo bar baz / ]

Creates a slot that holds a code reference. Takes a string or a reference
to a list of string and for each string, x, creates a method B<x> which
if called with one argument which is a CODE reference, it installs that
code in the slot. Otherwise it runs the code stored in the slot with
whatever arguments (including none) were passed in.

=cut

sub code 	  { return 'Template::Hash:code' }


=head2 method

  method => [ qw / foo bar baz / ]

Just like B<code>, except the code is called like a method, with $self
as its first argument. Basically, you are creating a method which can be
different for each object. Which is sort of weird. But perhaps useful.

=cut

sub method 	  { return 'Template::Hash:code --method' }


=head2 abstract

  abstract => [ qw / foo bar baz / ]

This creates a number of methods will die if called.  This is intended
to support the use of abstract methods, that must be overidden in a
useful subclass.

=cut

sub abstract { return 'Template::Universal:croak --abstract' }


=head1 ARRAY CONSTRUCTOR AND ACCESSORS

=head2 builtin_class (EXPERIMENTAL)

Purpose: This class generates a wrapper around some builtin function,
cacheing the results in the object and providing a by-name interface.

Takes a (core) function name, and a arrayref of return position names
(we will call it pos_list).  Creates:

=over 4

=item	new

Calls the core func with any given arguments, stores the result in the
instance.

=item	x

For each member of pos_list, creates a method of the same name which
gets/sets the nth member of the returned list, where n is the position
of x in pos_list.

=item	fields

Returns pos_list, in the given order.

=item	dump

Returns a list item name, item value, in order.

=back

Example Usage:

  package Stat;

  use Class::MakeMethods::Emulator::MethodMaker
    builtin_class => [stat => [qw/ dev ino mode nlink /]],

  package main;

  my $file = "$ENV{HOME}/.profile";
  my $s = Stat->new ($file);
  print "File $file has ", $s->nlink, " links\n";

Note that (a) the new method does not check the return value of the
function called (in the above example, if $file does not exist, you will
silently get an empty object), and (b) if you really want the above
example, see the core File::stat module.   But you get the idea, I hope.

=cut

sub builtin_class { 
  shift and return [ 'Template::StructBuiltin:builtin_isa', 
			'-new_function'=>(shift), @{(shift)} ]
}

=head1 CONVERSION

If you wish to convert your code from use of the Class::MethodMaker emulator to direct use of Class::MakeMethods, you will need to adjust the arguments specified in your C<use> or C<make> calls.

Often this is simply a matter of replacing the names of aliased method-types listed below with the new equivalents.

For example, suppose that you code contained the following declaration:

  use Class::MethodMaker ( 
    counter => [ 'foo' ]
  );

Consulting the listings below you can find that C<counter> is an alias for C<Hash:number --counter> and you could thus revise your declaration to read:

  use Class::MakeMethods ( 
    'Hash:number --counter' => [ 'foo' ] 
  );

However, note that those methods marked "(with custom interface)" below have a different default naming convention for helper methods in Class::MakeMethods, and you will need to either supply a similar interface or alter your module's calling interface. 

Also note that the C<forward>, C<object>, and C<object_list> method types, marked "(with modified arguments)" below, require their arguments to be specified differently. 

See L<Class::MakeMethods::Template::Generic> for more information about the default interfaces of these method types.


=head2 Hash methods

The following equivalencies are declared for old meta-method names that are now handled by the Hash implementation:

  new 		   'Template::Hash:new --with_values'
  new_with_init    'Template::Hash:new --with_init'
  new_hash_init    'Template::Hash:new --instance_with_methods'
  copy	 	   'Template::Hash:copy'
  get_set 	   'Template::Hash:scalar' (with custom interfaces)
  counter 	   'Template::Hash:number --counter'
  get_concat 	   'Template::Hash:string --get_concat' (with custom interface)
  boolean 	   'Template::Hash:bits' (with custom interface)
  list 		   'Template::Hash:array' (with custom interface)
  struct           'Template::Hash:struct'
  hash	 	   'Template::Hash:hash' (with custom interface)
  tie_hash 	   'Template::Hash:tiedhash' (with custom interface)
  hash_of_lists    'Template::Hash:hash_of_arrays'
  code 		   'Template::Hash:code'
  method 	   'Template::Hash:code --method'
  object 	   'Template::Hash:object' (with custom interface and modified arguments)
  object_list 	   'Template::Hash:array_of_objects' (with custom interface and modified arguments)
  key_attrib       'Template::Hash:string_index'
  key_with_create  'Template::Hash:string_index --find_or_new'

=head2 Static methods

The following equivalencies are declared for old meta-method names
that are now handled by the Static implementation:

  static_get_set   'Template::Static:scalar' (with custom interface)
  static_hash      'Template::Static:hash' (with custom interface)

=head2 Flyweight method

The following equivalency is declared for the one old meta-method name
that us now handled by the Flyweight implementation:

  listed_attrib   'Template::Flyweight:boolean_index'

=head2 Struct methods

The following equivalencies are declared for old meta-method names
that are now handled by the Struct implementation:

  builtin_class   'Template::Struct:builtin_isa'

=head2 Universal methods

The following equivalencies are declared for old meta-method names
that are now handled by the Universal implementation:

  abstract         'Template::Universal:croak --abstract'
  forward          'Template::Universal:forward_methods' (with modified arguments)


=head1 EXTENDING

In order to enable third-party subclasses of MethodMaker to run under this emulator, several aliases or stub replacements are provided for internal Class::MethodMaker methods which have been eliminated or renamed.

=over 4

=item *

install_methods - now simply return the desired methods

=item *

find_target_class - now passed in as the target_class attribute

=item *

ima_method_maker - no longer supported; use target_class instead

=back

=cut

sub find_target_class { (shift)->_context('TargetClass') }
sub get_target_class { (shift)->_context('TargetClass') }
sub install_methods { (shift)->_install_methods(@_) }
sub ima_method_maker { 1 }


=head1 BUGS

This module aims to provide a 100% compatible drop-in replacement for Class::MethodMaker; if you detect a difference when using this emulation, please inform the author. 

There are no known incompatibilities at this time.

The test suite from Class::MethodMaker version 1.02 is included with this package. The tests are unchanged except for the a direct substitution of C<Class::MakeMethods::Emulator::MethodMaker> in the place of C<Class::MethodMaker>.

=head2 Earlier Versions

In cases where Class::MethodMaker version 0.92's test suite contained
a different version of a test, it is also included. (Note that
version 0.92's get_concat returned '' for empty values, but in
version 0.96 this was changed to undef; this emulator follows the
later behavior. To avoid "use of undefined value" warnings from
the 0.92 version of get_concat.t, that test has been modified by
appending a new flag after the name, C<'get_concat --noundef'>,
which restores the earlier behavior.)


=head1 SEE ALSO

See L<Class::MethodMaker> for more information about the original module.

A good introduction to Class::MethodMaker is provided by pages 222-234 of I<Object Oriented Perl>, by Damian Conway (Manning, 1999).

  http://www.browsebooks.com/Conway/ 

The following tutorials provide usage examples and accompanying commentary for Class::MethodMaker:

   http://savage.net.au/Perl-tutorials.html#tut-33
   http://savage.net.au/Perl-tutorials.html#tut-34

See L<Class::MakeMethods> for an overview of the method-generation
framework this is based on.

See L<Class::MakeMethods::Guide> for a getting-started guide,
annotated examples of usage, and a listing of the method generation
classes included in this distribution.

See L<Class::MakeMethods::ReadMe> for distribution, installation,
version and support information.


=head1 AUTHORS

Developed by:

  M. Simon Cavalletto, Evolution Online Systems, simonm@evolution.com

Based on Class::MethodMaker, originally developed by:

  Peter Seibel, Organic Online

Class::MethodMaker is currently maintained by:

  Martyn J. Pearce


=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 1998, 1999, 2000, 2001 Evolution Online Systems, Inc.

Portions Copyright (c) 1996 Organic Online

Portions Copyright (c) 2000 Martyn J. Pearce.

=cut

1;
