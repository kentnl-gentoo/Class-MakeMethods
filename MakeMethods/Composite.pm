=head1 NAME

Class::MakeMethods::Composite - Make extensible compound methods


=head1 SYNOPSIS

  package MyObject;
  use Class::MakeMethods::Composite::Hash (
    new => 'new',
    scalar => [ 'foo', 'bar' ],
    array => 'my_list',
    hash => 'my_index',
  );


=head1 DESCRIPTION

This document describes the various subclasses of Class::MakeMethods
included under the Composite::* namespace, and the method types each
one provides.

The Composite subclasses provide a parameterized set of method-generation
implementations.

Subroutines are generated as closures bound to a hash containing
the method name and additional parameters, including the arrays of subroutine references that will provide the method's functionality.


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

package Class::MakeMethods::Composite;

$VERSION = 1.000;
use strict;
use Class::MakeMethods::Standard '-isasubclass';
use Carp;

########################################################################

=head2 About Composite Methods

The methods generated by Class::MakeMethods::Composite are assembled
from groups of "fragment" subroutines, each of which provides some
aspect of the method's behavior.

You can add pre- and post- operations to any composite method.

  package MyObject;
  use Class::MakeMethods::Composite::Hash (
    new => 'new',
    scalar => [ 
      'foo' => { 
	'pre_rules' => [ 
	  sub {
	    # Don't automatically convert list to array-ref
	    croak "Too many arguments" if ( scalar @_ > 2 );
	  }
	],
	'post_rules' => [ 
	  sub {
	    # Don't let anyone see my credit card number!
	    ${(pop)->{result}} =~ s/\d{13,16}/****/g;
	  }
	],
      }
    ],
  );

=cut

use vars qw( $Method );

sub CurrentMethod {
  $Method;
}

sub CurrentResults {
  my $package = shift;
  if ( ! scalar @_ ) {
    ( ! $Method->{result} ) 	          ? () :
    ( ref($Method->{result}) eq 'ARRAY' ) ? @{$Method->{result}} :  
					    ${$Method->{result}};
  } elsif ( scalar @_ == 1) {
    my $value = shift;
    $Method->{result} = \$value; 
    $value
  } else {
    my @value = @_;
    $Method->{result} = \@value;
    @value;
  }
}

sub _build_composite {
  my $class = shift;
  my $fragments = shift;
  map { 
    my $method = $_;
    my @fragments = @{ $fragments->{''} };
    foreach my $flagname ( grep $method->{$_}, qw/ permit modifier / ) {
      my $value = $method->{$flagname};
      my $fragment = $fragments->{$value}
		or croak "Unsupported $flagname flag '$value'";
      push @fragments, @$fragment;
    }
    _bind_composite( $method, @fragments );
  } $class->get_declarations(@_)
}

sub _assemble_fragments {
  my $method = shift;
  my @fragments = @_;
  while ( scalar @fragments ) {
    my ($rule, $sub) = splice( @fragments, 0, 2 );
    if ( $rule =~ s/\A\+// ) {
      unshift @{$method->{"${rule}_rules"}}, $sub  
    } elsif ( $rule =~ s/\+\Z// ) {
      push @{$method->{"${rule}_rules"}}, $sub  
    } elsif ( $rule =~ /\A\w+\Z/ ) {
      @{$method->{"${rule}_rules"}} = $sub;
    } else { 	
      croak "Unsupported rule type '$rule'"
    }
  }
}

sub _bind_composite {
  my $method = shift;
  _assemble_fragments( $method, @_ );
  if ( my $subs = $method->{"init_rules"} ) {
    foreach my $sub ( @$subs ) {
      &$sub( $method );
    }
  }
  $method->{name} => sub {
    local $Method = $method;
    local $Method->{args} = [ @_ ];
    local $Method->{result};    
    local $Method->{scratch};
    # Strange but true: you can local a hash-value in hash that's not 
    # a package variable. Confirmed in in 5.004, 5.005, 5.6.0.

    local $Method->{wantarray} = wantarray;

    if ( my $subs = $Method->{"pre_rules"} ) {
      foreach my $sub ( @$subs ) {
	&$sub( @{$Method->{args}}, $Method );
      }
    }
    
    my $subs = $Method->{"do_rules"} 
	or Carp::confess("No operations provided for $Method->{name}");
    if ( ! defined $Method->{wantarray} ) {
      foreach my $sub ( @$subs ) {
	last if $Method->{result};
	&$sub( @{$Method->{args}}, $Method );	
      }
    } elsif ( ! $Method->{wantarray} ) {
      foreach my $sub ( @$subs ) {
	last if $Method->{result};
	my $value = &$sub( @{$Method->{args}}, $Method );
	if ( defined $value ) { 
	  $Method->{result} = \$value;
	}
      }
    } else {
      foreach my $sub ( @$subs ) {
	last if $Method->{result};
	my @value = &$sub( @{$Method->{args}}, $Method );
	if ( scalar @value ) { 
	  $Method->{result} = \@value;
	}
      }
    }
    
    if ( my $subs = $Method->{"post_rules"} ) {
      foreach my $sub ( @$subs ) {
	&$sub( @{$Method->{args}}, $Method );
      }
    }
    
    ( ! $Method->{result} ) 	          ? () :
    ( ref($Method->{result}) eq 'ARRAY' ) ? @{$Method->{result}} :  
					    ${$Method->{result}};
  }
}

########################################################################

=head1 SEE ALSO

See L<Class::MakeMethods> for general information about this distribution. 

=cut

1;
