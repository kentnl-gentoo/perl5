#ifndef H_PERLIO
#define H_PERLIO 1

/* Allow -DUSE_STDIO to force the issue for x2p directory */
#ifdef USE_STDIO
#ifdef PERLIO_IS_STDIO
#undef PERLIO_IS_STDIO
#endif
#define PERLIO_IS_STDIO
#else
extern void PerlIO_init _((void));
#endif

#ifdef PERLIO_IS_STDIO
#include <stdio.h>
#define PerlIO				FILE 
#define PerlIO_stderr()			stderr
#define PerlIO_stdout()			stdout
#define PerlIO_stdin()			stdin

#define PerlIO_printf			fprintf
#define PerlIO_stdoutf			printf
#define PerlIO_vprintf(f,fmt,a)		vfprintf(f,fmt,a)          
#define PerlIO_read(f,buf,count)	fread(buf,1,count,f)
#define PerlIO_write(f,buf,count)	fwrite1(buf,1,count,f)
#define PerlIO_open(path,mode)		fopen(path,mode)
#define PerlIO_fdopen(fd,mode)		fdopen(fd,mode)
#define PerlIO_close(f)			fclose(f)
#define PerlIO_puts(f,s)		fputs(s,f)
#define PerlIO_putc(f,c)		fputc(c,f)
#define PerlIO_ungetc(f,c)		ungetc(c,f)
#define PerlIO_getc(f)			getc(f)
#define PerlIO_eof(f)			feof(f)
#define PerlIO_error(f)			ferror(f)
#define PerlIO_fileno(f)		fileno(f)
#define PerlIO_clearerr(f)		clearerr(f)
#define PerlIO_flush(f)			Fflush(f)
#define PerlIO_tell(f)			ftell(f)
#define PerlIO_seek(f,o,w)		fseek(f,o,w)
#ifdef HAS_FGETPOS
#define PerlIO_getpos(f,p)		fgetpos(f,p)
#endif
#ifdef HAS_FSETPOS
#define PerlIO_setpos(f,p)		fsetpos(f,p)
#endif

#define PerlIO_rewind(f)		rewind(f)
#define PerlIO_tmpfile()		tmpfile()

#define PerlIO_importFILE(f,fl)		(f)            
#define PerlIO_exportFILE(f,fl)		(f)            
#define PerlIO_findFILE(f)		(f)            
#define PerlIO_releaseFILE(p,f)		((void) 0)            

#ifdef HAS_SETLINEBUF
#define PerlIO_setlinebuf(f)		setlinebuf(f);
#else
#define PerlIO_setlinebuf(f)		setvbuf(f, Nullch, _IOLBF, 0);
#endif

/* Now our interface to Configure's FILE_xxx macros */

#ifdef USE_STDIO_PTR
#define PerlIO_has_cntptr(f)		1       
#define PerlIO_get_ptr(f)		FILE_ptr(f)          
#define PerlIO_get_cnt(f)		FILE_cnt(f)          

#ifdef FILE_CNT_LVALUE
#define PerlIO_canset_cnt(f)		1      
#ifdef FILE_PTR_LVALUE
#define PerlIO_fast_gets(f)		1        
#endif
#define PerlIO_set_cnt(f,c)		(FILE_cnt(f) = (c))          
#else
#define PerlIO_canset_cnt(f)		0      
#define PerlIO_set_cnt(f,c)		abort()
#endif

#ifdef FILE_PTR_LVALUE
#define PerlIO_set_ptrcnt(f,p,c)	(FILE_ptr(f) = (p), PerlIO_set_cnt(f,c))          
#else
#define PerlIO_set_ptrcnt(f,p,c)	abort()
#endif

#else  /* USE_STDIO_PTR */
#define PerlIO_has_cntptr(f)		0
#endif /* USE_STDIO_PTR */

#ifndef PerlIO_fast_gets
#define PerlIO_fast_gets(f)		0        
#endif


#ifdef FILE_base
#define PerlIO_has_base(f)		1         
#define PerlIO_get_base(f)		FILE_base(f)         
#define PerlIO_get_bufsiz(f)		FILE_bufsiz(f)       
#else
#define PerlIO_has_base(f)		0
#endif

#else /* PERLIO_IS_STDIO */

#undef Fpos_t

#ifndef PERLIO_C
#include "nostdio.h"
#endif

extern char *tmpnam _((char *));

#ifdef HASATTRIBUTE
/*
 * #define of printf breaks __attribute__ stuff 
 * so do not do that here, but rather at end of perl.h
 */
#else
#define printf  PerlIO_stdoutf
#endif



/* This is an 1st attempt to stop other include files pulling 
   in real <stdio.h>.
   A more ambitious set of possible symbols can be found in
   sfio.h (inside an _cplusplus gard).
*/
#if !defined(_STDIO_H) && !defined(FILE)
#define	_STDIO_H
struct _FILE;
#define FILE struct _FILE
#endif

#ifdef USE_SFIO
/* The next #ifdef should be redundant if Configure behaves ... */
#ifdef I_SFIO
#include <sfio.h>
#endif

extern Sfio_t*	_stdopen _ARG_((int, const char*));
extern int	_stdprintf _ARG_((const char*, ...));

#define PerlIO				Sfio_t
#define PerlIO_stderr()			sfstderr
#define PerlIO_stdout()			sfstdout
#define PerlIO_stdin()			sfstdin

#define PerlIO_printf			sfprintf
#define PerlIO_stdoutf			_stdprintf
#define PerlIO_vprintf(f,fmt,a)		sfvprintf(f,fmt,a)          
#define PerlIO_read(f,buf,count)	sfread(f,buf,count)
#define PerlIO_write(f,buf,count)	sfwrite(f,buf,count)
#define PerlIO_open(path,mode)		sfopen(NULL,path,mode)
#define PerlIO_fdopen(fd,mode)		_stdopen(fd,mode)
#define PerlIO_close(f)			sfclose(f)
#define PerlIO_puts(f,s)		sfputr(f,s,-1)
#define PerlIO_putc(f,c)		sfputc(f,c)
#define PerlIO_ungetc(f,c)		sfungetc(f,c)
#define PerlIO_getc(f)			sfgetc(f)
#define PerlIO_eof(f)			sfeof(f)
#define PerlIO_error(f)			sferror(f)
#define PerlIO_fileno(f)		sffileno(f)
#define PerlIO_clearerr(f)		sfclrerr(f)
#define PerlIO_flush(f)			sfsync(f)
#define PerlIO_tell(f)			sftell(f)
#define PerlIO_seek(f,o,w)		sfseek(f,o,w)
#define PerlIO_rewind(f)		(void) sfseek((f),0L,0)
#define PerlIO_tmpfile()		sftmp(0)

#define PerlIO_importFILE(f,fl)		croak("Import from FILE * unimplemeted")
#define PerlIO_exportFILE(f,fl)		croak("Export to FILE * unimplemeted")
#define PerlIO_findFILE(f)		NULL
#define PerlIO_releaseFILE(p,f)		croak("Release of FILE * unimplemeted")

#define PerlIO_setlinebuf(f)		sfset(f,SF_LINE,1)

/* Now our interface to equivalent of Configure's FILE_xxx macros */

#define PerlIO_has_cntptr(f)		1       
#define PerlIO_get_ptr(f)		((f)->next)
#define PerlIO_get_cnt(f)		((f)->endr - (f)->next)
#define PerlIO_canset_cnt(f)		1      
#define PerlIO_fast_gets(f)		1        
#define PerlIO_set_ptrcnt(f,p,c)	((f)->next = (p))          
#define PerlIO_set_cnt(f,c)		1

#define PerlIO_has_base(f)		1         
#define PerlIO_get_base(f)		((f)->data)
#define PerlIO_get_bufsiz(f)		((f)->endr - (f)->data)


#else /* PERLIO_IS_SFIO */

#ifndef EOF
#define EOF (-1)
#endif


#ifndef PerlIO
struct _PerlIO;
#define PerlIO struct _PerlIO
#endif /* No PerlIO */

#ifndef NEXT30_NO_ATTRIBUTE
#ifndef HASATTRIBUTE       /* disable GNU-cc attribute checking? */
#ifdef  __attribute__      /* Avoid possible redefinition errors */
#undef  __attribute__
#endif
#define __attribute__(attr)
#endif 
#endif

extern int	PerlIO_stdoutf		_((const char *,...))
					__attribute__((format (printf, 1, 2)));
extern int	PerlIO_puts		_((PerlIO *,const char *));
extern PerlIO *	PerlIO_open		_((const char *,const char *));
extern int	PerlIO_close		_((PerlIO *));
extern int	PerlIO_eof		_((PerlIO *));
extern int	PerlIO_error		_((PerlIO *));
extern void	PerlIO_clearerr		_((PerlIO *));
extern int	PerlIO_getc		_((PerlIO *));
extern int	PerlIO_putc		_((PerlIO *,int));
extern int	PerlIO_flush		_((PerlIO *));
extern int	PerlIO_ungetc		_((PerlIO *,int));
extern int	PerlIO_fileno		_((PerlIO *));
extern PerlIO *	PerlIO_fdopen		_((int, const char *));
extern PerlIO *	PerlIO_importFILE	_((FILE *,int));
extern FILE *	PerlIO_exportFILE	_((PerlIO *,int));
extern FILE *	PerlIO_findFILE		_((PerlIO *));
extern void	PerlIO_releaseFILE	_((PerlIO *,FILE *));
extern int	PerlIO_read		_((PerlIO *,void *,size_t)); 
extern int	PerlIO_write		_((PerlIO *,const void *,size_t)); 
extern void	PerlIO_setlinebuf	_((PerlIO *)); 
extern int	PerlIO_printf		_((PerlIO *, const char *,...))
					__attribute__((format (printf, 2, 3))); 
extern int	PerlIO_vprintf		_((PerlIO *, const char *, va_list)); 
extern long	PerlIO_tell		_((PerlIO *));
extern int	PerlIO_seek		_((PerlIO *,off_t,int));
extern void	PerlIO_rewind		_((PerlIO *));
                       
extern int	PerlIO_has_base		_((PerlIO *)); 
extern int	PerlIO_has_cntptr	_((PerlIO *)); 
extern int	PerlIO_fast_gets	_((PerlIO *)); 
extern int	PerlIO_canset_cnt	_((PerlIO *)); 

extern char *	PerlIO_get_ptr		_((PerlIO *)); 
extern int	PerlIO_get_cnt		_((PerlIO *)); 
extern void	PerlIO_set_cnt		_((PerlIO *,int)); 
extern void	PerlIO_set_ptrcnt	_((PerlIO *,char *,int)); 
extern char *	PerlIO_get_base		_((PerlIO *)); 
extern int	PerlIO_get_bufsiz	_((PerlIO *)); 
extern PerlIO *	PerlIO_tmpfile		_((void));

extern PerlIO *	PerlIO_stdin	_((void));
extern PerlIO *	PerlIO_stdout	_((void));
extern PerlIO *	PerlIO_stderr	_((void));

#endif /* USE_SFIO */
#endif /* PERLIO_IS_STDIO */

#ifndef Fpos_t
#define Fpos_t long
#endif

#ifndef PerlIO_getpos
extern int	PerlIO_getpos		_((PerlIO *,Fpos_t *));
#endif

#ifndef PerlIO_setpos
extern int	PerlIO_setpos		_((PerlIO *,const Fpos_t *));
#endif 

#endif /* Include guard */



