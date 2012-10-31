package MenuAtivoHelper;
use Mojo::Base 'Mojolicious::Plugin';

sub register {
  my ($self, $app) = @_;

  $app->helper(menu_ativo => 
    sub { 
			my ($self, $menu) = @_;
			return ($self->stash('menu') eq $menu) ? Mojo::ByteStream->new(' class="active"') : '';
    }
  );

}

1;
