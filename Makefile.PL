use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'		=> 'Class::MakeMethods',
    'VERSION_FROM'	=> 'MakeMethods.pm', 
    'PREREQ_PM'		=> {}, 
    ($] >= 5.005 ? (
      ABSTRACT_FROM     => 'MakeMethods.pm', 
      AUTHOR            => 'Matthew Simon Cavalletto <simonm@cavalletto.org>',
    ) : ()),
    test                => { 'TESTS' => 't/*/*.t', },
);
sub MY::postamble { q{

cleanmanifest:
	make realclean; rm MANIFEST ; perl Makefile.PL; touch MANIFEST; make manifest

docs : README docs/MANUAL docs/CATALOG docs/EXAMPLES docs/CHANGES docs/TODO

docs/MANUAL: MakeMethods.pm
	pod2text MakeMethods.pm > docs/MANUAL

docs/CATALOG: MakeMethods/Docs/Catalog.pod
	pod2text MakeMethods/Docs/Catalog.pod > docs/CATALOG

docs/EXAMPLES: MakeMethods/Docs/Examples.pod
	pod2text MakeMethods/Docs/Examples.pod > docs/EXAMPLES

docs/CHANGES: MakeMethods/Docs/Changes.pod
	pod2text MakeMethods/Docs/Changes.pod > docs/CHANGES

README: MakeMethods/Docs/ReadMe.pod
	pod2text MakeMethods/Docs/ReadMe.pod > README

docs/TODO: MakeMethods/Docs/ToDo.pod
	pod2text MakeMethods/Docs/ToDo.pod > docs/TODO

}; }
