use ExtUtils::MakeMaker;
WriteMakefile(
  'NAME'	=> 'Class::MakeMethods',
  VERSION	=> "1.0.14",
  PREREQ_PM	=> {},
);
sub MY::postamble { q{

docs : README CHANGES TODO GUIDE

README: MakeMethods/ReadMe.pod
	pod2text MakeMethods/ReadMe.pod > README

CHANGES: MakeMethods/Changes.pod
	pod2text MakeMethods/Changes.pod > CHANGES

TODO: MakeMethods/ToDo.pod
	pod2text MakeMethods/ToDo.pod > TODO

GUIDE: MakeMethods/Guide.pod
	pod2text MakeMethods/Guide.pod > GUIDE

}; }
