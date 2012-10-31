package Teste::Cidade;
use Mojo::Base 'Mojolicious::Controller';
use Model::Cidade;
use utf8;

sub listar {
	my $self = shift;
	if ($self->req->method eq 'GET') {
		$self->render(dados => []);
	} else {
		my $pesquisa = $self->req->param('pesquisa');
		my $fitrado = [];
		if ($pesquisa) {
			$fitrado = Model::Cidade->find_by_nome($pesquisa);
		}
		$self->render(dados => $fitrado, 
			mensagem_erro => (@$fitrado ? undef : 'Nenhuma cidade encontrada para o critério'));
	}
}

sub editar {
	my $self = shift;
	my $acao = undef;
	my $cidade = undef;
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

	$self->render(estados => scalar Model::Estado->find_all, 
		dados => $cidade, 
		acao => $acao);	
}

sub salvar {
	my $self = shift;
	my $cidade = undef;

	my $acao = uc($self->req->param('acao'));
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

sub excluir {
	my $self = shift;
	my $id = $self->param('id');
	my $cidade = Model::Cidade->load($id);
	if ($cidade) {
		$cidade->delete;
		$self->redirect_sucesso('/cidade', 'Registro excluído com sucesso.');
	} else {
		$self->redirect_sucesso('/cidade', 'Falha ao excluir a cidade.');
	}
}

1;
