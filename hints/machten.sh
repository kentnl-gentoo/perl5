# machten.sh
# This file has been put together by Mark Pease <peasem@primenet.com>
# Comments, questions, and improvements welcome!
#
# MachTen does not support dynamic loading. If you wish to, you
# can get <ftp://tsx-11.mit.edu/pub/linux/sources/libs/dld-src-3.2.4.tar.gz>
# compile and install. This is the version of DLD that works with the
# ext/DynaLoader/dl_dld.xs in the perl5 package. Have fun!
#
#  Original version was for MachTen 2.1.1.
#  Last modified by Andy Dougherty   <doughera@lafcol.lafayette.edu>
#  Wed Mar  8 15:58:05 EST 1995

# I don't know why this is needed.  It might be similar to NeXT's
# problem.  See hints/next_3_2.sh.
usemymalloc='n'

so='none'
# These are useful only if you have DLD, but harmless otherwise.
lddlflags='-r'
dlext='o'

# MachTen does not support POSIX enough to compile the POSIX module.
useposix=false

#MachTen might have an incomplete Berkeley DB implementation.
i_db=$undef