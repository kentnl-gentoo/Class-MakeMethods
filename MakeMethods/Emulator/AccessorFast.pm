package Class::MakeMethods::Emulator::AccessorFast;

use strict;
use Class::MakeMethods::Composite::Hash;
use Class::MakeMethods::Emulator::TakeName;

my $emulation_target = 'Class::Accessor::Fast';

sub import {
  my $mm_class = shift;
  if ( scalar @_ and $_[0] =~ /^-take_namespace/ and shift) {
    Class::MakeMethods::Emulator::TakeName::namespace_capture(__PACKAGE__, $emulation_target);
  } elsif ( scalar @_ and $_[0] =~ /^-release_namespace/ and shift) {
    Class::MakeMethods::Emulator::TakeName::namespace_release(__PACKAGE__, $emulation_target);
  }
  # The fallback should really be to NEXT::import.
  $mm_class->SUPER::import( @_ );
}

sub mk_accessors {
  Class::MakeMethods::Composite::Hash->make(
    -TargetClass => (shift),
    'new' => { name => 'new', modifier => 'with_values' },
    'scalar' => [ map { 
	$_, 
	"_${_}_accessor", { 'hash_key' => $_ } 
    } @_ ],
  );
}

sub mk_ro_accessors {
  Class::MakeMethods::Composite::Hash->make(
    -TargetClass => (shift),
    'new' => { name => 'new', modifier => 'with_values' },
    'scalar' => [ map { 
	$_, { permit => 'ro' }, 
	"_${_}_accessor", { 'hash_key' => $_, permit => 'ro' }
    } @_ ],
  );
}

sub mk_wo_accessors {
  Class::MakeMethods::Composite::Hash->make(
    -TargetClass => (shift),
    'new' => { name => 'new', modifier => 'with_values' },
    'scalar' => [ map { 
	$_, { permit => 'wo' }, 
	"_${_}_accessor", { 'hash_key' => $_, permit => 'wo' } 
    } @_ ],
  );
}

1;

__END__

=head1 NAME

B<Class::MakeMethods::Emulator::AccessorFast> - Emulate Class::Accessor::Fast


=head1 SYNOPSIS

    package Foo;
    
    use base qw(Class::MakeMethods::Emulator::AccessorFast);
    Foo->mk_accessors(qw(this that whatever));
    
    # Meanwhile, in a nearby piece of code!
    # Emulator::AccessorFast provides new().
    my $foo = Foo->new;
    
    my $whatever = $foo->whatever;    # gets $foo->{whatever}
    $foo->this('likmi');              # sets $foo->{this} = 'likmi'


=head1 DESCRIPTION

This module emulates the functionality of Class:: Accessor::Fast, using Class::MakeMethods to generate similar methods.

You may use it directly, as shown in the SYNOPSIS above, 

Furthermore, you may call  C<use Class::MakeMethods::Emulator::AccessorFast
'-take_namespace';> to alias the Class::Accessor::Fast namespace
to this package, and subsequent calls to the original package will
be transparently handled by this emulator. To remove the emulation
aliasing, call C<use Class::MakeMethods::Emulator::AccessorFast
'-release_namespace'>.

B<Caution:> This affects B<all> subsequent uses of Class::Accessor::Fast
in your program, including those in other modules, and might cause
unexpected effects.


=head1 SEE ALSO

See L<Class::Accessor::Fast> for documentation of the original module.

See L<Class::MakeMethods> for an overview of the method-generation
framework this is based on.

See L<Class::MakeMethods::Guide> for a getting-started guide,
annotated examples of usage, and a listing of the method generation
classes included in this distribution.

See L<Class::MakeMethods::ReadMe> for distribution, installation,
version and support information.


=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 2001 Evolution Online Systems, Inc.

Developed by:

  M. Simon Cavalletto, Evolution Online Systems, simonm@evolution.com

=cut

