#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef VMS
#  include <file.h>
#else
#if defined(__GNUC__) && defined(__cplusplus) && defined(WIN32)
#define _NO_OLDNAMES
#endif 
#  include <fcntl.h>
#if defined(__GNUC__) && defined(__cplusplus) && defined(WIN32)
#undef _NO_OLDNAMES
#endif 
#endif

#ifdef I_UNISTD
#include <unistd.h>
#endif

/* This comment is a kludge to get metaconfig to see the symbols
    VAL_O_NONBLOCK
    VAL_EAGAIN
    RD_NODATA
    EOF_NONBLOCK
   and include the appropriate metaconfig unit
   so that Configure will test how to turn on non-blocking I/O
   for a file descriptor.  See config.h for how to use these
   in your extension. 
   
   While I'm at it, I'll have metaconfig look for HAS_POLL too.
   --AD  October 16, 1995
*/

static int
not_here(char *s)
{
    croak("%s not implemented on this architecture", s);
    return -1;
}

static double
constant(char *name, int arg)
{
    errno = 0;
    switch (*name) {
    case 'F':
	if (strnEQ(name, "F_", 2)) {
	    if (strEQ(name, "F_ALLOCSP"))
#ifdef F_ALLOCSP
	        return F_ALLOCSP;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_ALLOCSP64"))
#ifdef F_ALLOCSP64
	        return F_ALLOCSP64;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_COMPAT"))
#ifdef F_COMPAT
	        return F_COMPAT;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_DUP2FD"))
#ifdef F_DUP2FD
	        return F_DUP2FD;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_DUPFD"))
#ifdef F_DUPFD
	        return F_DUPFD;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_EXLCK"))
#ifdef F_EXLCK
	        return F_EXLCK;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_FREESP"))
#ifdef F_FREESP
	        return F_FREESP;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_FREESP64"))
#ifdef F_FREESP64
	        return F_FREESP64;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_FSYNC"))
#ifdef F_FSYNC
	        return F_FSYNC;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_FSYNC64"))
#ifdef F_FSYNC64
	        return F_FSYNC64;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_GETFD"))
#ifdef F_GETFD
	        return F_GETFD;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_GETFL"))
#ifdef F_GETFL
	        return F_GETFL;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_GETLK"))
#ifdef F_GETLK
	        return F_GETLK;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_GETLK64"))
#ifdef F_GETLK64
	        return F_GETLK64;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_GETOWN"))
#ifdef F_GETOWN
	        return F_GETOWN;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_NODNY"))
#ifdef F_NODNY
	        return F_NODNY;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_POSIX"))
#ifdef F_POSIX
	        return F_POSIX;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_RDACC"))
#ifdef F_RDACC
	        return F_RDACC;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_RDDNY"))
#ifdef F_RDDNY
	        return F_RDDNY;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_RDLCK"))
#ifdef F_RDLCK
	        return F_RDLCK;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_RWACC"))
#ifdef F_RWACC
	        return F_RWACC;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_RWDNY"))
#ifdef F_RWDNY
	        return F_RWDNY;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_SETFD"))
#ifdef F_SETFD
	        return F_SETFD;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_SETFL"))
#ifdef F_SETFL
	        return F_SETFL;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_SETLK"))
#ifdef F_SETLK
	        return F_SETLK;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_SETLK64"))
#ifdef F_SETLK64
	        return F_SETLK64;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_SETLKW"))
#ifdef F_SETLKW
	        return F_SETLKW;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_SETLKW64"))
#ifdef F_SETLKW64
	        return F_SETLKW64;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_SETOWN"))
#ifdef F_SETOWN
	        return F_SETOWN;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_SHARE"))
#ifdef F_SHARE
	        return F_SHARE;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_SHLCK"))
#ifdef F_SHLCK
	        return F_SHLCK;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_UNLCK"))
#ifdef F_UNLCK
	        return F_UNLCK;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_UNSHARE"))
#ifdef F_UNSHARE
	        return F_UNSHARE;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_WRACC"))
#ifdef F_WRACC
	        return F_WRACC;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_WRDNY"))
#ifdef F_WRDNY
	        return F_WRDNY;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "F_WRLCK"))
#ifdef F_WRLCK
	        return F_WRLCK;
#else
	        goto not_there;
#endif
	    errno = EINVAL;
	    return 0;
	}
        if (strEQ(name, "FAPPEND"))
#ifdef FAPPEND
            return FAPPEND;
#else
            goto not_there;
#endif
        if (strEQ(name, "FASYNC"))
#ifdef FASYNC
            return FASYNC;
#else
            goto not_there;
#endif
        if (strEQ(name, "FCREAT"))
#ifdef FCREAT
            return FCREAT;
#else
            goto not_there;
#endif
	if (strEQ(name, "FD_CLOEXEC"))
#ifdef FD_CLOEXEC
	    return FD_CLOEXEC;
#else
	    goto not_there;
#endif
	if (strEQ(name, "FDEFER"))
#ifdef FDEFER
	    return FDEFER;
#else
	    goto not_there;
#endif
        if (strEQ(name, "FDSYNC"))
#ifdef FDSYNC
            return FDSYNC;
#else
            goto not_there;
#endif
        if (strEQ(name, "FEXCL"))
#ifdef FEXCL
            return FEXCL;
#else
            goto not_there;
#endif
        if (strEQ(name, "FLARGEFILE"))
#ifdef FLARGEFILE
            return FLARGEFILE;
#else
            goto not_there;
#endif
        if (strEQ(name, "FNDELAY"))
#ifdef FNDELAY
            return FNDELAY;
#else
            goto not_there;
#endif
        if (strEQ(name, "FNONBLOCK"))
#ifdef FNONBLOCK
            return FNONBLOCK;
#else
            goto not_there;
#endif
        if (strEQ(name, "FRSYNC"))
#ifdef FRSYNC
            return FRSYNC;
#else
            goto not_there;
#endif
        if (strEQ(name, "FSYNC"))
#ifdef FSYNC
            return FSYNC;
#else
            goto not_there;
#endif
        if (strEQ(name, "FTRUNC"))
#ifdef FTRUNC
            return FTRUNC;
#else
            goto not_there;
#endif
	break;
    case 'L':
    	if (strnEQ(name, "LOCK_", 5)) {
	    /* We support flock() on systems which don't have it, so
	       always supply the constants. */
	    if (strEQ(name, "LOCK_SH"))
#ifdef LOCK_SH
		return LOCK_SH;
#else
		return 1;
#endif
	    if (strEQ(name, "LOCK_EX"))
#ifdef LOCK_EX
		return LOCK_EX;
#else
		return 2;
#endif
    	    if (strEQ(name, "LOCK_NB"))
#ifdef LOCK_NB
		return LOCK_NB;
#else
		return 4;
#endif
    	    if (strEQ(name, "LOCK_UN"))
#ifdef LOCK_UN
    	    	return LOCK_UN;
#else
    	    	return 8;
#endif
	} else
	  goto not_there;
    	break;
    case 'O':
	if (strnEQ(name, "O_", 2)) {
	    if (strEQ(name, "O_ACCMODE"))
#ifdef O_ACCMODE
	        return O_ACCMODE;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_APPEND"))
#ifdef O_APPEND
	        return O_APPEND;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_ASYNC"))
#ifdef O_ASYNC
	        return O_ASYNC;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_BINARY"))
#ifdef O_BINARY
	        return O_BINARY;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_CREAT"))
#ifdef O_CREAT
	        return O_CREAT;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_DEFER"))
#ifdef O_DEFER
	        return O_DEFER;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_DSYNC"))
#ifdef O_DSYNC
	        return O_DSYNC;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_EXCL"))
#ifdef O_EXCL
	        return O_EXCL;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_EXLOCK"))
#ifdef O_EXLOCK
	        return O_EXLOCK;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_LARGEFILE"))
#ifdef O_LARGEFILE
	        return O_LARGEFILE;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_NDELAY"))
#ifdef O_NDELAY
	        return O_NDELAY;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_NOCTTY"))
#ifdef O_NOCTTY
	        return O_NOCTTY;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_NONBLOCK"))
#ifdef O_NONBLOCK
	        return O_NONBLOCK;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_RDONLY"))
#ifdef O_RDONLY
	        return O_RDONLY;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_RDWR"))
#ifdef O_RDWR
	        return O_RDWR;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_RSYNC"))
#ifdef O_RSYNC
	        return O_RSYNC;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_SHLOCK"))
#ifdef O_SHLOCK
	        return O_SHLOCK;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_SYNC"))
#ifdef O_SYNC
	        return O_SYNC;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_TEXT"))
#ifdef O_TEXT
	        return O_TEXT;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_TRUNC"))
#ifdef O_TRUNC
	        return O_TRUNC;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_WRONLY"))
#ifdef O_WRONLY
	        return O_WRONLY;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_ALIAS"))
#ifdef O_ALIAS
	        return O_ALIAS;
#else
	        goto not_there;
#endif
	    if (strEQ(name, "O_RSRC"))
#ifdef O_RSRC
	        return O_RSRC;
#else
	        goto not_there;
#endif
	} else
	  goto not_there;
	break;
    case 'S':
      if (strEQ(name, "SEEK_CUR"))
#ifdef SEEK_CUR
	return SEEK_CUR;
#else
        goto not_there;
#endif
      if (strEQ(name, "SEEK_END"))
#ifdef SEEK_END
	return SEEK_END;
#else
        goto not_there;
#endif
      if (strEQ(name, "SEEK_SET"))
#ifdef SEEK_SET
	return SEEK_SET;
#else
        goto not_there;
#endif
        break;
    }
    errno = EINVAL;
    return 0;

not_there:
    errno = ENOENT;
    return 0;
}


MODULE = Fcntl		PACKAGE = Fcntl

double
constant(name,arg)
	char *		name
	int		arg

