package Model::Cidade;

use Model;
use Model::Estado;
use Mojo::Base -base;

has 'id';
has 'estado';
has 'nome';

sub find_by_nome {
	shift;
	return undef unless (@_);
	my $nome = shift;
	return __PACKAGE__->find_where('where nome like ?', undef, "%$nome%");
}

sub find_where {
	shift;
	my $where = shift; # $
	my $attr = shift; # %
	my $limit = defined($attr->{MaxRows}) ? ' LIMIT ' . $attr->{MaxRows} : '';
	my $sth = Model->dbh->prepare('select id, estado, nome from cidade ' . ($where // ''). ' order by nome' . $limit, $attr);
	$sth->execute(@_);
	my @rows;
  while (my ($id, $estado, $nome) = $sth->fetchrow_array) {
      push @rows, __PACKAGE__->new(
				'id' => $id, 
				'estado' => $estado, 
				'nome' => $nome);
  }
  wantarray ? @rows : \@rows;
}

sub load {				
	shift;
	return undef unless (@_);
	my @rows = __PACKAGE__->find_where(' where id = ? ', {MaxRows => 1}, @_);
	return shift @rows;
}

sub update {
	my $self = shift;
	my $sth = Model->dbh->prepare('update cidade set estado = ?, nome = ? where id = ?');
	$sth->execute($self->estado, $self->nome, $self->id);
	$sth->finish;
}

sub delete {
	my $self = shift;
	my $sth = Model->dbh->prepare('delete from cidade where id = ?');
	$sth->execute($self->id);
	$sth->finish;
}

sub create {
	shift;
	my $self = __PACKAGE__->new(@_);
	my $dbh = Model->dbh;
	my $sth = $dbh->prepare('insert into cidade (estado, nome) values (?, ?)');
	$sth->execute($self->estado, $self->nome);
	__PACKAGE__->id($dbh->last_insert_id(undef,undef,"cidade",undef));
	$sth->finish;
	$self;
}

sub existe_no_estado {
	shift;
	my @rows = __PACKAGE__->find_where('where id <> ? and estado = ? and nome = ?', {MaxRows => 1}, @_);
	return shift @rows;
}

1;
