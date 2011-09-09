use utf8;
use strict;
use warnings qw< FATAL utf8 >;
use Test::More tests => 2;

my $s = "Pâques";
is length($s), 6;
open my $f, '<:bytes', \$s;
my $p = <$f>;
is length($p), 7;
