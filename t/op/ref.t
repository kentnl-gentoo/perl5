#!./perl

print "1..37\n";

# Test glob operations.

$bar = "ok 1\n";
$foo = "ok 2\n";
{
    local(*foo) = *bar;
    print $foo;
}
print $foo;

$baz = "ok 3\n";
$foo = "ok 4\n";
{
    local(*foo) = 'baz';
    print $foo;
}
print $foo;

$foo = "ok 6\n";
{
    local(*foo);
    print $foo;
    $foo = "ok 5\n";
    print $foo;
}
print $foo;

# Test fake references.

$baz = "ok 7\n";
$bar = 'baz';
$foo = 'bar';
print $$$foo;

# Test real references.

$FOO = \$BAR;
$BAR = \$BAZ;
$BAZ = "ok 8\n";
print $$$FOO;

# Test references to real arrays.

@ary = (9,10,11,12);
$ref[0] = \@a;
$ref[1] = \@b;
$ref[2] = \@c;
$ref[3] = \@d;
for $i (3,1,2,0) {
    push(@{$ref[$i]}, "ok $ary[$i]\n");
}
print @a;
print ${$ref[1]}[0];
print @{$ref[2]}[0];
print @{'d'};

# Test references to references.

$refref = \\$x;
$x = "ok 13\n";
print $$$refref;

# Test nested anonymous lists.

$ref = [[],2,[3,4,5,]];
print scalar @$ref == 3 ? "ok 14\n" : "not ok 14\n";
print $$ref[1] == 2 ? "ok 15\n" : "not ok 15\n";
print ${$$ref[2]}[2] == 5 ? "ok 16\n" : "not ok 16\n";
print scalar @{$$ref[0]} == 0 ? "ok 17\n" : "not ok 17\n";

print $ref->[1] == 2 ? "ok 18\n" : "not ok 18\n";
print $ref->[2]->[0] == 3 ? "ok 19\n" : "not ok 18\n";

# Test references to hashes of references.

$refref = \%whatever;
$refref->{"key"} = $ref;
print $refref->{"key"}->[2]->[0] == 3 ? "ok 20\n" : "not ok 20\n";

# Test to see if anonymous subarrays spring into existence.

$spring[5]->[0] = 123;
$spring[5]->[1] = 456;
push(@{$spring[5]}, 789);
print join(':',@{$spring[5]}) eq "123:456:789" ? "ok 21\n" : "not ok 21\n";

# Test to see if anonymous subhashes spring into existence.

@{$spring2{"foo"}} = (1,2,3);
$spring2{"foo"}->[3] = 4;
print join(':',@{$spring2{"foo"}}) eq "1:2:3:4" ? "ok 22\n" : "not ok 22\n";

# Test references to subroutines.

sub mysub { print "ok 23\n" }
$subref = \&mysub;
&$subref;

$subrefref = \\&mysub2;
&$$subrefref("ok 24\n");
sub mysub2 { print shift }

# Test the ref operator.

print ref $subref	eq CODE  ? "ok 25\n" : "not ok 25\n";
print ref $ref		eq ARRAY ? "ok 26\n" : "not ok 26\n";
print ref $refref	eq HASH  ? "ok 27\n" : "not ok 27\n";

# Test anonymous hash syntax.

$anonhash = {};
print ref $anonhash	eq HASH  ? "ok 28\n" : "not ok 28\n";
$anonhash2 = {FOO => BAR, ABC => XYZ,};
print join('', sort values %$anonhash2) eq BARXYZ ? "ok 29\n" : "not ok 29\n";

# Test bless operator.

package MYHASH;

$object = bless $main'anonhash2;
print ref $object	eq MYHASH  ? "ok 30\n" : "not ok 30\n";
print $object->{ABC}	eq XYZ     ? "ok 31\n" : "not ok 31\n";

$object2 = bless {};
print ref $object2	eq MYHASH  ? "ok 32\n" : "not ok 32\n";

# Test ordinary call on object method.

&mymethod($object,33);

sub mymethod {
    local($THIS, @ARGS) = @_;
    die "Not a MYHASH" unless ref $THIS eq MYHASH;
    print $THIS->{FOO} eq BAR  ? "ok $ARGS[0]\n" : "not ok $ARGS[0]\n";
}

# Test automatic destructor call.

$string = "not ok 34\n";
$object = "foo";
$string = "ok 34\n";
$main'anonhash2 = "foo";
$string = "not ok 34\n";

sub DESTROY {
    print $string;

    # Test that the object has already been "cursed".
    print ref shift eq HASH ? "ok 35\n" : "not ok 35\n";
}

# Now test inheritance of methods.

package OBJ;

@ISA = (BASEOBJ);

$main'object = bless {FOO => foo, BAR => bar};

package main;

# Test arrow-style method invocation.

print $object->doit("BAR") eq bar ? "ok 36\n" : "not ok 36\n";

# Test indirect-object-style method invocation.

$foo = doit $object "FOO";
print $foo eq foo ? "ok 37\n" : "not ok 37\n";

sub BASEOBJ'doit {
    local $ref = shift;
    die "Not an OBJ" unless ref $ref eq OBJ;
    $ref->{shift};
}