#include "EXTERN.h"
#include "perl.h"

void
taint_not(s)
char *s;
{
    if (euid != uid)
        croak("No %s allowed while running setuid", s);
    if (egid != gid)
        croak("No %s allowed while running setgid", s);
}

void
taint_proper(f, s)
char *f;
char *s;
{
    if (tainting) {
	DEBUG_u(fprintf(stderr,"%s %d %d %d\n",s,tainted,uid, euid));
	if (tainted) {
	    char *ug = 0;
	    if (euid != uid)
		ug = " while running setuid";
	    else if (egid != gid)
		ug = " while running setgid";
	    else if (tainting)
		ug = " while running with -T switch";
	    if (ug) {
		if (!unsafe)
		    croak(f, s, ug);
		else if (dowarn)
		    warn(f, s, ug);
	    }
	}
    }
}

void
taint_env()
{
    SV** svp;

    if (tainting) {
	svp = hv_fetch(GvHVn(envgv),"PATH",4,FALSE);
	if (!svp || *svp == &sv_undef || mg_find(*svp, 't')) {
	    tainted = 1;
	    if (SvPRIVATE(*svp) & SVp_TAINTEDDIR)
		taint_proper("Insecure directory in %s%s", "PATH");
	    else
		taint_proper("Insecure %s%s", "PATH");
	}
	svp = hv_fetch(GvHVn(envgv),"IFS",3,FALSE);
	if (svp && *svp != &sv_undef && mg_find(*svp, 't')) {
	    tainted = 1;
	    taint_proper("Insecure %s%s", "IFS");
	}
    }
}
