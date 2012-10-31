package Model;
use Mojo::Base -strict;
use DBI;

sub user { $ENV{'APP_DB_USER'} }
sub pass { $ENV{'APP_DB_PASS'} }

sub dbh {
	$_[0]->connect;
}

sub connect {
	my $dbh = DBI->connect_cached( undef, $_[0]->user, $_[0]->pass, {
		PrintError => 0,
		RaiseError => 1,
	} );
	$dbh->{pg_enable_utf8} = 1;
	$dbh;
}

sub do {
	shift->dbh->do(\@_);
}

1;
