package Class::MakeMethods::Attribute;

require 5.006;
use strict;
use Carp;
use Attribute::Handlers;

use Class::MakeMethods;

our $VERSION = 1.000_013;

our %DefaultMaker;

sub import {
  my $class = shift;

  if ( scalar @_ and $_[0] =~ m/^\d/ ) {
    Class::MakeMethods::_import_version( $class, shift );
  }
  
  if ( scalar @_ == 1 ) {
    my $target_class = ( caller(0) )[0];
    $DefaultMaker{ $target_class } = shift;
  }
}

sub UNIVERSAL::MakeMethod :ATTR(CODE) {
  my ($package, $symbol, $referent, $attr, $data) = @_;
  if ( $symbol eq 'ANON' or $symbol eq 'LEXICAL' ) {
    croak "Can't apply MakeMethod attribute to $symbol declaration."
  }
  if ( ! $data ) {
    croak "No method type provided for MakeMethod attribute."
  }
  my $symname = *{$symbol}{NAME};
  if ( ref $data eq 'ARRAY' ) {
    local $_ = shift @$data;
    $symname = [ @$data, $symname ];
    $data = $_;
  }
  Class::MakeMethods->make( 
    -TargetClass => $package,
    -ForceInstall => 1, 
    ( $DefaultMaker{$package} ? ('-MakerClass'=>$DefaultMaker{$package}) : () ),
    $data => $symname
  );
}

1;

__END__

=head1 NAME

Class::MakeMethods::Attribute - Declare generated subs

=head1 SYNOPSIS

  package MyObject;
  use Class::MakeMethods::Attribute 'Standard::Hash';
  
  sub new    :MakeMethod('new');
  sub foo    :MakeMethod('scalar');
  sub bar    :MakeMethod('scalar', { hashkey => 'bar_data' });
  sub debug  :MakeMethod('Standard::Global:scalar');

=head1 DESCRIPTION

This package allows common types of methods to be generated via a subroutine attribute declaration.

Adding the :MakeMethod() attribute to a subroutine declaration causes Class::MakeMethods to create and install a subroutine based on the :MakeMethod parameters.

In particular, the example presented in the SYNOPSIS is equivalent to the following Class::MakeMethods declaration:

  package MyObject;
  use Class::MakeMethods ( 
    -MakerClass => 'Standard::Hash',
    new => 'new',
    scalar => 'foo',
    scalar => [ 'bar_accessor', { hashkey => 'bar' } ],
    'Standard::Global:scalar' => 'debug',
  );

=head1 DIAGNOSTICS

=over

=item Can't apply MakeMethod attribute to %s declaration.

You can not use the C<:MakeMethod> attribute with lexical or anonymous subroutine declarations. 

=item No method type provided for MakeMethod attribute.

You called C<:MakeMethod()> without the required method-type argument.

=back

=head1 SEE ALSO

See L<Attribute::Handlers> by Damian Conway 

=head1 AUTHOR

Developed by:

  M. Simon Cavalletto, Evolution Online Systems, simonm@evolution.com

Inspired by Attribute::Abstract and Attribute::Memoize by Marcel Grunauer.

=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 2001 Evolution Online Systems, Inc.

=cut
