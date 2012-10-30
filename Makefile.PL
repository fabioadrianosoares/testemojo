use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'app.pl',
  VERSION      => '1.0',
  AUTHOR       => 'Fabio Soares <fabioadrianosoares@gmail.com>',
  EXE_FILES    => ['app.pl'],
  PREREQ_PM    => {'Mojolicious' => '2.47', 'DBI' => '1.609', 'DBD::Pg' => '2.16.1' },
  test         => {TESTS => 't/*.t'}
);
