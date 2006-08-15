____________________________________________________________________________
[ 28726] By: rgs                                   on 2006/08/15  09:59:24
        Log: Update Module::CoreList data with 5.9.4
     Branch: perl
	   ! lib/Module/CoreList.pm
____________________________________________________________________________
[ 28725] By: rgs                                   on 2006/08/15  09:55:27
        Log: 5.9.4 is today.
     Branch: perl
	   ! pod/perlhist.pod
____________________________________________________________________________
[ 28724] By: rgs                                   on 2006/08/15  09:54:02
        Log: Actually, Richard Clamp doesn't maintain Module::CoreList anymore.
     Branch: perl
	   ! Porting/Maintainers.pl
____________________________________________________________________________
[ 28723] By: rgs                                   on 2006/08/15  09:43:40
        Log: Regenerate perlmodlib and perltoc
     Branch: perl
	   ! pod/perlmodlib.pod pod/perltoc.pod
____________________________________________________________________________
[ 28722] By: rgs                                   on 2006/08/15  09:40:08
        Log: POD formatting nit
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28721] By: rgs                                   on 2006/08/15  09:29:03
        Log: Remove some of the known problems documented in perldelta, which were
             caused by change #28319, just backed out. Add some Windows news (by
             Steve Hay)
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28720] By: rgs                                   on 2006/08/15  09:22:54
        Log: Revert change 28319, which may cause segfaults with threaded perls
             on eval("syntax error") statements
     Branch: perl
	   ! perly.c
____________________________________________________________________________
[ 28719] By: rgs                                   on 2006/08/15  07:57:54
        Log: More perldelta nits found by my reviewers
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28718] By: rgs                                   on 2006/08/14  22:30:18
        Log: Spelling fixes, thanks to Nicholas and to Ronald Kimball
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28717] By: rgs                                   on 2006/08/14  21:58:15
        Log: More perldelta entries and fixes
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28716] By: rgs                                   on 2006/08/14  21:31:43
        Log: Typo fix in the documentation of source filters in @INC
     Branch: perl
	   ! pod/perlfunc.pod
____________________________________________________________________________
[ 28715] By: mhx                                   on 2006/08/14  20:29:57
        Log: Only copy ppport.h to destination if it is different.
             This avoids unneccessary rebuilds.
     Branch: perl
	   ! mkppport
____________________________________________________________________________
[ 28714] By: mhx                                   on 2006/08/14  19:43:23
        Log: Upgrade to Devel::PPPort 3.10
     Branch: perl
	   ! ext/Devel/PPPort/Changes ext/Devel/PPPort/PPPort_pm.PL
	   ! ext/Devel/PPPort/soak
____________________________________________________________________________
[ 28713] By: rgs                                   on 2006/08/14  19:30:17
        Log: perldelta entry describing regexp work, by Yves Orton
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28712] By: rgs                                   on 2006/08/14  15:27:51
        Log: Regenerate metafile
     Branch: perl
	   ! META.yml
____________________________________________________________________________
[ 28711] By: rgs                                   on 2006/08/14  14:24:19
        Log: New authors
     Branch: perl
	   ! AUTHORS
____________________________________________________________________________
[ 28710] By: rgs                                   on 2006/08/14  12:45:59
        Log: More perldelta entries; plus, credits.
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28709] By: rgs                                   on 2006/08/14  12:35:13
        Log: Typo fix in perldiag
     Branch: perl
	   ! pod/perldiag.pod
____________________________________________________________________________
[ 28708] By: steveh                                on 2006/08/14  10:20:13
        Log: Update pod/perl594delta.pod w.r.t. #28706, and arrange list of modules
             alphabetically.
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28707] By: steveh                                on 2006/08/14  10:15:04
        Log: Update Porting/Maintainers.pl w.r.t. #28695, #28703 and #28706.
     Branch: perl
	   ! Porting/Maintainers.pl
____________________________________________________________________________
[ 28706] By: steveh                                on 2006/08/14  10:10:07
        Log: Subject: [PATCH] Add Module::Loaded to the core
             From: kane@xs4all.nl
             Date: Sun, 13 Aug 2006 16:22:09 +0200 (CEST)
             Message-ID: <9310.80.127.35.68.1155478929.squirrel@webmail.xs4all.nl>
     Branch: perl
	   + lib/Module/Loaded.pm lib/Module/Loaded/t/01_Module-Loaded.t
	   ! MANIFEST
____________________________________________________________________________
[ 28705] By: rgs                                   on 2006/08/14  09:30:38
        Log: More perldelta nits.
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28704] By: rgs                                   on 2006/08/14  09:19:02
        Log: Make the NAME section of Package::Constants more conformant to
             man page conventions
     Branch: perl
	   ! lib/Package/Constants.pm
____________________________________________________________________________
[ 28703] By: steveh                                on 2006/08/14  09:09:40
        Log: Subject: [PATCH] Add Package::Constants to the core
             From: kane@xs4all.nl
             Date: Sat, 12 Aug 2006 23:57:58 +0200 (CEST)
             Message-ID: <9749.80.127.35.68.1155419878.squirrel@webmail.xs4all.nl>
     Branch: perl
	   + lib/Package/Constants.pm lib/Package/Constants/t/01_list.t
	   ! MANIFEST
____________________________________________________________________________
[ 28702] By: nicholas                              on 2006/08/13  19:51:41
        Log: Regularise the indents of Changes to placate Porting/checkAUTHORS.pl
     Branch: perl
	   ! Changes
____________________________________________________________________________
[ 28701] By: rgs                                   on 2006/08/13  13:53:54
        Log: Fix URL of perlbug database
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28700] By: rgs                                   on 2006/08/13  12:44:18
        Log: More perldelta entries
     Branch: perl
	   ! pod/perl594delta.pod
____________________________________________________________________________
[ 28699] By: rgs                                   on 2006/08/13  07:51:46
        Log: Fix a couple URLs in perlhack
     Branch: perl
	   ! pod/perlhack.pod
____________________________________________________________________________
[ 28698] By: rgs                                   on 2006/08/12  12:53:32
        Log: Subject: [PATCH] perlhack.pod: more portability pitfalls
             From: Jarkko Hietaniemi <jhi@cc.hut.fi>
             Date: Sat, 12 Aug 2006 10:33:38 +0300 (EEST)
             Message-Id: <200608120733.k7C7XcU0268432@kosh.hut.fi>
     Branch: perl
	   ! pod/perlhack.pod
____________________________________________________________________________
[ 28697] By: steveh                                on 2006/08/11  17:31:45
        Log: Resync win32/config_H.* and win32/config.* with config_h.SH
             and Porting/config.sh respectively
             
             No real changes except for the addition of the missing
             HAS_C99_VARIADIC_MACROS to win32/config_H.* and
             initialinstalllocation, madlyh, madlyobj and madlysrc to
             win32/config.*
     Branch: perl
	   ! win32/config.bc win32/config.gc win32/config.vc
	   ! win32/config.vc64 win32/config_H.bc win32/config_H.gc
	   ! win32/config_H.vc win32/config_H.vc64
____________________________________________________________________________
[ 28696] By: rgs                                   on 2006/08/11  16:02:32
        Log: More perldelta notes. Also, I did forget things
             in perl593delta...
     Branch: perl
	   ! pod/perl593delta.pod pod/perl594delta.pod
____________________________________________________________________________
[ 28695] By: steveh                                on 2006/08/11  12:52:51
        Log: Subject: [PATCH] Add Module::Load to 5.9.x
             From: kane@xs4all.nl
             Date: Wed, 9 Aug 2006 12:23:42 +0200 (CEST)
             Message-ID: <9866.194.109.0.185.1155119022.squirrel@webmail.xs4all.nl>
     Branch: perl
	   + lib/Module/Load.pm lib/Module/Load/t/01_Module-Load.t
	   + lib/Module/Load/t/to_load/LoadIt.pm
	   + lib/Module/Load/t/to_load/LoadMe.pl
	   + lib/Module/Load/t/to_load/Must/Be/Loaded.pm
	   + lib/Module/Load/t/to_load/TestModule.pm
	   + lib/Module/Load/t/to_load/ToBeLoaded
	   + lib/Module/Load/t/to_load/config_file
	   ! MANIFEST
____________________________________________________________________________
[ 28694] By: steveh                                on 2006/08/11  12:49:00
        Log: Close file before unlinking (on Win32 at least!)
     Branch: perl
	   ! t/op/stat.t
____________________________________________________________________________
[ 28693] By: rgs                                   on 2006/08/10  16:46:07
        Log: Subject: [PATCH] Re: Smoke [5.9.4] 28683 FAIL(F) Solaris 2.11 (i386/1 cpu)
             From: Andrew Dougherty <doughera@lafayette.edu>
             Date: Thu, 10 Aug 2006 12:37:39 -0400 (EDT)
             Message-ID: <Pine.LNX.4.62.0608101230260.12531@fractal.phys.lafayette.edu>
     Branch: perl
	   ! lib/open.t
____________________________________________________________________________
[ 28692] By: rgs                                   on 2006/08/10  14:27:44
        Log: Update Changes
     Branch: perl
	   ! Changes
____________________________________________________________________________
[ 28691] By: rgs                                   on 2006/08/10  13:17:51
        Log: Some updates to the cross-compilation config script
     Branch: perl
	   ! Cross/config.sh-arm-linux
