/*    sharedsv.c
 *
 *    Copyright (c) 2001, Larry Wall
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 * "Hand any two wizards a piece of rope and they would instinctively pull in
 * opposite directions."
 *                         --Sourcery
 *
 * Contributed by Arthur Bergman arthur@contiller.se
 * pulled in the (an)other direction by Nick Ing-Simmons nick@ing-simmons.net
 */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define SHAREDSvPTR(a)      ((a)->sv)

/*
 * The shared things need an intepreter to live in ...
 */
PerlInterpreter *PL_sharedsv_space;             /* The shared sv space */
/* To access shared space we fake aTHX in this scope and thread's context */
#define SHARED_CONTEXT 	    PERL_SET_CONTEXT((aTHX = PL_sharedsv_space))

/* So we need a way to switch back to the caller's context... */
/* So we declare _another_ copy of the aTHX variable ... */
#define dTHXc PerlInterpreter *caller_perl = aTHX
/* and use it to switch back */
#define CALLER_CONTEXT      PERL_SET_CONTEXT((aTHX = caller_perl))

/*
 * Only one thread at a time is allowed to mess with shared space.
 */

typedef struct
{
 perl_mutex		 mutex;
 PerlInterpreter	*owner;
 I32			 locks;
 perl_cond		 cond;
#ifdef DEBUG_LOCKS
 char *			 file;
 int			 line;
#endif
} recursive_lock_t;

recursive_lock_t PL_sharedsv_lock;       /* Mutex protecting the shared sv space */

void
recursive_lock_init(pTHX_ recursive_lock_t *lock)
{
    Zero(lock,1,recursive_lock_t);
    MUTEX_INIT(&lock->mutex);
    COND_INIT(&lock->cond);
}

void
recursive_lock_release(pTHX_ recursive_lock_t *lock)
{
    MUTEX_LOCK(&lock->mutex);
    if (lock->owner != aTHX) {
	MUTEX_UNLOCK(&lock->mutex);
    }
    else {
	if (--lock->locks == 0) {
	    lock->owner = NULL;
	    COND_SIGNAL(&lock->cond);
	}
    }
    MUTEX_UNLOCK(&lock->mutex);
}

void
recursive_lock_acquire(pTHX_ recursive_lock_t *lock,char *file,int line)
{
    assert(aTHX);
    MUTEX_LOCK(&lock->mutex);
    if (lock->owner == aTHX) {
	lock->locks++;
    }
    else {
	while (lock->owner) {
#ifdef DEBUG_LOCKS
	    Perl_warn(aTHX_ " %p waiting - owned by %p %s:%d\n",
		      aTHX, lock->owner, lock->file, lock->line);
#endif
	    COND_WAIT(&lock->cond,&lock->mutex);
        }
	lock->locks = 1;
	lock->owner = aTHX;
#ifdef DEBUG_LOCKS
	lock->file  = file;
	lock->line  = line;
#endif
    }
    MUTEX_UNLOCK(&lock->mutex);
    SAVEDESTRUCTOR_X(recursive_lock_release,lock);
}

#define ENTER_LOCK         STMT_START { \
			      ENTER; \
			      recursive_lock_acquire(aTHX_ &PL_sharedsv_lock, __FILE__, __LINE__);   \
                            } STMT_END

#define LEAVE_LOCK       LEAVE


/* A common idiom is to acquire access and switch in ... */
#define SHARED_EDIT	    STMT_START {	\
				ENTER_LOCK;	\
				SHARED_CONTEXT;	\
			    } STMT_END

/* then switch out and release access. */
#define SHARED_RELEASE     STMT_START {	\
		                CALLER_CONTEXT;	\
				LEAVE_LOCK;	\
			    } STMT_END


/*

  Shared SV

  Shared SV is a structure for keeping the backend storage
  of shared svs.

  Shared-ness really only needs the SV * - the rest is for locks.
  (Which suggests further space optimization ... )

*/

typedef struct {
    SV                 *sv;             /* The actual SV - in shared space */
    recursive_lock_t    lock;
    perl_cond           user_cond;      /* For user-level conditions */
} shared_sv;

/* The SV in shared-space has a back-pointer to the shared_sv
   struct associated with it PERL_MAGIC_ext.

   The vtable used has just one entry - when the SV goes away
   we free the memory for the above.

 */

int
sharedsv_shared_mg_free(pTHX_ SV *sv, MAGIC *mg)
{
    shared_sv *shared = (shared_sv *) mg->mg_ptr;
    assert( aTHX == PL_sharedsv_space );
    if (shared) {
	PerlMemShared_free(shared);
	mg->mg_ptr = NULL;
    }
    return 0;
}

MGVTBL sharedsv_shared_vtbl = {
 0,				/* get */
 0,				/* set */
 0,				/* len */
 0,				/* clear */
 sharedsv_shared_mg_free,	/* free */
 0,				/* copy */
 0,				/* dup */
};

/* Access to shared things is heavily based on MAGIC - in mg.h/mg.c/sv.c sense */

/* In any thread that has access to a shared thing there is a "proxy"
   for it in its own space which has 'MAGIC' associated which accesses
   the shared thing.
 */

MGVTBL sharedsv_scalar_vtbl;    /* scalars have this vtable */
MGVTBL sharedsv_array_vtbl;     /* hashes and arrays have this - like 'tie' */
MGVTBL sharedsv_elem_vtbl;      /* elements of hashes and arrays have this
				   _AS WELL AS_ the scalar magic */

/* The sharedsv_elem_vtbl associates the element with the array/hash and
   the sharedsv_scalar_vtbl associates it with the value
 */


/* Accessor to convert threads::shared::tie objects back shared_sv * */
shared_sv *
SV_to_sharedsv(pTHX_ SV *sv)
{
    shared_sv *shared = 0;
    if (SvROK(sv))
     {
      shared = INT2PTR(shared_sv *, SvIV(SvRV(sv)));
     }
    return shared;
}

=for apidoc sharedsv_find

Given a private side SV tries to find if the SV has a shared backend,
by looking for the magic.

=cut

shared_sv *
Perl_sharedsv_find(pTHX_ SV *sv)
{
    MAGIC *mg;
    if (SvTYPE(sv) >= SVt_PVMG) {
	switch(SvTYPE(sv)) {
	case SVt_PVAV:
	case SVt_PVHV:
	    if ((mg = mg_find(sv, PERL_MAGIC_tied))
		&& mg->mg_virtual == &sharedsv_array_vtbl) {
		return (shared_sv *) mg->mg_ptr;
	    }
	    break;
	default:
	    /* This should work for elements as well as they
	     * have scalar magic as well as their element magic
	     */
	    if ((mg = mg_find(sv, PERL_MAGIC_shared_scalar))
		&& mg->mg_virtual == &sharedsv_scalar_vtbl) {
		return (shared_sv *) mg->mg_ptr;
	    }
	    break;
	}
    }
    /* Just for tidyness of API also handle tie objects */
    if (SvROK(sv) && sv_derived_from(sv, "threads::shared::tie")) {
	return SV_to_sharedsv(aTHX_ sv);
    }
    return NULL;
}

/*
 *  Almost all the pain is in this routine.
 *
 */

shared_sv *
Perl_sharedsv_associate(pTHX_ SV **psv, SV *ssv, shared_sv *data)
{
    dTHXc;
    MAGIC *mg = 0;
    SV *sv    = (psv) ? *psv : Nullsv;

    /* If we are asked for an private ops we need a thread */
    assert ( aTHX !=  PL_sharedsv_space );

    /* To avoid need for recursive locks require caller to hold lock */
    assert ( PL_sharedsv_lock.owner == aTHX );

    /* First try and get existing global data structure */

    /* Try shared SV as 1st choice */
    if (!data && ssv && SvTYPE(ssv) >= SVt_PVMG) {
	if (mg = mg_find(ssv, PERL_MAGIC_ext)) {
	    data = (shared_sv *) mg->mg_ptr;
	}
    }

    /* Next see if private SV is associated with something */
    if (!data && sv) {
	data = Perl_sharedsv_find(aTHX_ sv);
    }

    /* If neither of those then create a new one */
    if (!data) {
	    SHARED_CONTEXT;
	    if (!ssv)
		ssv = newSV(0);
	    data = PerlMemShared_malloc(sizeof(shared_sv));
	    Zero(data,1,shared_sv);
	    SHAREDSvPTR(data) = ssv;
	    /* Tag shared side SV with data pointer */
	    sv_magicext(ssv, ssv, PERL_MAGIC_ext, &sharedsv_shared_vtbl,
		   (char *)data, 0);
	    recursive_lock_init(aTHX_ &data->lock);
	    COND_INIT(&data->user_cond);
	    CALLER_CONTEXT;
    }

    if (!ssv)
	ssv = SHAREDSvPTR(data);
    if (!SHAREDSvPTR(data))
	SHAREDSvPTR(data) = ssv;

    /* If we know type upgrade shared side SV */
    if (sv && SvTYPE(ssv) < SvTYPE(sv)) {
	SHARED_CONTEXT;
	sv_upgrade(ssv, SvTYPE(*psv));
	CALLER_CONTEXT;
    }

    /* Now if requested allocate private SV */
    if (psv && !sv) {
	*psv = sv = newSV(0);
    }

    /* Finally if private SV exists check and add magic */
    if (sv) {
	MAGIC *mg = 0;
	if (SvTYPE(sv) < SvTYPE(ssv)) {
	    sv_upgrade(sv, SvTYPE(ssv));
	}
	switch(SvTYPE(sv)) {
	case SVt_PVAV:
	case SVt_PVHV:
	    if (!(mg = mg_find(sv, PERL_MAGIC_tied))
		|| mg->mg_virtual != &sharedsv_array_vtbl
		|| (shared_sv *) mg->mg_ptr != data) {
		SV *obj = newSV(0);
		sv_setref_iv(obj, "threads::shared::tie",PTR2IV(data));
		if (mg) {
		    sv_unmagic(sv, PERL_MAGIC_tied);
		}
		mg = sv_magicext(sv, obj, PERL_MAGIC_tied, &sharedsv_array_vtbl,
				(char *) data, 0);
		mg->mg_flags |= (MGf_COPY|MGf_DUP);
		SvREFCNT_inc(ssv);
		SvREFCNT_dec(obj);
	    }
	    break;

	default:
	    if ((SvTYPE(sv) < SVt_PVMG)
		|| !(mg = mg_find(sv, PERL_MAGIC_shared_scalar))
		|| mg->mg_virtual != &sharedsv_scalar_vtbl
		|| (shared_sv *) mg->mg_ptr != data) {
		if (mg) {
		    sv_unmagic(sv, PERL_MAGIC_shared_scalar);
		}
		mg = sv_magicext(sv, Nullsv, PERL_MAGIC_shared_scalar,
				&sharedsv_scalar_vtbl, (char *)data, 0);
		mg->mg_flags |= (MGf_COPY|MGf_DUP);
		SvREFCNT_inc(ssv);
	    }
	    break;
	}
	assert ( Perl_sharedsv_find(aTHX_ *psv) == data );
    }
    return data;
}

void
Perl_sharedsv_free(pTHX_ shared_sv *shared)
{
    if (shared) {
	dTHXc;
	SHARED_EDIT;
	SvREFCNT_dec(SHAREDSvPTR(shared));
	SHARED_RELEASE;
    }
}

void
Perl_sharedsv_share(pTHX_ SV *sv)
{
    switch(SvTYPE(sv)) {
    case SVt_PVGV:
	Perl_croak(aTHX_ "Cannot share globs yet");
	break;

    case SVt_PVCV:
	Perl_croak(aTHX_ "Cannot share subs yet");
	break;

    default:
	ENTER_LOCK;
	Perl_sharedsv_associate(aTHX_ &sv, 0, 0);
	LEAVE_LOCK;
	SvSETMAGIC(sv);
	break;
    }
}

/* MAGIC (in mg.h sense) hooks */

int
sharedsv_scalar_mg_get(pTHX_ SV *sv, MAGIC *mg)
{
    shared_sv *shared = (shared_sv *) mg->mg_ptr;
    assert(shared);

    ENTER_LOCK;
    if (SHAREDSvPTR(shared)) {
	if (SvROK(SHAREDSvPTR(shared))) {
	    SV *obj = Nullsv;
	    Perl_sharedsv_associate(aTHX_ &obj, SvRV(SHAREDSvPTR(shared)), NULL);
	    sv_setsv_nomg(sv, &PL_sv_undef);
	    SvRV(sv) = obj;
	    SvROK_on(sv);
	}
	else {
	    sv_setsv_nomg(sv, SHAREDSvPTR(shared));
	}
    }
    LEAVE_LOCK;
    return 0;
}

void
sharedsv_scalar_store(pTHX_ SV *sv, shared_sv *shared)
{
    dTHXc;
    bool allowed = TRUE;
    if (SvROK(sv)) {
	shared_sv* target = Perl_sharedsv_find(aTHX_ SvRV(sv));
	if (target) {
	    SV *tmp;
	    SHARED_CONTEXT;
	    tmp = newRV(SHAREDSvPTR(target));
	    sv_setsv_nomg(SHAREDSvPTR(shared), tmp);
	    SvREFCNT_dec(tmp);
	    CALLER_CONTEXT;
	}
	else {
	    allowed = FALSE;
	}
    }
    else {
		SvTEMP_off(sv);
	SHARED_CONTEXT;
	sv_setsv_nomg(SHAREDSvPTR(shared), sv);
	CALLER_CONTEXT;
    }
    if (!allowed) {
	Perl_croak(aTHX_ "Invalid value for shared scalar");
    }
}

int
sharedsv_scalar_mg_set(pTHX_ SV *sv, MAGIC *mg)
{
    shared_sv *shared;
    ENTER_LOCK;
    /* We call associate to potentially upgrade shared side SV */
    shared = Perl_sharedsv_associate(aTHX_ &sv, Nullsv, (shared_sv *) mg->mg_ptr);
    assert(shared);
    sharedsv_scalar_store(aTHX_ sv, shared);
    LEAVE_LOCK;
    return 0;
}

int
sharedsv_scalar_mg_free(pTHX_ SV *sv, MAGIC *mg)
{
    shared_sv *shared = (shared_sv *) mg->mg_ptr;
#if 0
    assert (SvREFCNT(SHAREDSvPTR(shared)) < 1000);
#endif
    Perl_sharedsv_free(aTHX_ shared);
    return 0;
}

int
sharedsv_scalar_mg_clear(pTHX_ SV *sv, MAGIC *mg)
{
    shared_sv *shared = (shared_sv *) mg->mg_ptr;
    return 0;
}

/*
 * Called during cloning of new threads
 */
int
sharedsv_scalar_mg_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param)
{
    shared_sv *shared = (shared_sv *) mg->mg_ptr;
    if (shared) {
	SvREFCNT_inc(SHAREDSvPTR(shared));
    }
    return 0;
}

MGVTBL sharedsv_scalar_vtbl = {
 sharedsv_scalar_mg_get,	/* get */
 sharedsv_scalar_mg_set,	/* set */
 0,				/* len */
 sharedsv_scalar_mg_clear,	/* clear */
 sharedsv_scalar_mg_free,	/* free */
 0,				/* copy */
 sharedsv_scalar_mg_dup		/* dup */
};

/* Now the arrays/hashes stuff */
int
sharedsv_elem_mg_FETCH(pTHX_ SV *sv, MAGIC *mg)
{
    dTHXc;
    shared_sv *shared = SV_to_sharedsv(aTHX_ mg->mg_obj);
    shared_sv *target = Perl_sharedsv_find(aTHX_ sv);
    SV** svp;

    assert ( shared );
    assert ( SHAREDSvPTR(shared) );

    ENTER_LOCK;

    if (SvTYPE(SHAREDSvPTR(shared)) == SVt_PVAV) {
	assert ( mg->mg_ptr == 0 );
	SHARED_CONTEXT;
	svp = av_fetch((AV*) SHAREDSvPTR(shared), mg->mg_len, 0);
    }
    else {
	char *key = mg->mg_ptr;
	STRLEN len = mg->mg_len;
	assert ( mg->mg_ptr != 0 );
	if (mg->mg_len == HEf_SVKEY) {
	   key = SvPV((SV *) mg->mg_ptr, len);
	}
	SHARED_CONTEXT;
	svp = hv_fetch((HV*) SHAREDSvPTR(shared), key, len, 0);
    }
    CALLER_CONTEXT;
    if (svp) {
	/* Exists in the array */
	target = Perl_sharedsv_associate(aTHX_ &sv, *svp, target);
	sv_setsv(sv, *svp);
    }
    else {
	/* Not in the array */
	sv_setsv(sv, &PL_sv_undef);
    }
    LEAVE_LOCK;
    return 0;
}

int
sharedsv_elem_mg_STORE(pTHX_ SV *sv, MAGIC *mg)
{
    dTHXc;
    bool allowed;
    shared_sv *shared = SV_to_sharedsv(aTHX_ mg->mg_obj);
    shared_sv *target;
    SV **svp;
    /* Theory - SV itself is magically shared - and we have ordered the
       magic such that by the time we get here it has been stored
       to its shared counterpart
     */
    ENTER_LOCK;
    assert(shared);
    assert(SHAREDSvPTR(shared));
    if (SvTYPE(SHAREDSvPTR(shared)) == SVt_PVAV) {
	assert ( mg->mg_ptr == 0 );
	SHARED_CONTEXT;
	svp = av_fetch((AV*) SHAREDSvPTR(shared), mg->mg_len, 1);
    }
    else {
	char *key = mg->mg_ptr;
	STRLEN len = mg->mg_len;
	assert ( mg->mg_ptr != 0 );
	if (mg->mg_len == HEf_SVKEY)
	   key = SvPV((SV *) mg->mg_ptr, len);
	SHARED_CONTEXT;
	svp = hv_fetch((HV*) SHAREDSvPTR(shared), key, len, 1);
    }
    CALLER_CONTEXT;
    target = Perl_sharedsv_associate(aTHX_ &sv, *svp, 0);
    sharedsv_scalar_store(aTHX_ sv, target);
    LEAVE_LOCK;
    return 0;
}

int
sharedsv_elem_mg_DELETE(pTHX_ SV *sv, MAGIC *mg)
{
    dTHXc;
    shared_sv *shared = SV_to_sharedsv(aTHX_ mg->mg_obj);
    SV* ssv;
    ENTER_LOCK;
    sharedsv_elem_mg_FETCH(aTHX_ sv, mg);
    if (SvTYPE(SHAREDSvPTR(shared)) == SVt_PVAV) {
	SHARED_CONTEXT;
	av_delete((AV*) SHAREDSvPTR(shared), mg->mg_len, G_DISCARD);
    }
    else {
	char *key = mg->mg_ptr;
	STRLEN len = mg->mg_len;
	assert ( mg->mg_ptr != 0 );
	if (mg->mg_len == HEf_SVKEY)
	   key = SvPV((SV *) mg->mg_ptr, len);
	SHARED_CONTEXT;
	hv_delete((HV*) SHAREDSvPTR(shared), key, len, G_DISCARD);
    }
    CALLER_CONTEXT;
    LEAVE_LOCK;
    return 0;
}

int
sharedsv_elem_mg_free(pTHX_ SV *sv, MAGIC *mg)
{
    Perl_sharedsv_free(aTHX_ SV_to_sharedsv(aTHX_ mg->mg_obj));
    return 0;
}

int
sharedsv_elem_mg_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param)
{
    shared_sv *shared = SV_to_sharedsv(aTHX_ mg->mg_obj);
    SvREFCNT_inc(SHAREDSvPTR(shared));
    mg->mg_flags |= MGf_DUP;
    return 0;
}

MGVTBL sharedsv_elem_vtbl = {
 sharedsv_elem_mg_FETCH,	/* get */
 sharedsv_elem_mg_STORE,	/* set */
 0,				/* len */
 sharedsv_elem_mg_DELETE,	/* clear */
 sharedsv_elem_mg_free,		/* free */
 0,				/* copy */
 sharedsv_elem_mg_dup		/* dup */
};

U32
sharedsv_array_mg_FETCHSIZE(pTHX_ SV *sv, MAGIC *mg)
{
    dTHXc;
    shared_sv *shared = (shared_sv *) mg->mg_ptr;
    U32 val;
    SHARED_EDIT;
    if (SvTYPE(SHAREDSvPTR(shared)) == SVt_PVAV) {
	val = av_len((AV*) SHAREDSvPTR(shared));
    }
    else {
	/* not actually defined by tie API but ... */
	val = HvKEYS((HV*) SHAREDSvPTR(shared));
    }
    SHARED_RELEASE;
    return val;
}

int
sharedsv_array_mg_CLEAR(pTHX_ SV *sv, MAGIC *mg)
{
    dTHXc;
    shared_sv *shared = (shared_sv *) mg->mg_ptr;
    SHARED_EDIT;
    if (SvTYPE(SHAREDSvPTR(shared)) == SVt_PVAV) {
	av_clear((AV*) SHAREDSvPTR(shared));
    }
    else {
	hv_clear((HV*) SHAREDSvPTR(shared));
    }
    SHARED_RELEASE;
    return 0;
}

int
sharedsv_array_mg_free(pTHX_ SV *sv, MAGIC *mg)
{
    Perl_sharedsv_free(aTHX_ (shared_sv *) mg->mg_ptr);
    return 0;
}

/*
 * This is called when perl is about to access an element of
 * the array -
 */
int
sharedsv_array_mg_copy(pTHX_ SV *sv, MAGIC* mg,
		       SV *nsv, const char *name, int namlen)
{
    shared_sv *shared = (shared_sv *) mg->mg_ptr;
    MAGIC *nmg = sv_magicext(nsv,mg->mg_obj,
			    toLOWER(mg->mg_type),&sharedsv_elem_vtbl,
			    name, namlen);
    SvREFCNT_inc(SHAREDSvPTR(shared));
    nmg->mg_flags |= MGf_DUP;
    return 1;
}

int
sharedsv_array_mg_dup(pTHX_ MAGIC *mg, CLONE_PARAMS *param)
{
    shared_sv *shared = (shared_sv *) mg->mg_ptr;
    SvREFCNT_inc(SHAREDSvPTR(shared));
    mg->mg_flags |= MGf_DUP;
    return 0;
}

MGVTBL sharedsv_array_vtbl = {
 0,				/* get */
 0,				/* set */
 sharedsv_array_mg_FETCHSIZE,	/* len */
 sharedsv_array_mg_CLEAR,	/* clear */
 sharedsv_array_mg_free,	/* free */
 sharedsv_array_mg_copy,	/* copy */
 sharedsv_array_mg_dup		/* dup */
};

=for apidoc sharedsv_unlock

Recursively unlocks a shared sv.

=cut

void
Perl_sharedsv_unlock(pTHX_ shared_sv* ssv)
{
    recursive_lock_release(aTHX_ &ssv->lock);
}

=for apidoc sharedsv_lock

Recursive locks on a sharedsv.
Locks are dynamically scoped at the level of the first lock.

=cut

void
Perl_sharedsv_lock(pTHX_ shared_sv* ssv)
{
    if (!ssv)
	return;
    recursive_lock_acquire(aTHX_ &ssv->lock, __FILE__, __LINE__);
}

void
Perl_sharedsv_locksv(pTHX_ SV *sv)
{
    Perl_sharedsv_lock(aTHX_ Perl_sharedsv_find(aTHX_ sv));
}

=head1 Shared SV Functions

=for apidoc sharedsv_init

Saves a space for keeping SVs wider than an interpreter,
currently only stores a pointer to the first interpreter.

=cut

void
Perl_sharedsv_init(pTHX)
{
  dTHXc;
  /* This pair leaves us in shared context ... */
  PL_sharedsv_space = perl_alloc();
  perl_construct(PL_sharedsv_space);
  CALLER_CONTEXT;
  recursive_lock_init(aTHX_ &PL_sharedsv_lock);
  PL_lockhook = &Perl_sharedsv_locksv;
  PL_sharehook = &Perl_sharedsv_share;
}

MODULE = threads::shared	PACKAGE = threads::shared::tie

PROTOTYPES: DISABLE


void
PUSH(shared_sv *shared, ...)
CODE:
	dTHXc;
	int i;
	for(i = 1; i < items; i++) {
	    SV* tmp = newSVsv(ST(i));
	    shared_sv *target;
	    ENTER_LOCK;
	    target = Perl_sharedsv_associate(aTHX_ &tmp, Nullsv, 0);
	    sharedsv_scalar_store(aTHX_ tmp, target);
	    SHARED_CONTEXT;
	    av_push((AV*) SHAREDSvPTR(shared), SHAREDSvPTR(target));
	    SHARED_RELEASE;
	    SvREFCNT_dec(tmp);
	}

void
UNSHIFT(shared_sv *shared, ...)
CODE:
	dTHXc;
	int i;
	ENTER_LOCK;
	SHARED_CONTEXT;
	av_unshift((AV*)SHAREDSvPTR(shared), items - 1);
	CALLER_CONTEXT;
	for(i = 1; i < items; i++) {
	    SV* tmp = newSVsv(ST(i));
	    shared_sv *target = Perl_sharedsv_associate(aTHX_ &tmp, Nullsv, 0);
	    sharedsv_scalar_store(aTHX_ tmp, target);
	    SHARED_CONTEXT;
	    av_store((AV*) SHAREDSvPTR(shared), i - 1, SHAREDSvPTR(target));
	    CALLER_CONTEXT;
	    SvREFCNT_dec(tmp);
	}
	LEAVE_LOCK;

void
POP(shared_sv *shared)
CODE:
	dTHXc;
	SV* sv;
	ENTER_LOCK;
	SHARED_CONTEXT;
	sv = av_pop((AV*)SHAREDSvPTR(shared));
	CALLER_CONTEXT;
	ST(0) = Nullsv;
	Perl_sharedsv_associate(aTHX_ &ST(0), sv, 0);
	LEAVE_LOCK;
	XSRETURN(1);

void
SHIFT(shared_sv *shared)
CODE:
	dTHXc;
	SV* sv;
	ENTER_LOCK;
	SHARED_CONTEXT;
	sv = av_shift((AV*)SHAREDSvPTR(shared));
	CALLER_CONTEXT;
	ST(0) = Nullsv;
	Perl_sharedsv_associate(aTHX_ &ST(0), sv, 0);
	LEAVE_LOCK;
	XSRETURN(1);

void
EXTEND(shared_sv *shared, IV count)
CODE:
	dTHXc;
	SHARED_EDIT;
	av_extend((AV*)SHAREDSvPTR(shared), count);
	SHARED_RELEASE;

void
STORESIZE(shared_sv *shared,IV count)
CODE:
	dTHXc;
	SHARED_EDIT;
	av_fill((AV*) SHAREDSvPTR(shared), count);
	SHARED_RELEASE;




void
EXISTS(shared_sv *shared, SV *index)
CODE:
	dTHXc;
	bool exists;
	SHARED_EDIT;
	if (SvTYPE(SHAREDSvPTR(shared)) == SVt_PVAV) {
	    exists = av_exists((AV*) SHAREDSvPTR(shared), SvIV(index));
	}
	else {
	    STRLEN len;
	    char *key = SvPV(index,len);
	    exists = hv_exists((HV*) SHAREDSvPTR(shared), key, len);
	}
	SHARED_RELEASE;
	ST(0) = (exists) ? &PL_sv_yes : &PL_sv_no;
	XSRETURN(1);


void
FIRSTKEY(shared_sv *shared)
CODE:
	dTHXc;
	char* key = NULL;
	I32 len = 0;
	HE* entry;
	ENTER_LOCK;
	SHARED_CONTEXT;
	hv_iterinit((HV*) SHAREDSvPTR(shared));
	entry = hv_iternext((HV*) SHAREDSvPTR(shared));
	if (entry) {
		key = hv_iterkey(entry,&len);
		CALLER_CONTEXT;
		ST(0) = sv_2mortal(newSVpv(key, len));
	} else {
	     CALLER_CONTEXT;
	     ST(0) = &PL_sv_undef;
	}
	LEAVE_LOCK;
	XSRETURN(1);

void
NEXTKEY(shared_sv *shared, SV *oldkey)
CODE:
	dTHXc;
	char* key = NULL;
	I32 len = 0;
	HE* entry;
	ENTER_LOCK;
	SHARED_CONTEXT;
	entry = hv_iternext((HV*) SHAREDSvPTR(shared));
	if (entry) {
		key = hv_iterkey(entry,&len);
		CALLER_CONTEXT;
		ST(0) = sv_2mortal(newSVpv(key, len));
	} else {
	     CALLER_CONTEXT;
	     ST(0) = &PL_sv_undef;
	}
	LEAVE_LOCK;
	XSRETURN(1);

MODULE = threads::shared                PACKAGE = threads::shared

PROTOTYPES: ENABLE

void
_id(SV *ref)
	PROTOTYPE: \[$@%]
CODE:
	shared_sv *shared;
	if(SvROK(ref))
	    ref = SvRV(ref);
	if (shared = Perl_sharedsv_find(aTHX_ ref)) {
	    ST(0) = sv_2mortal(newSViv(PTR2IV(shared)));
	    XSRETURN(1);
	}
	XSRETURN_UNDEF;


void
_refcnt(SV *ref)
	PROTOTYPE: \[$@%]
CODE:
	shared_sv *shared;
	if(SvROK(ref))
	    ref = SvRV(ref);
	if (shared = Perl_sharedsv_find(aTHX_ ref)) {
	  if (SHAREDSvPTR(shared)) {
	    ST(0) = sv_2mortal(newSViv(SvREFCNT(SHAREDSvPTR(shared))));
	    XSRETURN(1);
	  }
	  else {
	     Perl_warn(aTHX_ "%_ s=%p has no shared SV",ST(0),shared);
	  }
	}
	else {
	     Perl_warn(aTHX_ "%_ is not shared",ST(0));
	}
	XSRETURN_UNDEF;

void
share(SV *ref)
	PROTOTYPE: \[$@%]
	CODE:
	if(SvROK(ref))
	    ref = SvRV(ref);
	Perl_sharedsv_share(aTHX, ref);

void
lock_enabled(SV *ref)
	PROTOTYPE: \[$@%]
	CODE:
	shared_sv* shared;
	if(SvROK(ref))
	    ref = SvRV(ref);
	shared = Perl_sharedsv_find(aTHX, ref);
	if(!shared)
	   croak("lock can only be used on shared values");
	Perl_sharedsv_lock(aTHX_ shared);

void
cond_wait_enabled(SV *ref)
	PROTOTYPE: \[$@%]
	CODE:
	shared_sv* shared;
	int locks;
	if(SvROK(ref))
	    ref = SvRV(ref);
	shared = Perl_sharedsv_find(aTHX_ ref);
	if(!shared)
	    croak("cond_wait can only be used on shared values");
	if(shared->lock.owner != aTHX)
	    croak("You need a lock before you can cond_wait");
	/* Stealing the members of the lock object worries me - NI-S */
	MUTEX_LOCK(&shared->lock.mutex);
	shared->lock.owner = NULL;
	locks = shared->lock.locks = 0;
	COND_WAIT(&shared->user_cond, &shared->lock.mutex);
	shared->lock.owner = aTHX;
	shared->lock.locks = locks;
	MUTEX_UNLOCK(&shared->lock.mutex);

void
cond_signal_enabled(SV *ref)
	PROTOTYPE: \[$@%]
	CODE:
	shared_sv* shared;
	if(SvROK(ref))
	    ref = SvRV(ref);
	shared = Perl_sharedsv_find(aTHX_ ref);
	if(!shared)
	    croak("cond_signal can only be used on shared values");
	COND_SIGNAL(&shared->user_cond);

void
cond_broadcast_enabled(SV *ref)
	PROTOTYPE: \[$@%]
	CODE:
	shared_sv* shared;
	if(SvROK(ref))
	    ref = SvRV(ref);
	shared = Perl_sharedsv_find(aTHX_ ref);
	if(!shared)
	    croak("cond_broadcast can only be used on shared values");
	COND_BROADCAST(&shared->user_cond);

BOOT:
{
     Perl_sharedsv_init(aTHX);
}
