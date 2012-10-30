#!/usr/bin/env perl

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

package Model::Estado;

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

package Model::Cidade;

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

package main;

use Mojolicious::Lite;
use Mojo::ByteStream;
use utf8;

helper menu_ativo => sub {
	my ($self, $menu) = @_;
	return ($self->stash('menu') eq $menu) ? Mojo::ByteStream->new(' class="active"') : '';
};


helper redirect_erro => sub {
	my ($self, $caminho, $mensagem) = @_;
	$self->tx->req->method('GET');
	$self->tx->req->url->path($caminho);
	$self->app->defaults(mensagem_erro => $mensagem);
	$self->app->handler($self->tx);
	$self->app->defaults(mensagem_erro => '');	
	$self->rendered;
};

helper redirect_sucesso => sub {
	my ($self, $caminho, $mensagem) = @_;
	$self->tx->req->method('GET');
	$self->tx->req->url->path($caminho);
	$self->app->defaults(mensagem_sucesso => $mensagem);
	$self->app->handler($self->tx);
	$self->app->defaults(mensagem_sucesso => '');	
	$self->rendered;
};

get '/' => sub {
	my $self = shift;
	$self->render('index');
};

get '/estado' => sub {
	my $self = shift;
	$self->render('estado/listar', dados => scalar Model::Estado->find_all);
};

any ['get', 'post'] => '/estado/editar/:sigla' => {sigla => undef} => sub {
	my $self = shift;
	my $acao = undef;
	my $estado = undef;
	if ($self->req->method eq 'GET') {
		my $sigla = $self->param('sigla');

		if (defined($sigla)) {
			$estado = Model::Estado->load(uc $sigla);
			unless (defined($estado)) {
				$self->redirect_erro('/estado', "Estado não encontrado para a sigla '$sigla'.");
				return;
			}
			$acao = 'A';
		} else {
			$estado = Model::Estado->new(sigla => '', nome => '');
			$acao = 'I';
		}

		$self->render('estado/editar', 
			dados => $estado, 
			acao => $acao);
			
	} else { # POST
		$acao = uc $self->req->param('acao');
		my $sigla = uc $self->req->param('sigla');
		my $nome = $self->req->param('nome');
		my $mensagem = undef;

		unless ($mensagem || $acao =~ /^[AI]$/) {
			$mensagem = 'Ação inválida';
		}

		unless ($mensagem || $sigla =~ /^[A-Z]{2}$/) {
			$mensagem = 'Informe a sigla do estado';
		}

		unless ($mensagem || $nome =~ /^\w{2}/) {
			$mensagem = 'Informe o nome do estado';
		}
		
		unless ($mensagem) {
			$estado = Model::Estado->load($sigla);
			if (defined($estado)) {
				if ($acao eq 'I') {
					$mensagem = 'Estado já cadastrado';
				}
			} else {
				if ($acao eq 'A') {
					$mensagem = 'Estado não encontrado';
				}
			}
		}
		
		if ($mensagem) {
			$self->render('estado/editar', 
				dados => Model::Estado->new(sigla => $sigla, nome => $nome), 
				acao => $acao,
				mensagem_erro => $mensagem);
			return;
		} 

		if ($acao eq 'I') {
			Model::Estado->create(sigla => $sigla, 
				nome => $nome);
			$self->redirect_sucesso('/estado', 'Registro incluído com sucesso.');
		} elsif ($acao eq 'A') {
			$estado->nome($nome);
			$estado->update;
			$self->redirect_sucesso('/estado', 'Registro atualizado com sucesso.');
		}
	}
};

get '/estado/excluir/:sigla' => sub {
	my $self = shift;
	my $sigla = uc $self->param('sigla');
	if (Model::Estado->existe_cidade($sigla)) {
		$self->redirect_erro("/estado", "Não é possível excluir o estado '$sigla' porque existe cidade cadastrada.");
	} else {
		my $estado = Model::Estado->load($sigla);
		if ($estado) {
			$estado->delete;
			$self->redirect_sucesso('/estado', 'Registro excluído com sucesso.');
		} else {
			$self->redirect_erro("/estado", "Falha ao excluir o estado '$sigla'.");
		}
	}
};

any ['get', 'post'] => '/cidade' => sub {
	my $self = shift;
	if ($self->req->method eq 'GET') {
		$self->render('cidade/listar', dados => []);
	} else {
		my $pesquisa = $self->req->param('pesquisa');
		my $fitrado = [];
		if ($pesquisa) {
			$fitrado = Model::Cidade->find_by_nome($pesquisa);
		}
		$self->render('cidade/listar', 
			dados => $fitrado, 
			mensagem_erro => (@$fitrado ? undef : 'Nenhuma cidade encontrada para o critério'));
	}
};

any ['get', 'post'] => '/cidade/editar/:id' => [id => qr/\d+/] => {id => undef} => sub {
	my $self = shift;
	my $acao = undef;
	my $cidade = undef;
	if ($self->req->method eq 'GET') {
		my $id = $self->param('id');

		if (defined($id)) {
			$cidade = Model::Cidade->load($id);
			unless (defined($cidade)) {
				$self->redirect_erro('/cidade', 'Cidade não encontrada.');
				return;
			}
			$acao = 'A';
		} else {
			$cidade = Model::Cidade->new(id => '', estado => '', nome => '');
			$acao = 'I';
		}

		$self->render('cidade/editar', 
			estados => scalar Model::Estado->find_all, 
			dados => $cidade, 
			acao => $acao);

	} else { # POST
		$acao = uc($self->req->param('acao'));
		my $id = $self->req->param('id');
		my $estado = $self->req->param('estado'); 
		my $nome = $self->req->param('nome'); 
		my $mensagem = undef;

		unless ($mensagem || $acao =~ /^[AI]$/) {
			$mensagem = 'Ação inválida';
		}
		
		if (!defined($mensagem) && $acao eq 'A' && $id !~ /^\d+$/) {
			$mensagem = 'Id inválido';
		}

		unless ($mensagem ||$estado =~ /^[A-Z]{2}$/) {
			$mensagem = 'Selecione o estado';
		}

		unless ($mensagem || $nome =~ /^\w{2}/) {
			$mensagem = 'Informe o nome da cidade';
		}

		unless ($mensagem || Model::Estado->load($estado)) {
			$mensagem = 'Estado não encontrado';
		}
		
		unless (defined($mensagem)) {
			if (Model::Cidade->existe_no_estado(($acao eq 'I' ? 0 : $id), $estado, $nome)) {
				$mensagem = 'Já existe uma cidade com o mesmo nome este estado.';
			}
		}

		if ($mensagem) {
			$self->render('cidade/editar', 
				estados => scalar Model::Estado->find_all, 
				dados => Model::Cidade->new(id => $id, estado => $estado, nome => $nome), 
				acao => $acao,
				mensagem_erro => $mensagem);
			return;
		}
		
		if ($acao eq 'I') {
			Model::Cidade->create(estado => $estado, 
				nome => $nome);
			$self->redirect_sucesso('/cidade', 'Registro incluído com sucesso.');
		} elsif ($acao eq 'A') {
			$cidade = Model::Cidade->load($id);
			$cidade->estado($estado);
			$cidade->nome($nome);
			$cidade->update;			
			$self->redirect_sucesso('/cidade', 'Registro atualizado com sucesso.');
		}
	}
};	

get '/cidade/excluir/:id' => sub {
	my $self = shift;
	my $id = $self->param('id');
	my $cidade = Model::Cidade->load($id);
	if ($cidade) {
		$cidade->delete;
		$self->redirect_sucesso('/cidade', 'Registro excluído com sucesso.');
	} else {
		$self->redirect_sucesso('/cidade', 'Falha ao excluir a cidade.');
	}	
};

if (exists $ENV{'DATABASE_URL'}) {
	if ($ENV{'DATABASE_URL'} =~ m|postgres://([^:]+):([^@]+)@([^:]+):([^/]+)/(.+)|) {
		$ENV{'DBI_DSN'} = "dbi:Pg:dbname=$5;host=$3;port=$4";
		$ENV{'APP_DB_USER'} = $1;
		$ENV{'APP_DB_PASS'}	= $2;
	}
}

plugin Config => {file => 'app.conf'};

$ENV{'DBI_DSN'} ||= app->config->{database};
$ENV{'APP_DB_USER'} ||= app->config->{user};
$ENV{'APP_DB_PASS'} ||= app->config->{pass};

app->defaults(layout => 'default');
app->defaults(mensagem_erro => '');
app->defaults(mensagem_sucesso => '');
app->secret('sao seus olhos');
app->mode('production');
app->log->level('debug');
app->log->debug('Conectar ao banco "' . $ENV{'DBI_DSN'} . '", com usuario "' . $ENV{'APP_DB_USER'} . '".');
app->log->level('fatal');
app->start;
__DATA__

@@ layouts/default.html.ep
<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="utf-8">
		<title>Sistema de Teste</title>
		<meta name="viewport" content="width=device-width, initial-scale=1.0">

		<!-- Le styles -->
		<link href="http://netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/css/bootstrap-combined.min.css" rel="stylesheet">
		<style>
			body {
				padding-top: 60px; /* 60px to make the container go all the way to the bottom of the topbar */
			}
			
			td.botoes {
				padding-left: 20px
			}
		</style>

		<!-- Le HTML5 shim, for IE6-8 support of HTML5 elements -->
		<!--[if lt IE 9]>
			<script src="http://html5shim.googlecode.com/svn/trunk/html5.js"></script>
		<![endif]-->

	</head>

	<body>

		<div class="navbar navbar-fixed-top">
			<div class="navbar-inner">
				<div class="container">
					<a class="brand" href="/">Sistema de Teste</a>
				</div>
			</div>
		</div>		

		<div class="container">

			<div class="row">
				<div class="span2">
					<ul class="nav nav-pills nav-stacked">
						<li<%= menu_ativo 'estado' %>><a href="/estado" data-togglex="tab">Estado</a></li>
						<li<%= menu_ativo 'cidade' %>><a href="/cidade" data-togglex="tab">Cidade</a></li>
					</ul>
				</div>
				<div class="span8">
					% if ($mensagem_erro) {
						<div class="alert alert-error">
							<button class="close" data-dismiss="alert">×</button>
							%= $mensagem_erro
						</div>
					% }
					% if ($mensagem_sucesso) {
						<div class="alert alert-success">
							<button class="close" data-dismiss="alert">×</button>
							%= $mensagem_sucesso
						</div>
					% }					
<%= content %>
				</div>
			</div>

		</div>

		<!-- Le javascript
		================================================== -->
		<!-- Placed at the end of the document so the pages load faster -->
		<script src="http://code.jquery.com/jquery-1.8.0.min.js"></script>
		<script src="http://netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/js/bootstrap.min.js"></script>

	</body>
</html>

@@ index.html.ep
% stash menu => '';
<h1>Bem-vindo ao sistema de teste</h1>

@@ estado/listar.html.ep
% stash menu => 'estado';
<p>Lista com os estados cadastrados</p>
<table class="table table-striped table-condensed">
	<thead>
		<tr>
			<th class="span1"></th>
			<th class="span1">Sigla</th>
			<th class="span6">Nome</th>
		</tr>
	</thead>
	<tbody>
		% for my $estado (@$dados) {
		<tr>
			<td class="botoes"><a href="/estado/editar/<%= $estado->sigla %>"><i class="icon-edit"></i></a></td>
			<td><%= $estado->sigla %></a></td>
			<td><%= $estado->nome %></td>
		</tr>
		% }
	</tbody>
</table>
<a href="/estado/editar" class="btn btn-primary">Novo</a>

@@ estado/editar.html.ep
% stash menu => 'estado';
% if ($acao eq 'A') {
	<h3>Editar Estado</h3> 
% } else {
	<h3>Novo Estado</h3> 
% }
<form class="form-vertical" method="POST">
	%= hidden_field acao => $acao
	<div class="control-group">
		<label class="control-label" for="sigla">Sigla:</label>
		<div class="controls">
			% if ($acao eq 'A') {
				%= hidden_field sigla => $dados->sigla
				<strong><%= $dados->sigla%></strong> 
			% } else {
				<input type="text" class="input-mini" id="sigla" name="sigla" value="<%= $dados->sigla %>">
			% }
		</div>
	</div>
	<div class="control-group">
		<label class="control-label" for="nome">Nome: </label>
		<div class="controls">
			<input type="text" class="input-xlarge" id="nome" name="nome" value="<%= $dados->nome %>">
		</div>
	</div>
	<div class="form-actions">
		<button type="submit" class="btn btn-primary">Salvar</button>
% if ($acao eq 'A') {
		<a href="/estado/excluir/<%= $dados->sigla%>" onclick="$('#myModal').modal('show'); return false;" class="btn btn-danger">Excluir</a>
% }
	</div>	
	<div class="modal hide" id="myModal">
		<div class="modal-header">
			<button type="button" class="close" data-dismiss="modal">×</button>
			<h3>Excluir Estado</h3>
		</div>
		<div class="modal-body">
			<p>Confirma a exclusão do estado?</p>
		</div>
		<div class="modal-footer">
			<a href="#" class="btn btn-primary" data-dismiss="modal">Cancelar</a>
			<a href="/estado/excluir/<%= $dados->sigla%>" class="btn btn-danger">Excluir</a>
		</div>
	</div>
</form>

@@ cidade/listar.html.ep
% stash menu => 'cidade';
<form class="well form-search" method="POST" action="/cidade">
	<input type="text" class="input-medium search-query" id="pesquisa" name="pesquisa" value="<%= param('pesquisa') %>">
	<button type="submit" class="btn">Buscar</button>
</form>
% if (@$dados) {
<p>Lista com as cidades cadastradas</p>
<table class="table table-striped table-condensed">
	<thead>
		<tr>
			<th class="span1"></th>
			<th class="span2">Estado</th>
			<th class="span5">Nome</th>
		</tr>
	</thead>
	<tbody>
		% for my $cidade (@$dados) {
		<tr>
			<td class="botoes"><a href="/cidade/editar/<%= $cidade->id %>"><i class="icon-edit"></i></a></td>
			<td><%= $cidade->estado %></td>
			<td><%= $cidade->nome %></td>
		</tr>
		% }
	</tbody>
</table>
% }
<a href="/cidade/editar" class="btn btn-primary">Nova</a>

@@ cidade/editar.html.ep
% stash menu => 'cidade';
% if ($acao eq 'A') {
	<h3>Editar Cidade</h3> 
% } else {
	<h3>Nova Cidade</h3> 
% }
<form class="form-vertical" method="POST">
	%= hidden_field acao => $acao
	%= hidden_field id => $dados->id
	<div class="control-group">
		<label class="control-label" for="sigla">Estado:</label>
		<div class="controls">
			<select id="estado" name="estado">
				<option value=""></option>
				% for (@$estados) {
					<option value="<%= $_->sigla %>"<%= $_->sigla eq $dados->estado ? ' selected' : '' %>><%= $_->nome %></option>
				% }
			</select>
		</div>
	</div>
	<div class="control-group">
		<label class="control-label" for="nome">Nome: </label>
		<div class="controls">
			<input type="text" class="input-xlarge" id="nome" name="nome" value="<%= $dados->nome %>">
		</div>
	</div>
	<div class="form-actions">
		<button type="submit" class="btn btn-primary">Salvar</button>
% if ($acao eq 'A') {
		<a href="/cidade/excluir/<%= $dados->id %>" onclick="$('#myModal').modal('show'); return false;" class="btn btn-danger">Excluir</a>
% }
	</div>	
	<div class="modal hide" id="myModal">
		<div class="modal-header">
			<button type="button" class="close" data-dismiss="modal">×</button>
			<h3>Excluir Cidade</h3>
		</div>
		<div class="modal-body">
			<p>Confirma a exclusão da cidade?</p>
		</div>
		<div class="modal-footer">
			<a href="#" class="btn btn-primary" data-dismiss="modal">Cancelar</a>
			<a href="/cidade/excluir/<%= $dados->id %>" class="btn btn-danger">Excluir</a>
		</div>
	</div>
</form>
