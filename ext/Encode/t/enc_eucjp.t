# $Id: enc_eucjp.t,v 1.4 2003/04/24 17:43:16 dankogai Exp $
# This is the twin of enc_utf8.t .

BEGIN {
    require Config; import Config;
    if ($Config{'extensions'} !~ /\bEncode\b/) {
      print "1..0 # Skip: Encode was not built\n";
      exit 0;
    }
    unless (find PerlIO::Layer 'perlio') {
	print "1..0 # Skip: PerlIO was not built\n";
	exit 0;
    }
    if (ord("A") == 193) {
	print "1..0 # encoding pragma does not support EBCDIC platforms\n";
	exit(0);
    }
    if ($] <= 5.008 and !$Config{perl_patchlevel}){
	print "1..0 # Skip: Perl 5.8.1 or later required\n";
	exit 0;
    }
}

use encoding 'euc-jp';

my @c = (127, 128, 255, 256);

print "1.." . (scalar @c + 1) . "\n";

my @f;

for my $i (0..$#c) {
  no warnings 'pack';
  push @f, "f$i";
  open(F, ">f$i") or die "$0: failed to open 'f$i' for writing: $!";
  binmode(F, ":utf8");
  print F chr($c[$i]);
  print F pack("C" => $c[$i]);
  close F;
}

my $t = 1;

for my $i (0..$#c) {
  open(F, "<f$i") or die "$0: failed to open 'f$i' for reading: $!";
  binmode(F, ":utf8");
  my $c = <F>;
  my $o = ord($c);
  print $o == $c[$i] ? "ok $t - utf8 I/O $c[$i]\n" : "not ok $t - utf8 I/O $c[$i]: $o != $c[$i]\n";
  $t++;
}

my $f = "f" . @f;

push @f, $f;
open(F, ">$f") or die "$0: failed to open '$f' for writing: $!";
binmode(F, ":raw"); # Output raw bytes.
print F chr(128); # Output illegal UTF-8.
close F;
open(F, $f) or die "$0: failed to open '$f' for reading: $!";
binmode(F, ":encoding(utf-8)");
{
	local $^W = 1;
	local $SIG{__WARN__} = sub { $a = shift };
	eval { <F> }; # This should get caught.
}
close F;
print $a =~ qr{^utf8 "\\x80" does not map to Unicode} ?
  "ok $t - illegal utf8 input\n" : "not ok $t - illegal utf8 input: a = " . unpack("H*", $a) . "\n";

END {
  1 while unlink @f;
}