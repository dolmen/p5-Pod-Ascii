#!/usr/bin/perl
# Copyright © 2011 Olivier Mengué
use strict;
use warnings qw< FATAL utf8 >;

use Encode ();
use Unicode::Normalize ();

use Pod::Escapes ();

# TODO in tests: check that scalar(keys %ESCAPE_NAME) == scalar(%Pod::Escapes::Name2character)
my %ESCAPE_NAME = reverse %Pod::Escapes::Name2character;


my $ENCODING = 'ascii';




sub process_file
{
    my $file = shift;
    my $in_pod = 0;
    my $encoding = $ENCODING;
    my $content;

    open my $f, '<:bytes', $file or die;
LINE: while (<$f>) {	
        if (/^=cut\b/) {
            $in_pod = !$in_pod;
        } elsif (/^=(?:pod|head[1-4]|over|back|item|begin|end|for)\b/) {
            $in_pod = 1;
        } elsif (/^=encoding\s+(\S+)/) {
            # Note that we are not too strict about the "only one =encoding"
            # rule as that could be the easy way to fix a broken POD that
            # mixed various encodings: make temporarily a semi-broken POD
            # that specifies the right encoding before 8 bits each block, then
            # pass it to this module to completely fix it.
            $in_pod = 1;
            $encoding = $1;
            # Drop the line
            # Fetch the next one
            $_ = <$f>;
            # Drop it too if it's not empty
            redo LINE unless /^\s*$/;
            next;
        } elsif (!$in_pod) {
            if (/^use\s+utf8;\s*$/ && $encoding eq 'ascii') {
                $encoding = 'utf8';
            } elsif (/^use\s+encoding\b\s*(?:q[wq]?)?(\W)(.*?)\1/) {
                $encoding = $2;
            }
        } else { # $in_pod == 1
            unless (/^\s/) {
                $_ = Encode::decode($encoding, $_) if /[\x80-\xff]/;

                s/E<((?![lg]t>)[^>]+)>/ Pod::Escapes::e2char($1) /ge;

                # NFC normalization helps the ESCAPE_NAME resolving to work
                # better
                $_ = Unicode::Normalize::NFC($_);

                s!([^\x00-\x7f])!'E<'.($ESCAPE_NAME{$1} // sprintf('%u', ord($1))).'>'!ge;

                # Transform back to bytes
                $_ = Encode::encode('ascii', $_);
            }
        }
        $content .= $_;
    }
    close $f;
    #open my $f, '>:bytes
    binmode STDOUT, '>:raw:bytes';
    print $content;

}


process_file($ARGV[0]);
#process_file($_) foreach @ARGV;

# vim: set et sw=4 sts=4:
