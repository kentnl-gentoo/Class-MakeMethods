package Class::MakeMethods::Template::PseudoHash;

require Class::MakeMethods::Template::Array;
@ISA = qw( Class::MakeMethods::Template::Array );

sub generic {
  {
    '-import' => { 'Template::Struct:generic' => '*' },
    'code_expr' => {
      _EMPTY_NEW_INSTANCE_ => 'bless [\%{"$class\::FIELDS"], _SELF_CLASS_',
    },
  }
}

### This package hasn't been completed yet

1;
