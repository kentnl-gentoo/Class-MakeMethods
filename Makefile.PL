use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'		=> 'Class::MakeMethods',
    'VERSION_FROM'	=> 'MakeMethods.pm', 
    'PREREQ_PM'		=> {
    }, 
    ($] >= 5.005 ? (
      ABSTRACT_FROM => 'MakeMethods.pm', 
      AUTHOR     => 'Matthew Simon Cavalletto <simonm@cavalletto.org>',
    ) : ()),
);
sub MY::postamble { q{

docs : README CHANGES TODO

README: MakeMethods/ReadMe.pod
	pod2text MakeMethods/ReadMe.pod > README

CHANGES: MakeMethods/Changes.pod
	pod2text MakeMethods/Changes.pod > CHANGES

TODO: MakeMethods/ToDo.pod
	pod2text MakeMethods/ToDo.pod > TODO

GUIDE: MakeMethods/Guide.pod
	pod2text MakeMethods/Guide.pod > GUIDE

cleanmanifest:
	rm MANIFEST ; touch MANIFEST; make manifest

}; }
