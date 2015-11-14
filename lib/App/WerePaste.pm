package App::WerePaste;

use strict;
use warnings;

use App::WerePaste::Util::PygmentsBridge qw/:all/;
use Dancer2;
use Dancer2::Plugin::DBIC qw/schema/;
use DateTime;
use Data::UUID;

my $nextexpunge = 0;

sub DeploySchema {
	# we override sigwarn to prevent warnings from showing up when the schema has previously been deployed
	# TODO: find a way to mute only the deploy warning here, should any other warnings somehow arise
	local $SIG{__WARN__} = sub {};
	eval { schema->deploy; };
}
sub DateTimeToQueryable {
	my $dt = DateTime->now(time_zone => config->{tz});
	$dt->add(@_) if scalar @_;
	return schema->storage->datetime_parser->format_datetime($dt);
}
sub ExpirationToDate {
	my $expire = shift;
	$expire = $expire ? { split ':', $expire } : config->{default_expire};
	return undef if $expire and $expire->{never};
	return DateTimeToQueryable(%{ $expire });
}
sub GetUUID {
	my $uuid = Data::UUID->new->create_str;
	$uuid =~ s/\-//g;
	return lc $uuid;
}
sub CheckExpiry {
	return unless time > $nextexpunge;
	$nextexpunge = time+30;
	schema->resultset('Paste')->search({expiration => { '<' => DateTimeToQueryable() }})->delete_all;
}
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
sub GetPaste {
	my $id = shift; $id = lc $id;
	return undef unless $id =~ /^[a-f0-9]*$/;
	#This got a bit messy, required because otherwise there are scenarios where an expired paste may still be viewed
	my $paste schema->resultset('Paste')->single({ id => $id }) or return undef;
}
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

# Startup
DeploySchema();

# Hooks
hook 'before'    => sub { CheckExpiry(); };
# Routes
#get
get  '/'         => sub { template 'index.tt'; };
get  '/:id'      => sub { my $paste=GetPaste(scalar params 'route') or pass; template 'show.tt',  { paste => $paste }; };
get  '/:id/copy' => sub { my $paste=GetPaste(scalar params 'route') or pass; template 'index.tt', { paste => $paste }; };
get  '/:id/raw'  => sub { my $paste=GetPaste(scalar params 'route') or pass; content_type 'text/plain'; return $paste->code; };
#post
post '/'         => sub {
	my $p = params 'body';
	ValidateParams($p) or return send_error('Submitted paste is not valid. Check your post title and language, and try again.', 400);
	my $id = StorePaste($p) or return redirect '/503.html';
	return redirect "/$id";
};
#default
any  qr/.*/      => sub { return send_error('What you seek cannot be found here.', 404); };

1;
__END__
