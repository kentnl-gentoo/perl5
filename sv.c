/* $RCSfile: sv.c,v $$Revision: 4.1 $$Date: 92/08/07 18:26:45 $
 *
 *    Copyright (c) 1991, Larry Wall
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 * $Log:	sv.c,v $
 * Revision 4.1  92/08/07  18:26:45  lwall
 * 
 * Revision 4.0.1.6  92/06/11  21:14:21  lwall
 * patch34: quotes containing subscripts containing variables didn't parse right
 * 
 * Revision 4.0.1.5  92/06/08  15:40:43  lwall
 * patch20: removed implicit int declarations on functions
 * patch20: Perl now distinguishes overlapped copies from non-overlapped
 * patch20: paragraph mode now skips extra newlines automatically
 * patch20: fixed memory leak in doube-quote interpretation
 * patch20: made /\$$foo/ look for literal '$foo'
 * patch20: "$var{$foo'bar}" didn't scan subscript correctly
 * patch20: a splice on non-existent array elements could dump core
 * patch20: running taintperl explicitly now does checks even if $< == $>
 * 
 * Revision 4.0.1.4  91/11/05  18:40:51  lwall
 * patch11: $foo .= <BAR> could overrun malloced memory
 * patch11: \$ didn't always make it through double-quoter to regexp routines
 * patch11: prepared for ctype implementations that don't define isascii()
 * 
 * Revision 4.0.1.3  91/06/10  01:27:54  lwall
 * patch10: $) and $| incorrectly handled in run-time patterns
 * 
 * Revision 4.0.1.2  91/06/07  11:58:13  lwall
 * patch4: new copyright notice
 * patch4: taint check on undefined string could cause core dump
 * 
 * Revision 4.0.1.1  91/04/12  09:15:30  lwall
 * patch1: fixed undefined environ problem
 * patch1: substr($ENV{"PATH"},0,0) = "/foo:" didn't modify environment
 * patch1: $foo .= <BAR> could cause core dump for certain lengths of $foo
 * 
 * Revision 4.0  91/03/20  01:39:55  lwall
 * 4.0 baseline.
 * 
 */

#include "EXTERN.h"
#include "perl.h"
#include "perly.h"

static void ucase();
static void lcase();

static SV* sv_root;

static SV* more_sv();

static SV*
new_sv()
{
    SV* sv;
    if (sv_root) {
	sv = sv_root;
	sv_root = (SV*)SvANY(sv);
	return sv;
    }
    return more_sv();
}

static void
del_sv(p)
SV* p;
{
    SvANY(p) = sv_root;
    sv_root = p;
}

static SV*
more_sv()
{
    register int i;
    register SV* sv;
    register SV* svend;
    sv_root = (SV*)malloc(1008);
    sv = sv_root;
    svend = &sv[1008 / sizeof(SV) - 1];
    while (sv < svend) {
	SvANY(sv) = (SV*)(sv + 1);
	sv++;
    }
    SvANY(sv) = 0;
    return new_sv();
}

static I32* xiv_root;

static XPVIV* more_xiv();

static XPVIV*
new_xiv()
{
    I32* xiv;
    if (xiv_root) {
	xiv = xiv_root;
	xiv_root = *(I32**)xiv;
	return (XPVIV*)((char*)xiv - sizeof(XPV));
    }
    return more_xiv();
}

static void
del_xiv(p)
XPVIV* p;
{
    I32* xiv = (I32*)((char*)(p) + sizeof(XPV));
    *(I32**)xiv = xiv_root;
    xiv_root = xiv;
}

static XPVIV*
more_xiv()
{
    register int i;
    register I32* xiv;
    register I32* xivend;
    xiv = (I32*)malloc(1008);
    xivend = &xiv[1008 / sizeof(I32) - 1];
    xiv += (sizeof(XPV) - 1) / sizeof(I32) + 1;   /* fudge by size of XPV */
    xiv_root = xiv;
    while (xiv < xivend) {
	*(I32**)xiv = (I32*)(xiv + 1); /* XXX busted on Alpha? */
	xiv++;
    }
    *(I32**)xiv = 0;
    return new_xiv();
}

static double* xnv_root;

static XPVNV* more_xnv();

static XPVNV*
new_xnv()
{
    double* xnv;
    if (xnv_root) {
	xnv = xnv_root;
	xnv_root = *(double**)xnv;
	return (XPVNV*)((char*)xnv - sizeof(XPVIV));
    }
    return more_xnv();
}

static void
del_xnv(p)
XPVNV* p;
{
    double* xnv = (double*)((char*)(p) + sizeof(XPVIV));
    *(double**)xnv = xnv_root;
    xnv_root = xnv;
}

static XPVNV*
more_xnv()
{
    register int i;
    register double* xnv;
    register double* xnvend;
    xnv = (double*)malloc(1008);
    xnvend = &xnv[1008 / sizeof(double) - 1];
    xnv += (sizeof(XPVIV) - 1) / sizeof(double) + 1; /* fudge by sizeof XPVIV */
    xnv_root = xnv;
    while (xnv < xnvend) {
	*(double**)xnv = (double*)(xnv + 1);
	xnv++;
    }
    *(double**)xnv = 0;
    return new_xnv();
}

static XPV* xpv_root;

static XPV* more_xpv();

static XPV*
new_xpv()
{
    XPV* xpv;
    if (xpv_root) {
	xpv = xpv_root;
	xpv_root = (XPV*)xpv->xpv_pv;
	return xpv;
    }
    return more_xpv();
}

static void
del_xpv(p)
XPV* p;
{
    p->xpv_pv = (char*)xpv_root;
    xpv_root = p;
}

static XPV*
more_xpv()
{
    register int i;
    register XPV* xpv;
    register XPV* xpvend;
    xpv_root = (XPV*)malloc(1008);
    xpv = xpv_root;
    xpvend = &xpv[1008 / sizeof(XPV) - 1];
    while (xpv < xpvend) {
	xpv->xpv_pv = (char*)(xpv + 1);
	xpv++;
    }
    xpv->xpv_pv = 0;
    return new_xpv();
}

#ifdef PURIFY

#define new_SV() sv = (SV*)malloc(sizeof(SV))
#define del_SV(p) free((char*)p)

#else

#define new_SV()			\
    if (sv_root) {			\
	sv = sv_root;			\
	sv_root = (SV*)SvANY(sv);	\
    }					\
    else				\
	sv = more_sv();
#define del_SV(p) del_sv(p)

#endif

#ifdef PURIFY
#define new_XIV() (void*)malloc(sizeof(XPVIV))
#define del_XIV(p) free((char*)p)
#else
#define new_XIV() new_xiv()
#define del_XIV(p) del_xiv(p)
#endif

#ifdef PURIFY
#define new_XNV() (void*)malloc(sizeof(XPVNV))
#define del_XNV(p) free((char*)p)
#else
#define new_XNV() new_xnv()
#define del_XNV(p) del_xnv(p)
#endif

#ifdef PURIFY
#define new_XPV() (void*)malloc(sizeof(XPV))
#define del_XPV(p) free((char*)p)
#else
#define new_XPV() new_xpv()
#define del_XPV(p) del_xpv(p)
#endif

#define new_XPVIV() (void*)malloc(sizeof(XPVIV))
#define del_XPVIV(p) free((char*)p)

#define new_XPVNV() (void*)malloc(sizeof(XPVNV))
#define del_XPVNV(p) free((char*)p)

#define new_XPVMG() (void*)malloc(sizeof(XPVMG))
#define del_XPVMG(p) free((char*)p)

#define new_XPVLV() (void*)malloc(sizeof(XPVLV))
#define del_XPVLV(p) free((char*)p)

#define new_XPVAV() (void*)malloc(sizeof(XPVAV))
#define del_XPVAV(p) free((char*)p)

#define new_XPVHV() (void*)malloc(sizeof(XPVHV))
#define del_XPVHV(p) free((char*)p)

#define new_XPVCV() (void*)malloc(sizeof(XPVCV))
#define del_XPVCV(p) free((char*)p)

#define new_XPVGV() (void*)malloc(sizeof(XPVGV))
#define del_XPVGV(p) free((char*)p)

#define new_XPVBM() (void*)malloc(sizeof(XPVBM))
#define del_XPVBM(p) free((char*)p)

#define new_XPVFM() (void*)malloc(sizeof(XPVFM))
#define del_XPVFM(p) free((char*)p)

bool
sv_upgrade(sv, mt)
register SV* sv;
U32 mt;
{
    char*	pv;
    U32		cur;
    U32		len;
    I32		iv;
    double	nv;
    MAGIC*	magic;
    HV*		stash;

    if (SvTYPE(sv) == mt)
	return TRUE;

    switch (SvTYPE(sv)) {
    case SVt_NULL:
	pv	= 0;
	cur	= 0;
	len	= 0;
	iv	= 0;
	nv	= 0.0;
	magic	= 0;
	stash	= 0;
	break;
    case SVt_REF:
	sv_free((SV*)SvANY(sv));
	pv	= 0;
	cur	= 0;
	len	= 0;
	iv	= (I32)SvANY(sv);
	nv	= (double)(unsigned long)SvANY(sv);
	SvNOK_only(sv);
	magic	= 0;
	stash	= 0;
	if (mt == SVt_PV)
	    mt = SVt_PVIV;
	break;
    case SVt_IV:
	pv	= 0;
	cur	= 0;
	len	= 0;
	iv	= SvIVX(sv);
	nv	= (double)SvIVX(sv);
	del_XIV(SvANY(sv));
	magic	= 0;
	stash	= 0;
	if (mt == SVt_PV)
	    mt = SVt_PVIV;
	else if (mt == SVt_NV)
	    mt = SVt_PVNV;
	break;
    case SVt_NV:
	pv	= 0;
	cur	= 0;
	len	= 0;
	nv	= SvNVX(sv);
	iv	= (I32)nv;
	magic	= 0;
	stash	= 0;
	del_XNV(SvANY(sv));
	SvANY(sv) = 0;
	if (mt == SVt_PV || mt == SVt_PVIV)
	    mt = SVt_PVNV;
	break;
    case SVt_PV:
	nv = 0.0;
	pv	= SvPVX(sv);
	cur	= SvCUR(sv);
	len	= SvLEN(sv);
	iv	= 0;
	nv	= 0.0;
	magic	= 0;
	stash	= 0;
	del_XPV(SvANY(sv));
	break;
    case SVt_PVIV:
	nv = 0.0;
	pv	= SvPVX(sv);
	cur	= SvCUR(sv);
	len	= SvLEN(sv);
	iv	= SvIVX(sv);
	nv	= 0.0;
	magic	= 0;
	stash	= 0;
	del_XPVIV(SvANY(sv));
	break;
    case SVt_PVNV:
	nv = SvNVX(sv);
	pv	= SvPVX(sv);
	cur	= SvCUR(sv);
	len	= SvLEN(sv);
	iv	= SvIVX(sv);
	nv	= SvNVX(sv);
	magic	= 0;
	stash	= 0;
	del_XPVNV(SvANY(sv));
	break;
    case SVt_PVMG:
	pv	= SvPVX(sv);
	cur	= SvCUR(sv);
	len	= SvLEN(sv);
	iv	= SvIVX(sv);
	nv	= SvNVX(sv);
	magic	= SvMAGIC(sv);
	stash	= SvSTASH(sv);
	del_XPVMG(SvANY(sv));
	break;
    default:
	croak("Can't upgrade that kind of scalar");
    }

    switch (mt) {
    case SVt_NULL:
	croak("Can't upgrade to undef");
    case SVt_REF:
	SvOK_on(sv);
	break;
    case SVt_IV:
	SvANY(sv) = new_XIV();
	SvIVX(sv)	= iv;
	break;
    case SVt_NV:
	SvANY(sv) = new_XNV();
	SvNVX(sv)	= nv;
	break;
    case SVt_PV:
	SvANY(sv) = new_XPV();
	SvPVX(sv)	= pv;
	SvCUR(sv)	= cur;
	SvLEN(sv)	= len;
	break;
    case SVt_PVIV:
	SvANY(sv) = new_XPVIV();
	SvPVX(sv)	= pv;
	SvCUR(sv)	= cur;
	SvLEN(sv)	= len;
	SvIVX(sv)	= iv;
	if (SvNIOK(sv))
	    SvIOK_on(sv);
	SvNOK_off(sv);
	break;
    case SVt_PVNV:
	SvANY(sv) = new_XPVNV();
	SvPVX(sv)	= pv;
	SvCUR(sv)	= cur;
	SvLEN(sv)	= len;
	SvIVX(sv)	= iv;
	SvNVX(sv)	= nv;
	break;
    case SVt_PVMG:
	SvANY(sv) = new_XPVMG();
	SvPVX(sv)	= pv;
	SvCUR(sv)	= cur;
	SvLEN(sv)	= len;
	SvIVX(sv)	= iv;
	SvNVX(sv)	= nv;
	SvMAGIC(sv)	= magic;
	SvSTASH(sv)	= stash;
	break;
    case SVt_PVLV:
	SvANY(sv) = new_XPVLV();
	SvPVX(sv)	= pv;
	SvCUR(sv)	= cur;
	SvLEN(sv)	= len;
	SvIVX(sv)	= iv;
	SvNVX(sv)	= nv;
	SvMAGIC(sv)	= magic;
	SvSTASH(sv)	= stash;
	LvTARGOFF(sv)	= 0;
	LvTARGLEN(sv)	= 0;
	LvTARG(sv)	= 0;
	LvTYPE(sv)	= 0;
	break;
    case SVt_PVAV:
	SvANY(sv) = new_XPVAV();
	if (pv)
	    Safefree(pv);
	AvARRAY(sv)	= 0;
	AvMAX(sv)	= 0;
	AvFILL(sv)	= 0;
	SvIVX(sv)	= 0;
	SvNVX(sv)	= 0.0;
	SvMAGIC(sv)	= magic;
	SvSTASH(sv)	= stash;
	AvALLOC(sv)	= 0;
	AvARYLEN(sv)	= 0;
	AvFLAGS(sv)	= 0;
	break;
    case SVt_PVHV:
	SvANY(sv) = new_XPVHV();
	if (pv)
	    Safefree(pv);
	SvPVX(sv)	= 0;
	HvFILL(sv)	= 0;
	HvMAX(sv)	= 0;
	HvKEYS(sv)	= 0;
	SvNVX(sv)	= 0.0;
	SvMAGIC(sv)	= magic;
	SvSTASH(sv)	= stash;
	HvRITER(sv)	= 0;
	HvEITER(sv)	= 0;
	HvPMROOT(sv)	= 0;
	HvNAME(sv)	= 0;
	break;
    case SVt_PVCV:
	SvANY(sv) = new_XPVCV();
	SvPVX(sv)	= pv;
	SvCUR(sv)	= cur;
	SvLEN(sv)	= len;
	SvIVX(sv)	= iv;
	SvNVX(sv)	= nv;
	SvMAGIC(sv)	= magic;
	SvSTASH(sv)	= stash;
	CvSTASH(sv)	= 0;
	CvSTART(sv)	= 0;
	CvROOT(sv)	= 0;
	CvUSERSUB(sv)	= 0;
	CvUSERINDEX(sv)	= 0;
	CvFILEGV(sv)	= 0;
	CvDEPTH(sv)	= 0;
	CvPADLIST(sv)	= 0;
	CvDELETED(sv)	= 0;
	break;
    case SVt_PVGV:
	SvANY(sv) = new_XPVGV();
	SvPVX(sv)	= pv;
	SvCUR(sv)	= cur;
	SvLEN(sv)	= len;
	SvIVX(sv)	= iv;
	SvNVX(sv)	= nv;
	SvMAGIC(sv)	= magic;
	SvSTASH(sv)	= stash;
	GvGP(sv)	= 0;
	GvNAME(sv)	= 0;
	GvNAMELEN(sv)	= 0;
	GvSTASH(sv)	= 0;
	break;
    case SVt_PVBM:
	SvANY(sv) = new_XPVBM();
	SvPVX(sv)	= pv;
	SvCUR(sv)	= cur;
	SvLEN(sv)	= len;
	SvIVX(sv)	= iv;
	SvNVX(sv)	= nv;
	SvMAGIC(sv)	= magic;
	SvSTASH(sv)	= stash;
	BmRARE(sv)	= 0;
	BmUSEFUL(sv)	= 0;
	BmPREVIOUS(sv)	= 0;
	break;
    case SVt_PVFM:
	SvANY(sv) = new_XPVFM();
	SvPVX(sv)	= pv;
	SvCUR(sv)	= cur;
	SvLEN(sv)	= len;
	SvIVX(sv)	= iv;
	SvNVX(sv)	= nv;
	SvMAGIC(sv)	= magic;
	SvSTASH(sv)	= stash;
	FmLINES(sv)	= 0;
	break;
    }
    SvTYPE(sv) = mt;
    return TRUE;
}

char *
sv_peek(sv)
register SV *sv;
{
    char *t = tokenbuf;
    *t = '\0';

  retry:
    if (!sv) {
	strcpy(t, "VOID");
	return tokenbuf;
    }
    else if (sv == (SV*)0x55555555 || SvTYPE(sv) == 'U') {
	strcpy(t, "WILD");
	return tokenbuf;
    }
    else if (SvREFCNT(sv) == 0 && !SvREADONLY(sv)) {
	strcpy(t, "UNREF");
	return tokenbuf;
    }
    else {
	switch (SvTYPE(sv)) {
	default:
	    strcpy(t,"FREED");
	    return tokenbuf;
	    break;

	case SVt_NULL:
	    strcpy(t,"UNDEF");
	    return tokenbuf;
	case SVt_REF:
	    *t++ = '\\';
	    if (t - tokenbuf > 10) {
		strcpy(tokenbuf + 3,"...");
		return tokenbuf;
	    }
	    sv = (SV*)SvANY(sv);
	    goto retry;
	case SVt_IV:
	    strcpy(t,"IV");
	    break;
	case SVt_NV:
	    strcpy(t,"NV");
	    break;
	case SVt_PV:
	    strcpy(t,"PV");
	    break;
	case SVt_PVIV:
	    strcpy(t,"PVIV");
	    break;
	case SVt_PVNV:
	    strcpy(t,"PVNV");
	    break;
	case SVt_PVMG:
	    strcpy(t,"PVMG");
	    break;
	case SVt_PVLV:
	    strcpy(t,"PVLV");
	    break;
	case SVt_PVAV:
	    strcpy(t,"AV");
	    break;
	case SVt_PVHV:
	    strcpy(t,"HV");
	    break;
	case SVt_PVCV:
	    strcpy(t,"CV");
	    break;
	case SVt_PVGV:
	    strcpy(t,"GV");
	    break;
	case SVt_PVBM:
	    strcpy(t,"BM");
	    break;
	case SVt_PVFM:
	    strcpy(t,"FM");
	    break;
	}
    }
    t += strlen(t);

    if (SvPOK(sv)) {
	if (!SvPVX(sv))
	    return "(null)";
	if (SvOOK(sv))
	    sprintf(t,"(%d+\"%0.127s\")",SvIVX(sv),SvPVX(sv));
	else
	    sprintf(t,"(\"%0.127s\")",SvPVX(sv));
    }
    else if (SvNOK(sv))
	sprintf(t,"(%g)",SvNVX(sv));
    else if (SvIOK(sv))
	sprintf(t,"(%ld)",(long)SvIVX(sv));
    else
	strcpy(t,"()");
    return tokenbuf;
}

int
sv_backoff(sv)
register SV *sv;
{
    assert(SvOOK(sv));
    if (SvIVX(sv)) {
	char *s = SvPVX(sv);
	SvLEN(sv) += SvIVX(sv);
	SvPVX(sv) -= SvIVX(sv);
	SvIV_set(sv, 0);
	Move(s, SvPVX(sv), SvCUR(sv)+1, char);
    }
    SvFLAGS(sv) &= ~SVf_OOK;
}

char *
sv_grow(sv,newlen)
register SV *sv;
#ifndef DOSISH
register I32 newlen;
#else
unsigned long newlen;
#endif
{
    register char *s;

#ifdef MSDOS
    if (newlen >= 0x10000) {
	fprintf(stderr, "Allocation too large: %lx\n", newlen);
	my_exit(1);
    }
#endif /* MSDOS */
    if (SvREADONLY(sv))
	croak(no_modify);
    if (SvTYPE(sv) < SVt_PV) {
	sv_upgrade(sv, SVt_PV);
	s = SvPVX(sv);
    }
    else if (SvOOK(sv)) {	/* pv is offset? */
	sv_backoff(sv);
	s = SvPVX(sv);
	if (newlen > SvLEN(sv))
	    newlen += 10 * (newlen - SvCUR(sv)); /* avoid copy each time */
    }
    else
	s = SvPVX(sv);
    if (newlen > SvLEN(sv)) {		/* need more room? */
        if (SvLEN(sv))
	    Renew(s,newlen,char);
        else
	    New(703,s,newlen,char);
	SvPV_set(sv, s);
        SvLEN_set(sv, newlen);
    }
    return s;
}

void
sv_setiv(sv,i)
register SV *sv;
I32 i;
{
    if (SvREADONLY(sv))
	croak(no_modify);
    switch (SvTYPE(sv)) {
    case SVt_NULL:
    case SVt_REF:
	sv_upgrade(sv, SVt_IV);
	break;
    case SVt_NV:
	sv_upgrade(sv, SVt_PVNV);
	break;
    case SVt_PV:
	sv_upgrade(sv, SVt_PVIV);
	break;
    }
    SvIVX(sv) = i;
    SvIOK_only(sv);			/* validate number */
    SvTAINT(sv);
}

void
sv_setnv(sv,num)
register SV *sv;
double num;
{
    if (SvREADONLY(sv))
	croak(no_modify);
    if (SvTYPE(sv) < SVt_NV)
	sv_upgrade(sv, SVt_NV);
    else if (SvTYPE(sv) < SVt_PVNV)
	sv_upgrade(sv, SVt_PVNV);
    else if (SvPOK(sv)) {
	SvOOK_off(sv);
    }
    SvNVX(sv) = num;
    SvNOK_only(sv);			/* validate number */
    SvTAINT(sv);
}

I32
sv_2iv(sv)
register SV *sv;
{
    if (!sv)
	return 0;
    if (SvMAGICAL(sv)) {
	mg_get(sv);
	if (SvIOKp(sv))
	    return SvIVX(sv);
	if (SvNOKp(sv))
	    return (I32)SvNVX(sv);
	if (SvPOKp(sv) && SvLEN(sv))
	    return (I32)atol(SvPVX(sv));
	return 0;
    }
    if (SvREADONLY(sv)) {
	if (SvNOK(sv))
	    return (I32)SvNVX(sv);
	if (SvPOK(sv) && SvLEN(sv))
	    return (I32)atol(SvPVX(sv));
	if (dowarn)
	    warn("Use of uninitialized variable");
	return 0;
    }
    switch (SvTYPE(sv)) {
    case SVt_REF:
	return (I32)SvANY(sv);
    case SVt_NULL:
	sv_upgrade(sv, SVt_IV);
	return SvIVX(sv);
    case SVt_PV:
	sv_upgrade(sv, SVt_PVIV);
	break;
    case SVt_NV:
	sv_upgrade(sv, SVt_PVNV);
	break;
    }
    if (SvNOK(sv))
	SvIVX(sv) = (I32)SvNVX(sv);
    else if (SvPOK(sv) && SvLEN(sv)) {
	if (dowarn && !looks_like_number(sv)) {
	    if (op)
		warn("Argument wasn't numeric for \"%s\"",op_name[op->op_type]);
	    else
		warn("Argument wasn't numeric");
	}
	SvIVX(sv) = (I32)atol(SvPVX(sv));
    }
    else  {
	if (dowarn)
	    warn("Use of uninitialized variable");
	SvUPGRADE(sv, SVt_IV);
	SvIVX(sv) = 0;
    }
    SvIOK_on(sv);
    DEBUG_c((stderr,"0x%lx 2iv(%d)\n",sv,SvIVX(sv)));
    return SvIVX(sv);
}

double
sv_2nv(sv)
register SV *sv;
{
    if (!sv)
	return 0.0;
    if (SvMAGICAL(sv)) {
	mg_get(sv);
	if (SvNOKp(sv))
	    return SvNVX(sv);
	if (SvPOKp(sv) && SvLEN(sv))
	    return atof(SvPVX(sv));
	if (SvIOKp(sv))
	    return (double)SvIVX(sv);
	return 0;
    }
    if (SvREADONLY(sv)) {
	if (SvPOK(sv) && SvLEN(sv))
	    return atof(SvPVX(sv));
	if (dowarn)
	    warn("Use of uninitialized variable");
	return 0.0;
    }
    if (SvTYPE(sv) < SVt_NV) {
	if (SvTYPE(sv) == SVt_REF)
	    return (double)(unsigned long)SvANY(sv);
	if (SvTYPE(sv) == SVt_IV)
	    sv_upgrade(sv, SVt_PVNV);
	else
	    sv_upgrade(sv, SVt_NV);
	DEBUG_c((stderr,"0x%lx num(%g)\n",sv,SvNVX(sv)));
	return SvNVX(sv);
    }
    else if (SvTYPE(sv) < SVt_PVNV)
	sv_upgrade(sv, SVt_PVNV);
    if (SvIOK(sv) &&
	    (!SvPOK(sv) || !strchr(SvPVX(sv),'.') || !looks_like_number(sv)))
    {
	SvNVX(sv) = (double)SvIVX(sv);
    }
    else if (SvPOK(sv) && SvLEN(sv)) {
	if (dowarn && !SvIOK(sv) && !looks_like_number(sv)) {
	    if (op)
		warn("Argument wasn't numeric for \"%s\"",op_name[op->op_type]);
	    else
		warn("Argument wasn't numeric");
	}
	SvNVX(sv) = atof(SvPVX(sv));
    }
    else  {
	if (dowarn)
	    warn("Use of uninitialized variable");
	SvNVX(sv) = 0.0;
    }
    SvNOK_on(sv);
    DEBUG_c((stderr,"0x%lx 2nv(%g)\n",sv,SvNVX(sv)));
    return SvNVX(sv);
}

char *
sv_2pv(sv, lp)
register SV *sv;
STRLEN *lp;
{
    register char *s;
    int olderrno;

    if (!sv) {
	*lp = 0;
	return "";
    }
    if (SvMAGICAL(sv)) {
	mg_get(sv);
	if (SvPOKp(sv)) {
	    *lp = SvCUR(sv);
	    return SvPVX(sv);
	}
	if (SvIOKp(sv)) {
	    (void)sprintf(tokenbuf,"%ld",SvIVX(sv));
	    *lp = strlen(tokenbuf);
	    return tokenbuf;
	}
	if (SvNOKp(sv)) {
	    (void)sprintf(tokenbuf,"%.20g",SvNVX(sv));
	    *lp = strlen(tokenbuf);
	    return tokenbuf;
	}
	*lp = 0;
	return "";
    }
    if (SvTYPE(sv) == SVt_REF) {
	sv = (SV*)SvANY(sv);
	if (!sv)
	    s = "NULLREF";
	else {
	    switch (SvTYPE(sv)) {
	    case SVt_NULL:
	    case SVt_REF:
	    case SVt_IV:
	    case SVt_NV:
	    case SVt_PV:
	    case SVt_PVIV:
	    case SVt_PVNV:
	    case SVt_PVMG:	s = "SCALAR";			break;
	    case SVt_PVLV:	s = "LVALUE";			break;
	    case SVt_PVAV:	s = "ARRAY";			break;
	    case SVt_PVHV:	s = "HASH";			break;
	    case SVt_PVCV:	s = "CODE";			break;
	    case SVt_PVGV:	s = "GLOB";			break;
	    case SVt_PVBM:	s = "SEARCHSTRING";			break;
	    case SVt_PVFM:	s = "FORMATLINE";			break;
	    default:		s = "UNKNOWN";			break;
	    }
	    if (SvSTORAGE(sv) == 'O')
		sprintf(tokenbuf, "%s=%s(0x%lx)",
			    HvNAME(SvSTASH(sv)), s, (unsigned long)sv);
	    else
		sprintf(tokenbuf, "%s(0x%lx)", s, (unsigned long)sv);
	    s = tokenbuf;
	}
	*lp = strlen(s);
	return s;
    }
    if (SvREADONLY(sv)) {
	if (SvIOK(sv)) {
	    (void)sprintf(tokenbuf,"%ld",SvIVX(sv));
	    *lp = strlen(tokenbuf);
	    return tokenbuf;
	}
	if (SvNOK(sv)) {
	    (void)sprintf(tokenbuf,"%.20g",SvNVX(sv));
	    *lp = strlen(tokenbuf);
	    return tokenbuf;
	}
	if (dowarn)
	    warn("Use of uninitialized variable");
	*lp = 0;
	return "";
    }
    if (!SvUPGRADE(sv, SVt_PV))
	return 0;
    if (SvNOK(sv)) {
	if (SvTYPE(sv) < SVt_PVNV)
	    sv_upgrade(sv, SVt_PVNV);
	SvGROW(sv, 28);
	s = SvPVX(sv);
	olderrno = errno;	/* some Xenix systems wipe out errno here */
#if defined(scs) && defined(ns32000)
	gcvt(SvNVX(sv),20,s);
#else
#ifdef apollo
	if (SvNVX(sv) == 0.0)
	    (void)strcpy(s,"0");
	else
#endif /*apollo*/
	(void)sprintf(s,"%.20g",SvNVX(sv));
#endif /*scs*/
	errno = olderrno;
	while (*s) s++;
#ifdef hcx
	if (s[-1] == '.')
	    s--;
#endif
    }
    else if (SvIOK(sv)) {
	if (SvTYPE(sv) < SVt_PVIV)
	    sv_upgrade(sv, SVt_PVIV);
	SvGROW(sv, 11);
	s = SvPVX(sv);
	olderrno = errno;	/* some Xenix systems wipe out errno here */
	(void)sprintf(s,"%ld",SvIVX(sv));
	errno = olderrno;
	while (*s) s++;
    }
    else {
	if (dowarn)
	    warn("Use of uninitialized variable");
	sv_grow(sv, 1);
	s = SvPVX(sv);
    }
    *s = '\0';
    *lp = s - SvPVX(sv);
    SvCUR_set(sv, *lp);
    SvPOK_on(sv);
    DEBUG_c((stderr,"0x%lx 2pv(%s)\n",sv,SvPVX(sv)));
    return SvPVX(sv);
}

/* This function is only called on magical items */
bool
sv_2bool(sv)
register SV *sv;
{
    if (SvMAGICAL(sv))
	mg_get(sv);

    if (SvTYPE(sv) == SVt_REF)
	return SvANY(sv) != 0;
    if (SvPOKp(sv)) {
	register XPV* Xpv;
	if ((Xpv = (XPV*)SvANY(sv)) &&
		(*Xpv->xpv_pv > '0' ||
		Xpv->xpv_cur > 1 ||
		(Xpv->xpv_cur && *Xpv->xpv_pv != '0')))
	    return 1;
	else
	    return 0;
    }
    else {
	if (SvIOKp(sv))
	    return SvIVX(sv) != 0;
	else {
	    if (SvNOKp(sv))
		return SvNVX(sv) != 0.0;
	    else
		return FALSE;
	}
    }
}

/* Note: sv_setsv() should not be called with a source string that needs
 * to be reused, since it may destroy the source string if it is marked
 * as temporary.
 */

void
sv_setsv(dstr,sstr)
SV *dstr;
register SV *sstr;
{
    int flags;

    if (sstr == dstr)
	return;
    if (SvREADONLY(dstr))
	croak(no_modify);
    if (!sstr)
	sstr = &sv_undef;

    /* There's a lot of redundancy below but we're going for speed here */

    switch (SvTYPE(sstr)) {
    case SVt_NULL:
	if (SvTYPE(dstr) == SVt_REF) {
	    sv_free((SV*)SvANY(dstr));
	    SvANY(dstr) = 0;
	    SvTYPE(dstr) = SVt_NULL;
	}
	else
	    SvOK_off(dstr);
	return;
    case SVt_REF:
	if (SvTYPE(dstr) < SVt_REF)
	    sv_upgrade(dstr, SVt_REF);
	if (SvTYPE(dstr) == SVt_REF) {
	    sv_free((SV*)SvANY(dstr));
	    SvANY(dstr) = 0;
	    SvANY(dstr) = (void*)sv_ref((SV*)SvANY(sstr));
	}
	else {
	    if (SvMAGICAL(dstr))
		croak("Can't assign a reference to a magical variable");
	    if (SvREFCNT(dstr) != 1)
		warn("Reference miscount in sv_setsv()");
	    SvREFCNT(dstr) = 0;
	    sv_clear(dstr);
	    SvTYPE(dstr) = SVt_REF;
	    SvANY(dstr) = (void*)sv_ref((SV*)SvANY(sstr));
	    SvOK_off(dstr);
	}
	SvTAINT(sstr);
	return;
    case SVt_IV:
	if (SvTYPE(dstr) < SVt_IV)
	    sv_upgrade(dstr, SVt_IV);
	else if (SvTYPE(dstr) == SVt_PV)
	    sv_upgrade(dstr, SVt_PVIV);
	else if (SvTYPE(dstr) == SVt_NV)
	    sv_upgrade(dstr, SVt_PVNV);
	flags = SvFLAGS(sstr);
	break;
    case SVt_NV:
	if (SvTYPE(dstr) < SVt_NV)
	    sv_upgrade(dstr, SVt_NV);
	else if (SvTYPE(dstr) == SVt_PV)
	    sv_upgrade(dstr, SVt_PVNV);
	else if (SvTYPE(dstr) == SVt_PVIV)
	    sv_upgrade(dstr, SVt_PVNV);
	flags = SvFLAGS(sstr);
	break;
    case SVt_PV:
	if (SvTYPE(dstr) < SVt_PV)
	    sv_upgrade(dstr, SVt_PV);
	flags = SvFLAGS(sstr);
	break;
    case SVt_PVIV:
	if (SvTYPE(dstr) < SVt_PVIV)
	    sv_upgrade(dstr, SVt_PVIV);
	flags = SvFLAGS(sstr);
	break;
    case SVt_PVNV:
	if (SvTYPE(dstr) < SVt_PVNV)
	    sv_upgrade(dstr, SVt_PVNV);
	flags = SvFLAGS(sstr);
	break;
    case SVt_PVGV:
	if (SvTYPE(dstr) <= SVt_PVGV) {
	    if (SvTYPE(dstr) < SVt_PVGV)
		sv_upgrade(dstr, SVt_PVGV);
	    SvOK_off(dstr);
	    if (!GvAV(sstr))
		gv_AVadd(sstr);
	    if (!GvHV(sstr))
		gv_HVadd(sstr);
	    if (!GvIO(sstr))
		GvIO(sstr) = newIO();
	    if (GvGP(dstr))
		gp_free(dstr);
	    GvGP(dstr) = gp_ref(GvGP(sstr));
	    SvTAINT(sstr);
	    return;
	}
	/* FALL THROUGH */

    default:
	if (SvTYPE(dstr) < SvTYPE(sstr))
	    sv_upgrade(dstr, SvTYPE(sstr));
	if (SvMAGICAL(sstr)) {
	    mg_get(sstr);
	    flags = SvPRIVATE(sstr);
	}
	else
	    flags = SvFLAGS(sstr);
    }


    SvPRIVATE(dstr)	= SvPRIVATE(sstr) & ~(SVf_IOK|SVf_POK|SVf_NOK);

    if (flags & SVf_POK) {

	/*
	 * Check to see if we can just swipe the string.  If so, it's a
	 * possible small lose on short strings, but a big win on long ones.
	 * It might even be a win on short strings if SvPVX(dstr)
	 * has to be allocated and SvPVX(sstr) has to be freed.
	 */

	if (SvTEMP(sstr)) {		/* slated for free anyway? */
	    if (SvPOK(dstr)) {
		SvOOK_off(dstr);
		Safefree(SvPVX(dstr));
	    }
	    SvPV_set(dstr, SvPVX(sstr));
	    SvLEN_set(dstr, SvLEN(sstr));
	    SvCUR_set(dstr, SvCUR(sstr));
	    SvPOK_only(dstr);
	    SvTEMP_off(dstr);
	    SvPV_set(sstr, Nullch);
	    SvLEN_set(sstr, 0);
	    SvPOK_off(sstr);			/* wipe out any weird flags */
	    SvPVX(sstr) = 0;			/* so sstr frees uneventfully */
	}
	else {					/* have to copy actual string */
	    if (SvPVX(dstr)) { /* XXX ck type */
		SvOOK_off(dstr);
	    }
	    sv_setpvn(dstr,SvPVX(sstr),SvCUR(sstr));
	}
	/*SUPPRESS 560*/
	if (flags & SVf_NOK) {
	    SvNOK_on(dstr);
	    SvNVX(dstr) = SvNVX(sstr);
	}
	if (flags & SVf_IOK) {
	    SvIOK_on(dstr);
	    SvIVX(dstr) = SvIVX(sstr);
	}
    }
    else if (flags & SVf_NOK) {
	SvNVX(dstr) = SvNVX(sstr);
	SvNOK_only(dstr);
	if (SvIOK(sstr)) {
	    SvIOK_on(dstr);
	    SvIVX(dstr) = SvIVX(sstr);
	}
    }
    else if (flags & SVf_IOK) {
	SvIOK_only(dstr);
	SvIVX(dstr) = SvIVX(sstr);
    }
    else {
	SvOK_off(dstr);
    }
    SvTAINT(dstr);
}

void
sv_setpvn(sv,ptr,len)
register SV *sv;
register char *ptr;
register STRLEN len;
{
    if (SvREADONLY(sv))
	croak(no_modify);
    if (!ptr) {
	SvOK_off(sv);
	return;
    }
    if (!SvUPGRADE(sv, SVt_PV))
	return;
    SvGROW(sv, len + 1);
    if (ptr)
	Move(ptr,SvPVX(sv),len,char);
    SvCUR_set(sv, len);
    *SvEND(sv) = '\0';
    SvPOK_only(sv);		/* validate pointer */
    SvTAINT(sv);
}

void
sv_setpv(sv,ptr)
register SV *sv;
register char *ptr;
{
    register STRLEN len;

    if (SvREADONLY(sv))
	croak(no_modify);
    if (!ptr) {
	SvOK_off(sv);
	return;
    }
    len = strlen(ptr);
    if (!SvUPGRADE(sv, SVt_PV))
	return;
    SvGROW(sv, len + 1);
    Move(ptr,SvPVX(sv),len+1,char);
    SvCUR_set(sv, len);
    SvPOK_only(sv);		/* validate pointer */
    SvTAINT(sv);
}

void
sv_usepvn(sv,ptr,len)
register SV *sv;
register char *ptr;
register STRLEN len;
{
    if (SvREADONLY(sv))
	croak(no_modify);
    if (!SvUPGRADE(sv, SVt_PV))
	return;
    if (!ptr) {
	SvOK_off(sv);
	return;
    }
    if (SvPVX(sv))
	Safefree(SvPVX(sv));
    Renew(ptr, len+1, char);
    SvPVX(sv) = ptr;
    SvCUR_set(sv, len);
    SvLEN_set(sv, len+1);
    *SvEND(sv) = '\0';
    SvPOK_only(sv);		/* validate pointer */
    SvTAINT(sv);
}

void
sv_chop(sv,ptr)	/* like set but assuming ptr is in sv */
register SV *sv;
register char *ptr;
{
    register STRLEN delta;

    if (!ptr || !SvPOK(sv))
	return;
    if (SvREADONLY(sv))
	croak(no_modify);
    if (SvTYPE(sv) < SVt_PVIV)
	sv_upgrade(sv,SVt_PVIV);

    if (!SvOOK(sv)) {
	SvIVX(sv) = 0;
	SvFLAGS(sv) |= SVf_OOK;
    }
    SvFLAGS(sv) &= ~(SVf_IOK|SVf_NOK);
    delta = ptr - SvPVX(sv);
    SvLEN(sv) -= delta;
    SvCUR(sv) -= delta;
    SvPVX(sv) += delta;
    SvIVX(sv) += delta;
}

void
sv_catpvn(sv,ptr,len)
register SV *sv;
register char *ptr;
register STRLEN len;
{
    STRLEN tlen;
    char *s;
    if (SvREADONLY(sv))
	croak(no_modify);
    s = SvPV(sv, tlen);
    SvGROW(sv, tlen + len + 1);
    Move(ptr,SvPVX(sv)+tlen,len,char);
    SvCUR(sv) += len;
    *SvEND(sv) = '\0';
    SvPOK_only(sv);		/* validate pointer */
    SvTAINT(sv);
}

void
sv_catsv(dstr,sstr)
SV *dstr;
register SV *sstr;
{
    char *s;
    STRLEN len;
    if (!sstr)
	return;
    if (s = SvPV(sstr, len))
	sv_catpvn(dstr,s,len);
}

void
sv_catpv(sv,ptr)
register SV *sv;
register char *ptr;
{
    register STRLEN len;
    STRLEN tlen;
    char *s;

    if (SvREADONLY(sv))
	croak(no_modify);
    if (!ptr)
	return;
    s = SvPV(sv, tlen);
    len = strlen(ptr);
    SvGROW(sv, tlen + len + 1);
    Move(ptr,SvPVX(sv)+tlen,len+1,char);
    SvCUR(sv) += len;
    SvPOK_only(sv);		/* validate pointer */
    SvTAINT(sv);
}

SV *
#ifdef LEAKTEST
newSV(x,len)
I32 x;
#else
newSV(len)
#endif
STRLEN len;
{
    register SV *sv;
    
    new_SV();
    Zero(sv, 1, SV);
    SvREFCNT(sv)++;
    if (len) {
	sv_upgrade(sv, SVt_PV);
	SvGROW(sv, len + 1);
    }
    return sv;
}

void
sv_magic(sv, obj, how, name, namlen)
register SV *sv;
SV *obj;
char how;
char *name;
I32 namlen;
{
    MAGIC* mg;
    
    if (SvREADONLY(sv))
	croak(no_modify);
    if (SvMAGICAL(sv)) {
	if (SvMAGIC(sv) && mg_find(sv, how))
	    return;
    }
    else {
	if (!SvUPGRADE(sv, SVt_PVMG))
	    return;
	SvMAGICAL_on(sv);
	SvPRIVATE(sv) &= ~(SVf_IOK|SVf_NOK|SVf_POK);
	SvPRIVATE(sv) |= SvFLAGS(sv) & (SVf_IOK|SVf_NOK|SVf_POK);
	SvFLAGS(sv) &= ~(SVf_IOK|SVf_NOK|SVf_POK);
    }
    Newz(702,mg, 1, MAGIC);
    mg->mg_moremagic = SvMAGIC(sv);

    SvMAGIC(sv) = mg;
    mg->mg_obj = sv_ref(obj);
    mg->mg_type = how;
    mg->mg_len = namlen;
    if (name && namlen >= 0)
	mg->mg_ptr = nsavestr(name, namlen);
    switch (how) {
    case 0:
	mg->mg_virtual = &vtbl_sv;
	break;
    case 'B':
	mg->mg_virtual = &vtbl_bm;
	break;
    case 'E':
	mg->mg_virtual = &vtbl_env;
	break;
    case 'e':
	mg->mg_virtual = &vtbl_envelem;
	break;
    case 'g':
	mg->mg_virtual = &vtbl_mglob;
	break;
    case 'I':
	mg->mg_virtual = &vtbl_isa;
	break;
    case 'i':
	mg->mg_virtual = &vtbl_isaelem;
	break;
    case 'L':
	mg->mg_virtual = 0;
	break;
    case 'l':
	mg->mg_virtual = &vtbl_dbline;
	break;
    case 'P':
	mg->mg_virtual = &vtbl_pack;
	break;
    case 'p':
	mg->mg_virtual = &vtbl_packelem;
	break;
    case 'S':
	mg->mg_virtual = &vtbl_sig;
	break;
    case 's':
	mg->mg_virtual = &vtbl_sigelem;
	break;
    case 't':
	mg->mg_virtual = &vtbl_taint;
	break;
    case 'U':
	mg->mg_virtual = &vtbl_uvar;
	break;
    case 'v':
	mg->mg_virtual = &vtbl_vec;
	break;
    case 'x':
	mg->mg_virtual = &vtbl_substr;
	break;
    case '*':
	mg->mg_virtual = &vtbl_glob;
	break;
    case '#':
	mg->mg_virtual = &vtbl_arylen;
	break;
    default:
	croak("Don't know how to handle magic of type '%c'", how);
    }
}

int
sv_unmagic(sv, type)
SV* sv;
char type;
{
    MAGIC* mg;
    MAGIC** mgp;
    if (!SvMAGICAL(sv))
	return 0;
    mgp = &SvMAGIC(sv);
    for (mg = *mgp; mg; mg = *mgp) {
	if (mg->mg_type == type) {
	    MGVTBL* vtbl = mg->mg_virtual;
	    *mgp = mg->mg_moremagic;
	    if (vtbl && vtbl->svt_free)
		(*vtbl->svt_free)(sv, mg);
	    if (mg->mg_ptr && mg->mg_type != 'g')
		Safefree(mg->mg_ptr);
	    sv_free(mg->mg_obj);
	    Safefree(mg);
	}
	else
	    mgp = &mg->mg_moremagic;
    }
    if (!SvMAGIC(sv)) {
	SvMAGICAL_off(sv);
	SvFLAGS(sv) &= ~(SVf_IOK|SVf_NOK|SVf_POK);
	SvFLAGS(sv) |= SvPRIVATE(sv) & (SVf_IOK|SVf_NOK|SVf_POK);
	SvPRIVATE(sv) &= ~(SVf_IOK|SVf_NOK|SVf_POK);
    }

    return 0;
}

void
sv_insert(bigstr,offset,len,little,littlelen)
SV *bigstr;
STRLEN offset;
STRLEN len;
char *little;
STRLEN littlelen;
{
    register char *big;
    register char *mid;
    register char *midend;
    register char *bigend;
    register I32 i;

    if (SvREADONLY(bigstr))
	croak(no_modify);
    SvPOK_only(bigstr);

    i = littlelen - len;
    if (i > 0) {			/* string might grow */
	if (!SvUPGRADE(bigstr, SVt_PV))
	    return;
	SvGROW(bigstr, SvCUR(bigstr) + i + 1);
	big = SvPVX(bigstr);
	mid = big + offset + len;
	midend = bigend = big + SvCUR(bigstr);
	bigend += i;
	*bigend = '\0';
	while (midend > mid)		/* shove everything down */
	    *--bigend = *--midend;
	Move(little,big+offset,littlelen,char);
	SvCUR(bigstr) += i;
	SvSETMAGIC(bigstr);
	return;
    }
    else if (i == 0) {
	Move(little,SvPVX(bigstr)+offset,len,char);
	SvSETMAGIC(bigstr);
	return;
    }

    big = SvPVX(bigstr);
    mid = big + offset;
    midend = mid + len;
    bigend = big + SvCUR(bigstr);

    if (midend > bigend)
	croak("panic: sv_insert");

    if (mid - big > bigend - midend) {	/* faster to shorten from end */
	if (littlelen) {
	    Move(little, mid, littlelen,char);
	    mid += littlelen;
	}
	i = bigend - midend;
	if (i > 0) {
	    Move(midend, mid, i,char);
	    mid += i;
	}
	*mid = '\0';
	SvCUR_set(bigstr, mid - big);
    }
    /*SUPPRESS 560*/
    else if (i = mid - big) {	/* faster from front */
	midend -= littlelen;
	mid = midend;
	sv_chop(bigstr,midend-i);
	big += i;
	while (i--)
	    *--midend = *--big;
	if (littlelen)
	    Move(little, mid, littlelen,char);
    }
    else if (littlelen) {
	midend -= littlelen;
	sv_chop(bigstr,midend);
	Move(little,midend,littlelen,char);
    }
    else {
	sv_chop(bigstr,midend);
    }
    SvSETMAGIC(bigstr);
}

/* make sv point to what nstr did */

void
sv_replace(sv,nsv)
register SV *sv;
register SV *nsv;
{
    U32 refcnt = SvREFCNT(sv);
    if (SvREADONLY(sv))
	croak(no_modify);
    if (SvREFCNT(nsv) != 1)
	warn("Reference miscount in sv_replace()");
    if (SvMAGICAL(sv)) {
	SvUPGRADE(nsv, SVt_PVMG);
	SvMAGIC(nsv) = SvMAGIC(sv);
	SvMAGICAL_on(nsv);
	SvMAGICAL_off(sv);
	SvMAGIC(sv) = 0;
    }
    SvREFCNT(sv) = 0;
    sv_clear(sv);
    StructCopy(nsv,sv,SV);
    SvREFCNT(sv) = refcnt;
    del_SV(nsv);
}

void
sv_clear(sv)
register SV *sv;
{
    assert(sv);
    assert(SvREFCNT(sv) == 0);

    if (SvSTORAGE(sv) == 'O') {
	dSP;
	BINOP myop;		/* fake syntax tree node */
	GV* destructor;

	SvSTORAGE(sv) = 0;		/* Curse the object. */

	ENTER;
	SAVETMPS;
	SAVESPTR(curcop);
	SAVESPTR(op);
	curcop = &compiling;
	curstash = SvSTASH(sv);
	destructor = gv_fetchpv("DESTROY", FALSE);

	if (destructor && GvCV(destructor)) {
	    SV* ref = sv_mortalcopy(&sv_undef);
	    sv_upgrade(ref, SVt_REF);
	    SvANY(ref) = (void*)sv_ref(sv);

	    op = (OP*)&myop;
	    Zero(op, 1, OP);
	    myop.op_last = (OP*)&myop;
	    myop.op_flags = OPf_STACKED;
	    myop.op_next = Nullop;

	    EXTEND(SP, 2);
	    PUSHs((SV*)destructor);
	    pp_pushmark();
	    PUSHs(ref);
	    PUTBACK;
	    op = pp_entersubr();
	    if (op)
		run();
	    stack_sp--;
	    SvREFCNT(sv) = 0;
	    SvTYPE(ref) = SVt_NULL;
	    free_tmps();
	}
	LEAVE;
    }
    switch (SvTYPE(sv)) {
    case SVt_PVFM:
	goto freemagic;
    case SVt_PVBM:
	goto freemagic;
    case SVt_PVGV:
	gp_free(sv);
	goto freemagic;
    case SVt_PVCV:
	cv_clear((CV*)sv);
	goto freemagic;
    case SVt_PVHV:
	hv_clear((HV*)sv);
	goto freemagic;
    case SVt_PVAV:
	av_clear((AV*)sv);
	goto freemagic;
    case SVt_PVLV:
	goto freemagic;
    case SVt_PVMG:
      freemagic:
	if (SvMAGICAL(sv))
	    mg_free(sv);
    case SVt_PVNV:
    case SVt_PVIV:
	SvOOK_off(sv);
	/* FALL THROUGH */
    case SVt_PV:
	if (SvPVX(sv))
	    Safefree(SvPVX(sv));
	break;
    case SVt_NV:
	break;
    case SVt_IV:
	break;
    case SVt_REF:
	sv_free((SV*)SvANY(sv));
	break;
    case SVt_NULL:
	break;
    }

    switch (SvTYPE(sv)) {
    case SVt_NULL:
	break;
    case SVt_REF:
	break;
    case SVt_IV:
	del_XIV(SvANY(sv));
	break;
    case SVt_NV:
	del_XNV(SvANY(sv));
	break;
    case SVt_PV:
	del_XPV(SvANY(sv));
	break;
    case SVt_PVIV:
	del_XPVIV(SvANY(sv));
	break;
    case SVt_PVNV:
	del_XPVNV(SvANY(sv));
	break;
    case SVt_PVMG:
	del_XPVMG(SvANY(sv));
	break;
    case SVt_PVLV:
	del_XPVLV(SvANY(sv));
	break;
    case SVt_PVAV:
	del_XPVAV(SvANY(sv));
	break;
    case SVt_PVHV:
	del_XPVHV(SvANY(sv));
	break;
    case SVt_PVCV:
	del_XPVCV(SvANY(sv));
	break;
    case SVt_PVGV:
	del_XPVGV(SvANY(sv));
	break;
    case SVt_PVBM:
	del_XPVBM(SvANY(sv));
	break;
    case SVt_PVFM:
	del_XPVFM(SvANY(sv));
	break;
    }
    DEB(SvTYPE(sv) = 0xff;)
}

SV *
sv_ref(sv)
SV* sv;
{
    if (sv)
	SvREFCNT(sv)++;
    return sv;
}

void
sv_free(sv)
SV *sv;
{
    if (!sv)
	return;
    if (SvREADONLY(sv)) {
	if (sv == &sv_undef || sv == &sv_yes || sv == &sv_no)
	    return;
    }
    if (SvREFCNT(sv) == 0) {
	warn("Attempt to free unreferenced scalar");
	return;
    }
#ifdef DEBUGGING
    if (SvTEMP(sv)) {
	warn("Attempt to free temp prematurely");
	return;
    }
#endif
    if (--SvREFCNT(sv) > 0)
	return;
    sv_clear(sv);
    DEB(SvTYPE(sv) = 0xff;)
    del_SV(sv);
}

STRLEN
sv_len(sv)
register SV *sv;
{
    char *s;
    STRLEN len;

    if (!sv)
	return 0;

    s = SvPV(sv, len);
    return len;
}

I32
sv_eq(str1,str2)
register SV *str1;
register SV *str2;
{
    char *pv1;
    STRLEN cur1;
    char *pv2;
    STRLEN cur2;

    if (!str1) {
	pv1 = "";
	cur1 = 0;
    }
    else
	pv1 = SvPV(str1, cur1);

    if (!str2)
	return !cur1;
    else
	pv2 = SvPV(str2, cur2);

    if (cur1 != cur2)
	return 0;

    return !bcmp(pv1, pv2, cur1);
}

I32
sv_cmp(str1,str2)
register SV *str1;
register SV *str2;
{
    I32 retval;
    char *pv1;
    STRLEN cur1;
    char *pv2;
    STRLEN cur2;

    if (!str1) {
	pv1 = "";
	cur1 = 0;
    }
    else
	pv1 = SvPV(str1, cur1);

    if (!str2) {
	pv2 = "";
	cur2 = 0;
    }
    else
	pv2 = SvPV(str2, cur2);

    if (!cur1)
	return cur2 ? -1 : 0;
    if (!cur2)
	return 1;

    if (cur1 < cur2) {
	/*SUPPRESS 560*/
	if (retval = memcmp(pv1, pv2, cur1))
	    return retval < 0 ? -1 : 1;
	else
	    return -1;
    }
    /*SUPPRESS 560*/
    else if (retval = memcmp(pv1, pv2, cur2))
	return retval < 0 ? -1 : 1;
    else if (cur1 == cur2)
	return 0;
    else
	return 1;
}

char *
sv_gets(sv,fp,append)
register SV *sv;
register FILE *fp;
I32 append;
{
    register char *bp;		/* we're going to steal some values */
    register I32 cnt;		/*  from the stdio struct and put EVERYTHING */
    register STDCHAR *ptr;	/*   in the innermost loop into registers */
    register I32 newline = rschar;/* (assuming >= 6 registers) */
    I32 i;
    STRLEN bpx;
    I32 shortbuffered;

    if (SvREADONLY(sv))
	croak(no_modify);
    if (!SvUPGRADE(sv, SVt_PV))
	return;
    if (rspara) {		/* have to do this both before and after */
	do {			/* to make sure file boundaries work right */
	    i = getc(fp);
	    if (i != '\n') {
		ungetc(i,fp);
		break;
	    }
	} while (i != EOF);
    }
#ifdef STDSTDIO		/* Here is some breathtakingly efficient cheating */
    cnt = fp->_cnt;			/* get count into register */
    SvPOK_only(sv);			/* validate pointer */
    if (SvLEN(sv) - append <= cnt + 1) { /* make sure we have the room */
	if (cnt > 80 && SvLEN(sv) > append) {
	    shortbuffered = cnt - SvLEN(sv) + append + 1;
	    cnt -= shortbuffered;
	}
	else {
	    shortbuffered = 0;
	    SvGROW(sv, append+cnt+2);/* (remembering cnt can be -1) */
	}
    }
    else
	shortbuffered = 0;
    bp = SvPVX(sv) + append;		/* move these two too to registers */
    ptr = fp->_ptr;
    for (;;) {
      screamer:
	if (cnt > 0) {
	    while (--cnt >= 0) {		 /* this */	/* eat */
		if ((*bp++ = *ptr++) == newline) /* really */	/* dust */
		    goto thats_all_folks;	 /* screams */	/* sed :-) */ 
	    }
	}
	
	if (shortbuffered) {			/* oh well, must extend */
	    cnt = shortbuffered;
	    shortbuffered = 0;
	    bpx = bp - SvPVX(sv);	/* prepare for possible relocation */
	    SvCUR_set(sv, bpx);
	    SvGROW(sv, SvLEN(sv) + append + cnt + 2);
	    bp = SvPVX(sv) + bpx;	/* reconstitute our pointer */
	    continue;
	}

	fp->_cnt = cnt;			/* deregisterize cnt and ptr */
	fp->_ptr = ptr;
	i = _filbuf(fp);		/* get more characters */
	cnt = fp->_cnt;
	ptr = fp->_ptr;			/* reregisterize cnt and ptr */

	bpx = bp - SvPVX(sv);	/* prepare for possible relocation */
	SvCUR_set(sv, bpx);
	SvGROW(sv, bpx + cnt + 2);
	bp = SvPVX(sv) + bpx;	/* reconstitute our pointer */

	if (i == newline) {		/* all done for now? */
	    *bp++ = i;
	    goto thats_all_folks;
	}
	else if (i == EOF)		/* all done for ever? */
	    goto thats_really_all_folks;
	*bp++ = i;			/* now go back to screaming loop */
    }

thats_all_folks:
    if (rslen > 1 && (bp - SvPVX(sv) < rslen || bcmp(bp - rslen, rs, rslen)))
	goto screamer;	/* go back to the fray */
thats_really_all_folks:
    if (shortbuffered)
	cnt += shortbuffered;
    fp->_cnt = cnt;			/* put these back or we're in trouble */
    fp->_ptr = ptr;
    *bp = '\0';
    SvCUR_set(sv, bp - SvPVX(sv));	/* set length */

#else /* !STDSTDIO */	/* The big, slow, and stupid way */

    {
	char buf[8192];
	register char * bpe = buf + sizeof(buf) - 3;

screamer:
	bp = buf;
	while ((i = getc(fp)) != EOF && (*bp++ = i) != newline && bp < bpe) ;

	if (append)
	    sv_catpvn(sv, buf, bp - buf);
	else
	    sv_setpvn(sv, buf, bp - buf);
	if (i != EOF			/* joy */
	    &&
	    (i != newline
	     ||
	     (rslen > 1
	      &&
	      (SvCUR(sv) < rslen
	       ||
	       bcmp(SvPVX(sv) + SvCUR(sv) - rslen, rs, rslen)
	      )
	     )
	    )
	   )
	{
	    append = -1;
	    goto screamer;
	}
    }

#endif /* STDSTDIO */

    if (rspara) {
        while (i != EOF) {
	    i = getc(fp);
	    if (i != '\n') {
		ungetc(i,fp);
		break;
	    }
	}
    }
    return SvCUR(sv) - append ? SvPVX(sv) : Nullch;
}

void
sv_inc(sv)
register SV *sv;
{
    register char *d;
    int flags;

    if (!sv)
	return;
    if (SvREADONLY(sv))
	croak(no_modify);
    if (SvMAGICAL(sv)) {
	mg_get(sv);
	flags = SvPRIVATE(sv);
    }
    else
	flags = SvFLAGS(sv);
    if (flags & SVf_IOK) {
	++SvIVX(sv);
	SvIOK_only(sv);
	return;
    }
    if (flags & SVf_NOK) {
	SvNVX(sv) += 1.0;
	SvNOK_only(sv);
	return;
    }
    if (!(flags & SVf_POK) || !*SvPVX(sv)) {
	if (!SvUPGRADE(sv, SVt_NV))
	    return;
	SvNVX(sv) = 1.0;
	SvNOK_only(sv);
	return;
    }
    d = SvPVX(sv);
    while (isALPHA(*d)) d++;
    while (isDIGIT(*d)) d++;
    if (*d) {
        sv_setnv(sv,atof(SvPVX(sv)) + 1.0);  /* punt */
	return;
    }
    d--;
    while (d >= SvPVX(sv)) {
	if (isDIGIT(*d)) {
	    if (++*d <= '9')
		return;
	    *(d--) = '0';
	}
	else {
	    ++*d;
	    if (isALPHA(*d))
		return;
	    *(d--) -= 'z' - 'a' + 1;
	}
    }
    /* oh,oh, the number grew */
    SvGROW(sv, SvCUR(sv) + 2);
    SvCUR(sv)++;
    for (d = SvPVX(sv) + SvCUR(sv); d > SvPVX(sv); d--)
	*d = d[-1];
    if (isDIGIT(d[1]))
	*d = '1';
    else
	*d = d[1];
}

void
sv_dec(sv)
register SV *sv;
{
    int flags;

    if (!sv)
	return;
    if (SvREADONLY(sv))
	croak(no_modify);
    if (SvMAGICAL(sv)) {
	mg_get(sv);
	flags = SvPRIVATE(sv);
    }
    else
	flags = SvFLAGS(sv);
    if (flags & SVf_IOK) {
	--SvIVX(sv);
	SvIOK_only(sv);
	return;
    }
    if (flags & SVf_NOK) {
	SvNVX(sv) -= 1.0;
	SvNOK_only(sv);
	return;
    }
    if (!(flags & SVf_POK)) {
	if (!SvUPGRADE(sv, SVt_NV))
	    return;
	SvNVX(sv) = -1.0;
	SvNOK_only(sv);
	return;
    }
    sv_setnv(sv,atof(SvPVX(sv)) - 1.0);
}

/* Make a string that will exist for the duration of the expression
 * evaluation.  Actually, it may have to last longer than that, but
 * hopefully we won't free it until it has been assigned to a
 * permanent location. */

SV *
sv_mortalcopy(oldstr)
SV *oldstr;
{
    register SV *sv;

    new_SV();
    Zero(sv, 1, SV);
    SvREFCNT(sv)++;
    sv_setsv(sv,oldstr);
    if (++tmps_ix > tmps_max) {
	tmps_max = tmps_ix;
	if (!(tmps_max & 127)) {
	    if (tmps_max)
		Renew(tmps_stack, tmps_max + 128, SV*);
	    else
		New(702,tmps_stack, 128, SV*);
	}
    }
    tmps_stack[tmps_ix] = sv;
    if (SvPOK(sv))
	SvTEMP_on(sv);
    return sv;
}

/* same thing without the copying */

SV *
sv_2mortal(sv)
register SV *sv;
{
    if (!sv)
	return sv;
    if (SvREADONLY(sv))
	croak(no_modify);
    if (++tmps_ix > tmps_max) {
	tmps_max = tmps_ix;
	if (!(tmps_max & 127)) {
	    if (tmps_max)
		Renew(tmps_stack, tmps_max + 128, SV*);
	    else
		New(704,tmps_stack, 128, SV*);
	}
    }
    tmps_stack[tmps_ix] = sv;
    if (SvPOK(sv))
	SvTEMP_on(sv);
    return sv;
}

SV *
newSVpv(s,len)
char *s;
STRLEN len;
{
    register SV *sv;

    new_SV();
    Zero(sv, 1, SV);
    SvREFCNT(sv)++;
    if (!len)
	len = strlen(s);
    sv_setpvn(sv,s,len);
    return sv;
}

SV *
newSVnv(n)
double n;
{
    register SV *sv;

    new_SV();
    Zero(sv, 1, SV);
    SvREFCNT(sv)++;
    sv_setnv(sv,n);
    return sv;
}

SV *
newSViv(i)
I32 i;
{
    register SV *sv;

    new_SV();
    Zero(sv, 1, SV);
    SvREFCNT(sv)++;
    sv_setiv(sv,i);
    return sv;
}

/* make an exact duplicate of old */

SV *
newSVsv(old)
register SV *old;
{
    register SV *sv;

    if (!old)
	return Nullsv;
    if (SvTYPE(old) == 0xff) {
	warn("semi-panic: attempt to dup freed string");
	return Nullsv;
    }
    new_SV();
    Zero(sv, 1, SV);
    SvREFCNT(sv)++;
    if (SvTEMP(old)) {
	SvTEMP_off(old);
	sv_setsv(sv,old);
	SvTEMP_on(old);
    }
    else
	sv_setsv(sv,old);
    return sv;
}

void
sv_reset(s,stash)
register char *s;
HV *stash;
{
    register HE *entry;
    register GV *gv;
    register SV *sv;
    register I32 i;
    register PMOP *pm;
    register I32 max;
    char todo[256];

    if (!*s) {		/* reset ?? searches */
	for (pm = HvPMROOT(stash); pm; pm = pm->op_pmnext) {
	    pm->op_pmflags &= ~PMf_USED;
	}
	return;
    }

    /* reset variables */

    if (!HvARRAY(stash))
	return;

    Zero(todo, 256, char);
    while (*s) {
	i = *s;
	if (s[1] == '-') {
	    s += 2;
	}
	max = *s++;
	for ( ; i <= max; i++) {
	    todo[i] = 1;
	}
	for (i = 0; i <= HvMAX(stash); i++) {
	    for (entry = HvARRAY(stash)[i];
	      entry;
	      entry = entry->hent_next) {
		if (!todo[(U8)*entry->hent_key])
		    continue;
		gv = (GV*)entry->hent_val;
		sv = GvSV(gv);
		SvOK_off(sv);
		if (SvTYPE(sv) >= SVt_PV) {
		    SvCUR_set(sv, 0);
		    SvTAINT(sv);
		    if (SvPVX(sv) != Nullch)
			*SvPVX(sv) = '\0';
		}
		if (GvAV(gv)) {
		    av_clear(GvAV(gv));
		}
		if (GvHV(gv)) {
		    hv_clear(GvHV(gv));
		    if (gv == envgv)
			environ[0] = Nullch;
		}
	    }
	}
    }
}

CV *
sv_2cv(sv, st, gvp, lref)
SV *sv;
HV **st;
GV **gvp;
I32 lref;
{
    GV *gv;
    CV *cv;

    if (!sv)
	return *gvp = Nullgv, Nullcv;
    switch (SvTYPE(sv)) {
    case SVt_REF:
	cv = (CV*)SvANY(sv);
	if (SvTYPE(cv) != SVt_PVCV)
	    croak("Not a subroutine reference");
	*gvp = Nullgv;
	*st = CvSTASH(cv);
	return cv;
    case SVt_PVCV:
	*st = CvSTASH(sv);
	*gvp = Nullgv;
	return (CV*)sv;
    case SVt_PVHV:
    case SVt_PVAV:
	*gvp = Nullgv;
	return Nullcv;
    default:
	if (isGV(sv))
	    gv = (GV*)sv;
	else
	    gv = gv_fetchpv(SvPV(sv, na), lref);
	*gvp = gv;
	if (!gv)
	    return Nullcv;
	*st = GvESTASH(gv);
	return GvCV(gv);
    }
}

#ifndef SvTRUE
I32
SvTRUE(sv)
register SV *sv;
{
    if (SvMAGICAL(sv))
	mg_get(sv);
    if (SvPOK(sv)) {
	register XPV* Xpv;
	if ((Xpv = (XPV*)SvANY(sv)) &&
		(*Xpv->xpv_pv > '0' ||
		Xpv->xpv_cur > 1 ||
		(Xpv->xpv_cur && *Xpv->xpv_pv != '0')))
	    return 1;
	else
	    return 0;
    }
    else {
	if (SvIOK(sv))
	    return SvIVX(sv) != 0;
	else {
	    if (SvNOK(sv))
		return SvNVX(sv) != 0.0;
	    else
		return sv_2bool(sv);
	}
    }
}
#endif /* SvTRUE */

#ifndef SvNV
double SvNV(Sv)
register SV *Sv;
{
    if (SvNOK(Sv))
	return SvNVX(Sv);
    if (SvIOK(Sv))
	return (double)SvIVX(Sv);
    return sv_2nv(Sv);
}
#endif /* SvNV */

#ifdef CRIPPLED_CC
char *
sv_pvn(sv, lp)
SV *sv;
STRLEN *lp;
{
    if (SvPOK(sv))
	return SvPVX(sv)
    return sv_2pv(sv, lp);
}
#endif

int
sv_isa(sv, name)
SV *sv;
char *name;
{
    if (SvTYPE(sv) != SVt_REF)
	return 0;
    sv = (SV*)SvANY(sv);
    if (SvSTORAGE(sv) != 'O')
	return 0;

    return strEQ(HvNAME(SvSTASH(sv)), name);
}

SV*
sv_setptrobj(rv, ptr, name)
SV *rv;
void *ptr;
char *name;
{
    HV *stash;
    SV *sv;

    if (!ptr)
	return rv;

    new_SV();
    Zero(sv, 1, SV);
    SvREFCNT(sv)++;
    sv_setnv(sv, (double)(unsigned long)ptr);
    sv_upgrade(rv, SVt_REF);
    SvANY(rv) = (void*)sv_ref(sv);

    stash = fetch_stash(newSVpv(name,0), TRUE);
    SvSTORAGE(sv) = 'O';
    SvUPGRADE(sv, SVt_PVMG);
    SvSTASH(sv) = stash;

    return rv;
}
