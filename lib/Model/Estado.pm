package Model::Estado;

use Model;
use Model::Cidade;

use Mojo::Base -base;

has 'sigla';
has 'nome';

sub find_all {
	return __PACKAGE__->find_where;
}
	
sub find_where {
	shift;
	my $where = shift; # $
	my $attr = shift; # %
	my $limit = defined($attr->{MaxRows}) ? ' LIMIT ' . $attr->{MaxRows} : '';
	my $sth = Model->dbh->prepare('select sigla, nome from estado ' . ($where // ''). ' order by sigla' . $limit, $attr);
	$sth->execute(@_);
	my @rows;
  while (my ($sigla, $nome) = $sth->fetchrow_array) {
      push @rows, __PACKAGE__->new(
				'sigla' => $sigla, 
				'nome' => $nome);
  }
  wantarray ? @rows : \@rows;
}

sub load {				
	shift;
	return undef unless (@_);
	my @rows = __PACKAGE__->find_where(' where sigla = ? ', {MaxRows => 1}, @_);
	return shift @rows;
}

sub update {
	my $self = shift;
	my $sth = Model->dbh->prepare('update estado set nome = ? where sigla = ?');
	$sth->execute($self->nome, $self->sigla);
	$sth->finish;
}

sub delete {
	my $self = shift;
	my $sth = Model->dbh->prepare('delete from estado where sigla = ?');
	$sth->execute($self->sigla);
	$sth->finish;
}

sub create {
	shift;
	my $self = __PACKAGE__->new(@_);
	my $sth = Model->dbh->prepare('insert into estado (sigla, nome) values (?, ?)');
	$sth->execute($self->sigla, $self->nome);
	$sth->finish;
	$self;
}

sub existe_cidade {
	shift;
	return undef unless (@_);
	my @rows = Model::Cidade->find_where(' where estado = ? ', {MaxRows => 1}, @_);
	return shift @rows;
}

1;
