package App::WerePaste;

use strict;
use warnings;

use App::WerePaste::Util::PygmentsBridge qw/:all/;
use Dancer2;
use Dancer2::Plugin::DBIC qw/schema/;
use DateTime;
use Data::UUID;

my $lastexpunge = 0;

sub DeploySchema {
	# need to find a way to handle this that doesn't shit errors everywhere
	eval {schema->deploy};
}
sub DateTimeToQueryable {
	my $dt = DateTime->now(time_zone => config->{tz});
	$dt->add(@_) if scalar @_;
	return schema->storage->datetime_parser->format_datetime($dt);
}
sub ExpirationToDate {
	my $expire = shift;
	$expire = $expire ? { split ':', $expire } : undef;
	return undef if $expire and $expire->{never};
	return DateTimeToQueryable(%{ $expire || config->{default_expire} });
}
sub GetUUID {
	my $uuid = Data::UUID->new->create_str;
	$uuid =~ s/\-//g;
	return lc $uuid;
}
sub CheckExpired {
	return unless time > ($lastexpunge+900); #expunge once every 15 mins
	$lastexpunge = time;
	schema->resultset('Paste')->search({ expiration => [undef, { '<' => DateTimeToQueryable() }]})->delete_all;
}
sub ValidateParams {
	my $params = shift;
	if($params->{id}) {
		return undef unless lc($params->{id}) =~ /^[a-f0-9]*$/;
		return 1;
	}
	return undef unless $params->{code};
	return undef unless $params->{title} =~ /^[a-zA-Z0-9\.\-_ @\(\)]{0,255}$/;
	return undef unless $params->{lang} =~ /^[a-z0-9\.\-\+# ]{0,40}$/;
	return undef unless $params->{expiration} =~ /^([a-z]+:[0-9]+)(,[a-z]+:[0-9]+)*$/ or not $params->{expiration};
	return 1;
}
sub GetPaste {
	my $id = shift;
	return schema->resultset('Paste')->single({ id => $id }) or return undef;
}
sub SubmitPaste {
	my $params = shift;
	my ($lang,$html) = PygmentsHighlight(lang => $params->{lang}, code => $params->{code});
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
sub ValidateAndGet {
	my $params = shift;
	ValidateParams($params) or return undef;
	return GetPaste(lc $params->{id}) or return undef;
}

# Startup
DeploySchema();
# Hooks
hook 'before'    => sub { CheckExpired(); };
# Routes
#get
get  '/'         => sub { template 'index.tt'; };
get  '/:id'      => sub { my $paste=ValidateAndGet(scalar params('route')) or pass; template 'show.tt', { paste => $paste };};
get  '/:id/copy' => sub { my $paste=ValidateAndGet(scalar params('route')) or pass; template 'index.tt', { paste => $paste }; };
get  '/:id/raw'  => sub { my $paste=ValidateAndGet(scalar params('route')) or pass; content_type 'text/plain'; return $paste->code; };
#post
post '/'         => sub {
	my $p = params('body');
	ValidateParams($p) or return send_error('Submitted paste is not valid. Check your post title and language, and try again.',400);
	my $id = SubmitPaste($p) or return redirect '/503.html';
	return redirect "/$id";
};
#default
any  qr/.*/      => sub { return send_error('Page gone',404); };

1;
__END__
