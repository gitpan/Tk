/*
 * tkImage.c --
 *
 *      This module implements the image protocol, which allows lots
 *      of different kinds of images to be used in lots of different
 *      widgets.
 *
 * Copyright (c) 1994 The Regents of the University of California.
 * Copyright (c) 1994-1997 Sun Microsystems, Inc.
 *
 * See the file "license.terms" for information on usage and redistribution
 * of this file, and for a DISCLAIMER OF ALL WARRANTIES.
 *
 * RCS: @(#) $Id: tkImage.c,v 1.19.2.1 2003/07/07 09:43:01 dkf Exp $
 */

#include "tkInt.h"
#include "tkPort.h"

/*
 * Each call to Tk_GetImage returns a pointer to one of the following
 * structures, which is used as a token by clients (widgets) that
 * display images.
 */

typedef struct Image {
    Tk_Window tkwin;            /* Window passed to Tk_GetImage (needed to
				 * "re-get" the image later if the manager
				 * changes). */
    Display *display;           /* Display for tkwin.  Needed because when
				 * the image is eventually freed tkwin may
				 * not exist anymore. */
    struct ImageMaster *masterPtr;
				/* Master for this image (identifiers image
				 * manager, for example). */
    ClientData instanceData;
				/* One word argument to pass to image manager
				 * when dealing with this image instance. */
    Tk_ImageChangedProc *changeProc;
				/* Code in widget to call when image changes
				 * in a way that affects redisplay. */
    ClientData widgetClientData;
				/* Argument to pass to changeProc. */
    struct Image *nextPtr;      /* Next in list of all image instances
				 * associated with the same name. */

} Image;

/*
 * For each image master there is one of the following structures,
 * which represents a name in the image table and all of the images
 * instantiated from it.  Entries in mainPtr->imageTable point to
 * these structures.
 */

typedef struct ImageMaster {
    Tk_ImageType *typePtr;      /* Information about image type.  NULL means
				 * that no image manager owns this image:  the
				 * image was deleted. */
    ClientData masterData;      /* One-word argument to pass to image mgr
				 * when dealing with the master, as opposed
				 * to instances. */
    int width, height;          /* Last known dimensions for image. */
    Tcl_HashTable *tablePtr;    /* Pointer to hash table containing image
				 * (the imageTable field in some TkMainInfo
				 * structure). */
    Tcl_HashEntry *hPtr;        /* Hash entry in mainPtr->imageTable for
				 * this structure (used to delete the hash
				 * entry). */
    Image *instancePtr;         /* Pointer to first in list of instances
				 * derived from this name. */
    int deleted;                /* Flag set when image is being deleted. */
    TkWindow *winPtr;           /* Main window of interpreter (used to
				 * detect when the world is falling apart.) */
} ImageMaster;

typedef struct ThreadSpecificData {
    Tk_ImageType *imageTypeList;/* First in a list of all known image
				 * types. */
    Tk_ImageType *oldImageTypeList;/* First in a list of all known old-style image
				 * types. */
} ThreadSpecificData;
static Tcl_ThreadDataKey dataKey;

/*
 * Prototypes for local procedures:
 */

static void     DeleteImage _ANSI_ARGS_((ImageMaster *masterPtr));
static void     EventuallyDeleteImage _ANSI_ARGS_((ImageMaster *masterPtr,
						   int forgetHashEntryNow));

/*
 *----------------------------------------------------------------------
 *
 * Tk_CreateOldImageType, Tk_CreateImageType --
 *
 *      This procedure is invoked by an image manager to tell Tk about
 *      a new kind of image and the procedures that manage the new type.
 *      The procedure is typically invoked during Tcl_AppInit.
 *
 * Results:
 *      None.
 *
 * Side effects:
 *      The new image type is entered into a table used in the "image
 *      create" command.
 *
 *----------------------------------------------------------------------
 */

void
Tk_CreateOldImageType(typePtr)
    Tk_ImageType *typePtr;      /* Structure describing the type.  All of
				 * the fields except "nextPtr" must be filled
				 * in by caller.  Must not have been passed
				 * to Tk_CreateImageType previously. */
{
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	    Tcl_GetThreadData(&dataKey, sizeof(ThreadSpecificData));

    typePtr->nextPtr = tsdPtr->oldImageTypeList;
    tsdPtr->oldImageTypeList = typePtr;
}

void
Tk_CreateImageType(typePtr)
    Tk_ImageType *typePtr;      /* Structure describing the type.  All of
				 * the fields except "nextPtr" must be filled
				 * in by caller.  Must not have been passed
				 * to Tk_CreateImageType previously. */
{
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	    Tcl_GetThreadData(&dataKey, sizeof(ThreadSpecificData));

    typePtr->nextPtr = tsdPtr->imageTypeList;
    tsdPtr->imageTypeList = typePtr;
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_ImageObjCmd --
 *
 *      This procedure is invoked to process the "image" Tcl command.
 *      See the user documentation for details on what it does.
 *
 * Results:
 *      A standard Tcl result.
 *
 * Side effects:
 *      See the user documentation.
 *
 *----------------------------------------------------------------------
 */

int
Tk_ImageObjCmd(clientData, interp, objc, objv)
    ClientData clientData;      /* Main window associated with interpreter. */
    Tcl_Interp *interp;         /* Current interpreter. */
    int objc;                   /* Number of arguments. */
    Tcl_Obj *CONST objv[];      /* Argument strings. */
{
    static CONST char *imageOptions[] = {
	"create", "delete", "height", "inuse", "names", "type", "types",
	    "width", (char *) NULL
    };
    enum options {
	IMAGE_CREATE, IMAGE_DELETE, IMAGE_HEIGHT, IMAGE_INUSE, IMAGE_NAMES,
	IMAGE_TYPE, IMAGE_TYPES, IMAGE_WIDTH
    };
    TkWindow *winPtr = (TkWindow *) clientData;
    int i, new, firstOption,  index;
    Tk_ImageType *typePtr;
    ImageMaster *masterPtr;
    Image *imagePtr;
    Tcl_HashEntry *hPtr;
    Tcl_HashSearch search;
    char idString[16 + TCL_INTEGER_SPACE], *name;
    TkDisplay *dispPtr = winPtr->dispPtr;
    ThreadSpecificData *tsdPtr = (ThreadSpecificData *)
	    Tcl_GetThreadData(&dataKey, sizeof(ThreadSpecificData));

    if (objc < 2) {
	Tcl_WrongNumArgs(interp, 1, objv, "option ?args?");
	return TCL_ERROR;
    }

    if (Tcl_GetIndexFromObj(interp, objv[1], imageOptions, "option", 0,
	    &index) != TCL_OK) {
	return TCL_ERROR;
    }
    switch ((enum options) index) {
	case IMAGE_CREATE: {
	    char *arg;
	    Tcl_Obj **args;
	    int oldimage = 0;
	    if (objc < 3) {
		Tcl_WrongNumArgs(interp, 2, objv, "type ?name? ?options?");
		return TCL_ERROR;
	    }

	    /*
	     * Look up the image type.
	     */

	    arg = Tcl_GetString(objv[2]);
	    for (typePtr = tsdPtr->imageTypeList; typePtr != NULL;
		 typePtr = typePtr->nextPtr) {
		if ((*arg == typePtr->name[0])
			&& (strcmp(arg, typePtr->name) == 0)) {
		    break;
		}
	    }
	    if (typePtr == NULL) {
		oldimage = 1;
		for (typePtr = tsdPtr->oldImageTypeList; typePtr != NULL;
		     typePtr = typePtr->nextPtr) {
		    if ((*arg == typePtr->name[0])
			    && (strcmp(arg, typePtr->name) == 0)) {
			break;
		    }
		}
	    }
	    if (typePtr == NULL) {
		Tcl_AppendResult(interp, "image type \"", arg,
			"\" doesn't exist", (char *) NULL);
		return TCL_ERROR;
	    }

	    /*
	     * Figure out a name to use for the new image.
	     */

	    if ((objc == 3) || (*(arg = Tcl_GetString(objv[3])) == '-')) {
		dispPtr->imageId++;
		sprintf(idString, "image%d", dispPtr->imageId);
		name = idString;
		firstOption = 3;
	    } else {
		TkWindow *topWin;

		name = arg;
		firstOption = 4;
		/*
		 * Need to check if the _command_ that we are about to
		 * create is the name of the current master widget
		 * command (normally "." but could have been renamed)
		 * and fail in that case before a really nasty and
		 * hard to stop crash happens.
		 */
		topWin = (TkWindow *) TkToplevelWindowForCommand(interp, name);
		if (topWin != NULL && winPtr->mainPtr->winPtr == topWin) {
		    Tcl_AppendResult(interp, "images may not be named the ",
			    "same as the main window", (char *) NULL);
		    return TCL_ERROR;
		}
	    }

	    /*
	     * Create the data structure for the new image.
	     */

	    hPtr = Tcl_CreateHashEntry(&winPtr->mainPtr->imageTable,
		    name, &new);
	    if (new) {
		masterPtr = (ImageMaster *) ckalloc(sizeof(ImageMaster));
		masterPtr->typePtr = NULL;
		masterPtr->masterData = NULL;
		masterPtr->width = masterPtr->height = 1;
		masterPtr->tablePtr = &winPtr->mainPtr->imageTable;
		masterPtr->hPtr = hPtr;
		masterPtr->instancePtr = NULL;
		masterPtr->deleted = 0;
		masterPtr->winPtr = winPtr->mainPtr->winPtr;
		Tcl_Preserve((ClientData) masterPtr->winPtr);
		Tcl_SetHashValue(hPtr, masterPtr);
	    } else {
		/*
		 * An image already exists by this name.  Disconnect the
		 * instances from the master.
		 */

		masterPtr = (ImageMaster *) Tcl_GetHashValue(hPtr);
		if (masterPtr->typePtr != NULL) {
		    for (imagePtr = masterPtr->instancePtr; imagePtr != NULL;
			 imagePtr = imagePtr->nextPtr) {
			(*masterPtr->typePtr->freeProc)(
			    imagePtr->instanceData, imagePtr->display);
			(*imagePtr->changeProc)(imagePtr->widgetClientData,
				0, 0, masterPtr->width, masterPtr->height,
				masterPtr->width, masterPtr->height);
		    }
		    (*masterPtr->typePtr->deleteProc)(masterPtr->masterData);
		    masterPtr->typePtr = NULL;
		}
	    }

	    /*
	     * Call the image type manager so that it can perform its own
	     * initialization, then re-"get" for any existing instances of
	     * the image.
	     */

	    objv += firstOption;
	    objc -= firstOption;
	    args = (Tcl_Obj **) objv;
	    if (oldimage) {
		int i;
		args = (Tcl_Obj **) ckalloc((objc+1) * sizeof(char *));
		for (i = 0; i < objc; i++) {
		    args[i] = (Tcl_Obj *) Tcl_GetString(objv[i]);
		}
		args[objc] = NULL;
	    }
	    Tcl_Preserve((ClientData) masterPtr);
	    if ((*typePtr->createProc)(interp, name, objc,
		    args, typePtr, (Tk_ImageMaster) masterPtr,
		    &masterPtr->masterData) != TCL_OK) {
		EventuallyDeleteImage(masterPtr, 0);
		Tcl_Release((ClientData) masterPtr);
		if (oldimage) {
		    ckfree((char *) args);
		}
		return TCL_ERROR;
	    }
	    Tcl_Release((ClientData) masterPtr);
	    if (oldimage) {
		ckfree((char *) args);
	    }
	    masterPtr->typePtr = typePtr;
	    for (imagePtr = masterPtr->instancePtr; imagePtr != NULL;
		 imagePtr = imagePtr->nextPtr) {
		imagePtr->instanceData = (*typePtr->getProc)(
		    imagePtr->tkwin, masterPtr->masterData);
	    }
            Tcl_SetObjResult(interp, LangObjectObj( interp, Tcl_GetHashKey(&winPtr->mainPtr->imageTable, hPtr)));
	    break;
	}
	case IMAGE_DELETE: {
	    for (i = 2; i < objc; i++) {
		char *arg = Tcl_GetString(objv[i]);
		hPtr = Tcl_FindHashEntry(&winPtr->mainPtr->imageTable, arg);
		if (hPtr == NULL) {
		    Tcl_AppendResult(interp, "image \"", arg,
			    "\" doesn't exist", (char *) NULL);
		    return TCL_ERROR;
		}
		DeleteImage((ImageMaster *) Tcl_GetHashValue(hPtr));
	    }
	    break;
	}
	case IMAGE_HEIGHT: {
	    char *arg;
	    if (objc != 3) {
		Tcl_WrongNumArgs(interp, 2, objv, "name");
		return TCL_ERROR;
	    }
	    arg = Tcl_GetString(objv[2]);
	    hPtr = Tcl_FindHashEntry(&winPtr->mainPtr->imageTable, arg);
	    if (hPtr == NULL) {
		Tcl_AppendResult(interp, "image \"", arg,
			"\" doesn't exist", (char *) NULL);
		return TCL_ERROR;
	    }
	    masterPtr = (ImageMaster *) Tcl_GetHashValue(hPtr);
	    Tcl_SetIntObj(Tcl_GetObjResult(interp), masterPtr->height);
	    break;
	}

	case IMAGE_INUSE: {
	    int count = 0;
	    char *arg;
	    if (objc != 3) {
		Tcl_WrongNumArgs(interp, 2, objv, "name");
		return TCL_ERROR;
	    }
	    arg = Tcl_GetString(objv[2]);
	    hPtr = Tcl_FindHashEntry(&winPtr->mainPtr->imageTable, arg);
	    if (hPtr == NULL) {
		Tcl_AppendResult(interp, "image \"", arg,
			"\" doesn't exist", (char *) NULL);
		return TCL_ERROR;
	    }
	    masterPtr = (ImageMaster *) Tcl_GetHashValue(hPtr);
	    if (masterPtr->typePtr != NULL && masterPtr->instancePtr != NULL) {
		count = 1;
	    }
	    Tcl_SetBooleanObj(Tcl_GetObjResult(interp), count);
	    break;
	}

	case IMAGE_NAMES: {
	    if (objc != 2) {
		Tcl_WrongNumArgs(interp, 2, objv, NULL);
		return TCL_ERROR;
	    }
	    hPtr = Tcl_FirstHashEntry(&winPtr->mainPtr->imageTable, &search);
	    for ( ; hPtr != NULL; hPtr = Tcl_NextHashEntry(&search)) {
		Tcl_ListObjAppendElement(interp, Tcl_GetObjResult(interp),
			LangObjectObj(interp,Tcl_GetHashKey(&winPtr->mainPtr->imageTable, hPtr)));
	    }
	    break;
	}

	case IMAGE_TYPE: {
	    char *arg;
	    if (objc != 3) {
		Tcl_WrongNumArgs(interp, 2, objv, "name");
		return TCL_ERROR;
	    }
	    arg = Tcl_GetString(objv[2]);
	    hPtr = Tcl_FindHashEntry(&winPtr->mainPtr->imageTable, arg);
	    if (hPtr == NULL) {
		Tcl_AppendResult(interp, "image \"", arg,
			"\" doesn't exist", (char *) NULL);
		return TCL_ERROR;
	    }
	    masterPtr = (ImageMaster *) Tcl_GetHashValue(hPtr);
	    if (masterPtr->typePtr != NULL) {
		Tcl_SetResult(interp, masterPtr->typePtr->name, TCL_STATIC);
	    }
	    break;
	}
	case IMAGE_TYPES: {
	    if (objc != 2) {
		Tcl_WrongNumArgs(interp, 2, objv, NULL);
		return TCL_ERROR;
	    }
	    for (typePtr = tsdPtr->imageTypeList; typePtr != NULL;
		 typePtr = typePtr->nextPtr) {
		Tcl_AppendElement(interp, typePtr->name);
	    }
	    for (typePtr = tsdPtr->oldImageTypeList; typePtr != NULL;
		 typePtr = typePtr->nextPtr) {
		Tcl_AppendElement(interp, typePtr->name);
	    }
	    break;
	}
	case IMAGE_WIDTH: {
	    char *arg;
	    if (objc != 3) {
		Tcl_WrongNumArgs(interp, 2, objv, "name");
		return TCL_ERROR;
	    }
	    arg = Tcl_GetString(objv[2]);
	    hPtr = Tcl_FindHashEntry(&winPtr->mainPtr->imageTable, arg);
	    if (hPtr == NULL) {
		Tcl_AppendResult(interp, "image \"", arg,
			"\" doesn't exist", (char *) NULL);
		return TCL_ERROR;
	    }
	    masterPtr = (ImageMaster *) Tcl_GetHashValue(hPtr);
	    Tcl_SetIntObj(Tcl_GetObjResult(interp), masterPtr->width);
	    break;
	}
    }
    return TCL_OK;
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_ImageChanged --
 *
 *      This procedure is called by an image manager whenever something
 *      has happened that requires the image to be redrawn (some of its
 *      pixels have changed, or its size has changed).
 *
 * Results:
 *      None.
 *
 * Side effects:
 *      Any widgets that display the image are notified so that they
 *      can redisplay themselves as appropriate.
 *
 *----------------------------------------------------------------------
 */

void
Tk_ImageChanged(imageMaster, x, y, width, height, imageWidth,
	imageHeight)
    Tk_ImageMaster imageMaster; /* Image that needs redisplay. */
    int x, y;                   /* Coordinates of upper-left pixel of
				 * region of image that needs to be
				 * redrawn. */
    int width, height;          /* Dimensions (in pixels) of region of
				 * image to redraw.  If either dimension
				 * is zero then the image doesn't need to
				 * be redrawn (perhaps all that happened is
				 * that its size changed). */
    int imageWidth, imageHeight;/* New dimensions of image. */
{
    ImageMaster *masterPtr = (ImageMaster *) imageMaster;
    Image *imagePtr;

    masterPtr->width = imageWidth;
    masterPtr->height = imageHeight;
    for (imagePtr = masterPtr->instancePtr; imagePtr != NULL;
	 imagePtr = imagePtr->nextPtr) {
	(*imagePtr->changeProc)(imagePtr->widgetClientData, x, y,
		width, height, imageWidth, imageHeight);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_NameOfImage --
 *
 *      Given a token for an image master, this procedure returns
 *      the name of the image.
 *
 * Results:
 *      The return value is the string name for imageMaster.
 *
 * Side effects:
 *      None.
 *
 *----------------------------------------------------------------------
 */

CONST char *
Tk_NameOfImage(imageMaster)
    Tk_ImageMaster imageMaster;         /* Token for image. */
{
    ImageMaster *masterPtr = (ImageMaster *) imageMaster;

    if (masterPtr->hPtr == NULL) {
	return NULL;
    }
    return Tcl_GetHashKey(masterPtr->tablePtr, masterPtr->hPtr);
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_GetImage --
 *
 *      This procedure is invoked by a widget when it wants to use
 *      a particular image in a particular window.
 *
 * Results:
 *      The return value is a token for the image.  If there is no image
 *      by the given name, then NULL is returned and an error message is
 *      left in the interp's result.
 *
 * Side effects:
 *      Tk records the fact that the widget is using the image, and
 *      it will invoke changeProc later if the widget needs redisplay
 *      (i.e. its size changes or some of its pixels change).  The
 *      caller must eventually invoke Tk_FreeImage when it no longer
 *      needs the image.
 *
 *----------------------------------------------------------------------
 */

Tk_Image
Tk_GetImage(interp, tkwin, name, changeProc, clientData)
    Tcl_Interp *interp;         /* Place to leave error message if image
				 * can't be found. */
    Tk_Window tkwin;            /* Token for window in which image will
				 * be used. */
    CONST char *name;           /* Name of desired image. */
    Tk_ImageChangedProc *changeProc;
				/* Procedure to invoke when redisplay is
				 * needed because image's pixels or size
				 * changed. */
    ClientData clientData;      /* One-word argument to pass to damageProc. */
{
    Tcl_HashEntry *hPtr;
    ImageMaster *masterPtr;
    Image *imagePtr;

    hPtr = Tcl_FindHashEntry(&((TkWindow *) tkwin)->mainPtr->imageTable, name);
    if (hPtr == NULL) {
	goto noSuchImage;
    }
    masterPtr = (ImageMaster *) Tcl_GetHashValue(hPtr);
    if (masterPtr->typePtr == NULL) {
	goto noSuchImage;
    }
    imagePtr = (Image *) ckalloc(sizeof(Image));
    imagePtr->tkwin = tkwin;
    imagePtr->display = Tk_Display(tkwin);
    imagePtr->masterPtr = masterPtr;
    imagePtr->instanceData =
	    (*masterPtr->typePtr->getProc)(tkwin, masterPtr->masterData);
    imagePtr->changeProc = changeProc;
    imagePtr->widgetClientData = clientData;
    imagePtr->nextPtr = masterPtr->instancePtr;
    masterPtr->instancePtr = imagePtr;
    return (Tk_Image) imagePtr;

    noSuchImage:
    Tcl_AppendResult(interp, "image \"", name, "\" doesn't exist",
	    (char *) NULL);
    return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_FreeImage --
 *
 *      This procedure is invoked by a widget when it no longer needs
 *      an image acquired by a previous call to Tk_GetImage.  For each
 *      call to Tk_GetImage there must be exactly one call to Tk_FreeImage.
 *
 * Results:
 *      None.
 *
 * Side effects:
 *      The association between the image and the widget is removed.
 *
 *----------------------------------------------------------------------
 */

void
Tk_FreeImage(image)
    Tk_Image image;             /* Token for image that is no longer
				 * needed by a widget. */
{
    Image *imagePtr = (Image *) image;
    ImageMaster *masterPtr = imagePtr->masterPtr;
    Image *prevPtr;

    /*
     * Clean up the particular instance.
     */

    if (masterPtr->typePtr != NULL) {
	(*masterPtr->typePtr->freeProc)(imagePtr->instanceData,
		imagePtr->display);
    }
    prevPtr = masterPtr->instancePtr;
    if (prevPtr == imagePtr) {
	masterPtr->instancePtr = imagePtr->nextPtr;
    } else {
	while (prevPtr->nextPtr != imagePtr) {
	    prevPtr = prevPtr->nextPtr;
	}
	prevPtr->nextPtr = imagePtr->nextPtr;
    }
    ckfree((char *) imagePtr);

    /*
     * If there are no more instances left for the master, and if the
     * master image has been deleted, then delete the master too.
     */

    if ((masterPtr->typePtr == NULL) && (masterPtr->instancePtr == NULL)) {
	if (masterPtr->hPtr != NULL) {
	    Tcl_DeleteHashEntry(masterPtr->hPtr);
	}
	Tcl_Release(masterPtr->winPtr);
	ckfree((char *) masterPtr);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_PostscriptImage --
 *
 *      This procedure is called by widgets that contain images in order
 *      to redisplay an image on the screen or an off-screen pixmap.
 *
 * Results:
 *      None.
 *
 * Side effects:
 *      The image's manager is notified, and it redraws the desired
 *      portion of the image before returning.
 *
 *----------------------------------------------------------------------
 */

int
Tk_PostscriptImage(image, interp, tkwin, psinfo, x, y, width, height, prepass)
    Tk_Image image;             /* Token for image to redisplay. */
    Tcl_Interp *interp;
    Tk_Window tkwin;
    Tk_PostscriptInfo psinfo;   /* postscript info */
    int x, y;                   /* Upper-left pixel of region in image that
				 * needs to be redisplayed. */
    int width, height;          /* Dimensions of region to redraw. */
    int prepass;
{
    Image *imagePtr = (Image *) image;
    int result;
    XImage *ximage;
    Pixmap pmap;
    GC newGC;
    XGCValues gcValues;

    if (imagePtr->masterPtr->typePtr == NULL) {
	/*
	 * No master for image, so nothing to display on postscript.
	 */
	return TCL_OK;
    }

    /*
     * Check if an image specific postscript-generation function
     * exists; otherwise go on with generic code.
     */

    if (imagePtr->masterPtr->typePtr->postscriptProc != NULL) {
	return (*imagePtr->masterPtr->typePtr->postscriptProc)(
	    imagePtr->masterPtr->masterData, interp, tkwin, psinfo,
	    x, y, width, height, prepass);
    }

    if (prepass) {
	return TCL_OK;
    }

    /*
     * Create a Pixmap, tell the image to redraw itself there, and then
     * generate an XImage from the Pixmap.  We can then read pixel
     * values out of the XImage.
     */

    pmap = Tk_GetPixmap(Tk_Display(tkwin), Tk_WindowId(tkwin),
			width, height, Tk_Depth(tkwin));

    gcValues.foreground = WhitePixelOfScreen(Tk_Screen(tkwin));
    newGC = Tk_GetGC(tkwin, GCForeground, &gcValues);
    if (newGC != None) {
	XFillRectangle(Tk_Display(tkwin), pmap, newGC,
		0, 0, (unsigned int)width, (unsigned int)height);
	Tk_FreeGC(Tk_Display(tkwin), newGC);
    }

    Tk_RedrawImage(image, x, y, width, height, pmap, 0, 0);

    ximage = XGetImage(Tk_Display(tkwin), pmap, 0, 0,
	    (unsigned int)width, (unsigned int)height, AllPlanes, ZPixmap);

    Tk_FreePixmap(Tk_Display(tkwin), pmap);

    if (ximage == NULL) {
	/* The XGetImage() function is apparently not
	 * implemented on this system. Just ignore it.
	 */
	return TCL_OK;
    }
    result = TkPostscriptImage(interp, tkwin, psinfo, ximage, x, y,
	    width, height);

    XDestroyImage(ximage);
    return result;
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_RedrawImage --
 *
 *      This procedure is called by widgets that contain images in order
 *      to redisplay an image on the screen or an off-screen pixmap.
 *
 * Results:
 *      None.
 *
 * Side effects:
 *      The image's manager is notified, and it redraws the desired
 *      portion of the image before returning.
 *
 *----------------------------------------------------------------------
 */

void
Tk_RedrawImage(image, imageX, imageY, width, height, drawable,
	drawableX, drawableY)
    Tk_Image image;             /* Token for image to redisplay. */
    int imageX, imageY;         /* Upper-left pixel of region in image that
				 * needs to be redisplayed. */
    int width, height;          /* Dimensions of region to redraw. */
    Drawable drawable;          /* Drawable in which to display image
				 * (window or pixmap).  If this is a pixmap,
				 * it must have the same depth as the window
				 * used in the Tk_GetImage call for the
				 * image. */
    int drawableX, drawableY;   /* Coordinates in drawable that correspond
				 * to imageX and imageY. */
{
    Image *imagePtr = (Image *) image;

    if (imagePtr->masterPtr->typePtr == NULL) {
	/*
	 * No master for image, so nothing to display.
	 */

	return;
    }

    /*
     * Clip the redraw area to the area of the image.
     */

    if (imageX < 0) {
	width += imageX;
	drawableX -= imageX;
	imageX = 0;
    }
    if (imageY < 0) {
	height += imageY;
	drawableY -= imageY;
	imageY = 0;
    }
    if ((imageX + width) > imagePtr->masterPtr->width) {
	width = imagePtr->masterPtr->width - imageX;
    }
    if ((imageY + height) > imagePtr->masterPtr->height) {
	height = imagePtr->masterPtr->height - imageY;
    }
    (*imagePtr->masterPtr->typePtr->displayProc)(
	    imagePtr->instanceData, imagePtr->display, drawable,
	    imageX, imageY, width, height, drawableX, drawableY);
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_SizeOfImage --
 *
 *      This procedure returns the current dimensions of an image.
 *
 * Results:
 *      The width and height of the image are returned in *widthPtr
 *      and *heightPtr.
 *
 * Side effects:
 *      None.
 *
 *----------------------------------------------------------------------
 */

void
Tk_SizeOfImage(image, widthPtr, heightPtr)
    Tk_Image image;             /* Token for image whose size is wanted. */
    int *widthPtr;              /* Return width of image here. */
    int *heightPtr;             /* Return height of image here. */
{
    Image *imagePtr = (Image *) image;

    *widthPtr = imagePtr->masterPtr->width;
    *heightPtr = imagePtr->masterPtr->height;
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_DeleteImage --
 *
 *      Given the name of an image, this procedure destroys the
 *      image.
 *
 * Results:
 *      None.
 *
 * Side effects:
 *      The image is destroyed; existing instances will display as
 *      blank areas.  If no such image exists then the procedure does
 *      nothing.
 *
 *----------------------------------------------------------------------
 */

void
Tk_DeleteImage(interp, name)
    Tcl_Interp *interp;         /* Interpreter in which the image was
				 * created. */
    CONST char *name;           /* Name of image. */
{
    Tcl_HashEntry *hPtr;
    TkWindow *winPtr;

    winPtr = (TkWindow *) Tk_MainWindow(interp);
    if (winPtr == NULL) {
	return;
    }
    hPtr = Tcl_FindHashEntry(&winPtr->mainPtr->imageTable, name);
    if (hPtr == NULL) {
	return;
    }
    DeleteImage((ImageMaster *)Tcl_GetHashValue(hPtr));
}

/*
 *----------------------------------------------------------------------
 *
 * DeleteImage --
 *
 *      This procedure is responsible for deleting an image.
 *
 * Results:
 *      None.
 *
 * Side effects:
 *      The connection is dropped between instances of this image and
 *      an image master.  Image instances will redisplay themselves
 *      as empty areas, but existing instances will not be deleted.
 *
 *----------------------------------------------------------------------
 */

static void
DeleteImage(masterPtr)
    ImageMaster *masterPtr;     /* Pointer to main data structure for image. */
{
    Image *imagePtr;
    Tk_ImageType *typePtr;

    typePtr = masterPtr->typePtr;
    masterPtr->typePtr = NULL;
    if (typePtr != NULL) {
	for (imagePtr = masterPtr->instancePtr; imagePtr != NULL;
		imagePtr = imagePtr->nextPtr) {
	   (*typePtr->freeProc)(imagePtr->instanceData,
		   imagePtr->display);
	   (*imagePtr->changeProc)(imagePtr->widgetClientData, 0, 0,
		    masterPtr->width, masterPtr->height, masterPtr->width,
		    masterPtr->height);
	}
	(*typePtr->deleteProc)(masterPtr->masterData);
    }
    if (masterPtr->instancePtr == NULL) {
	if (masterPtr->hPtr != NULL) {
	    Tcl_DeleteHashEntry(masterPtr->hPtr);
	}
	Tcl_Release((ClientData) masterPtr->winPtr);
	ckfree((char *) masterPtr);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * EventuallyDeleteImage --
 *
 *      Arrange for an image to be deleted when it is safe to do so.
 *
 * Results:
 *      None.
 *
 * Side effects:
 *      Image will get freed, though not until it is no longer
 *      Tcl_Preserve()d by anything.  May be called multiple times on
 *      the same image without ill effects.
 *
 *----------------------------------------------------------------------
 */

static void
EventuallyDeleteImage(masterPtr, forgetHashEntryNow)
    ImageMaster *masterPtr;     /* Pointer to main data structure for image. */
    int forgetHashEntryNow;
{
    if (forgetHashEntryNow) {
	masterPtr->hPtr = NULL;
    }
    if (!masterPtr->deleted) {
	masterPtr->deleted = 1;
	Tcl_EventuallyFree((ClientData) masterPtr,
		(Tcl_FreeProc *)DeleteImage);
    }
}

/*
 *----------------------------------------------------------------------
 *
 * TkDeleteAllImages --
 *
 *      This procedure is called when an application is deleted.  It
 *      calls back all of the managers for all images so that they
 *      can cleanup, then it deletes all of Tk's internal information
 *      about images.
 *
 * Results:
 *      None.
 *
 * Side effects:
 *      All information for all images gets deleted.
 *
 *----------------------------------------------------------------------
 */

void
TkDeleteAllImages(mainPtr)
    TkMainInfo *mainPtr;        /* Structure describing application that is
				 * going away. */
{
    Tcl_HashSearch search;
    Tcl_HashEntry *hPtr;

    for (hPtr = Tcl_FirstHashEntry(&mainPtr->imageTable, &search);
	    hPtr != NULL; hPtr = Tcl_NextHashEntry(&search)) {
	EventuallyDeleteImage((ImageMaster *) Tcl_GetHashValue(hPtr), 1);
    }
    Tcl_DeleteHashTable(&mainPtr->imageTable);
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_GetImageMasterData --
 *
 *      Given the name of an image, this procedure returns the type
 *      of the image and the clientData associated with its master.
 *
 * Results:
 *      If there is no image by the given name, then NULL is returned
 *      and a NULL value is stored at *typePtrPtr.  Otherwise the return
 *      value is the clientData returned by the createProc when the
 *      image was created and a pointer to the type structure for the
 *      image is stored at *typePtrPtr.
 *
 * Side effects:
 *      None.
 *
 *----------------------------------------------------------------------
 */

ClientData
Tk_GetImageMasterData(interp, name, typePtrPtr)
    Tcl_Interp *interp;         /* Interpreter in which the image was
				 * created. */
    CONST char *name;           /* Name of image. */
    Tk_ImageType **typePtrPtr;  /* Points to location to fill in with
				 * pointer to type information for image. */
{
    Tcl_HashEntry *hPtr;
    TkWindow *winPtr;
    ImageMaster *masterPtr;

    winPtr = (TkWindow *) Tk_MainWindow(interp);
    hPtr = Tcl_FindHashEntry(&winPtr->mainPtr->imageTable, name);
    if (hPtr == NULL) {
	*typePtrPtr = NULL;
	return NULL;
    }
    masterPtr = (ImageMaster *) Tcl_GetHashValue(hPtr);
    *typePtrPtr = masterPtr->typePtr;
    return masterPtr->masterData;
}


/*========================================================================
 * Tile support - reimplemented avoiding BLTisms
 *========================================================================*/

typedef struct Tk_TileChange_
{
 struct Tk_TileChange_ *next;
 Tk_TileChangedProc *changeProc;
 ClientData clientData;
} Tk_TileChange;

struct Tk_Tile_
{
 Tk_Image image;
 int width;
 int height;
 Tk_Window tkwin;
 Pixmap   pixmap;
 Tk_TileChange *handlers;
};

static void             TileImageChanged _ANSI_ARGS_((ClientData clientData,
			    int x, int y, int width, int height,
			    int imgWidth, int imgHeight));

void
TileImageChanged(clientData, x, y, width, height, imgWidth, imgHeight)
ClientData clientData;
int x;
int y;
int width;
int height;
{
    Tk_Tile tile = (Tk_Tile) clientData;
    Tk_TileChange *handler;
    if (tile->pixmap == None ||
        tile->width != imgWidth || tile->height != imgHeight) {
	Tk_Window tkwin = tile->tkwin;
	if (tile->pixmap) {
	    Tk_FreePixmap(Tk_Display(tkwin),tile->pixmap);
	    tile->width  = 0;
	    tile->height = 0;
	    tile->pixmap = None;
	}
	if (imgWidth >= 0 && imgHeight >= 0) {
	    tile->pixmap = Tk_GetPixmap(Tk_Display(tkwin), Tk_WindowId(tkwin),
				imgWidth, imgHeight, Tk_Depth(tkwin));
	    if (tile->pixmap) {
		tile->width  = imgWidth;
		tile->height = imgHeight;
	    }
	}
    }
    if (tile->pixmap != None) {
	Tk_RedrawImage(tile->image, 0, 0, tile->width, tile->height,
		       tile->pixmap, 0, 0);
    }
    for (handler = tile->handlers; handler != NULL; handler = handler->next) {
	(*handler->changeProc)(handler->clientData, tile);

    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_GetTile
 *
 *      Convert the named image into a tile.
 *
 * Results:
 *      If the image is valid, a new tile is returned.  If the name
 *      does not represent a proper image, an error message is left in
 *      interp->result.
 *
 * Side Effects:
 *      Memory and X resources are allocated.  Bookkeeping is
 *      maintained on the tile (i.e. width, height, and name).
 *
 *----------------------------------------------------------------------
 */
Tk_Tile
Tk_GetTile(interp, tkwin, imageName)
    Tcl_Interp *interp;         /* Interpreter to report results back to */
    Tk_Window tkwin;            /* Window on the same display as tile */
    CONST char *imageName;      /* Name of image */
{
    Tk_Tile tile = (Tk_Tile) ckalloc(sizeof(struct Tk_Tile_));
    memset(tile,0,sizeof(*tile));
    tile->tkwin = tkwin;
    tile->image = Tk_GetImage(interp, tkwin, (char *) imageName,
			TileImageChanged, (ClientData) tile);
    if (!tile->image) {
	Tk_FreeTile(tile);
	return NULL;
    }
    return tile;
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_FreeTile
 *
 *      Release the resources associated with the tile.
 *
 * Results:
 *      None.
 *
 * Side Effects:
 *      Memory and X resources are freed.  Bookkeeping information
 *      about the tile (i.e. width, height, and name) is discarded.
 *
 */
void
Tk_FreeTile(tile)
    Tk_Tile tile;               /* Tile to be deleted */
{
 if (tile->image)
  Tk_FreeImage(tile->image);
 if (tile->pixmap)
  Tk_FreePixmap(Tk_Display(tile->tkwin),tile->pixmap);
 while (tile->handlers) {
    Tk_TileChange *handler = tile->handlers;
    tile->handlers = handler->next;
    ckfree((char *) handler);
 }
 ckfree((char *) tile);
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_NameOfTile
 *
 *      Returns the name of the image from which the tile was
 *      generated.
 *
 * Results:
 *      The name of the image is returned.  The name is not unique.
 *      Many tiles may use the same image.
 *
 *----------------------------------------------------------------------
 */
CONST char *
Tk_NameOfTile(tile)
    Tk_Tile tile;               /* Tile to query */
{
 if (tile)
  {
   Image *imagePtr = (Image *) tile->image;
   return Tk_NameOfImage((Tk_ImageMaster)(imagePtr->masterPtr));
  }
 return NULL;
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_PixmapOfTile
 *
 *      Returns the pixmap of the tile.
 *
 * Results:
 *      The X pixmap used as the tile is returned.
 *
 *----------------------------------------------------------------------
 */
Pixmap
Tk_PixmapOfTile(tile)
    Tk_Tile tile;               /* Tile to query */
{
    if (tile) {
	if (tile->image && tile->pixmap == None) {
	    Tk_Window tkwin = tile->tkwin;
	    int width  = 0;
	    int height = 0;
	    Tk_SizeOfImage(tile->image,&width,&height);
	    if (width >= 0 && height >= 0) {
		Tk_MakeWindowExist(tkwin);
		tile->pixmap = Tk_GetPixmap(Tk_Display(tkwin), Tk_WindowId(tkwin),
				width, height, Tk_Depth(tkwin));
		if (tile->pixmap != None) {
		    tile->width  = width;
		    tile->height = height;
		    Tk_RedrawImage(tile->image, 0, 0, width, height,  tile->pixmap, 0, 0);
		}
	    }
	}
	return tile->pixmap;
    }
    return None;
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_SizeOfTile
 *
 *      Returns the width and height of the tile.
 *
 * Results:
 *      The width and height of the tile are returned.
 *
 *----------------------------------------------------------------------
 */
void
Tk_SizeOfTile(tile, widthPtr, heightPtr)
    Tk_Tile tile;               /* Tile to query */
    int *widthPtr, *heightPtr;  /* Returned dimensions of the tile (out) */
{
    if (tile) {
	if (tile->image && tile->pixmap == None) {
	    Tk_SizeOfImage(tile->image,widthPtr,heightPtr);
	}
	else {
	    *widthPtr  = tile->height;
	    *heightPtr = tile->width;
	}
    }
    else {
	*widthPtr  = 0;
	*heightPtr = 0;
    }
}

/*
 *----------------------------------------------------------------------
 *
 * Tk_SetTileChangedProc
 *
 *      Sets the routine to called when an image changes.  If
 *      *changeProc* is NULL, no callback will be performed.
 *
 * Results:
 *      None.
 *
 * Side Effects:
 *      The designated routine will be called the next time the
 *      image associated with the tile changes.
 *
 *----------------------------------------------------------------------
 */
void
Tk_SetTileChangedProc(tile, changeProc, clientData)
    Tk_Tile tile;               /* Tile to query */
    Tk_TileChangedProc *changeProc;
    ClientData clientData;
{
    if (tile) {
	Tk_TileChange **link = &tile->handlers;
	Tk_TileChange *handler;

	while ((handler = *link)) {
	    if (handler->clientData == clientData) {
		break;
	    }
	    link = &handler->next;
	}
	if (changeProc == NULL ) {
	    if (handler) {
		*link = handler->next;
		ckfree((char *) handler);
	    }
	}
	else {
	    if (handler == NULL) {
		handler = (Tk_TileChange *) ckalloc(sizeof(Tk_TileChange));
		memset(handler,0,sizeof(*handler));
		handler->next = NULL;
		*link = handler;
		handler->clientData = clientData;
	    }
	    handler->changeProc = changeProc;
	}
    }
}


/*
 *----------------------------------------------------------------------
 *
 * Tk_SetTSOrigin --
 *
 *      Set the pattern origin of the tile to a common point (i.e. the
 *      origin (0,0) of the top level window) so that tiles from two
 *      different widgets will match up.  This done by setting the
 *      GCTileStipOrigin field is set to the translated origin of the
 *      toplevel window in the hierarchy.
 *
 * Results:
 *      None.
 *
 * Side Effects:
 *      The GCTileStipOrigin is reset in the GC.  This will cause the
 *      tile origin to change when the GC is used for drawing.
 *
 *----------------------------------------------------------------------
 */
/*ARGSUSED*/
void
Tk_SetTSOrigin(tkwin, gc, x, y)
    Tk_Window tkwin;
    GC gc;
    int x, y;
{
    while (!Tk_TopWinHierarchy(tkwin)) {
	x -= Tk_X(tkwin) + Tk_Changes(tkwin)->border_width;
	y -= Tk_Y(tkwin) + Tk_Changes(tkwin)->border_width;
	tkwin = Tk_Parent(tkwin);
    }
    XSetTSOrigin(Tk_Display(tkwin), gc, x, y);
}


