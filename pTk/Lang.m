#ifndef _LANG_VM
#define _LANG_VM
#include "Lang_f.h"
#define LangOptionCommand (*LangVptr->V_LangOptionCommand)
#define LangAllocVec (*LangVptr->V_LangAllocVec)
#define LangBadFile (*LangVptr->V_LangBadFile)
#define LangCallbackArg (*LangVptr->V_LangCallbackArg)
#define LangCloseHandler (*LangVptr->V_LangCloseHandler)
#define LangCmpArg (*LangVptr->V_LangCmpArg)
#define LangCmpCallback (*LangVptr->V_LangCmpCallback)
#define LangCmpOpt (*LangVptr->V_LangCmpOpt)
#define LangCopyArg (*LangVptr->V_LangCopyArg)
#define LangCopyCallback (*LangVptr->V_LangCopyCallback)
#define LangDoCallback (*LangVptr->V_LangDoCallback)
#define LangEval (*LangVptr->V_LangEval)
#define LangEventCallback (*LangVptr->V_LangEventCallback)
#define LangEventHook (*LangVptr->V_LangEventHook)
#define LangExit (*LangVptr->V_LangExit)
#define LangFreeArg (*LangVptr->V_LangFreeArg)
#define LangFreeCallback (*LangVptr->V_LangFreeCallback)
#define LangFreeVar (*LangVptr->V_LangFreeVar)
#define LangFreeVec (*LangVptr->V_LangFreeVec)
#define LangLibraryDir (*LangVptr->V_LangLibraryDir)
#define LangMakeCallback (*LangVptr->V_LangMakeCallback)
#define LangMergeString (*LangVptr->V_LangMergeString)
#define LangMethodCall (*LangVptr->V_LangMethodCall)
#define LangNull (*LangVptr->V_LangNull)
#define LangRestoreResult (*LangVptr->V_LangRestoreResult)
#define LangSaveResult (*LangVptr->V_LangSaveResult)
#define LangSaveVar (*LangVptr->V_LangSaveVar)
#define LangSetArg (*LangVptr->V_LangSetArg)
#define LangSetDefault (*LangVptr->V_LangSetDefault)
#define LangSetDouble (*LangVptr->V_LangSetDouble)
#define LangSetInt (*LangVptr->V_LangSetInt)
#define LangSetString (*LangVptr->V_LangSetString)
#define LangString (*LangVptr->V_LangString)
#define LangStringArg (*LangVptr->V_LangStringArg)
#define LangStringMatch (*LangVptr->V_LangStringMatch)
#define LangVarArg (*LangVptr->V_LangVarArg)
#define Lang_BuildInImages (*LangVptr->V_Lang_BuildInImages)
#define Lang_CreateObject (*LangVptr->V_Lang_CreateObject)
#define Lang_DeleteObject (*LangVptr->V_Lang_DeleteObject)
#define Lang_FreeRegExp (*LangVptr->V_Lang_FreeRegExp)
#define Lang_GetErrorCode (*LangVptr->V_Lang_GetErrorCode)
#define Lang_GetErrorInfo (*LangVptr->V_Lang_GetErrorInfo)
#define Lang_RegExpCompile (*LangVptr->V_Lang_RegExpCompile)
#define Lang_RegExpExec (*LangVptr->V_Lang_RegExpExec)
#define Lang_SetBinaryResult (*LangVptr->V_Lang_SetBinaryResult)
#define Lang_SetErrorCode (*LangVptr->V_Lang_SetErrorCode)
#define Lang_SplitList (*LangVptr->V_Lang_SplitList)
#define TclCalloc (*LangVptr->V_TclCalloc)
#define TclOpen (*LangVptr->V_TclOpen)
#define TclRead (*LangVptr->V_TclRead)
#define TclWrite (*LangVptr->V_TclWrite)
#define Tcl_AddErrorInfo (*LangVptr->V_Tcl_AddErrorInfo)
#define Tcl_AppendArg (*LangVptr->V_Tcl_AppendArg)
#define Tcl_AppendElement (*LangVptr->V_Tcl_AppendElement)
#define Tcl_AppendResult (*LangVptr->V_Tcl_AppendResult)
#define Tcl_ArgResult (*LangVptr->V_Tcl_ArgResult)
#define Tcl_CallWhenDeleted (*LangVptr->V_Tcl_CallWhenDeleted)
#define Tcl_Concat (*LangVptr->V_Tcl_Concat)
#define Tcl_CreateCommand (*LangVptr->V_Tcl_CreateCommand)
#define Tcl_CreateInterp (*LangVptr->V_Tcl_CreateInterp)
#define Tcl_DStringAppend (*LangVptr->V_Tcl_DStringAppend)
#define Tcl_DStringFree (*LangVptr->V_Tcl_DStringFree)
#define Tcl_DStringGetResult (*LangVptr->V_Tcl_DStringGetResult)
#define Tcl_DStringInit (*LangVptr->V_Tcl_DStringInit)
#define Tcl_DStringResult (*LangVptr->V_Tcl_DStringResult)
#define Tcl_DStringSetLength (*LangVptr->V_Tcl_DStringSetLength)
#define Tcl_DeleteHashEntry (*LangVptr->V_Tcl_DeleteHashEntry)
#define Tcl_DeleteHashTable (*LangVptr->V_Tcl_DeleteHashTable)
#define Tcl_DeleteInterp (*LangVptr->V_Tcl_DeleteInterp)
#define Tcl_DoubleResults (*LangVptr->V_Tcl_DoubleResults)
#define Tcl_FirstHashEntry (*LangVptr->V_Tcl_FirstHashEntry)
#define Tcl_GetBoolean (*LangVptr->V_Tcl_GetBoolean)
#define Tcl_GetDouble (*LangVptr->V_Tcl_GetDouble)
#define Tcl_GetInt (*LangVptr->V_Tcl_GetInt)
#define Tcl_GetOpenFile (*LangVptr->V_Tcl_GetOpenFile)
#define Tcl_GetResult (*LangVptr->V_Tcl_GetResult)
#define Tcl_GetVar (*LangVptr->V_Tcl_GetVar)
#define Tcl_GetVar2 (*LangVptr->V_Tcl_GetVar2)
#define Tcl_HashStats (*LangVptr->V_Tcl_HashStats)
#define Tcl_InitHashTable (*LangVptr->V_Tcl_InitHashTable)
#define Tcl_IntResults (*LangVptr->V_Tcl_IntResults)
#define Tcl_LinkVar (*LangVptr->V_Tcl_LinkVar)
#define Tcl_Merge (*LangVptr->V_Tcl_Merge)
#define Tcl_NextHashEntry (*LangVptr->V_Tcl_NextHashEntry)
#define Tcl_Panic (*LangVptr->V_Tcl_Panic)
#define Tcl_PosixError (*LangVptr->V_Tcl_PosixError)
#define Tcl_RegExpRange (*LangVptr->V_Tcl_RegExpRange)
#define Tcl_ResetResult (*LangVptr->V_Tcl_ResetResult)
#define Tcl_ResultArg (*LangVptr->V_Tcl_ResultArg)
#define Tcl_SetResult (*LangVptr->V_Tcl_SetResult)
#define Tcl_SetVar (*LangVptr->V_Tcl_SetVar)
#define Tcl_SetVar2 (*LangVptr->V_Tcl_SetVar2)
#define Tcl_SetVarArg (*LangVptr->V_Tcl_SetVarArg)
#define Tcl_SprintfResult (*LangVptr->V_Tcl_SprintfResult)
#define Tcl_TildeSubst (*LangVptr->V_Tcl_TildeSubst)
#define Tcl_TraceVar (*LangVptr->V_Tcl_TraceVar)
#define Tcl_TraceVar2 (*LangVptr->V_Tcl_TraceVar2)
#define Tcl_UnlinkVar (*LangVptr->V_Tcl_UnlinkVar)
#define Tcl_UntraceVar (*LangVptr->V_Tcl_UntraceVar)
#define Tcl_UntraceVar2 (*LangVptr->V_Tcl_UntraceVar2)
#define TkReadDataPending (*LangVptr->V_TkReadDataPending)
#endif /* _LANG_VM */
