package Teste::Estado;
use Mojo::Base 'Mojolicious::Controller';
use Model::Estado;
use utf8;

sub listar {
	my $self = shift;
	$self->render(dados => scalar Model::Estado->find_all);
}

sub editar {
	my $self = shift;
	my $acao = undef;
	my $estado = undef;
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
}

sub salvar {
	my $self = shift;
	my $estado = undef;

	my $acao = uc $self->req->param('acao');
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

sub excluir {
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
}

1;
