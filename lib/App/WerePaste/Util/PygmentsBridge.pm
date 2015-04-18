package App::WerePaste::Util::PygmentsBridge;

use strict;
use Exporter;
use vars qw/$VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS/;

use Carp;

use Encode qw/decode_utf8/;
use Try::Tiny;

use Inline Python => <<'END_INLINE_PYTHON';
from pygments import highlight
from pygments.lexers import guess_lexer, get_lexer_by_name
from pygments.formatters import HtmlFormatter

def py_highlight(c,l):
	return highlight(c,l,HtmlFormatter(anchorlinenos=True,lineanchors="L",linespans="L",encoding="utf-8"))

def py_guesslexer(c):
	return guess_lexer(c,encoding="utf-8")

def py_getlexer(l):
	return get_lexer_by_name(l,encoding="utf-8")

def py_getnamefromlexer(l):
	return l.name

END_INLINE_PYTHON

$VERSION = 1.0.0;
@ISA = qw/Exporter/;
@EXPORT = qw//;
@EXPORT_OK = qw/PygmentsHighlight/;
%EXPORT_TAGS = (all => [@EXPORT_OK]);

sub PygmentsHighlight {
	my (%params) = @_;
	return unless $params{code};
	my $lexer;
	try {
		$lexer = py_getlexer($params{lang}) if $params{lang};
	} catch {};
	try {
		$lexer = py_guesslexer($params{code}) unless $lexer;
	} catch {};
	$lexer = py_getlexer('text') unless $lexer;
	return (py_getnamefromlexer($lexer),decode_utf8(py_highlight($params{code},$lexer)));
}

1;
__END__
