#!./perl

# $RCSfile: local.t,v $$Revision: 4.1 $$Date: 92/08/07 18:28:04 $

print "1..46\n";

# XXX known to leak scalars
$ENV{PERL_DESTRUCT_LEVEL} = 0 unless $ENV{PERL_DESTRUCT_LEVEL} > 3;

sub foo {
    local($a, $b) = @_;
    local($c, $d);
    $c = "ok 3\n";
    $d = "ok 4\n";
    { local($a,$c) = ("ok 9\n", "ok 10\n"); ($x, $y) = ($a, $c); }
    print $a, $b;
    $c . $d;
}

$a = "ok 5\n";
$b = "ok 6\n";
$c = "ok 7\n";
$d = "ok 8\n";

print &foo("ok 1\n","ok 2\n");

print $a,$b,$c,$d,$x,$y;

# same thing, only with arrays and associative arrays

sub foo2 {
    local($a, @b) = @_;
    local(@c, %d);
    @c = "ok 13\n";
    $d{''} = "ok 14\n";
    { local($a,@c) = ("ok 19\n", "ok 20\n"); ($x, $y) = ($a, @c); }
    print $a, @b;
    $c[0] . $d{''};
}

$a = "ok 15\n";
@b = "ok 16\n";
@c = "ok 17\n";
$d{''} = "ok 18\n";

print &foo2("ok 11\n","ok 12\n");

print $a,@b,@c,%d,$x,$y;

eval 'local($$e)';
print +($@ =~ /Can't localize through a reference/) ? "" : "not ", "ok 21\n";

eval 'local(@$e)';
print +($@ =~ /Can't localize through a reference/) ? "" : "not ", "ok 22\n";

eval 'local(%$e)';
print +($@ =~ /Can't localize through a reference/) ? "" : "not ", "ok 23\n";

# Array and hash elements

@a = ('a', 'b', 'c');
{
    local($a[1]) = 'foo';
    local($a[2]) = $a[2];
    print +($a[1] eq 'foo') ? "" : "not ", "ok 24\n";
    print +($a[2] eq 'c') ? "" : "not ", "ok 25\n";
    undef @a;
}
print +($a[1] eq 'b') ? "" : "not ", "ok 26\n";
print +($a[2] eq 'c') ? "" : "not ", "ok 27\n";
print +(!defined $a[0]) ? "" : "not ", "ok 28\n";

@a = ('a', 'b', 'c');
{
    local($a[1]) = "X";
    shift @a;
}
print +($a[0].$a[1] eq "Xb") ? "" : "not ", "ok 29\n";

%h = ('a' => 1, 'b' => 2, 'c' => 3);
{
    local($h{'a'}) = 'foo';
    local($h{'b'}) = $h{'b'};
    print +($h{'a'} eq 'foo') ? "" : "not ", "ok 30\n";
    print +($h{'b'} == 2) ? "" : "not ", "ok 31\n";
    local($h{'c'});
    delete $h{'c'};
}
print +($h{'a'} == 1) ? "" : "not ", "ok 32\n";
print +($h{'b'} == 2) ? "" : "not ", "ok 33\n";
print +($h{'c'} == 3) ? "" : "not ", "ok 34\n";

# check for scope leakage
$a = 'outer';
if (1) { local $a = 'inner' }
print +($a eq 'outer') ? "" : "not ", "ok 35\n";

# see if localization works when scope unwinds
local $m = 5;
eval {
    for $m (6) {
	local $m = 7;
	die "bye";
    }
};
print $m == 5 ? "" : "not ", "ok 36\n";

# see if localization works on tied arrays
{
    package TA;
    sub TIEARRAY { bless [], $_[0] }
    sub STORE { print "# STORE [@_]\n"; $_[0]->[$_[1]] = $_[2] }
    sub FETCH { my $v = $_[0]->[$_[1]]; print "# FETCH [@_=$v]\n"; $v }
    sub CLEAR { print "# CLEAR [@_]\n"; @{$_[0]} = (); }
}

tie @a, 'TA';
@a = ('a', 'b', 'c');
{
    local($a[1]) = 'foo';
    local($a[2]) = $a[1];  # XXX LHS == RHS doesn't work yet
    print +($a[1] eq 'foo') ? "" : "not ", "ok 37\n";
    print +($a[2] eq 'foo') ? "" : "not ", "ok 38\n";
    @a = ();
}
print +($a[1] eq 'b') ? "" : "not ", "ok 39\n";
print +($a[2] eq 'c') ? "" : "not ", "ok 40\n";
print +(!defined $a[0]) ? "" : "not ", "ok 41\n";

## XXX shift doesn't do the right things in TIEARRAY yet
#@a = ('a', 'b', 'c');
#{
#    local($a[1]) = "X";
#    shift @a;
#}
#print +($a[0].$a[1] eq "Xb") ? "" : "not ", "ok 42\n";

{
    package TH;
    sub TIEHASH { bless {}, $_[0] }
    sub STORE { print "# STORE [@_]\n"; $_[0]->{$_[1]} = $_[2] }
    sub FETCH { my $v = $_[0]->{$_[1]}; print "# FETCH [@_=$v]\n"; $v }
    sub DELETE { print "# DELETE [@_]\n"; delete $_[0]->{$_[1]}; }
    sub CLEAR { print "# CLEAR [@_]\n"; %{$_[0]} = (); }
}

# see if localization works on tied hashes
tie %h, 'TH';
%h = ('a' => 1, 'b' => 2, 'c' => 3);

{
    local($h{'a'}) = 'foo';
    local($h{'b'}) = $h{'a'};  # XXX LHS == RHS doesn't work yet
    print +($h{'a'} eq 'foo') ? "" : "not ", "ok 42\n";
    print +($h{'b'} eq 'foo') ? "" : "not ", "ok 43\n";
    local($h{'c'});
    delete $h{'c'};
}
print +($h{'a'} == 1) ? "" : "not ", "ok 44\n";
print +($h{'b'} == 2) ? "" : "not ", "ok 45\n";
print +($h{'c'} == 3) ? "" : "not ", "ok 46\n";
