package App::WerePaste;

use strict;
use warnings;

use App::WerePaste::Util::PygmentsBridge qw/:all/;
use Dancer2;
use Dancer2::Plugin::DBIC qw/schema/;
use DateTime;
use Data::UUID;

# Application startup
sub DeploySchema {
	# we override sigwarn to prevent warnings from showing up when the schema has previously been deployed
	# TODO: find a way to mute only the deploy warning here, should any other warnings somehow arise
	local $SIG{__WARN__} = sub {};
	eval { schema->deploy; };
}

# Data transformation
sub DateTimeToQueryable {
	my $dt = DateTime->now(time_zone => config->{tz});
	$dt->add(@_) if scalar @_;
	return schema->storage->datetime_parser->format_datetime($dt);
}
sub ExpirationToDate {
	my $expire = shift;
	$expire = $expire ? { split ':', $expire } : config->{expiration};
	return undef if $expire and $expire->{never};
	return DateTimeToQueryable(%{ $expire });
}

# Data generation
sub GetUUID {
	my $uuid = Data::UUID->new->create_str;
	$uuid =~ s/\-//g;
	return lc $uuid;
}

# Data removal
my $nextexpunge = 0;
sub CheckExpiry {
	return unless time > $nextexpunge;
	$nextexpunge = time+15;
	schema->resultset('Paste')->search( {
		expiration => { '<' => DateTimeToQueryable() }
	} )->delete_all;
}

# Data validation
sub ValidateParams {
	my $params = shift;
	return undef unless $params->{code};
	#TODO: Allow all 'word' characters rather than just a-zA-Z0-9 and limited grammar
	## Presently this is limited so people can't do anything nasty.
	return undef unless $params->{title} =~ /^[a-zA-Z0-9\.\-_ @\(\)]{0,255}$/;
	return undef unless $params->{lang} =~ /^[a-z0-9\.\-\+# ]{0,40}$/;
	return undef unless $params->{expiration} =~ /^([a-z]+:[0-9]+)(:[a-z]+:[0-9]+)*$/ or not $params->{expiration};
	return 1;
}

# Data retrieval
sub GetPaste {
	my $params = shift;
	my $id = lc $params->{id};
	return undef unless $id =~ /^[a-f0-9]*$/;
	return schema->resultset('Paste')->single( { id => $id } );
}
sub PresentPaste {
	my $params = shift; my $tt = shift;
	my $paste = GetPaste($params) or return undef;
	content_type 'text/plain' and return $paste->code unless $tt;
	return template "$tt.tt", { paste => $paste };
}

# Data storage
sub StorePaste {
	my $params = shift;
	my ($lang,$html) = PygmentsHighlight(lang => $params->{lang}, code => $params->{code});
	#TODO: maybe figure out a nicer way of doing this, presently the UUID namespace changes with every app start
	my $id = GetUUID();
	my $result = schema->resultset('Paste')->create({
		id => $id,
		title => $params->{title},
		language => $lang,
		expiration => ExpirationToDate($params->{expiration}),
		code => $params->{code},
		html => $html,
	}) or return undef;
	return $id;
}
sub ReceivePaste {
	my $params = shift;
	return send_error('Submitted paste is not valid. Check your post title and language, and try again.', 400)
		unless ValidateParams $params;
	return send_error('Unfortunately, the paste could not be saved.', 503)
		unless my $id = StorePaste $params;
	return redirect "/$id";
}

# Startup
DeploySchema;

# Hooks
hook 'before'    => sub { CheckExpiry; };

# Routes
get  '/'         => sub { template 'index.tt'; };
get  '/:id'      => sub { return PresentPaste scalar(params 'route'), 'show'  || pass; };
get  '/:id/copy' => sub { return PresentPaste scalar(params 'route'), 'index' || pass; };
get  '/:id/raw'  => sub { return PresentPaste scalar params 'route'           || pass; };

#post
post '/'         => sub { return ReceivePaste scalar params 'body'; };

# Default catch-all route
any  qr/.*/      => sub { return send_error('What you seek cannot be found here.', 404); };

1;
__END__
