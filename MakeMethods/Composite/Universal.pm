=head1 NAME

Class::MakeMethods::Composite::Universal - Composite Method Tricks

=head1 SYNOPSIS

  package MyClass;
  use Class::MakeMethods::Composite::Universal (
    hook => 'init',
  );

  sub new {
    my $package = shift;
    my $self = bless {}, $package;
    $self->init();
    return $self;
  }

  MyClass->
  
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

The Composite::Universal suclass of MakeMethods provides some generally-applicable types of methods based on Class::MakeMethods::Composite.

=cut

package Class::MakeMethods::Composite::Universal;

use strict;
use Class::MakeMethods::Composite '-isasubclass';
use Carp;

########################################################################

=head1 METHOD GENERATOR TYPES

=head2 patch

The patch ruleset generates composites whose core behavior is based on an existing subroutine.

Here's an sample usage:

  sub foo {
    my $count = shift;
    return 'foo' x $count;
  }
  
  Class::MakeMethods::Composite::Universal->make(
    -ForceInstall => 1,
    patch => {
      name => 'foo',
      pre_rules => [
	sub { 
	  my $method = pop @_;
	  if ( ! scalar @_ ) {
	    @{ $method->{args} } = ( 2 );
	  }
	},
	sub { 
	  my $method = pop @_;
	  my $count = shift;
	  if ( $count > 99 ) {
	    Carp::confess "Won't foo '$count' -- that's too many!"
	  }
	},
      ],
      post_rules => [
	sub { 
	  my $method = pop @_;
	  if ( ref $method->{result} eq 'SCALAR' ) {
	    ${ $method->{result} } =~ s/oof/oozle-f/g;
	  } elsif ( ref $method->{result} eq 'ARRAY' ) {
	    map { s/oof/oozle-f/g } @{ $method->{result} };
	  }
	} 
      ],
    },
  );

=cut

use vars qw( %PatchFragments );

sub patch {
  (shift)->_build_composite( \%PatchFragments, @_ );
}

%PatchFragments = (
  '' => [
    '+init' => sub {
	my $method = pop @_;
	my $origin = ( $Class::MethodMaker::CONTEXT{TargetClass} || '' ) . 
			'::' . $method->{name};
	no strict 'refs';
	$method->{patch_original} = *{ $origin }{CODE}
	    or croak "No subroutine $origin() to patch";  
      },
    'do' => sub {
	my $method = pop @_;
	my $sub = $method->{patch_original};
	&$sub( @_ );
      },
  ],
);

=head2 make_patch

A convenient wrapper for C<make()> and the C<patch> method generator.

Provides the '-ForceInstall' flag, which is required to ensure that the patched subroutine replaces the original.

For example, one could add logging to an existing method as follows:

  Class::MakeMethods::Composite::Universal->make_patch(
    -TargetClass => 'SomeClassOverYonder',
    name => 'foo',
    pre_rules => [ 
      sub { my $method = pop; warn "Arguments:", @_ } 
    ]
    post_rules => [ 
      sub { my $method = pop; warn "Result:", $method->{result} } 
    ]
  );

=cut

sub make_patch {
  (shift)->make( -ForceInstall => 1, patch => { @_ } );
}


########################################################################

=head2 hook

External interface is normal; internally calls array of fragments. 
Among other things, this should allow meta-methods to individually
provide "on init" or "on destroy" code.

How do you add to the hook? Pre/post, or arbitrary order?
Ability to remove/replace specifc ones? Assign name? Loop in name order?

  package MyWidget;
  use C::MM::Composite (
    hook => 'init',
  );
  
  sub new {
    my $widget = ...;
    $widget->init();
    return $widget;
  }
  
  MyWidget->_hook_method('init', 
    'post+' => sub { (shift)->{count} ||= 3 },
  );

B<NOTE: THIS METHOD GENERATOR IS INCOMPLETE.> 

The _hook_method interface, or an improvement thereto, needs to be added.

Hook methods should call up the inheritance tree. 

=cut

use vars qw( %HookFragments );

sub hook {
  (shift)->_build_composite( \%HookFragments, @_ );
}

%HookFragments = (
  '' => [
    'do' => sub {
	1
      },
  ],
);

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
