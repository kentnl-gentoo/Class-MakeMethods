package Class::MakeMethods::Basic;

use Class::MakeMethods '-isasubclass';

1;

__END__

########################################################################

=head1 NAME

Class::MakeMethods::Basic - Make really simple methods


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


=head1 DESCRIPTION

This document describes the various subclasses of Class::MakeMethods
included under the Basic::* namespace, and the method types each
one provides.

The Basic subclasses provide stripped-down method-generation implementations.

Subroutines are generated as closures bound to each method name.

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

You can install methods in a different package by passing C<-TargetClass =E<gt> I<package>> as your first arguments to C<use> or C<make>. 

See L<Class::MakeMethods/"USAGE"> for more details.

=head2 Declaration Syntax

The following types of declarations are supported:

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


=head1 SUBCLASS CATALOG

=head2 Basic::Hash (Instances)

Methods for objects based on blessed hashes. See L<Class::MakeMethods::Basic::Hash> for details.

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

=back

=head2 Basic::Array (Instances)

Methods for manipulating positional values in arrays. See L<Class::MakeMethods::Basic::Array> for details.

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

=back

=head2 Basic::Global (Global)

Global methods are not instance-dependent; calling them by class
name or from any instance or subclass will consistently access the
same value. See L<Class::MakeMethods::Basic::Global> for details.

=over 4

=item *

scalar: get and set a global scalar value

=item *

array: get and set values in a global array

=item *

hash: get and set values in a global hash

=back

=head1 SEE ALSO

See L<Class::MakeMethods> for an overview of the method-generation
framework this is based on.

See L<Class::MakeMethods::ReadMe> for distribution, installation,
version and support information.

=cut
