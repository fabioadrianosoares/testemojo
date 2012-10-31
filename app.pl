#!/usr/bin/env perl

use Mojo::Base -strict;
use Mojolicious::Commands;

use File::Basename 'dirname';
use File::Spec;

push @INC, dirname(__FILE__) . '/lib';

if (exists $ENV{'DATABASE_URL'}) {
	if ($ENV{'DATABASE_URL'} =~ m|postgres://([^:]+):([^@]+)@([^:]+):([^/]+)/(.+)|) {
		$ENV{'DBI_DSN'} = "dbi:Pg:dbname=$5;host=$3;port=$4";
		$ENV{'APP_DB_USER'} = $1;
		$ENV{'APP_DB_PASS'}	= $2;
	}
}

$ENV{MOJO_APP} = 'Teste';

Mojolicious::Commands->start;
