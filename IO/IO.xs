/*
  Copyright (c) 1995-1998 Nick Ing-Simmons. All rights reserved.
  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.
*/

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <fcntl.h>

#include "tkGlue.def"

#include "pTk/tkPort.h"
#include "pTk/tkInt.h"
#include "pTk/tkVMacro.h"
#include "tkGlue.h"
#include "tkGlue.m"

#define InputStream PerlIO *
#define OutputStream PerlIO *

DECLARE_VTABLES;

typedef struct
 {
  PerlIO *f;
  SV *buf;
  int len;
  int offset;
  int count;
  int error;
  int eof; 
 } nIO_read;

#ifdef USE2
static int read_handler _((ClientData clientData, int mask, int flags));
static int 
#else
static void read_handler _((ClientData clientData, int mask));
static void
#endif
read_handler(clientData, mask
#ifdef USE2
,flags
#endif
)
ClientData clientData;
int mask;
#ifdef USE2
int flags;
#endif
{
 if (mask & TCL_READABLE)
  {
   nIO_read *info = (nIO_read *) clientData;
   SV *buf = info->buf;
   int count;
   SvGROW(buf,info->offset+info->len+1);
   count = read(PerlIO_fileno(info->f),SvPVX(buf)+info->offset,(size_t) info->len);
   if (count == 0)
    {
     info->eof = 1;
    }
   else if (count == -1)
    {
     perror("read_handler");
     if (errno == EAGAIN)
      {
       PerlIO_printf(PerlIO_stderr(),"%d would block\n",PerlIO_fileno(info->f));
      }
     else
      info->error = errno;
    }
   else
    {STRLEN len;
     SvCUR_set(buf,SvCUR(buf)+count);
     info->len    -= count;
     info->count  += count;
     info->offset += count;
    }
   SvPVX(buf)[SvCUR(buf)] = '\0';
  }
}

static int restore_mode _((PerlIO *f,int mode));
static int make_nonblock _((PerlIO *f,int *mode,int *newmode));

#ifdef __WIN32__
static int
make_nonblock(f,mode,newmode)
PerlIO *f;
int *mode;
int *newmode;
{
 croak("Cannot make nonblocking on Win32 yet");
 return -1;
}

static int
restore_mode(f,mode)
PerlIO *f;
int mode;
{
 croak("Cannot make nonblocking on Win32 yet");
 return -1;
}
#else
static int 
make_nonblock(f,mode,newmode)
PerlIO *f;
int *mode;
int *newmode;
{
 int RETVAL = fcntl(PerlIO_fileno(f), F_GETFL, 0);
 if (RETVAL >= 0)
  {
   *newmode = *mode = RETVAL;
#ifdef O_NONBLOCK
   /* POSIX style */ 
#ifdef O_NDELAY
   /* Ooops has O_NDELAY too - make sure we don't 
    * get SysV behaviour by mistake
    */
   if ((*mode & O_NDELAY) || !(*mode & O_NONBLOCK))
    {
     *newmode = (*mode & ~O_NDELAY) | O_NONBLOCK;
     RETVAL = fcntl(PerlIO_fileno(f),F_SETFL,*newmode);
    }
#else
   /* Standard POSIX */ 
   if (!(*mode & O_NONBLOCK))
    {
     *newmode = *mode | O_NONBLOCK;
     RETVAL = fcntl(PerlIO_fileno(f),F_SETFL,*newmode);
    }
#endif 
#else
   /* Not POSIX - better have O_NDELAY or we can't cope.
    * for BSD-ish machines this is an acceptable alternative
    * for SysV we can't tell "would block" from EOF but that is 
    * the way SysV is...
    */
   if (!(*mode & O_NDELAY))
    {
     *newmode = *mode | O_NDELAY;
     RETVAL = fcntl(PerlIO_fileno(f),F_SETFL,*newmode);
    }
#endif
  }
 return RETVAL;
}

static int
restore_mode(f,mode)
PerlIO *f;
int mode;
{
 return fcntl(PerlIO_fileno(f), F_SETFL, mode);
}

#endif

static int has_nl _((SV *sv));

static int has_nl(sv)
SV *sv;
{
 STRLEN n = SvCUR(sv);
 char *p = SvPVX(sv);
 while (n-- > 0)
  {
   if (*p++ == '\n')
    return 1; 
  }
 return 0;
}

#define TCL_UNIX_FD 0
#define Tcl_GetFile(x,y) x

/* Avoid Tcl's hacks here - we have enough of our own */
#undef write
#undef read
#undef open

MODULE = Tk::IO	PACKAGE = Tk::IO PREFIX = Tcl_

PROTOTYPES: DISABLE

void
Tcl_CreateReadHandler(f,callback)
InputStream	f
SV *		callback
CODE:
 {
#ifdef NOT_BROKEN
  int fd = PerlIO_fileno(f);
  Tcl_CreateFileHandler(Tcl_GetFile((ClientData) fd,TCL_UNIX_FD), 
                        TCL_READABLE, NULL, callback);
#endif
 }

void
Tcl_CreateWriteHandler(f,callback)
OutputStream	f
SV *		callback
CODE:
 {
#ifdef NOT_BROKEN
  int fd = PerlIO_fileno(f);
  Tcl_CreateFileHandler(Tcl_GetFile((ClientData) fd,TCL_UNIX_FD), 
                        TCL_WRITABLE, NULL, callback);
#endif
 }

void
Tcl_DeleteReadHandler(f)
InputStream	f
CODE:
 {
#ifdef NOT_BROKEN
  int fd = PerlIO_fileno(f);
  Tcl_DeleteFileHandler(Tcl_GetFile((ClientData) fd,TCL_UNIX_FD));
#endif
 }

void
Tcl_DeleteWriteHandler(f)
OutputStream	f
CODE:
 {
#ifdef NOT_BROKEN
  int fd = PerlIO_fileno(f);
  Tcl_DeleteFileHandler(Tcl_GetFile((ClientData) fd,TCL_UNIX_FD));
#endif
 }

MODULE = Tk::IO	PACKAGE = Tk::IO

PROTOTYPES: ENABLE

int
make_nonblock(f,mode,newmode)
InputStream	f
int	&mode = NO_INIT
int	&newmode  = NO_INIT
OUTPUT:
  mode
  newmode

int
restore_mode(f,mode)
InputStream	f
int	mode

SV *
read(f,buf,len,offset = 0)
InputStream	f
SV *	buf
int	len
int	offset
 CODE:
  {
   int mode;
   int newmode;
   int count = make_nonblock(f,&mode,&newmode);
   /* Copy stuff out of PerlIO *  */
   ST(0) = &sv_undef;
   if (count == 0)
    {
     int fd = PerlIO_fileno(f);
     nIO_read info;   
     info.f   = f;    
     info.buf = buf;  
     info.len = len;  
     info.offset = offset;
     info.count  = 0; 
     info.error  = 0; 
     info.eof    = 0; 
     if (!SvUPGRADE(buf, SVt_PV))
      {
       RETVAL = &sv_undef;
       return;
      }
     SvPOK_only(buf);		/* validate pointer */
#ifdef NOT_BROKEN
     Tcl_CreateFileHandler(Tcl_GetFile((ClientData) fd,TCL_UNIX_FD), TCL_READABLE, read_handler, (ClientData) &info);
     do                                        
      {                                        
       Tcl_DoOneEvent(0);                       
      } while (!info.eof && !info.error && info.count == 0);
     Tcl_DeleteFileHandler(Tcl_GetFile((ClientData) fd,TCL_UNIX_FD)); 
#endif
     if (mode != newmode)
      {
       count = restore_mode(f,mode);
       if (count != 0)
        croak("Cannot make blocking");
      }
     if (!info.eof && !info.error)
      {
       ST(0) = sv_2mortal(newSViv(info.count));
      }
    }
   else
    croak("Cannot make non-blocking");
  }

SV *
readline(f)
InputStream	f
 CODE:
  {
   int mode;
   int newmode;
   int count = make_nonblock(f,&mode,&newmode);
   /* Copy stuff out of PerlIO *  */
   ST(0) = &sv_undef;
   if (count == 0)
    {
     SV *buf =  newSVpv("",0);
     int fd = PerlIO_fileno(f);
     nIO_read info;   
     info.f   = f;    
     info.buf = buf;  
     info.len = 1;  
     info.offset = 0;
     info.count  = 0; 
     info.error  = 0; 
     info.eof    = 0; 
#ifdef NOT_BROKEN
     Tcl_CreateFileHandler(Tcl_GetFile((ClientData) fd, TCL_UNIX_FD), TCL_READABLE, read_handler, (ClientData) &info);
     while (!info.eof && !info.error && !has_nl(buf))
      {                                        
       info.len = 1;
       info.count = 0;
       while (!info.eof && !info.error && !info.count)
        Tcl_DoOneEvent(0);                       
      } 
     Tcl_DeleteFileHandler(Tcl_GetFile((ClientData) fd, TCL_UNIX_FD)); 
#endif
     if (mode != newmode)
      {
       count = restore_mode(f,mode);
       if (count != 0)
        croak("Cannot make blocking");
      }
     if (!info.eof && !info.error)
      {
       sv_setiv(buf,1);
       SvPOK_on(buf);
       ST(0) = sv_2mortal(buf);
      }
     else if (info.error)
      {
       warn("error=%d",info.error);
      }
    }
   else
    {
     croak("Cannot make non-blocking");
    }
  }



BOOT:
 {
  IMPORT_VTABLES;
 }
