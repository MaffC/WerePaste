package App::WerePaste::Schema::Result::Paste;

use strict;
use warnings;

use base 'DBIx::Class::Core';

__PACKAGE__->table("pastes");
__PACKAGE__->add_columns(
	'id', { data_type => 'text', is_nullable => 0 },
	'ts', { data_type => 'timestamp', default_value => \"current_timestamp", is_nullable => 0 },
	'expiration', { data_type => 'timestamp', is_nullable => 1 },
	'language', { data_type => 'text', is_nullable => 0 },
	'title', { data_type => 'text', is_nullable => 1 },
	'code', { data_type => 'blob', is_nullable => 0 },
	'html', { data_type => 'blob', is_nullable => 1 },
);
__PACKAGE__->set_primary_key('id');

use Dancer2;
__PACKAGE__->load_components(qw/InflateColumn::DateTime/);
__PACKAGE__->add_columns(
	'+ts' => { timezone => config->{tz}, locale => config->{locale} },
	'+expiration' => { timezone => config->{tz}, locale => config->{locale}, formatter => 'DateTime::Formatter::MySQL' }
);

1;
__END__
