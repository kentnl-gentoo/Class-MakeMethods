### Class::MakeMethods
  # Copyright 2002 Matthew Simon Cavalletto
  # See documentation, license, and other information after _END_.

package Class::MakeMethods;

require 5.00307; # for the UNIVERSAL::isa method.
use strict;
use Carp;

use vars qw( $VERSION );
$VERSION = 1.003;

use vars qw( %CONTEXT %DIAGNOSTICS );

########################################################################
### MODULE IMPORT: import(), _import_version()
########################################################################

sub import {
  my $class = shift;

  if ( scalar @_ and $_[0] =~ m/^\d/ ) {
    $class->_import_version( shift );
  }
  
  if ( scalar @_ == 1 and $_[0] eq '-isasubclass' ) {
    shift;
    my $target_class = ( caller )[0];
    no strict;
    push @{"$target_class\::ISA"}, $class;
  }
  
  $class->make( @_ ) if ( scalar @_ );
}

  # If passed a version number, ensure that we measure up.
  # Based on similar functionality in Exporter.pm
sub _import_version {
  my $class = shift;
  
  my $wanted = shift;
  my $version = ${ $class.'::VERSION '};
  
  if (!$version or $version < $wanted) {
    my $file = "$class.pm";
    $file =~ s!::!/!g;
    $file = $INC{$file} ? " ($INC{$file})" : '';
    _diagnostic('mm_version_fail', $class, $wanted, $version || '(undef)', $file);
  }
}

########################################################################
### METHOD GENERATION: make()
########################################################################

sub make {
  local $CONTEXT{MakerClass} = shift;
  
  # Find the first class in the caller() stack that's not a subclass of us 
  local $CONTEXT{TargetClass};
  my $i = 0;
  do {
    $CONTEXT{TargetClass} = ( caller($i ++) )[0];
  } while UNIVERSAL::isa($CONTEXT{TargetClass}, __PACKAGE__ );
  
  my @methods;
  
  # For compatibility with 5.004, which fails to splice use's constant @_
  my @uscore = @_; 
  
  if (@_ % 2) { _diagnostic('make_odd_args', $CONTEXT{MakerClass}); }
  while ( scalar @uscore ) {
    # The list passed to import should alternate between the names of the
    # meta-method to call to generate the methods, and arguments to it.
    my ($name, $args) = splice(@uscore, 0, 2);
    unless ( defined $name ) {
      croak "Undefined name";
    }
    
    # Leading dash on the first argument of a pair means it's a global/general
    # option handled via CONTEXT.
    if ( $name =~ s/^\-// ) {
    
      # To prevent difficult-to-predict retroactive behaviour, start by
      # flushing any pending methods before letting settings take effect
      if ( scalar @methods ) { 
	_install_methods( $CONTEXT{MakerClass}, @methods );
	@methods = ();
      }
      
      if ( $name eq 'MakerClass' ) {
	# Switch base package for remainder of args
	$CONTEXT{MakerClass} = _find_subclass($CONTEXT{MakerClass}, $args);
      } else {
	$CONTEXT{$name} = $args;
      }
      
      next;
    }
    
    # Argument normalization
    my @args = (
      ! ref($args) ? split(' ', $args) : # If a string, it is split on spaces.
      ref($args) eq 'ARRAY' ? (@$args) : # If an arrayref, use its contents.
      ( $args )     			 # If a hashref, it is used directly
    );
    
    # If the type argument contains space characters, use the first word
    # as the type, and prepend the remaining items to the argument list.
    if ( $name =~ /\s/ ) {
      my @items = split ' ', $name;
      $name = shift( @items );
      unshift @args, @items;
    }
    
    # If name contains a colon, treat the preceeding part as the
    # subclass name but only for this one set of methods.
    local $CONTEXT{MakerClass} = _find_subclass($CONTEXT{MakerClass}, $1)
		if ($name =~ s/^(.*)\://);
    
    # Meta-method invocation via named_method or direct method call
    my @results = (
	$CONTEXT{MakerClass}->can('named_method') ? 
			$CONTEXT{MakerClass}->named_method( $name, @args ) : 
	$CONTEXT{MakerClass}->can($name) ?
			$CONTEXT{MakerClass}->$name( @args ) : 
	    croak "Can't generate $CONTEXT{MakerClass}->$name() methods"
    );
    # warn "$CONTEXT{MakerClass} $name - ", join(', ', @results) . "\n";
    
    ### A method-generator may be implemented in any of the following ways:
    
    # SELF-CONTAINED: It may return nothing, if there are no methods
    # to install, or if it has installed the methods itself.
    # (We also accept a single false value, for backward compatibility 
    # with generators that are written as foreach loops, which return ''!)
    if ( ! scalar @results or scalar @results == 1 and ! $results[0] ) { } 
    
    # GENERATOR OBJECT: It may return an object reference which will construct
    # the relevant methods.
    elsif ( UNIVERSAL::can( $results[0], 'make_methods' ) ) {
      push @methods, ( shift @results )->make_methods(@results, @args);
    } 
    
    # ALIAS: It may return a string containing a meta-method type to run 
    # instead. Put the arguments back on the stack and go through again.
    elsif ( scalar @results == 1 and ! ref $results[0]) {
      unshift @uscore, $results[0], \@args;
    } 
    
    # REWRITER: It may return one or more array reference containing a meta-
    # method type and arguments which should be created to complete this 
    # request. Put the arguments back on the stack and go through again.
    elsif ( scalar @results and ! grep { ref $_ ne 'ARRAY' } @results ) {
      unshift @uscore, ( map { shift(@$_), $_ } @results );
    } 
    
    # CODE REFS: It may provide a list of name, code pairs to install
    elsif ( ! scalar @results % 2 and ! ref $results[0] ) {
      push @methods, @results;
    } 
    
    else {
      _diagnostic('make_bad_meta', $name, join(', ', map "'$_'", @results));
    }
  }
  
  _install_methods( $CONTEXT{MakerClass}, @methods );
  
  return;
}

########################################################################
### FUNCTION INSTALLATION: _install_methods()
########################################################################

sub _install_methods {
  my ($class, %methods) = @_;
  
  no strict 'refs';
  
  # print STDERR "CLASS: $class\n";
  my $package = $CONTEXT{TargetClass};
  
  my ($name, $code);
  while (($name, $code) = each %methods) {
    
    # Skip this if the target package already has a function by the given name.
    next if ( ! $CONTEXT{ForceInstall} and 
				defined *{$package. '::'. $name}{CODE} );
   
    if ( ! ref $code ) {
      local $SIG{__DIE__};
      local $^W;
      my $coderef = eval $code;
      if ( $@ ) {
	_diagnostic('inst_eval_syntax', $name, $@, $code);
      } elsif ( ref $coderef ne 'CODE' ) {
	_diagnostic('inst_eval_result', $name, $coderef, $code);
      }
      $code = $coderef;
    } elsif ( ref $code ne 'CODE' ) {
      _diagnostic('inst_result', $name, $code);
    }
    
    # Add the code refence to the target package
    # _diagnostic('debug_install', $package . '::', $name, $code);
    local $^W = 0 if ( $CONTEXT{ForceInstall} );
    *{$package . '::' . $name} = $code;

  }
  return;
}

########################################################################
### SUBCLASS LOADING: _find_subclass()
########################################################################

# $pckg = _find_subclass( $class, $optional_package_name );
sub _find_subclass {
  my $class = shift; 
  my $package = shift or die "No package for _find_subclass";
  
  $package =  $package =~ s/^::// ? $package :
		"Class::MakeMethods::$package";
  
  (my $file = $package . '.pm' ) =~ s|::|/|go;
  return $package if ( $::INC{ $file } );
  
  no strict 'refs';
  return $package if ( @{$package . '::ISA'} );
  
  local $SIG{__DIE__} = '';
  eval { require $file };
  $::INC{ $package } = $::INC{ $file };
  if ( $@ ) { _diagnostic('mm_package_fail', $package, $@) }
  
  return $package
}

########################################################################
### CONTEXT: _context(), %CONTEXT
########################################################################

sub _context {
  my $class = shift; 
  return %CONTEXT if ( ! scalar @_ );
  my $key = shift;
  return $CONTEXT{$key} if ( ! scalar @_ );
  $CONTEXT{$key} = shift;
}

BEGIN {
  $CONTEXT{Debug} ||= 0;
}

########################################################################
### DIAGNOSTICS: _diagnostic(), %DIAGNOSTICS
########################################################################

sub _diagnostic {
  my $case = shift;
  my $message = $DIAGNOSTICS{$case};
  $message =~ s/\A\s*\((\w)\)\s*//;
  my $severity = $1 || 'I';
  if ( $severity eq 'Q' ) {
    carp( sprintf( $message, @_ ) ) if ( $CONTEXT{Debug} );
  } elsif ( $severity eq 'W' ) {
    carp( sprintf( $message, @_ ) ) if ( $^W );
  } elsif ( $severity eq 'F' ) {
    croak( sprintf( $message, @_ ) )
  } else {
    confess( sprintf( $message, @_ ) )
  }
}

BEGIN {
  %DIAGNOSTICS = (
    make_behavior_mod => q|(F) Can't apply modifiers (%s) to code behavior %s|,
    behavior_mod_unknown => q|(F) Unknown modification to %s behavior: -%s|,
    debug_template_builder => qq|(Q) Template interpretation for %s:\n%s|.
	qq|\n---------\n%s\n---------\n|,
    debug_template => q|(Q) Parsed template '%s': %s|,
    debug_eval_builder => q|(Q) Compiling behavior builder '%s':| . qq|\n%s|,
    debug_declaration => q|(Q) Meta-method declaration parsed: %s|,
    debug_make_behave => q|(Q) Building meta-method behavior %s: %s(%s)|,
    debug_install => q|(W) Installing function %s%s (%s)|,
    make_odd_args => q|(F) Odd number of arguments passed to %s method generator|,
    make_empty => q|(F) Can't parse meta-method declaration: argument is empty or undefined|,
    make_noname => q|(F) Can't parse meta-method declaration: missing name attribute.| . 
	qq|\n  (Perhaps a trailing attributes hash has become separated from its name?)|,
    make_bad_modifier => q|(F) Can't parse meta-method declaration: unknown option for %s: %s|,
    make_unsupported => q|(F) Can't parse meta-method declaration: unsupported declaration type '%s'|,
    make_bad_behavior => q|(F) Can't make method %s(): template specifies unknown behavior '%s'|,
    make_bad_meta => q|(I) Unexpected return value from meta-method constructor %s: %s|,
    inst_eval_syntax => q|(I) Unable to compile generated method %s(): %s| . 
	qq|\n  (There's probably a syntax error in this generated code.)\n%s\n|,
    inst_eval_result => q|(I) Unexpected return value from compilation of %s(): '%s'| . 
	qq|\n  (This generated code should have returned a code ref.)\n%s\n|,
    inst_result => q|(I) Unable to install code for %s() method: '%s'|,
    mmdef_not_interpretable => qq|(I) Not an interpretable meta-method: '%s'| .
	qq|\n  (Perhaps a meta-method attempted to import from a non-templated meta-method?)|,
    mm_package_fail => q|(F) Unable to dynamically load %s: %s|,
    mm_version_fail => q|(F) %s %s required--this is only version %s%s|,
    behavior_eval => q|(I) Class::MakeMethods behavior compilation error: %s| . 
	qq|\n  (There's probably a syntax error in the below code.)\n%s|,
    tmpl_unkown => q|(F) Can't interpret meta-method template: unknown template name '%s'|,
    tmpl_empty => q|(F) Can't interpret meta-method template: argument is empty or undefined|,
    tmpl_unsupported => q|(F) Can't interpret meta-method template: unsupported template type '%s'|,
  );
}

1;

__END__


=head1 NAME

Class::MakeMethods - Generate common types of methods


=head1 SYNOPSIS

  package MyObject;
  use Class::MakeMethods::Standard::Hash (
    'new'       => 'new',
    'scalar'    => 'foo',
    'scalar'    => 'bar',
  );
  
  package main;   
 
  my $obj = MyObject->new( foo => "Foozle", bar => "Bozzle" );
  print $obj->foo();
  $obj->bar("Barbados");


=head1 DESCRIPTION

The Class::MakeMethods framework allows Perl class developers to
quickly define common types of methods. When a module C<use>s a
subclass of Class::MakeMethods, it can select from the supported
method types, and specify a name for each method desired. The
methods are dynamically generated and installed in the calling
package.

Construction of the individual methods is handled by subclasses.
This delegation approach allows for a wide variety of method-generation
techniques to be supported, each by a different subclass. Subclasses
can also be added to provide support for new types of methods.

Over a dozen subclasses are available, including implementations of
a variety of different method-generation techniques. Each subclass
generates several types of methods, with some supporting their own
open-eneded extension syntax, for hundreds of possible combinations
of method types.

=head2 Getting Started

The remainder of this document focuses on points of usage that are
common across all subclasses, and describes how to create your own
subclasses.

If this is your first exposure to Class::MakeMethods, you may want
to jump to the documentation for a few of the included subclasses,
perhaps starting with L<Class::MakeMethods::Standard::Hash> and
L<Class::MakeMethods::Standard::Universal>, before returning to
the details presented below.


=head1 MOTIVATION

  "Make easy things easier."

This module addresses a problem encountered in object-oriented
development wherein numerous methods are defined which differ only
slightly from each other.

Object-oriented Perl code is widespread -- you've probably seen code like the below a million times:

  my $obj = MyStruct->new( foo=>"Foozle", bar=>"Bozzle" );
  if ( $obj->foo() =~ /foo/i ) {
    $obj->bar("Barbados!");
  }
  print $obj->summary();

(If this doesn't look familiar, take a moment to read L<perlboot>
and you'll soon learn more than's good for you.)

Typically, this involves creating numerous subroutines that follow
a handful of common patterns, like constructor methods and accessor
methods. The classic example is accessor methods for hash-based
object attributes, which allow you to get and set the value
I<self>-E<gt>{I<foo>} by calling a method I<self>-E<gt>I<foo>().
These methods are generally quite simple, requiring only a couple
of lines of Perl, but in sufficient bulk, they can cut down on the
maintainability of large classes.

Here's a possible implementation for the class whose interface is
shown above:

  package MyStruct;
  
  sub new {
    my $callee = shift;
    my $self = bless { @_ }, (ref $callee || $callee);
    return $self;
  }

  sub foo {
    my $self = shift;
    if ( scalar @_ ) {
      $self->{'foo'} = shift();
    } else {
      $self->{'foo'}
    }
  }

  sub bar {
    my $self = shift;
    if ( scalar @_ ) {
      $self->{'bar'} = shift();
    } else {
      $self->{'bar'}
    }
  }

  sub summary {
    my $self = shift;
    join(', ', map { "\u$_: " . $self->$_() } qw( foo bar ) )
  }

Note in particular that the foo and bar methods are almost identical;
this is precisely the type of redundancy Class::MakeMethods addresses.

Class::MakeMethods allows you to simply declare those methods to
be of a predefined type, and it generates and installs the necessary
methods in your package at compile-time.

Here's the equivalent declaration for that same basic class:

  package MyStruct;
  use Class::MakeMethods::Standard::Hash (
    'new'       => 'new',
    'scalar'    => 'foo',
    'scalar'    => 'bar',
  );
  
  sub summary {
    my $self = shift;
    join(', ', map { "\u$_: " . $self->$_() } qw( foo bar ) )
  }

This is the basic purpose of Class::MakeMethods: The "boring" pieces
of code have been replaced by succinct declarations, placing the
focus on the "unique" or "custom" pieces.

The remaining complexity described in this document basically boils
down to figuring out which arguments to pass to generate the specific
methods you want.


=head1 ARCHITECTURE

Because there are so many common types of methods one might wish
to generate, the Class::MakeMethods framework provides an extensible
system based on subclasses.

When your class requests a method, the base class performs some
standard argument parsing, delegates the construction of the actual
method to the appropriate subclass, and then installs whatever
method the subclass returns.

=head2 What the Base Class Does

The Class::MakeMethods package defines a superclass for method-generating
modules, and provides a calling convention, on-the-fly subclass
loading, and subroutine installation that will be shared by all
subclasses.

The superclass also lets you generate several different types of
methods in a single call, and will automatically load named subclasses
the first time they're used.

=head2 What the Subclasses Do

The type of method that gets created is controlled by the specific
subclass and generator function you request. For example,
C<Class::MakeMethods::Standard::Hash> has a generator function C<scalar()>,
which is responsible for generating simple scalar-accessor methods
for blessed-hash objects.

Each generator function specified is passed the arguments specifying the method the caller wants, and produces a closure or eval-able sequence of Perl statements representing the ready-to-install function.

=head2 Included Subclasses

Because each subclass defines its own set of method types and
customization options, a key step is to find your way to the
appropriate subclasses.

=over 4 

=item Standard

Generally you will want to begin with the Standard::Hash subclass, to
create constructor and accessor methods for working with blessed-hash
objects (or you might choose the Standard::Array subclass instead).
The Standard::Global subclass provides methods for class data shared
by all objects in a class. 

Each Standard method declaration can optionally include a hash of associated parameters, which allows you to tweak some of the characteristics of the methods. Subroutines are bound as closures to a hash of each method's name and parameters. Standard::Hash and Standard::Array provide object constructor and
accessors. The Standard::Global provides for static data shared by
all instances and subclasses, while the data for Standard::Inheritable
methods trace the inheritance tree to find values, and can be
overriden for any subclass or instance. 

See L<Class::MakeMethods::Standard> for more. A listing of available
method types is provided in L<Class::MakeMethods::Standard/"SUBCLASS CATALOG">.

=item Basic

The Basic subclasses provide stripped down method generators with no configurable options, for minimal functionality (and minimum overhead). 

Subroutines are bound as closures to the name of each method. Basic::Hash and Basic::Array provide simple object constructors and accessors. Basic::Global provides basic global-data accessors. 

See L<Class::MakeMethods::Basic> for more. A listing of available method types is provided in L<Class::MakeMethods::Basic/"SUBCLASS CATALOG">.

=item Composite

For additional customization options, check out the Composite
subclasses, which allow you to select from a more varied set of
implementations and which allow you to adjust any specific method
by adding your own code-refs to be run before or after it.

Subroutines are bound as closures to a hash of each method's name
and optional additional data, and to one or more subroutine references
which make up the composite behavior of the method. Composite::Hash
and Composite::Array provide object constructor and accessors. The
Composite::Global provides for static data shared by all instances
and subclasses, while the data for Composite::Inheritable methods
can be overriden for any subclass or instance.

See L<Class::MakeMethods::Composite> for more. A listing of available method types is provided in  L<Class::MakeMethods::Composite/"SUBCLASS CATALOG">.

=back

=head2 Additional Subclasses

Other subclasses are available separately, or you can define
your own for future use. 

=over 4

=item Template

The Template subclasses provide an open-ended structure for objects
that assemble Perl code on the fly into cachable closure-generating
subroutines; if the method you need isn't included, you can extend
existing methods by re-defining just the snippet of code that's
different.

Class::MakeMethods::Template extends MakeMethods with a text
templating system that can assemble Perl code fragments into a
desired subroutine. The code for generated methods is eval'd once
for each type, and then repeatedly bound as closures to method-specific
data for better performance.

Templates for dozens of types of constructor, accessor, and mutator
methods are included, ranging from from the mundane (constructors
and value accessors for hash and array slots) to the esoteric
(inheritable class data and "flyweight" accessors with external
indexes).

Class::MakeMethods::Template is available as a separate distribution
from CPAN.  See L<Class::MakeMethods::Template> for more information.
A listing is provided in L<Class::MakeMethods::Template/"SUBCLASS
CATALOG">.

=item Emulators

In several cases, Class::MakeMethods provides functionality closely
equivalent to that of an existing module, and it is simple to map
the existing module's interface to that of Class::MakeMethods.

Class::MakeMethods::Emulator is available as a separate distribution
from CPAN.  See L<Class::MakeMethods::Emulator> for more
information. Emulators are included for Class::MethodMaker,
Class::Accessor::Fast, Class::Data::Inheritable, Class::Singleton,
and Class::Struct, each of which passes the original module's test
suite, usually requiring only a single-line change.

=item Extending

Class::MakeMethods can be extended by creating subclasses that
define additional method-generation functions. Callers can then
specify the name of your subclass and generator function in their
C<use Call::MakeMethods ...> statements and your function will be
invoked to produce the required closures. See L</EXTENDING> for more information.

=back


=head1 USAGE

The supported method types, and the kinds of arguments they expect, vary from subclass to subclass; see the documentation of each subclass for details. 

However, the features described below are applicable to all subclasses.

=head2 Invocation

Methods are dynamically generated and installed into the calling
package when you C<use Class::MakeMethods (...)> or one of its
subclasses, or if you later call C<Class::MakeMethods-E<gt>make(...)>.

The arguments to C<use> or C<make> should be pairs of a generator
type name and an associated array of method-name arguments to pass to
the generator. 

=over 4

=item *

use Class::MakeMethods::I<MakerClass> ( 
    'I<MethodType>' => [ I<Arguments> ], I<...>
  );

=item *

Class::MakeMethods::I<MakerClass>->make ( 
    'I<MethodType>' => [ I<Arguments> ], I<...>
  );

=back

You may select a specific subclass of Class::MakeMethods for
a single generator-type/argument pair by prefixing the type name
with a subclass name and a colon.

=over 4

=item *

use Class::MakeMethods ( 
    'I<MakerClass>:I<MethodType>' => [ I<Arguments> ], I<...>
  );

=item *

Class::MakeMethods->make ( 
    'I<MakerClass>:I<MethodType>' => [ I<Arguments> ], I<...>
  );

=back

The difference between C<use> and C<make> is primarily one of precedence; the C<use> keyword acts as a BEGIN block, and is thus evaluated before C<make> would be. (See L</"About Precedence"> for additional discussion of this issue.)

I<Note:> If you are using Perl version 5.6 or later, see
L<Class::MakeMethods::Attribute> for an additional declaration syntax
for generated methods.

=over 4

=item *

use Class::MakeMethods::Attribute 'I<MakerClass>';

sub I<name> :MakeMethod('I<MethodType>' => I<Arguments>);

=back

=head2 Subclass Naming Convention

Method generation functions in this document are often referred to using the 'I<MakerClass>:I<MethodType>' or 'I<MakerGroup>::I<MakerSubclass>:I<MethodType>' naming conventions. As you will see, these are simply the names of Perl packages and the names of functions that are contained in those packages.

The included subclasses are grouped into several major groups, so the names used by the included subclasses and method types reflect three axes of variation, "I<Group>::I<Subclass>:I<Type>":

=over 4

=item MakerGroup

Each group shares a similar style of technical implementation and level of complexity. For example, the C<Standard::*> packages are all simple, while the C<Composite::*> packages all support pre- and post-conditions.

(For a listing of the four main groups of included subclasses, see L<"/Included Subclasses">.)

=item MakerSubclass

Each subclass generates methods for a similar level of scoping or underlying object type. For example, the C<*::Hash> packages all make methods for objects based on blessed hashes, while the C<*::Global> packages make methods that access class-wide data that will be shared between all objects in a class.

=item Method Type

Each method type produces a similar type of constructor or accessor. For examples, the C<*:new> methods are all constructors, while the C<::scalar> methods are all accessors that allow you to get and set a single scalar value.

=back

Bearing that in mind, you should be able to guess the intent of many of the method types based on their names alone; when you see "Standard::Array:list" you can read it as "a type of method to access a I<list> of data stored in an I<array> object, with a I<"standard"> implementation style" and know that it's going to call the list() function in the Class::MakeMethods::Standard::Array package to generate the requested method.


=head2 Mixing Method Types

A single calling class can combine generated methods from different MakeMethods subclasses. In general, the only mixing that's problematic is combinations of methods which depend on different underlying object types, like using *::Hash and *::Array methods together -- the methods will be generated, but some of them  are guaranteed to fail when called, depending on whether your object happens to be a blessed hashref or arrayref. 

It's common to mix and match various *::Hash methods, with a scattering of Global or Inheritable methods:

  use Class::MakeMethods (
    'Basic::Hash:scalar'      => 'foo',
    'Composite::Hash:scalar'  => [ 'bar' => { post_rules => [] } ],
    'Standard::Global:scalar' => 'our_shared_baz'
  );



=head2 Argument Normalization

The following expansion rules are applied to argument pairs to
enable the use of simple strings instead of arrays of arguments.

=over 4

=item *

Each type can be followed by a single meta-method definition, or by a
reference to an array of them.

=item *

If the argument is provided as a string containing spaces, it is
split and each word is treated as a separate argument.

=item *

It the meta-method type string contains spaces, it is split and
only the first word is used as the type, while the remaining words
are placed at the front of the argument list.

=back

For example, the following statements are equivalent ways of
declaring a pair of Basic::Hash scalar methods named 'foo' and 'bar':

  use Class::MakeMethods::Basic::Hash ( 
    'scalar' => [ 'foo', 'bar' ], 
  );
  
  use Class::MakeMethods::Basic::Hash ( 
    'scalar' => 'foo', 
    'scalar' => 'bar', 
  );
  
  use Class::MakeMethods::Basic::Hash ( 
    'scalar' => 'foo bar', 
  );
  
  use Class::MakeMethods::Basic::Hash ( 
    'scalar foo' => 'bar', 
  );

(The last of these is clearly a bit peculiar and potentially misleading if used as shown, but it enables advanced subclasses to provide convenient formatting for declarations with  defaults or modifiers, such as C<'Template::Hash:scalar --private' =E<gt> 'foo'>, discussed elsewhere.)


=head2 Global Options

Global parameters may be specified as an argument pair with a leading hyphen. (Type names must be valid Perl subroutine names, and thus will never begin with a hyphen.) 

use Class::MakeMethods::I<MakerClass> ( 
    '-I<Param>' => I<ParamValue>,
    'I<MethodType>' => [ I<Arguments> ], I<...>
  );

Parameter settings apply to all subsequent method declarations within a single C<use> or C<make> call.

The below parameters allow you to control generation and installation of the requested methods. (Some subclasses may support additional parameters; see their documentation for details.)

=over 4 

=item TargetClass

By default, the methods are installed in the first package in the caller() stack that is not a Class::MakeMethods subclass; this is generally the package in which your use or make statement was issued. To override this you can pass C<-TargetClass =E<gt> I<package>> as initial arguments to C<use> or C<make>. 

This allows you to construct or modify classes "from the outside":

  package main;
  
  use Class::MakeMethods::Basic::Hash( 
    -TargetClass => 'MyWidget',
    'new' => ['create'],
    'scalar' => ['foo', 'bar'],
  );
  
  $o = MyWidget->new( foo => 'Foozle' );
  print $o->foo();

=item MakerClass

By default, meta-methods are looked up in the package you called
use or make on.

You can override this by passing the C<-MakerClass> flag, which
allows you to switch packages for the remainder of the meta-method
types and arguments.

use Class::MakeMethods ( 
    '-MakerClass'=>'I<MakerClass>', 
    'I<MethodType>' => [ I<Arguments> ] 
  );

When specifying the MakerClass, you may provide either the trailing
part name of a subclass inside of the C<Class::MakeMethods::>
namespace, or a full package name prefixed by C<::>. 

For example, the following four statements are equivalent ways of
declaring a Basic::Hash scalar method named 'foo':

  use Class::MakeMethods::Basic::Hash ( 
    'scalar' => [ 'foo' ] 
  );
  
  use Class::MakeMethods ( 
    'Basic::Hash:scalar' => [ 'foo' ] 
  );
  
  use Class::MakeMethods ( 
    '-MakerClass'=>'Basic::Hash', 
    'scalar' =>  [ 'foo' ] 
  );
  
  use Class::MakeMethods ( 
    '-MakerClass'=>'::Class::MakeMethods::Basic::Hash', 
    'scalar' =>  [ 'foo' ] 
  );

=item ForceInstall

By default, Class::MakeMethods will not install generated methods over any pre-existing methods in the target class. To override this you can pass C<-ForceInstall =E<gt> 1> as initial arguments to C<use> or C<make>. 

Note that the C<use> keyword acts as a BEGIN block, so a C<use> at the top of a file will be executed before any subroutine declarations later in the file have been seen. (See L</"About Precedence"> for additional discussion of this issue.)

=back

=head2 About Precedence

Rather than passing the method declaration arguments when you C<use> one of these packages, you may instead pass them to a subsequent call to the class method C<make>. 

The difference between C<use> and C<make> is primarily one of precedence; the C<use> keyword acts as a BEGIN block, and is thus evaluated before C<make> would be. In particular, a C<use> at the top of a file will be executed before any subroutine declarations later in the file have been seen, whereas a C<make> at the same point in the file will not. 

By default, Class::MakeMethods will not install generated methods over any pre-existing methods in the target class. To override this you can pass C<-ForceInstall =E<gt> 1> as initial arguments to C<use> or C<make>. 

If methods with the same name already exist, earlier
calls to C<use> or C<make()> win over later ones, but within each
call, later declarations superceed earlier ones.

Here are some examples of the results of these precedence rules:

  # 1
  use Class::MakeMethods::Standard::Hash (
    'scalar'=>['baz'] # baz() not seen yet, so we generate, install
  );
  sub baz { 1 } # Subsequent declaration overwrites it, with warning
  
  # 2
  sub foo { 1 }
  use Class::MakeMethods::Standard::Hash (
    'scalar'=>['foo'] # foo() is already declared, so has no effect
  );
  
  # 3
  sub bar { 1 }
  use Class::MakeMethods::Standard::Hash ( 
      -ForceInstall => 1, # Set flag for following methods...
    'scalar' => ['bar']   # ... now overwrites pre-existing bar()
  );
  
  # 4
  Class::MakeMethods::Standard::Hash->make(
    'scalar'=>['blip'] # blip() is already declared, so has no effect
  );
  sub blip { 1 } # Although lower than make(), this "happens" first
  
  # 5
  sub ping { 1 } 
  Class::MakeMethods::Standard::Hash->make(
      -ForceInstall => 1, # Set flag for following methods...
    'scalar' => ['ping']  # ... now overwrites pre-existing ping()
  );


=head1 EXAMPLES

The following examples indicate some of the capabilities of
Class::MakeMethods. 

=head2 Adding Custom Initialization to Constructors

Frequently you'll want to provide some custom code to initialize new objects of your class. Most of the C<*:new> constructor methods provides a way to ensure that this code is consistently called every time a new instance is created.

The Composite classes allow you to add pre- and post-operations to any method, so you can pass in a code-ref to be executed after the new() method.

  package MyClass;
  
  sub new_post_init {
    my $self = ${(pop)->{result}}; # get result of original new()
    length($self->foo) or $self->foo('FooBar');   # default value
    warn "Initialized new object '$self'";       
  }
  
  use Class::MakeMethods (
    'Composite::Hash:new' => [
	'new' => { post_rules=>[ \&new_post_init ] } 
    ],
    'Composite::Hash:scalar' => 'foo;,
  );
  ... 
  package main;
  my $self = MyClass->new( foo => 'Foozle' )


=head2 Access Control Example

The following defines a secret_password method, which will croak
if it is called from outside of the declaring package.

  use Class::MakeMethods::Composite::Hash
    'scalar' => [ 'secret_password' => { permit => 'pp' } ];

(See L<Class::MakeMethods::Composite> for information
about the C<permit> modifier.)


=head2 Mixing Object and Global Methods

Here's a package declaration using two of the included subclasses, C<Standard::Hash>, for creating and accessing hash-based objects, and C<Basic::Global>, for simple global-value accessors:

  package MyQueueItem;
  
  use Class::MakeMethods::Standard::Hash (
    new => { name => 'new', defaults=>{ foo => 'Foozle' } },
    scalar => [ 'foo', 'bar' ],
    hash => 'history'
  );
  
  use Class::MakeMethods::Basic::Global (
    scalar => 'Debug',
    array  => 'InQueue',
  );
  
  sub AddQueueItem {
    my $class = shift;
    my $instance = shift;
    $instance->history('AddQueueItem' => time());
    $class->InQueue([0, 0], $instance);    
  }
  
  sub GetQueueItem {
    my $class = shift;
    $class->InQueue([0, 1], []) or $class->new
  }



=head1 EXTENDING

Class::MakeMethods can be extended by creating subclasses that
define additional meta-method types. Callers then select your
subclass using any of the several techniques described above.

You can give your meta-method type any name that is a legal subroutine
identifier. Names begining with an underscore, and the names
C<import> and C<make>, are reserved for internal use by
Class::MakeMethods.

=head2 Implementation Options

Your meta-method subroutine should provide one of the following types of functionality:

=over 4

=item *

Subroutine Generation

Returns a list of subroutine name/code pairs.

The code returned may either be a coderef, or a string containing
Perl code that can be evaled and will return a coderef. If the eval
fails, or anything other than a coderef is returned, then
Class::MakeMethods croaks.

For example a simple sub-class with a method type upper_case_get_set
that generates an accessor method for each argument provided might
look like this:

  package My::UpperCaseMethods;
  use Class::MakeMethods '-isasubclass';
  
  sub uc_scalar {
    my $class = shift;
    map { 
      my $name = $_;
      $name => sub {
	my $self = shift;
	if ( scalar @_ ) { 
	  $self->{ $name } = uc( shift ) 
	} else {
	  $self->{ $name };
	}
      }
    } @_;
  }

Callers could then generate these methods as follows:

  use My::UpperCaseMethods ( 'uc_scalar' => 'foo' );

=item *

Aliasing

Returns a string containing a different meta-method type to use
for those same arguments.

For example a simple sub-class that defines a method type stored_value
might look like this:

  package My::UpperCaseMethods;
  use Class::MakeMethods '-isasubclass';

  sub regular_scalar { return 'Basic::Hash:scalar' }

And here's an example usage:

  use My::UpperCaseMethods ( 'regular_scalar' => [ 'foo' ] );

=item *

Rewriting

Returns one or more array references with different meta-method
types and arguments to use.

For example, the below meta-method definition reviews the name of
each method it's passed and creates different types of meta-methods
based on whether the declared name is in all upper case:

  package My::UpperCaseMethods;
  use Class::MakeMethods '-isasubclass';

  sub auto_detect { 
    my $class = shift;
    my @rewrite = ( [ 'Basic::Hash:scalar' ], 
		    [ '::My::UpperCaseMethods:uc_scalar' ] );
    foreach ( @_ ) {
      my $name_is_uppercase = ( $_ eq uc($_) ) ? 1 : 0;
      push @{ $rewrite[ $name_is_uppercase ] }, $_
    }
    return @rewrite;
  }

The following invocation would then generate a regular scalar accessor method foo, and a uc_scalar method BAR:

  use My::UpperCaseMethods ( 'auto_detect' => [ 'foo', 'BAR' ] );

=item * 

Generator Object

Returns an object with a method named make_methods which will be responsible for returning subroutine name/code pairs. 

See L<Class::MakeMethods::Template> for an example.

=item *

Self-Contained

Your code may do whatever it wishes, and return an empty list.

=back

=head2 Access to Parameters

Global parameter values are available through the _context() class method at the time that method generation is being performed.

  package My::Maker;
  sub my_methodtype {
    my $class = shift;
    warn "Installing in " . $class->_context('TargetClass');
    ...
  }

=over 4

=item *

TargetClass

Class into which code should be installed.

=item *

MakerClass

Which subclass of Class::MakeMethods will generate the methods?

=item *

ForceInstall

Controls whether generated methods will be installed over pre-existing methods in the target package.

=back


=head1 DIAGNOSTICS

The following warnings and errors may be produced when using
Class::MakeMethods to generate methods. (Note that this list does not
include run-time messages produced by calling the generated methods.)

These messages are classified as follows (listed in increasing order of
desperation): 

    (Q) A debugging message, only shown if $CONTEXT{Debug} is true
    (W) A warning.
    (D) A deprecation.
    (F) A fatal error in caller's use of the module.
    (I) An internal problem with the module or subclasses.

Portions of the message which may vary are denoted with a %s.

=over 4

=item Can't interpret meta-method template: argument is empty or
undefined

(F)

=item Can't interpret meta-method template: unknown template name
'%s'

(F)

=item Can't interpret meta-method template: unsupported template
type '%s'

(F)

=item Can't make method %s(): template specifies unknown behavior
'%s'

(F)

=item Can't parse meta-method declaration: argument is empty or
undefined

(F) You passed an undefined value or an empty string in the list
of meta-method declarations to use or make.

=item Can't parse meta-method declaration: missing name attribute.

(F) You included an hash-ref-style meta-method declaration that
did not include the required name attribute. You may have meant
this to be an attributes hash for a previously specified name, but
if so we were unable to locate it.

=item Can't parse meta-method declaration: unknown template name
'%s'

(F) You included a template specifier of the form C<'-I<template_name>'>
in a the list of meta-method declaration, but that template is not
available.

=item Can't parse meta-method declaration: unsupported declaration
type '%s'

(F) You included an unsupported type of value in a list of meta-method
declarations.

=item Compilation error: %s

(I)

=item Not an interpretable meta-method: '%s'

(I)

=item Odd number of arguments passed to %s make

(F) You specified an odd number of arguments in a call to use or
make.  The arguments should be key => value pairs.

=item Unable to compile generated method %s(): %s

(I) The install_methods subroutine attempted to compile a subroutine
by calling eval on a provided string, which failed for the indicated
reason, usually some type of Perl syntax error.

=item Unable to dynamically load $package: $%s

(F)

=item Unable to install code for %s() method: '%s'

(I) The install_methods subroutine was passed an unsupported value
as the code to install for the named method.

=item Unexpected return value from compilation of %s(): '%s'

(I) The install_methods subroutine attempted to compile a subroutine
by calling eval on a provided string, but the eval returned something
other than than the code ref we expect.

=item Unexpected return value from meta-method constructor %s: %s

(I) The requested method-generator was invoked, but it returned an unacceptable value.

=back


=head1 BUGS 

It does not appear to be possible to assign subroutine names to closures within Perl. As a result, debugging output from Carp and similar sources will show all generated methods as "ANON()" rather than "YourClass::methodname()".

See L<Class::MakeMethods::ToDo> for other outstanding issues.


=head1 SEE ALSO

=head2 Package Documentation

See L<Class::MakeMethods::Basic>, L<Class::MakeMethods::Standard>, L<Class::MakeMethods::Composite>, and L<Class::MakeMethods::Template> for information about each family of subclasses.

See L<Class::MakeMethods::ReadMe> for distribution, installation, version and support information.

For a brief survey of the numerous modules on CPAN which offer some
type of method generation, see L<Class::MakeMethods::RelatedModules>.

=head2 Getting-Started Resources

Ron Savage has posted a pair of annotated examples, linked to below.
Each demonstrates building a class with MakeMethods, and each
includes scads of comments that walk you through the logic and
demonstrate how the various methods work together.

  http://savage.net.au/Perl-tutorials.html
  http://savage.net.au/Perl-tutorials/tut-33.tgz
  http://savage.net.au/Perl-tutorials/tut-34.tgz

=head2 Perl Docs

See L<perlboot> for a quick introduction to objects for beginners. See L<perltoot>, and L<perltootc> for an extensive discussion of various approaches to class construction.

See L<perlref/"Making References">, point 4 for more information on closures. (FWIW, I think there's a big opportunity for a "perltfun" podfile bundled with Perl in the tradition of "perlboot" and "perltoot", exploring the utility of function references, callbacks, closures, and continuations... There are a bunch of useful references out there, but not a good overview of how they all interact in a Perlish way.)


=head1 VERSION

This is Class::MakeMethods v1.003.


=head1 CREDITS AND COPYRIGHT

=head2 Developed By

  M. Simon Cavalletto, simonm@cavalletto.org
  Evolution Softworks, www.evoscript.org

=head2 Source Material

Inspiration, cool tricks, and blocks of useful code for this module
were extracted from the following CPAN modules:

  Class::MethodMaker, by Peter Seibel.
  Class::Accessor, by Michael G Schwern 
  Class::Contract, by Damian Conway
  Class::SelfMethods, by Toby Everett

=head2 Feedback and Suggestions 

Thanks to:

  Martyn J. Pearce
  Scott R. Godin
  Ron Savage
  Jay Lawrence
  Adam Spiers

=head2 Copyright

Copyright 2002 Matthew Simon Cavalletto. 

Portions copyright 1998, 1999, 2000, 2001 Evolution Online Systems, Inc.

Portions copyright 1996 Organic Online.

Portions copyright 2000 Martyn J. Pearce.

=head2 License

You may use, modify, and distribute this software under the same terms as Perl.

=cut
