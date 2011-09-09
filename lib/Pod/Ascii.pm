package Pod::Ascii;
use 5.008001;  # We need stable UTF-8
use strict;
use warnings qw< FATAL utf8 >;

use Carp ();
use Encode ();
use Unicode::Normalize();

use Pod::Escapes ();

use Exporter 'import';
our @EXPORT    = qw< pod2ascii >;
#our @EXPORT_OK = qw< pod2ascii >;


# TODO in tests: check that scalar(keys %ESCAPE_NAME) == scalar(%Pod::Escapes::Name2character)
my %ESCAPE_NAME = reverse %Pod::Escapes::Name2character;


my $ENCODING = 'ascii';



sub input($)
{
    open my $in, '<:bytes', $_[0]
        or do {
            require Carp;
            Carp::croak("Can't open $_[0]: $!");
        };
    return $in
}

sub output($)
{
    open my $out, '>:bytes', $_[0]
        or do {
            require Carp;
            Carp::croak("Can't open $_[0]: $!");
        };
    return $out
}

sub pod2ascii
{
    my %opt = ref $_[0] eq 'HASH' ? %{+shift} : ();
    my ($in, $out) = @_;
    if (ref $in eq '') {
        my $name = $in;
        open( ($in = undef), '<:bytes', $name)
            or do {
                require Carp;
                Carp::croak("Can't open $name: $!");
            };
    } elsif (!defined $in) {
        require Carp;
        Carp::croak("Can't read input: missing filename or GLOB");
    } elsif (ref $in eq 'SCALAR' && utf8::is_utf8($$in)) {
        $in = \( utf8::decode($$in) );
    } else {
        #binmode($in, ':bytes');
    }
    my $out_str;
    if (ref $out eq '') {
        my $name = $out;
        open( ($out = undef), '>:bytes', $name);
    } elsif (!defined $out) {
        open $out, '>:bytes', \$out_str;
    } else {
        binmode($out, ':bytes');
    }

    my $in_pod = 0;
    my $encoding = 'latin1'; # Default 8 bit encoding

    # FIXME handle BOM

LINE: while (<$in>) {	
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
            $_ = <$in>;
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
        #$content .= $_;
        print $out $_;
    }
    close $in;

    return $out_str if defined $out_str
}


1;
__END__

=head1 NAME

Pod::Ascii - Process POD content to replace 8bits chars with pure ASCII escapes

=head1 SYNOPSIS

    use Pod::Ascii;

    $out_bytes = pod2ascii($in_file);
    $out_bytes = pod2ascii($in_bytes);
    $out_bytes = pod2ascii(\$in_bytes);
    $out_bytes = pod2ascii(*IN);
    pod2ascii($in_file, $out_file);
    pod2ascii(\$in_bytes, \$out_bytes);
    pod2ascii(\$in_bytes, $out_file);
    pod2ascii(*IN, *OUT);

=head1 DESCRIPTION

I<B<Note:> This distribution also includes the L<pod2ascii> command-line tool.>

This module converts POD content to make it (almost) pure ASCII. Non-POD content
(such as Perl code) is not touched.

=head1 FUNCTIONS

=head2 C<pod2ascii(I<in>, I<out>)>

Convert POD content.

Input and output can be:

=over 4

=item *

a filename

=item *

a GLOB (an opened file handle)

=item *

a SCALAR ref, for byte string input

=back

Do not use the same file/stream/scalar for input and output or bad things may
happen.

=head1 CAVEATS

=over 4

=item 1.

Non-ASCII bytes in verbatim text is not touched as they can not be replaced
with EE<lt>E<gt> sequences.

=item 2.

C<=encoding> lines are removed during processing. This I<may> be a problem for
some documents (see the first caveat).

=item 3.

Escape sequences are expanded, an NFC Unicode nomalization (see
L<Unicode::Normalize>) is applied, and
escapes are rebuilt. So this I<may> change existing escapes: for example,
replacing numeric escapes with named ones or changing Unicode codepoints.

=back

=head1 BUGS

=over 4

=item *

End-of-line style is not preserved on Windows: output always use CRLF. That
I<may> break the Perl code in which the POD is embedded.

=item *

Byte-order marks (BOM) are not yet handled.

=back

=head1 SEE ALSO

L<pod2ascii>, the command-line script

=head1 AUTHOR

Olivier MenguE<eacute>, L<mailto:dolmen@cpan.org>

=head1 COPYRIGHT & LICENSE

Copyright E<copy> 2011 Olivier MenguE<eacute>.

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl 5 itself.

=cut

# vim: set et sts=4 sw=4 :
