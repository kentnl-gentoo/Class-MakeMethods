### Class::MakeMethods
  # Copyright 1998, 1999, 2000, 2001 Evolution Online Systems, Inc.
  # See documentation, license, and other information after _END_.

package Class::MakeMethods;

use strict;
require 5.00307; # for the UNIVERSAL::isa method.

use vars qw( $VERSION );
$VERSION = 1.000_016;

use vars qw( %CONTEXT %DIAGNOSTICS );

use Carp;
use strict;

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
  use Class::MakeMethods::Basic::Hash (
    'new'     => [ 'new' ],
    'scalar'  => [ 'foo', 'bar' ]
  );

  package main;   
 
  my $obj = MyObject->new( foo => "Foozle", bar => "Bozzle" );
  print $obj->foo();
  $obj->bar("Barbados");


=head1 MOTIVATION

  "Make easy things easier."

This module addresses a problem encountered in object-oriented
development wherein numerous methods are defined which differ only
slightly from each other.

A common example is accessor methods for hash-based object attributes,
which allow you to get and set the value I<self>-E<gt>{I<foo>} by
calling a method I<self>-E<gt>I<foo>().

These methods are generally quite simple, requiring only a couple
of lines of Perl, but in sufficient bulk, they can cut down on the
maintainability of large classes.

Class::MakeMethods allows you to simply declare those methods to
be of a predefined type, and it generates and installs the necessary
methods in your package at compile-time.


=head1 DESCRIPTION

The Class::MakeMethods framework allows Perl class developers to
quickly define common types of methods. When a module C<use>s a
subclass of Class::MakeMethods, it can select from the supported
method types, and specify a name for each method desired. The
methods are dynamically generated and installed in the calling
package.

=head2 Extensible Architecture

The Class::MakeMethods package defines a superclass for method-generating
modules, and provides a calling convention, on-the-fly subclass
loading, and subroutine installation that will be shared by all
subclasses.

Construction of the individual methods is handled by subclasses.
This delegation approach allows for a wide variety of method-generation
techniques to be supported, each by a different subclass. Subclasses
can also be added to provide support for new types of methods.

Over a dozen subclasses are included, including implementations of
a variety of different method-generation techniques. Each subclass
generates several types of methods, with some supporting their own
open-eneded extension syntax, for hundreds of possible combinations
of method types. (See L<Class::MakeMethods::Guide> for an overview
of the included subclasses.)

=head2 Getting Started

The remainder of this document focuses on points of usage that
are common across all subclasses, and describes how to create your
own subclasses.

If this is your first exposure to Class::MakeMethods, you may want
to start with L<Class::MakeMethods::Guide>, and then perhaps jump
to the documentation for a few of the included subclasses, before
returning to the details presented below.

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

use Class::MakeMethods::I<MethodClass> ( 
    'I<MethodType>' => [ I<Arguments> ], I<...>
  );

=item *

Class::MakeMethods::I<MethodClass>->make ( 
    'I<MethodType>' => [ I<Arguments> ], I<...>
  );

=back

The difference between C<use> and C<make> is primarily one of precedence; the C<use> keyword acts as a BEGIN block, and is thus evaluated before C<make> would be. (See L< Class::MakeMethods::Guide/"About Precedence"> for additional discussion of this issue.)

I<Note:> If you are using Perl version 5.6 or later, see
L<Class::MakeMethods::Attribute> for an additional declaration syntax
for generated methods.

=over 4

=item *

use Class::MakeMethods::Attribute 'I<MethodClass>';

sub I<name> :MakeMethod('I<MethodType>' => I<Arguments>);

=back

=head2 Global Options

Global parameters may be specified as an argument pair with a leading hyphen. (Type names must be valid Perl identifiers, and thus will never begin with a hyphen.) 

use Class::MakeMethods::I<MethodClass> ( 
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
    '-MakerClass'=>'I<MethodClass>', 
    'I<MethodType>' => [ I<Arguments> ] 
  );

You may also select a specific subclass of Class::MakeMethods for
a single meta-method type/argument pair by prefixing the type name
with a subclass name and a colon.

use Class::MakeMethods ( 
    'I<MethodClass>:I<MethodType>' => [ I<Arguments> ] 
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
    '-MakerClass'=>'Basic::Hash', 
    'scalar' =>  [ 'foo' ] 
  );
  
  use Class::MakeMethods ( 
    'Basic::Hash:scalar' => [ 'foo' ] 
  );
  
  use Class::MakeMethods ( 
    '-MakerClass'=>'::Class::MakeMethods::Basic::Hash', 
    'scalar' =>  [ 'foo' ] 
  );

=item ForceInstall

By default, Class::MakeMethods will not install generated methods over any pre-existing methods in the target class. To override this you can pass C<-ForceInstall =E<gt> 1> as initial arguments to C<use> or C<make>. 

Note that the C<use> keyword acts as a BEGIN block, so a C<use> at the top of a file will be executed before any subroutine declarations later in the file have been seen. (See L< Class::MakeMethods::Guide/"About Precedence"> for additional discussion of this issue.)

=back

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
    'scalar' => [ 'foo', 'bar'], 
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

(The last of these is clearly a bit peculiar and potentially misleading if used as shown, but it enables advanced subclasses to provide convenient formatting for declarations with  defaults or modifiers, such as C<'Template::Hash:scalar --private' =E<gt> 'foo'>.)


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

  package Class::UpperCaseMethods;
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

  use Class::UpperCaseMethods ( 'uc_scalar' => 'foo' );

=item *

Aliasing

Returns a string containing a different meta-method type to use
for those same arguments.

For example a simple sub-class that defines a method type stored_value
might look like this:

  package Class::UpperCaseMethods;
  use Class::MakeMethods '-isasubclass';

  sub regular_scalar { return 'Basic::Hash:scalar' }

And here's an example usage:

  use Class::UpperCaseMethods ( 'regular_scalar' => [ 'foo' ] );

=item *

Rewriting

Returns one or more array references with different meta-method
types and arguments to use.

For example, the below meta-method definition reviews the name of
each method it's passed and creates different types of meta-methods
based on whether the declared name is in all upper case:

  package Class::UpperCaseMethods;
  use Class::MakeMethods '-isasubclass';

  sub auto_detect { 
    my $class = shift;
    my @rewrite = ( [ 'Basic::Hash:scalar' ], 
		    [ '::Class::UpperCaseMethods:uc_scalar' ] );
    foreach ( @_ ) {
      my $name_is_uppercase = ( $_ eq uc($_) ) ? 1 : 0;
      push @{ $rewrite[ $name_is_uppercase ] }, $_
    }
    return @rewrite;
  }

The following invocation would then generate a regular scalar accessor method foo, and a uc_scalar method BAR:

  use Class::UpperCaseMethods ( 'auto_detect' => [ 'foo', 'BAR' ] );

=item * 

Generator Object

Returns an object with a method named make_methods which will be responsible for returning subroutine name/code pairs. 

See L<Class::MakeMethods::Template> for an example.

=item *

Self-Contained

Your code may do whatever it wishes, and return an empty list.

=back

=head2 Access to Parameters

Global parameter values are available through the _context() class method:

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

See L<Class::MakeMethods::Guide> for a getting-started guide,
annotated examples of usage, and a listing of the method generation
classes included in this distribution.

See L<Class::MakeMethods::ReadMe> for distribution, installation,
version and support information.

For a brief survey of the numerous modules on CPAN which offer some
type of method generation, see L<Class::MakeMethods::RelatedModules>.

=head2 Perl Docs

See L<perlref/"Making References">, point 4 for more information on closures.

See L<perltoot> and L<perltootc> for an extensive discussion of various approaches to class construction.


=head1 VERSION

This is Class::MakeMethods v1.0.015.


=head1 CREDITS AND COPYRIGHT

=head2 Developed By

  M. Simon Cavalletto, simonm@cavalletto.org
  Evolution Softworks, www.evoscript.org

=head2 The Shoulders of Giants

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
