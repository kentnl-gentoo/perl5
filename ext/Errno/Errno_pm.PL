#!perl
use ExtUtils::MakeMaker;
use Config;
use strict;

use vars qw($VERSION);

$VERSION = "1.04";

my @incpath = (split(/\s+/, $Config{usrinc}), split(/\s+/ ,$Config{locincpth}));
my %err = ();
my %done = ();

unlink "Errno.pm" if -f "Errno.pm";
open OUT, ">Errno.pm" or die $!;
select OUT;
process_file("errno.h");
write_errno_pm();
unlink "errno.i" if -f "errno.i";

sub process_file {
    my($file) = @_;

    return unless defined $file;

    my $path = undef;
    my $dir;
    foreach $dir (@incpath) {
	my $tmp = MM->catfile($dir,$file);
	next unless -r $tmp;
	$path = $tmp;
	last;
    }

    return if exists $done{$path};
    $done{$path} = 1;

    unless(defined $path) {
	warn "Cannot find '$file'";
	return;
    }

    local *FH;
    open(FH,"< $path") or return;
    while(<FH>) {
	s#/\*.*(\*/|$)##;

	process_file($1)
		if /^#\s*include\s*[<"]([^>"]+)[>"]/;

	$err{$1} = 1
	    if /^#\s*define\s+(E\w+)\s+/;
   }
   close(FH);
}

sub write_errno_pm {
    my $err;

    # create the CPP input

    open(CPPI,"> errno.i") or
	die "Cannot open errno.i";

    print CPPI "#include <errno.h>\n";

    foreach $err (keys %err) {
	print CPPI '"',$err,'" [[',$err,']]',"\n";
    }

    close(CPPI);

    # invoke CPP and read the output

    open(CPPO,"$Config{cppstdin} $Config{cppflags} $Config{cppminus}  <errno.i |") or
	die "Cannot exec $Config{cppstdin}";

    %err = ();

    while(<CPPO>) {
	my($name,$expr);
	next unless ($name, $expr) = /"(.*?)"\s*\[\[\s*(.*?)\s*\]\]/;
	next if $name eq $expr;
	$err{$name} = eval $expr;
    }
    close(CPPO);

    # Write Errno.pm

    print <<"EDQ";
#
# This file is auto-generated. ***ANY*** changes here will be lost
#

package Errno;
use vars qw(\@EXPORT_OK \%EXPORT_TAGS \@ISA \$VERSION \%errno \$AUTOLOAD);
use Exporter ();
use Config;
use strict;

\$Config{'myarchname'} eq "$Config{'myarchname'}" or
	die "Errno architecture ($Config{'myarchname'}) does not match executable architecture (\$Config{'myarchname'})";

\$VERSION = "$VERSION";
\@ISA = qw(Exporter);

EDQ
   
    my $len = 0;
    my @err = sort { $err{$a} <=> $err{$b} } keys %err;
    map { $len = length if length > $len } @err;

    my $j = "\@EXPORT_OK = qw(" . join(" ",keys %err) . ");\n";
    $j =~ s/(.{50,70})\s/$1\n\t/g;
    print $j,"\n";

print <<'ESQ';
%EXPORT_TAGS = (
    POSIX => [qw(
ESQ

    my $k = join(" ", grep { exists $err{$_} } 
	qw(E2BIG EACCES EADDRINUSE EADDRNOTAVAIL EAFNOSUPPORT
	EAGAIN EALREADY EBADF EBUSY ECHILD ECONNABORTED
	ECONNREFUSED ECONNRESET EDEADLK EDESTADDRREQ EDOM EDQUOT
	EEXIST EFAULT EFBIG EHOSTDOWN EHOSTUNREACH EINPROGRESS
	EINTR EINVAL EIO EISCONN EISDIR ELOOP EMFILE EMLINK
	EMSGSIZE ENAMETOOLONG ENETDOWN ENETRESET ENETUNREACH
	ENFILE ENOBUFS ENODEV ENOENT ENOEXEC ENOLCK ENOMEM
	ENOPROTOOPT ENOSPC ENOSYS ENOTBLK ENOTCONN ENOTDIR
	ENOTEMPTY ENOTSOCK ENOTTY ENXIO EOPNOTSUPP EPERM
	EPFNOSUPPORT EPIPE EPROCLIM EPROTONOSUPPORT EPROTOTYPE
	ERANGE EREMOTE ERESTART EROFS ESHUTDOWN ESOCKTNOSUPPORT
	ESPIPE ESRCH ESTALE ETIMEDOUT ETOOMANYREFS ETXTBSY
	EUSERS EWOULDBLOCK EXDEV));

    $k =~ s/(.{50,70})\s/$1\n\t/g;
    print "\t",$k,"\n    )]\n);\n\n";

    foreach $err (@err) {
	printf "sub %s () { %d }\n",,$err,$err{$err};
    }

    print <<'ESQ';

sub TIEHASH { bless [] }

sub FETCH {
    my ($self, $errname) = @_;
    my $proto = prototype($errname);
    if (defined($proto) && $proto eq "") {
	no strict 'refs';
        return $! == &$errname;
    }
    require Carp;
    Carp::confess("No errno $errname");
} 

sub STORE {
    require Carp;
    Carp::confess("ERRNO hash is read only!");
}

*CLEAR = \&STORE;
*DELETE = \&STORE;

sub NEXTKEY {
    my($k,$v);
    while(($k,$v) = each %Errno::) {
	my $proto = prototype($k);
	last if (defined($proto) && $proto eq "");
	
    }
    $k
}

sub FIRSTKEY {
    my $s = scalar keys %Errno::;
    goto &NEXTKEY;
}

*DELETE = *CLEAR = \&STORE;

sub EXISTS {
    my ($self, $errname) = @_;
    my $proto = prototype($errname);
    defined($proto) && $proto eq "";
}

tie %!, __PACKAGE__;

1;
__END__

=head1 NAME

Errno - System errno constants

=head1 SYNOPSIS

    use Errno qw(EINTR EIO :POSIX);

=head1 DESCRIPTION

C<Errno> defines and conditionally exports all the error constants
defined in your system C<errno.h> include file. It has a single export
tag, C<:POSIX>, which will export all POSIX defined error numbers.

C<Errno> also makes C<%!> magic such that each element of C<%!> has a non-zero
value only if C<$!> is set to that value, eg

    use Errno;
    
    unless (open(FH, "/fangorn/spouse")) {
        if ($!{ENOENT}) {
            warn "Get a wife!\n";
        } else {
            warn "This path is barred: $!";
        } 
    } 

=head1 AUTHOR

Graham Barr <gbarr@pobox.com>

=head1 COPYRIGHT

Copyright (c) 1997-8 Graham Barr. All rights reserved.
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

ESQ

}
