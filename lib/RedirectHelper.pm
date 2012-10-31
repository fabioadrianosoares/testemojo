package RedirectHelper;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($self, $app) = @_;

	$app->helper(redirect_erro => 
		sub {
			my ($self, $caminho, $mensagem) = @_;
			$self->tx->req->method('GET');
			$self->tx->req->url->path($caminho);
			$self->app->defaults(mensagem_erro => $mensagem);
			$self->app->handler($self->tx);
			$self->app->defaults(mensagem_erro => '');	
			$self->rendered;
		}
	);

	$app->helper(redirect_sucesso => 
		sub {
			my ($self, $caminho, $mensagem) = @_;
			$self->tx->req->method('GET');
			$self->tx->req->url->path($caminho);
			$self->app->defaults(mensagem_sucesso => $mensagem);
			$self->app->handler($self->tx);
			$self->app->defaults(mensagem_sucesso => '');	
			$self->rendered;
		}
	);
}

1;
