package Carp;

=head1 NAME

carp - warn of errors (from perspective of caller)

croak - die of errors (from perspective of caller)

confess - die of errors with stack backtrace

=head1 SYNOPSIS

    use Carp;
    croak "We're outta here!";

=head1 DESCRIPTION

The Carp routines are useful in your own modules because
they act like die() or warn(), but report where the error
was in the code they were called from.  Thus if you have a 
routine Foo() that has a carp() in it, then the carp() 
will report the error as occurring where Foo() was called, 
not where carp() was called.

=cut

# This package implements handy routines for modules that wish to throw
# exceptions outside of the current package.

$CarpLevel = 0;		# How many extra package levels to skip on carp.
$MaxEvalLen = 0;	# How much eval '...text...' to show. 0 = all.
$MaxArgLen = 64;        # How much of each argument to print. 0 = all.
$MaxArgNums = 8;        # How many arguments to print. 0 = all.

require Exporter;
@ISA = Exporter;
@EXPORT = qw(confess croak carp);

sub longmess {
    my $error = shift;
    my $mess = "";
    my $i = 1 + $CarpLevel;
    my ($pack,$file,$line,$sub,$hargs,$eval,$require);
    my (@a);
    while (do { { package DB; @a = caller($i++) } } ) {
      ($pack,$file,$line,$sub,$hargs,undef,$eval,$require) = @a;
	if ($error =~ m/\n$/) {
	    $mess .= $error;
	} else {
	    if (defined $eval) {
	        if ($require) {
		    $sub = "require $eval";
		} else {
		    $eval =~ s/([\\\'])/\\$1/g;
		    if ($MaxEvalLen && length($eval) > $MaxEvalLen) {
			substr($eval,$MaxEvalLen) = '...';
		    }
		    $sub = "eval '$eval'";
		}
	    } elsif ($sub eq '(eval)') {
		$sub = 'eval {...}';
	    }
	    if ($hargs) {
	      @a = @DB::args;	# must get local copy of args
	      if ($MaxArgNums and @a > $MaxArgNums) {
		$#a = $MaxArgNums;
		$a[$#a] = "...";
	      }
	      for (@a) {
		s/'/\\'/g;
		substr($_,$MaxArgLen) = '...' if $MaxArgLen and $MaxArgLen < length;
		s/([^\0]*)/'$1'/ unless /^-?[\d.]+$/;
		s/([\200-\377])/sprintf("M-%c",ord($1)&0177)/eg;
		s/([\0-\37\177])/sprintf("^%c",ord($1)^64)/eg;
	      }
	      $sub .= '(' . join(', ', @a) . ')';
	    }
	    $mess .= "\t$sub " if $error eq "called";
	    $mess .= "$error at $file line $line\n";
	}
	$error = "called";
    }
    $mess || $error;
}

sub shortmess {	# Short-circuit &longmess if called via multiple packages
    my $error = $_[0];	# Instead of "shift"
    my ($prevpack) = caller(1);
    my $extra = $CarpLevel;
    my $i = 2;
    my ($pack,$file,$line);
    my %isa = ($prevpack,1);

    @isa{@{"${prevpack}::ISA"}} = ()
	if(defined @{"${prevpack}::ISA"});

    while (($pack,$file,$line) = caller($i++)) {
	if(defined @{$pack . "::ISA"}) {
	    my @i = @{$pack . "::ISA"};
	    my %i;
	    @i{@i} = ();
	    @isa{@i,$pack} = ()
		if(exists $i{$prevpack} || exists $isa{$pack});
	}

	next
	    if(exists $isa{$pack});

	if ($extra-- > 0) {
	    %isa = ($pack,1);
	    @isa{@{$pack . "::ISA"}} = ()
		if(defined @{$pack . "::ISA"});
	}
	else {
	    return "$error at $file line $line\n";
	}
    }
    continue {
	$prevpack = $pack;
    }

    goto &longmess;
}

sub confess { die longmess @_; }
sub croak { die shortmess @_; }
sub carp { warn shortmess @_; }

1;
