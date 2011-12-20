#!./perl

BEGIN {
    unshift @INC, 't';
    require Config;
    if (($Config::Config{'extensions'} !~ /\bB\b/) ){
        print "1..0 # Skip -- Perl configured without B module\n";
        exit 0;
    }
}

use warnings;
use strict;
BEGIN {
    # BEGIN block is actually a subroutine :-)
    return unless $] > 5.009;
    require feature;
    feature->import(':5.10');
}
use Test::More;
use Config ();

use B::Deparse;
my $deparse = B::Deparse->new();
isa_ok($deparse, 'B::Deparse', 'instantiate a B::Deparse object');

# Tell B::Deparse about our ambient pragmas
{ my ($hint_bits, $warning_bits, $hinthash);
 BEGIN { ($hint_bits, $warning_bits, $hinthash) = ($^H, ${^WARNING_BITS}, \%^H); }
 $deparse->ambient_pragmas (
     hint_bits    => $hint_bits,
     warning_bits => $warning_bits,
     '%^H'	  => $hinthash,
 );
}

$/ = "\n####\n";
while (<DATA>) {
    chomp;
    # This code is pinched from the t/lib/common.pl for TODO.
    # It's not clear how to avoid duplication
    # Now tweaked a bit to do skip or todo
    my %reason;
    foreach my $what (qw(skip todo)) {
	s/^#\s*\U$what\E\s*(.*)\n//m and $reason{$what} = $1;
	# If the SKIP reason starts ? then it's taken as a code snippet to
	# evaluate. This provides the flexibility to have conditional SKIPs
	if ($reason{$what} && $reason{$what} =~ s/^\?//) {
	    my $temp = eval $reason{$what};
	    if ($@) {
		die "# In \U$what\E code reason:\n# $reason{$what}\n$@";
	    }
	    $reason{$what} = $temp;
	}
    }

    s/^\s*#\s*(.*)$//mg;
    my $desc = $1;
    die "Missing name in test $_" unless defined $desc;

    if ($reason{skip}) {
	# Like this to avoid needing a label SKIP:
       Test::More->builder->skip($reason{skip});
	next;
    }

    my ($input, $expected);
    if (/(.*)\n>>>>\n(.*)/s) {
	($input, $expected) = ($1, $2);
    }
    else {
	($input, $expected) = ($_, $_);
    }

    my $coderef = eval "sub {$input}";

    if ($@) {
	is($@, "", "compilation of $desc");
    }
    else {
	my $deparsed = $deparse->coderef2text( $coderef );
	my $regex = $expected;
	$regex =~ s/(\S+)/\Q$1/g;
	$regex =~ s/\s+/\\s+/g;
	$regex = '^\{\s*' . $regex . '\s*\}$';

	local $::TODO = $reason{todo};
        like($deparsed, qr/$regex/, $desc);
    }
}

use constant 'c', 'stuff';
is((eval "sub ".$deparse->coderef2text(\&c))->(), 'stuff',
   'the subroutine generated by use constant deparses');

my $a = 0;
is($deparse->coderef2text(sub{(-1) ** $a }), "{\n    (-1) ** \$a;\n}",
   'anon sub capturing an external lexical');

use constant cr => ['hello'];
my $string = "sub " . $deparse->coderef2text(\&cr);
my $val = (eval $string)->() or diag $string;
is(ref($val), 'ARRAY', 'constant array references deparse');
is($val->[0], 'hello', 'and return the correct value');

my $path = join " ", map { qq["-I$_"] } @INC;

$a = `$^X $path "-MO=Deparse" -anlwi.bak -e 1 2>&1`;
$a =~ s/-e syntax OK\n//g;
$a =~ s/.*possible typo.*\n//;	   # Remove warning line
$a =~ s{\\340\\242}{\\s} if (ord("\\") == 224); # EBCDIC, cp 1047 or 037
$a =~ s{\\274\\242}{\\s} if (ord("\\") == 188); # $^O eq 'posix-bc'
$b = <<'EOF';
BEGIN { $^I = ".bak"; }
BEGIN { $^W = 1; }
BEGIN { $/ = "\n"; $\ = "\n"; }
LINE: while (defined($_ = <ARGV>)) {
    chomp $_;
    our(@F) = split(' ', $_, 0);
    '???';
}
EOF
is($a, $b,
   'command line flags deparse as BEGIN blocks setting control variables');

$a = `$^X $path "-MO=Deparse" -e "use constant PI => 4" 2>&1`;
$a =~ s/-e syntax OK\n//g;
is($a, "use constant ('PI', 4);\n",
   "Proxy Constant Subroutines must not show up as (incorrect) prototypes");

#Re: perlbug #35857, patch #24505
#handle warnings::register-ed packages properly.
package B::Deparse::Wrapper;
use strict;
use warnings;
use warnings::register;
sub getcode {
   my $deparser = B::Deparse->new();
   return $deparser->coderef2text(shift);
}

package Moo;
use overload '0+' => sub { 42 };

package main;
use strict;
use warnings;
use constant GLIPP => 'glipp';
use constant PI => 4;
use constant OVERLOADED_NUMIFICATION => bless({}, 'Moo');
use Fcntl qw/O_TRUNC O_APPEND O_EXCL/;
BEGIN { delete $::Fcntl::{O_APPEND}; }
use POSIX qw/O_CREAT/;
sub test {
   my $val = shift;
   my $res = B::Deparse::Wrapper::getcode($val);
   like($res, qr/use warnings/,
	'[perl #35857] [PATCH] B::Deparse doesnt handle warnings register properly');
}
my ($q,$p);
my $x=sub { ++$q,++$p };
test($x);
eval <<EOFCODE and test($x);
   package bar;
   use strict;
   use warnings;
   use warnings::register;
   package main;
   1
EOFCODE

# Exotic sub declarations
$a = `$^X $path "-MO=Deparse" -e "sub ::::{}sub ::::::{}" 2>&1`;
$a =~ s/-e syntax OK\n//g;
is($a, <<'EOCODG', "sub :::: and sub ::::::");
sub :::: {
    
}
sub :::::: {
    
}
EOCODG

# [perl #33752]
{
  my $code = <<"EOCODE";
{
    our \$\x{1e1f}\x{14d}\x{14d};
}
EOCODE
  my $deparsed
   = $deparse->coderef2text(eval "sub { our \$\x{1e1f}\x{14d}\x{14d} }" );
  s/$ \n//x for $deparsed, $code;
  is $deparsed, $code, 'our $funny_Unicode_chars';
}

# [perl #62500]
$a =
  `$^X $path "-MO=Deparse" -e "BEGIN{*CORE::GLOBAL::require=sub{1}}" 2>&1`;
$a =~ s/-e syntax OK\n//g;
is($a, <<'EOCODF', "CORE::GLOBAL::require override causing panick");
sub BEGIN {
    *CORE::GLOBAL::require = sub {
        1;
    }
    ;
}
EOCODF

# [perl #93990]
@* = ();
is($deparse->coderef2text(sub{ print "@{*}" }),
q<{
    print "@{*}";
}>, 'curly around to interpolate "@{*}"');
is($deparse->coderef2text(sub{ print "@{-}" }),
q<{
    print "@-";
}>, 'no need to curly around to interpolate "@-"');

done_testing();

__DATA__
# A constant
1;
####
# Constants in a block
{
    no warnings;
    '???';
    2;
}
####
# Lexical and simple arithmetic
my $test;
++$test and $test /= 2;
>>>>
my $test;
$test /= 2 if ++$test;
####
# list x
-((1, 2) x 2);
####
# lvalue sub
{
    my $test = sub : lvalue {
	my $x;
    }
    ;
}
####
# method
{
    my $test = sub : method {
	my $x;
    }
    ;
}
####
# block with continue
{
    234;
}
continue {
    123;
}
####
# lexical and package scalars
my $x;
print $main::x;
####
# lexical and package arrays
my @x;
print $main::x[1];
####
# lexical and package hashes
my %x;
$x{warn()};
####
# <>
my $foo;
$_ .= <ARGV> . <$foo>;
####
# \x{}
my $foo = "Ab\x{100}\200\x{200}\237Cd\000Ef\x{1000}\cA\x{2000}\cZ";
####
# s///e
s/x/'y';/e;
####
# block
{ my $x; }
####
# while 1
while (1) { my $k; }
####
# trailing for
my ($x,@a);
$x=1 for @a;
>>>>
my($x, @a);
$x = 1 foreach (@a);
####
# 2 arguments in a 3 argument for
for (my $i = 0; $i < 2;) {
    my $z = 1;
}
####
# 3 argument for
for (my $i = 0; $i < 2; ++$i) {
    my $z = 1;
}
####
# 3 argument for again
for (my $i = 0; $i < 2; ++$i) {
    my $z = 1;
}
####
# while/continue
my $i;
while ($i) { my $z = 1; } continue { $i = 99; }
####
# foreach with my
foreach my $i (1, 2) {
    my $z = 1;
}
####
# foreach
my $i;
foreach $i (1, 2) {
    my $z = 1;
}
####
# foreach, 2 mys
my $i;
foreach my $i (1, 2) {
    my $z = 1;
}
####
# foreach
foreach my $i (1, 2) {
    my $z = 1;
}
####
# foreach with our
foreach our $i (1, 2) {
    my $z = 1;
}
####
# foreach with my and our
my $i;
foreach our $i (1, 2) {
    my $z = 1;
}
####
# reverse sort
my @x;
print reverse sort(@x);
####
# sort with cmp
my @x;
print((sort {$b cmp $a} @x));
####
# reverse sort with block
my @x;
print((reverse sort {$b <=> $a} @x));
####
# foreach reverse
our @a;
print $_ foreach (reverse @a);
####
# foreach reverse (not inplace)
our @a;
print $_ foreach (reverse 1, 2..5);
####
# bug #38684
our @ary;
@ary = split(' ', 'foo', 0);
####
# bug #40055
do { () }; 
####
# bug #40055
do { my $x = 1; $x }; 
####
# <20061012113037.GJ25805@c4.convolution.nl>
my $f = sub {
    +{[]};
} ;
####
# bug #43010
'!@$%'->();
####
# bug #43010
::();
####
# bug #43010
'::::'->();
####
# bug #43010
&::::;
####
# [perl #77172]
package rt77172;
sub foo {} foo & & & foo;
>>>>
package rt77172;
foo(&{&} & foo());
####
# variables as method names
my $bar;
'Foo'->$bar('orz');
'Foo'->$bar('orz') = 'a stranger stranger than before';
####
# constants as method names
'Foo'->bar('orz');
####
# constants as method names without ()
'Foo'->bar;
####
# [perl #47359] "indirect" method call notation
our @bar;
foo{@bar}+1,->foo;
(foo{@bar}+1),foo();
foo{@bar}1 xor foo();
>>>>
our @bar;
(foo { @bar } 1)->foo;
(foo { @bar } 1), foo();
foo { @bar } 1 xor foo();
####
# SKIP ?$] < 5.010 && "say not implemented on this Perl version"
# say
say 'foo';
####
# SKIP ?$] < 5.010 && "state vars not implemented on this Perl version"
# state vars
state $x = 42;
####
# SKIP ?$] < 5.010 && "state vars not implemented on this Perl version"
# state var assignment
{
    my $y = (state $x = 42);
}
####
# SKIP ?$] < 5.010 && "state vars not implemented on this Perl version"
# state vars in anonymous subroutines
$a = sub {
    state $x;
    return $x++;
}
;
####
# SKIP ?$] < 5.011 && 'each @array not implemented on this Perl version'
# each @array;
each @ARGV;
each @$a;
####
# SKIP ?$] < 5.011 && 'each @array not implemented on this Perl version'
# keys @array; values @array
keys @$a if keys @ARGV;
values @ARGV if values @$a;
####
# Anonymous arrays and hashes, and references to them
my $a = {};
my $b = \{};
my $c = [];
my $d = \[];
####
# SKIP ?$] < 5.010 && "smartmatch and given/when not implemented on this Perl version"
# implicit smartmatch in given/when
given ('foo') {
    when ('bar') { continue; }
    when ($_ ~~ 'quux') { continue; }
    default { 0; }
}
####
# conditions in elsifs (regression in change #33710 which fixed bug #37302)
if ($a) { x(); }
elsif ($b) { x(); }
elsif ($a and $b) { x(); }
elsif ($a or $b) { x(); }
else { x(); }
####
# interpolation in regexps
my($y, $t);
/x${y}z$t/;
####
# TODO new undocumented cpan-bug #33708
# cpan-bug #33708
%{$_ || {}}
####
# TODO hash constants not yet fixed
# cpan-bug #33708
use constant H => { "#" => 1 }; H->{"#"}
####
# TODO optimized away 0 not yet fixed
# cpan-bug #33708
foreach my $i (@_) { 0 }
####
# tests with not, not optimized
my $c;
x() unless $a;
x() if not $a and $b;
x() if $a and not $b;
x() unless not $a and $b;
x() unless $a and not $b;
x() if not $a or $b;
x() if $a or not $b;
x() unless not $a or $b;
x() unless $a or not $b;
x() if $a and not $b and $c;
x() if not $a and $b and not $c;
x() unless $a and not $b and $c;
x() unless not $a and $b and not $c;
x() if $a or not $b or $c;
x() if not $a or $b or not $c;
x() unless $a or not $b or $c;
x() unless not $a or $b or not $c;
####
# tests with not, optimized
my $c;
x() if not $a;
x() unless not $a;
x() if not $a and not $b;
x() unless not $a and not $b;
x() if not $a or not $b;
x() unless not $a or not $b;
x() if not $a and not $b and $c;
x() unless not $a and not $b and $c;
x() if not $a or not $b or $c;
x() unless not $a or not $b or $c;
x() if not $a and not $b and not $c;
x() unless not $a and not $b and not $c;
x() if not $a or not $b or not $c;
x() unless not $a or not $b or not $c;
x() unless not $a or not $b or not $c;
>>>>
my $c;
x() unless $a;
x() if $a;
x() unless $a or $b;
x() if $a or $b;
x() unless $a and $b;
x() if $a and $b;
x() if not $a || $b and $c;
x() unless not $a || $b and $c;
x() if not $a && $b or $c;
x() unless not $a && $b or $c;
x() unless $a or $b or $c;
x() if $a or $b or $c;
x() unless $a and $b and $c;
x() if $a and $b and $c;
x() unless not $a && $b && $c;
####
# tests that should be constant folded
x() if 1;
x() if GLIPP;
x() if !GLIPP;
x() if GLIPP && GLIPP;
x() if !GLIPP || GLIPP;
x() if do { GLIPP };
x() if do { no warnings 'void'; 5; GLIPP };
x() if do { !GLIPP };
if (GLIPP) { x() } else { z() }
if (!GLIPP) { x() } else { z() }
if (GLIPP) { x() } elsif (GLIPP) { z() }
if (!GLIPP) { x() } elsif (GLIPP) { z() }
if (GLIPP) { x() } elsif (!GLIPP) { z() }
if (!GLIPP) { x() } elsif (!GLIPP) { z() }
if (!GLIPP) { x() } elsif (!GLIPP) { z() } elsif (GLIPP) { t() }
if (!GLIPP) { x() } elsif (!GLIPP) { z() } elsif (!GLIPP) { t() }
if (!GLIPP) { x() } elsif (!GLIPP) { z() } elsif (!GLIPP) { t() }
>>>>
x();
x();
'???';
x();
x();
x();
x();
do {
    '???'
};
do {
    x()
};
do {
    z()
};
do {
    x()
};
do {
    z()
};
do {
    x()
};
'???';
do {
    t()
};
'???';
!1;
####
# TODO constant deparsing has been backed out for 5.12
# XXXTODO ? $Config::Config{useithreads} && "doesn't work with threads"
# tests that shouldn't be constant folded
# It might be fundamentally impossible to make this work on ithreads, in which
# case the TODO should become a SKIP
x() if $a;
if ($a == 1) { x() } elsif ($b == 2) { z() }
if (do { foo(); GLIPP }) { x() }
if (do { $a++; GLIPP }) { x() }
>>>>
x() if $a;
if ($a == 1) { x(); } elsif ($b == 2) { z(); }
if (do { foo(); GLIPP }) { x(); }
if (do { ++$a; GLIPP }) { x(); }
####
# TODO constant deparsing has been backed out for 5.12
# tests for deparsing constants
warn PI;
####
# TODO constant deparsing has been backed out for 5.12
# tests for deparsing imported constants
warn O_TRUNC;
####
# TODO constant deparsing has been backed out for 5.12
# tests for deparsing re-exported constants
warn O_CREAT;
####
# TODO constant deparsing has been backed out for 5.12
# tests for deparsing imported constants that got deleted from the original namespace
warn O_APPEND;
####
# TODO constant deparsing has been backed out for 5.12
# XXXTODO ? $Config::Config{useithreads} && "doesn't work with threads"
# tests for deparsing constants which got turned into full typeglobs
# It might be fundamentally impossible to make this work on ithreads, in which
# case the TODO should become a SKIP
warn O_EXCL;
eval '@Fcntl::O_EXCL = qw/affe tiger/;';
warn O_EXCL;
####
# TODO constant deparsing has been backed out for 5.12
# tests for deparsing of blessed constant with overloaded numification
warn OVERLOADED_NUMIFICATION;
####
# TODO Only strict 'refs' currently supported
# strict
no strict;
$x;
####
# TODO Subsets of warnings could be encoded textually, rather than as bitflips.
# subsets of warnings
no warnings 'deprecated';
my $x;
####
# TODO Better test for CPAN #33708 - the deparsed code has different behaviour
# CPAN #33708
use strict;
no warnings;

foreach (0..3) {
    my $x = 2;
    {
	my $x if 0;
	print ++$x, "\n";
    }
}
####
# no attribute list
my $pi = 4;
####
# SKIP ?$] > 5.013006 && ":= is now a syntax error"
# := treated as an empty attribute list
no warnings;
my $pi := 4;
>>>>
no warnings;
my $pi = 4;
####
# : = empty attribute list
my $pi : = 4;
>>>>
my $pi = 4;
####
# in place sort
our @a;
my @b;
@a = sort @a;
@b = sort @b;
();
####
# in place reverse
our @a;
my @b;
@a = reverse @a;
@b = reverse @b;
();
####
# #71870 Use of uninitialized value in bitwise and B::Deparse
my($r, $s, @a);
@a = split(/foo/, $s, 0);
$r = qr/foo/;
@a = split(/$r/, $s, 0);
();
####
# package declaration before label
{
    package Foo;
    label: print 123;
}
####
# shift optimisation
shift;
>>>>
shift();
####
# shift optimisation
shift @_;
####
# shift optimisation
pop;
>>>>
pop();
####
# shift optimisation
pop @_;
####
#[perl #20444]
"foo" =~ (1 ? /foo/ : /bar/);
"foo" =~ (1 ? y/foo// : /bar/);
"foo" =~ (1 ? y/foo//r : /bar/);
"foo" =~ (1 ? s/foo// : /bar/);
>>>>
'foo' =~ ($_ =~ /foo/);
'foo' =~ ($_ =~ tr/fo//);
'foo' =~ ($_ =~ tr/fo//r);
'foo' =~ ($_ =~ s/foo//);
####
# The fix for [perl #20444] broke this.
'foo' =~ do { () };
####
# Test @threadsv_names under 5005threads
foreach $' (1, 2) {
    sleep $';
}
####
# y///r
tr/a/b/r;
####
# y/uni/code/
tr/\x{345}/\x{370}/;
####
# [perl #90898]
<a,>;
####
# [perl #91008]
each $@;
keys $~;
values $!;
####
# readpipe with complex expression
readpipe $a + $b;
####
# aelemfast
$b::a[0] = 1;
####
# aelemfast for a lexical
my @a;
$a[0] = 1;
####
# feature features without feature
BEGIN {
    delete $^H{'feature_say'};
    delete $^H{'feature_state'};
    delete $^H{'feature_switch'};
}
CORE::state $x;
CORE::say $x;
CORE::given ($x) {
    CORE::when (3) {
        continue;
    }
    CORE::default {
        CORE::break;
    }
}
CORE::evalbytes '';
() = CORE::__SUB__;
####
# $#- $#+ $#{%} etc.
my @x;
@x = ($#{`}, $#{~}, $#{!}, $#{@}, $#{$}, $#{%}, $#{^}, $#{&}, $#{*});
@x = ($#{(}, $#{)}, $#{[}, $#{{}, $#{]}, $#{}}, $#{'}, $#{"}, $#{,});
@x = ($#{<}, $#{.}, $#{>}, $#{/}, $#{?}, $#{=}, $#+, $#{\}, $#{|}, $#-);
@x = ($#{;}, $#{:});
####
# ${#} interpolated (the first line magically disables the warning)
() = *#;
() = "${#}a";
####
# ()[...]
my(@a) = ()[()];
####
# sort(foo(bar))
# sort(foo(bar)) is interpreted as sort &foo(bar)
# sort foo(bar) is interpreted as sort foo bar
# parentheses are not optional in this case
print sort(foo('bar'));
>>>>
print sort(foo('bar'));
####
# substr assignment
substr(my $a, 0, 0) = (foo(), bar());
$a++;
####
# hint hash
BEGIN { $^H{'foo'} = undef; }
{
 BEGIN { $^H{'bar'} = undef; }
 {
  BEGIN { $^H{'baz'} = undef; }
  {
   print $_;
  }
  print $_;
 }
 print $_;
}
BEGIN { $^H{q[']} = '('; }
print $_;
####
# hint hash changes that serialise the same way with sort %hh
BEGIN { $^H{'a'} = 'b'; }
{
 BEGIN { $^H{'b'} = 'a'; delete $^H{'a'}; }
 print $_;
}
print $_;
####
# [perl #47361] do({}) and do +{} (variants of do-file)
do({});
do +{};
sub foo::do {}
package foo;
CORE::do({});
CORE::do +{};
>>>>
do({});
do({});
package foo;
CORE::do({});
CORE::do({});
####
# [perl #77096] functions that do not follow the llafr
() = (return 1) + time;
() = (return ($1 + $2) * $3) + time;
() = (return ($a xor $b)) + time;
() = (do 'file') + time;
() = (do ($1 + $2) * $3) + time;
() = (do ($1 xor $2)) + time;
() = (goto 1) + 3;
() = (require 'foo') + 3;
() = (require foo) + 3;
() = (CORE::dump 1) + 3;
() = (last 1) + 3;
() = (next 1) + 3;
() = (redo 1) + 3;
() = (-R $_) + 3;
() = (-W $_) + 3;
() = (-X $_) + 3;
() = (-r $_) + 3;
() = (-w $_) + 3;
() = (-x $_) + 3;
####
# [perl #97476] not() *does* follow the llafr
$_ = ($a xor not +($1 || 2) ** 2);
####
# Precedence conundrums with argument-less function calls
() = (eof) + 1;
() = (return) + 1;
() = (return, 1);
() = warn;
() = warn() + 1;
() = setpgrp() + 1;
####
# [perl #63558] open local(*FH)
open local *FH;
pipe local *FH, local *FH;
####
# [perl #74740] -(f()) vs -f()
$_ = -(f());
####
# require <binop>
require 'a' . $1;
