#undef stdin
#undef stdout
#undef getc
#undef putc
#undef clearerr
#undef fflush
#undef feof
#undef ferror
#undef fileno
#define _CANNOT "CANNOT"
#define fprintf  _CANNOT fprintf_
#define stdin      _CANNOT _stdin_
#define stdout     _CANNOT _stdout_
#define stderr     _CANNOT _stderr_
#define tmpfile()  _CANNOT _tmpfile_
#define fclose(f)  _CANNOT _fclose_
#define fflush(f)  _CANNOT _fflush_
#define fopen(p,m)  _CANNOT _fopen_
#define freopen(p,m,f)  _CANNOT _freopen_
#define setbuf(f,b)  _CANNOT _setbuf_
#define setvbuf(f,b,x,s)  _CANNOT _setvbuf_
#define fscanf  _CANNOT _fscanf_
#define vfprintf(f,fmt,a)  _CANNOT _vfprintf_
#define fgetc(f)  _CANNOT _fgetc_
#define fgets(s,n,f)  _CANNOT _fgets_
#define fputc(c,f)  _CANNOT _fputc_
#define fputs(s,f)  _CANNOT _fputs_
#define getc(f)  _CANNOT _getc_
#define putc(c,f)  _CANNOT _putc_
#define ungetc(c,f)  _CANNOT _ungetc_
#define fread(b,s,c,f)  _CANNOT _fread_
#define fwrite(b,s,c,f)  _CANNOT _fwrite_
#define fgetpos(f,p)  _CANNOT _fgetpos_
#define fseek(f,o,w)  _CANNOT _fseek_
#define fsetpos(f,p)  _CANNOT _fsetpos_
#define ftell(f)  _CANNOT _ftell_
#define rewind(f)  _CANNOT _rewind_
#define clearerr(f)  _CANNOT _clearerr_
#define feof(f)  _CANNOT _feof_
#define ferror(f)  _CANNOT _ferror_
#define __filbuf(f)  _CANNOT __filbuf_
#define __flsbuf(c,f)  _CANNOT __flsbuf_
#define _filbuf(f)  _CANNOT _filbuf_
#define _flsbuf(c,f)  _CANNOT _flsbuf_
#define fdopen(fd,p)  _CANNOT _fdopen_
#define fileno(f)  _CANNOT _fileno_
#define flockfile(f)  _CANNOT _flockfile_
#define ftrylockfile(f)  _CANNOT _ftrylockfile_
#define funlockfile(f)  _CANNOT _funlockfile_
#define getc_unlocked(f)  _CANNOT _getc_unlocked_
#define putc_unlocked(c,f)  _CANNOT _putc_unlocked_
#define popen(c,m)  _CANNOT _popen_
#define getw(f)  _CANNOT _getw_
#define putw(v,f)  _CANNOT _putw_
#define pclose(f)  _CANNOT _pclose_

