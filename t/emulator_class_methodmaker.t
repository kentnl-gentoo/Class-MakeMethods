use Test;
BEGIN { plan tests => 2 }

use Test::Harness qw(&runtests $verbose); 
$verbose=0; 
@tests =  glob('t/emulator_class_methodmaker/*.t');
ok( $count = scalar @tests ); 
warn "\nRunning $count compatibility tests for Class::MethodMaker; this may take a minute...\n";
ok( runtests @tests );