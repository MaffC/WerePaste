App::WerePaste
--------------

Perl-based pastebin software, largely a rewrite of Dancebin, using Pygments via Inline::Python for syntax highlighting.

Requirements:

- Dancer2
- Dancer2::Plugin::DBIC
- Data::UUID
- Inline::Python
- Try::Tiny
- DateTime
- DateTime::Format::SQLite
- pip module Pygments

Note to FreeBSD users: When building Inline::Python, you may need to create a symlink from /usr/local/bin/python2.7 to /usr/local/bin/python, as Inline::Python does not, by default, look for any other binary, and no `python` symlink is created when installing python27 from pkg.
