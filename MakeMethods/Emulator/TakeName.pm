package Class::MakeMethods::Emulator::TakeName;

$VERSION = 1.000_001;

@EXPORT_OK = qw( namespace_capture namespace_release );
sub import { require Exporter and goto &Exporter::import } # lazy Exporter

########################################################################
### NAMESPACE MUNGING: _namespace_capture(), _namespace_release()
########################################################################

sub namespace_capture {
  my $source_package = shift;
  my $target_package = shift;
  
  my $source_file = "$source_package.pm";
  $source_file =~ s{::}{/}g;
  
  my $target_file = "$target_package.pm";
  $target_file =~ s{::}{/}g;
  
  my $temp_package = $source_package . '::Target::' . $target_package;
  my $temp_file = "$temp_package.pm";
  $temp_file =~ s{::}{/}g;
  
  no strict;
  unless ( ${$temp_package . "::TargetCaptured"} ++ ) {
    *{$temp_package . "::"} = *{$target_package . "::"};
    $::INC{$temp_file} = $::INC{$target_file};
  }
  *{$target_package . "::"} = *{$source_package . "::"};
  $::INC{$target_file} = $::INC{$source_file}
}

sub namespace_release {
  my $source_package = shift;
  my $target_package = shift;
  
  my $target_file = "$target_package.pm";
  $target_file =~ s{::}{/}g;
  
  my $temp_package = $source_package . '::Target::' . $target_package;
  my $temp_file = "$temp_package.pm";
  $temp_file =~ s{::}{/}g;
  
  no strict;
  unless ( ${"${temp_package}::TargetCaptured"} ) {
    Carp::croak("Can't _namespace_release: -take_namespace not called yet.");
  }
  *{$target_package . "::"} = *{$temp_package. "::"};
  $::INC{$target_file} = $::INC{$temp_file};
}

1;
