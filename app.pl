#!/usr/bin/env perl
use Mojolicious::Lite;
use Mojo::ByteStream;
use utf8;

use ORLite 1.96 {
	package => 'Model',
	file => 'dados.db',
	create => sub {
		my $dbh = shift;
		$dbh->do('CREATE TABLE estado (
			sigla CHAR(2) PRIMARY KEY NOT NULL,
			nome VARCHAR(100) NOT NULL)');
		$dbh->do('CREATE TABLE cidade (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			estado CHAR(2) NOT NULL REFERENCES estado (sigla),
			nome VARCHAR(100) NOT NULL)');
	}
};
							 
# Documentation browser under "/perldoc"
plugin 'PODRenderer';

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
	$self->render('estado/listar', dados => scalar Model::Estado->select('order by sigla'));
};

any ['get', 'post'] => '/estado/editar/:sigla' => {sigla => undef} => sub {
	my $self = shift;
	my $acao = undef;
	my $estado = undef;
	if ($self->req->method eq 'GET') {
		my $sigla = $self->param('sigla');

		if (defined($sigla)) {
			$estado = shift @{Model::Estado->select('where sigla = ?', uc $sigla)};
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
			if (Model::Estado->count('where sigla = ?', $sigla)) {
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

		utf8::decode($nome);
		if ($acao eq 'I') {
			Model::Estado->create(sigla => $sigla, 
				nome => $nome);
			$self->redirect_sucesso('/estado', 'Registro incluído com sucesso.');
		} elsif ($acao eq 'A') {
			Model->do('update estado set nome = ? where sigla = ?', {}, $nome, $sigla);
			$self->redirect_sucesso('/estado', 'Registro atualizado com sucesso.');
		}
	}
};

get '/estado/excluir/:sigla' => sub {
	my $self = shift;
	my $sigla = $self->param('sigla');
	if (Model::Cidade->count('where estado = ?', $sigla)) {
		$self->redirect_erro("/estado", "Não é possível excluir o estado '$sigla' porque existem cidades cadastradas.");
	} else {
		if (Model::Estado->delete_where('sigla = ?', $sigla)) {
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
			$fitrado = Model::Cidade->select('where nome like ?', "%$pesquisa%");
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
			$cidade = shift @{Model::Cidade->select('where id = ?', $id)};
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
			estados => scalar Model::Estado->select('order by sigla'), 
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

		unless ($mensagem || Model::Estado->count('where sigla = ?', $estado)) {
			$mensagem = 'Estado não encontrado';
		}
		
		utf8::decode($nome);
		
		unless (defined($mensagem)) {
			if (Model::Cidade->count('where id <> ? and estado = ? and nome = ?', ($acao eq 'I' ? 0 : $id), $estado, $nome)) {
				$mensagem = 'Já existe uma cidade com o mesmo nome este estado.';
			}
		}

		if ($mensagem) {
			$self->render('cidade/editar', 
				estados => scalar Model::Estado->select('order by sigla'), 
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
			Model->do('update cidade set nome = ?, estado = ? where id = ?', {}, $nome, $estado, $id);
			$self->redirect_sucesso('/cidade', 'Registro atualizado com sucesso.');
		}
	}
};	

get '/cidade/excluir/:id' => sub {
	my $self = shift;
	my $id = $self->param('id');
	if (Model::Cidade->delete_where('id = ?', $id)) {
		$self->redirect_sucesso('/cidade', 'Registro excluído com sucesso.');
	} else {
		$self->redirect_sucesso('/cidade', 'Falha ao excluir a cidade.');
	}	
};
		
app->defaults(layout => 'default');
app->defaults(mensagem_erro => '');
app->defaults(mensagem_sucesso => '');
app->secret('sao seus olhos');
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
			<td><%= $cidade->estado->nome %></td>
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
					<option value="<%= $_->sigla %>"<%= $_->sigla eq ($acao eq 'A' ? $dados->estado->sigla : '') ? ' selected' : '' %>><%= $_->nome %></option>
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
