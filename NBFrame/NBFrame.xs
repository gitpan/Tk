/*
  Copyright (c) 1995-1996 Nick Ing-Simmons. All rights reserved.
  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.
*/

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "tkGlue.def"

#include "pTk/tkPort.h"
#include "pTk/tkInt.h"
#include "pTk/tkVMacro.h"
#include "pTk/tix.h"
#include "pTk/tixInt.h"
#include "tkGlue.h"
#include "tkGlue.m"

extern int Tix_NoteBookFrameCmd _ANSI_ARGS_((ClientData,Tcl_Interp *,int, Arg *));

DECLARE_VTABLES;

MODULE = Tk::NBFrame	PACKAGE = Tk::NBFrame

PROTOTYPES: DISABLE


BOOT:
 {
  IMPORT_VTABLES;
  /* Initialize the display item types */
  Lang_TkCommand("nbframe",Tix_NoteBookFrameCmd);
 }
