/*
  Copyright (c) 1995 Nick Ing-Simmons. All rights reserved.
  This program is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself.
*/

#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#include "../tkGlue.def"

#include "tkPort.h"
#include "tkInt.h"
#include "tkVMacro.h"
#include "../tkGlue.h"
#include "../tkGlue.m"

DECLARE_VTABLES;


MODULE = Tk::Pixmap	PACKAGE = Tk::Pixmap

BOOT:
 {
  IMPORT_VTABLES;
  Tk_CreateImageType(&tkPixmapImageType);
 }
