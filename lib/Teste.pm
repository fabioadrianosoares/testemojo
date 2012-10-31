package Teste;
use Mojo::Base 'Mojolicious';

sub startup {
  my $self = shift;

	$self->plugin('Config', {file => 'app.conf'});
	$self->plugin('RedirectHelper');
	$self->plugin('MenuAtivoHelper');

	$ENV{'DBI_DSN'} ||= $self->config->{database};
	$ENV{'APP_DB_USER'} ||= $self->config->{user};
	$ENV{'APP_DB_PASS'} ||= $self->config->{pass};

	$self->defaults(layout => 'default');
	$self->defaults(mensagem_erro => '');
	$self->defaults(mensagem_sucesso => '');
	$self->secret('sao seus olhos');
	$self->mode('production');
	$self->log->level('debug');
	$self->log->debug('Conectar ao banco "' . $ENV{'DBI_DSN'} . '", com usuario "' . $ENV{'APP_DB_USER'} . '".');
	$self->log->level('fatal');
	
	my $r = $self->routes;

	my $estado = $r->route('/estado');
	$estado->route('/')->to('estado#listar');
	$estado->route('/editar/:sigla')->via('GET')->to('estado#editar', sigla => undef);
	$estado->route('/editar/:sigla')->via('POST')->to('estado#salvar', sigla => undef);
	$estado->route('/excluir/:sigla')->via('GET')->to('estado#excluir');
	
	my $cidade = $r->route('/cidade');
	$cidade->route('/')->to('cidade#listar');
	$cidade->route('/editar/:id', id => qr/\d+/)->via('GET')->to('cidade#editar', id => undef);
	$cidade->route('/editar/:id', id => qr/\d+/)->via('POST')->to('cidade#salvar', id => undef);
	$cidade->route('/excluir/:id', id => qr/\d+/)->via('GET')->to('cidade#excluir');

	$r->route('/')->to(cb => sub {$_[0]->render('index/index')});
}

1;
