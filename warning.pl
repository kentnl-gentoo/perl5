#!/usr/bin/perl

BEGIN {
  push @INC, './lib';
}
use strict ;

sub DEFAULT_ON  () { 1 }
sub DEFAULT_OFF () { 2 }

my $tree = {
       	 'unsafe'	=> { 	'untie'		=> DEFAULT_OFF,
				'substr'	=> DEFAULT_OFF,
				'taint'		=> DEFAULT_OFF,
				'signal'	=> DEFAULT_OFF,
				'closure'	=> DEFAULT_OFF,
				'utf8'		=> DEFAULT_OFF,
			   } ,
       	 'io'  		=> { 	'pipe' 		=> DEFAULT_OFF,
       				'unopened'	=> DEFAULT_OFF,
       				'closed'	=> DEFAULT_OFF,
       				'newline'	=> DEFAULT_OFF,
       				'exec'		=> DEFAULT_OFF,
       				#'wr in in file'=> DEFAULT_OFF,
			   },
       	 'syntax'	=> { 	'ambiguous'	=> DEFAULT_OFF,
			     	'semicolon'	=> DEFAULT_OFF,
			     	'precedence'	=> DEFAULT_OFF,
			     	'reserved'	=> DEFAULT_OFF,
				'octal'		=> DEFAULT_OFF,
			     	'parenthesis'	=> DEFAULT_OFF,
       	 			'deprecated'	=> DEFAULT_OFF,
       	 			'printf'	=> DEFAULT_OFF,
			   },
       	 'void'		=> DEFAULT_OFF,
       	 'recursion'	=> DEFAULT_OFF,
       	 'redefine'	=> DEFAULT_OFF,
       	 'numeric'	=> DEFAULT_OFF,
         'uninitialized'=> DEFAULT_OFF,
       	 'once'		=> DEFAULT_OFF,
       	 'misc'		=> DEFAULT_OFF,
       	 'default'	=> DEFAULT_ON,
	} ;


###########################################################################
sub tab {
    my($l, $t) = @_;
    $t .= "\t" x ($l - (length($t) + 1) / 8);
    $t;
}

###########################################################################

my %list ;
my %Value ;
my $index = 0 ;

sub walk
{
    my $tre = shift ;
    my @list = () ;
    my ($k, $v) ;

    foreach $k (sort keys %$tre) {
	$v = $tre->{$k};
	die "duplicate key $k\n" if defined $list{$k} ;
	$Value{$index} = uc $k ;
        push @{ $list{$k} }, $index ++ ;
	if (ref $v)
	  { push (@{ $list{$k} }, walk ($v)) }
	push @list, @{ $list{$k} } ;
    }

   return @list ;
}

###########################################################################

sub mkRange
{
    my @a = @_ ;
    my @out = @a ;
    my $i ;


    for ($i = 1 ; $i < @a; ++ $i) {
      	$out[$i] = ".." 
          if $a[$i] == $a[$i - 1] + 1 && $a[$i] + 1 == $a[$i + 1] ;
    }

    my $out = join(",",@out);

    $out =~ s/,(\.\.,)+/../g ;
    return $out;
}

###########################################################################

sub mkHex
{
    my ($max, @a) = @_ ;
    my $mask = "\x00" x $max ;
    my $string = "" ;

    foreach (@a) {
	vec($mask, $_, 1) = 1 ;
    }

    #$string = unpack("H$max", $mask) ;
    #$string =~ s/(..)/\x$1/g;
    foreach (unpack("C*", $mask)) {
	$string .= '\x' . sprintf("%2.2x", $_) ;
    }
    return $string ;
}

###########################################################################


#unlink "warning.h";
#unlink "lib/warning.pm";
open(WARN, ">warning.h") || die "Can't create warning.h: $!\n";
open(PM, ">lib/warning.pm") || die "Can't create lib/warning.pm: $!\n";

print WARN <<'EOM' ;
/* !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
   This file is built by warning.pl
   Any changes made here will be lost!
*/


#define Off(x)                  ((x) / 8)
#define Bit(x)                  (1 << ((x) % 8))
#define IsSet(a, x)		((a)[Off(x)] & Bit(x))

#define G_WARN_OFF		0 	/* $^W == 0 */
#define G_WARN_ON		1	/* $^W != 0 */
#define G_WARN_ALL_ON		2	/* -W flag */
#define G_WARN_ALL_OFF		4	/* -X flag */
#define G_WARN_ALL_MASK		(G_WARN_ALL_ON|G_WARN_ALL_OFF)

#if 1

/* Part of the logic below assumes that WARN_NONE is NULL */

#define ckDEAD(x)							\
	   (PL_curcop->cop_warnings != WARN_ALL &&			\
	    PL_curcop->cop_warnings != WARN_NONE &&			\
	    IsSet(SvPVX(PL_curcop->cop_warnings), 2*x+1))

#define ckWARN(x)							\
	( (PL_curcop->cop_warnings &&					\
	      (PL_curcop->cop_warnings == WARN_ALL ||			\
	       IsSet(SvPVX(PL_curcop->cop_warnings), 2*x) ) )		\
	  || (PL_dowarn & G_WARN_ON) )

#define ckWARN2(x,y)							\
	  ( (PL_curcop->cop_warnings &&					\
	      (PL_curcop->cop_warnings == WARN_ALL ||			\
	        IsSet(SvPVX(PL_curcop->cop_warnings), 2*x)  ||		\
	        IsSet(SvPVX(PL_curcop->cop_warnings), 2*y) ) ) 		\
	    ||	(PL_dowarn & G_WARN_ON) )

#else

#define ckDEAD(x)							\
	   (PL_curcop->cop_warnings != WARN_ALL &&			\
	    PL_curcop->cop_warnings != WARN_NONE &&			\
	    SvPVX(PL_curcop->cop_warnings)[Off(2*x+1)] & Bit(2*x+1) )

#define ckWARN(x)							\
	( (PL_dowarn & G_WARN_ON) || ( (PL_dowarn & G_WARN_DISABLE) && 	\
	  PL_curcop->cop_warnings &&					\
	  ( PL_curcop->cop_warnings == WARN_ALL ||			\
	    SvPVX(PL_curcop->cop_warnings)[Off(2*x)] & Bit(2*x)  ) ) )

#define ckWARN2(x,y)							\
	( (PL_dowarn & G_WARN_ON) || ( (PL_dowarn & G_WARN_DISABLE) && 	\
	  PL_curcop->cop_warnings &&					\
	  ( PL_curcop->cop_warnings == WARN_ALL ||			\
	    SvPVX(PL_curcop->cop_warnings)[Off(2*x)] & Bit(2*x) || 	\
	    SvPVX(PL_curcop->cop_warnings)[Off(2*y)] & Bit(2*y) ) ) ) 

#endif

#define WARN_NONE		NULL
#define WARN_ALL		(&PL_sv_yes)

EOM


$index = 0 ;
@{ $list{"all"} } = walk ($tree) ;

$index *= 2 ;
my $warn_size = int($index / 8) + ($index % 8 != 0) ;

my $k ;
foreach $k (sort { $a <=> $b } keys %Value) {
    print WARN tab(5, "#define WARN_$Value{$k}"), "$k\n" ;
}
print WARN "\n" ;

print WARN tab(5, '#define WARNsize'),	"$warn_size\n" ;
#print WARN tab(5, '#define WARN_ALLstring'), '"', ('\377' x $warn_size) , "\"\n" ;
print WARN tab(5, '#define WARN_ALLstring'), '"', ('\125' x $warn_size) , "\"\n" ;
print WARN tab(5, '#define WARN_NONEstring'), '"', ('\0' x $warn_size) , "\"\n" ;

print WARN <<'EOM';

/* end of file warning.h */

EOM

close WARN ;

while (<DATA>) {
    last if /^KEYWORDS$/ ;
    print PM $_ ;
}

$list{'all'} = [ 0 .. 8 * ($warn_size/2) - 1 ] ;
print PM "%Bits = (\n" ;
foreach $k (sort keys  %list) {

    my $v = $list{$k} ;
    my @list = sort { $a <=> $b } @$v ;

    print PM tab(4, "    '$k'"), '=> "', 
		# mkHex($warn_size, @list), 
		mkHex($warn_size, map $_ * 2 , @list), 
		'", # [', mkRange(@list), "]\n" ;
}

print PM "  );\n\n" ;

print PM "%DeadBits = (\n" ;
foreach $k (sort keys  %list) {

    my $v = $list{$k} ;
    my @list = sort { $a <=> $b } @$v ;

    print PM tab(4, "    '$k'"), '=> "', 
		# mkHex($warn_size, @list), 
		mkHex($warn_size, map $_ * 2 + 1 , @list), 
		'", # [', mkRange(@list), "]\n" ;
}

print PM "  );\n\n" ;
while (<DATA>) {
    print PM $_ ;
}

close PM ;

__END__

# This file was created by warning.pl
# Any changes made here will be lost.
#

package warning;

=head1 NAME

warning - Perl pragma to control 

=head1 SYNOPSIS

    use warning;

    use warning "all";
    use warning "deprecated";

    use warning;
    no warning "unsafe";

=head1 DESCRIPTION

If no import list is supplied, all possible restrictions are assumed.
(This is the safest mode to operate in, but is sometimes too strict for
casual programming.)  Currently, there are three possible things to be
strict about:  

=over 6

=item C<warning deprecated>

This generates a runtime error if you use deprecated 

    use warning 'deprecated';

=back

See L<perlmod/Pragmatic Modules>.


=cut

use Carp ;

KEYWORDS

sub bits {
    my $mask ;
    my $catmask ;
    my $fatal = 0 ;
    foreach my $word (@_) {
	if  ($word eq 'FATAL')
	  { $fatal = 1 }
	elsif ($catmask = $Bits{$word}) {
	  $mask |= $catmask ;
	  $mask |= $DeadBits{$word} if $fatal ;
	}
	else
	  { croak "unknown warning category '$word'" }
    }

    return $mask ;
}

sub import {
    shift;
    $^B |= bits(@_ ? @_ : 'all') ;
}

sub unimport {
    shift;
    $^B &= ~ bits(@_ ? @_ : 'all') ;
}


sub make_fatal
{
    my $self = shift ;
    my $bitmask = $self->bits(@_) ;
    $SIG{__WARN__} =
        sub
        {
            die @_ if $^B & $bitmask ;
            warn @_
        } ;
}

sub bitmask
{
    return $^B ;
}

sub enabled
{
    my $string = shift ;

    return 1
	if $bits{$string} && $^B & $bits{$string} ;
   
    return 0 ; 
}

1;
