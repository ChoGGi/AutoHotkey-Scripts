/*
;fAffinitySet(),fAffinityGet,fGetPID()
;fEnumProcesses(),fSeDebugPrivilege(),fSetIOPriority(),fEmptyMem()
sLoadDlls := "wtsapi32:advapi32:ntdll:psapi"
#Include <Processes>
*/

;load dlls into memory
If sLoadDlls
  {
  Loop Parse,sLoadDlls,:
    %A_LoopField% := LoadLibrary(A_LoopField)

  Global wtsapi32,advapi32,ntdll,psapi
  }

/*
Speedup DllCall (excluded: "User32.dll", "Kernel32.dll", "ComCtl32.dll" & "Gdi32.dll")
See DllCall>Performance section

Ex:
global psapi := LoadLibrary("psapi")
DllCall(psapi.EmptyWorkingSet,"UInt",h)
When done:
FreeLibrary("psapi")

LoadLibrary & FreeLibrary by Bentschi
https://autohotkey.com/board/topic/90266-funktionen-loadlibrary-freelibrary-schnellere-dllcalls/
https://github.com/ahkscript/ASPDM/blob/master/Local-Client/Test_Packages/loadlibrary/Lib/loadlibrary.ahk
*/
LoadLibrary(sDllName)
  {
  Static ref := {}
  If (!(ptr := p := DllCall("LoadLibrary","str",sDllName,"ptr")))
    Return 0
  ref[ptr,"count"] := (ref[ptr]) ? ref[ptr,"count"]+1 : 1
  p += NumGet(p+0,0x3c,"int")+24
  o := {_ptr:ptr,__delete:func("FreeLibrary"),_ref:ref[ptr]}
  If (NumGet(p+0,(A_PtrSize=4) ? 92 : 108,"uint")<1 || (ts := NumGet(p+0,(A_PtrSize=4) ? 96 : 112,"uint")+ptr)=ptr || (te := NumGet(p+0,(A_PtrSize=4) ? 100 : 116,"uint")+ts)=ts)
    Return o
  n := ptr+NumGet(ts+0,32,"uint")
  Loop % NumGet(ts+0,24,"uint")
    {
    If (p := NumGet(n+0,(A_Index-1)*4,"uint"))
      {
      o[f := StrGet(ptr+p,"cp0")] := DllCall("GetProcAddress","ptr",ptr,"astr",f,"ptr")
      If (Substr(f,0)==((A_IsUnicode) ? "W" : "A"))
        o[Substr(f,1,-1)] := o[f]
      }
    }
  Return o
  }
/*
FreeLibrary(lib)
  {
  If (lib._ref.count > =1)
    lib._ref.count -= 1
  If (lib._ref.count < 1)
    DllCall("FreeLibrary","ptr",lib._ptr)
  }
*/

;returns PID from *name*.exe,*name*,PID
fGetPID(siProc)
  {
  If siProc Is integer
    Return siProc
  Else
    {
    Process Exist,%siProc%.exe
    If ErrorLevel
      Return ErrorLevel
    Process Exist,%siProc%
    Return ErrorLevel
    }
  }

/*
Set process IO Priority
-1 makes it blank in process hacker, and 7 in process explorer.

;sets pid 11441 to very low io
fSetIOPriority(11441)
;sets explorer.exe to low
fSetIOPriority("explorer",1)
;sets explorer.exe to normal
fSetIOPriority("explorer.exe",2)

;fSetIOPriority()
sLoadDlls := "ntdll"
#Include <Processes>
fSetIOPriority(DllCall("GetCurrentProcessId"))

made by ChoGGi, and thanks to ReactOS DDK ntddk.h
*/
fSetIOPriority(siProc,iPriority := 0)
  {
  iPID := fGetPID(siProc)
  iHandle := DllCall("OpenProcess","UInt",PROCESS_SET_INFORMATION := 0x0200,"Int",0,"UInt",iPID)
  DllCall(ntdll.NtSetInformationProcess,"UInt",iHandle,"UInt",ProcessIoPriority := 33,"UInt*",iPriority,"UInt",4)
  DllCall("CloseHandle","Ptr",iHandle)
  }

/*
https://msdn.microsoft.com/en-us/library/windows/desktop/ms684320
HANDLE WINAPI OpenProcess(
  _In_ DWORD dwDesiredAccess,
  _In_ BOOL  bInheritHandle,
  _In_ DWORD dwProcessId
);
PROCESS_QUERY_INFORMATION (0x0400)
PROCESS_SET_INFORMATION (0x0200)
0x0200 (512) + 0x0400 (1024) = 1536

https://msdn.microsoft.com/en-us/library/windows/desktop/ms686223
BOOL WINAPI SetProcessAffinityMask(
  _In_ HANDLE    hProcess,
  _In_ DWORD_PTR dwProcessAffinityMask
);

https://msdn.microsoft.com/en-us/library/windows/desktop/ms683213
BOOL WINAPI GetProcessAffinityMask(
  _In_  HANDLE     hProcess,
  _Out_ PDWORD_PTR lpProcessAffinityMask,
  _Out_ PDWORD_PTR lpSystemAffinityMask
);

Affinity_Set(CPUmask,{PID/Process name})
By SKAN
https://autohotkey.com/board/topic/7984-ahk-functions-incache-cache-list-of-recent-items/page-7#post_id_191053
*/
fAffinitySet(sCPU,siProc)
  {
  iPID := fGetPID(siProc)
  If !InStr(sCPU,"0x")
    sCPU := "0x" sCPU

  iHandle := DllCall("OpenProcess","Int",512,"Int",0,"Int",iPID)
  DllCall("SetProcessAffinityMask","Ptr",iHandle,"UPtr",sCPU)
  DllCall("CloseHandle","Ptr",iHandle)
  }

/*
SetFormat IntegerFast,Hex
ProcAff := fAffinityGet("dopus.exe")
ProcAff := StrReplace(ProcAff,"0x")
msgbox %ProcAff%
Return

https://autohotkey.com/boards/viewtopic.php?t=18233
By Coco
*/
fAffinityGet(siProc)
  {
  iPID := fGetPID(siProc)

  hPr := DllCall("OpenProcess","Int",1024,"Int",0,"Int",iPID)
  VarSetCapacity(PAf,8,0)
  ;VarSetCapacity(PAf,8,0),VarSetCapacity(SAf,8,0)
  ;DllCall("GetProcessAffinityMask","Ptr",hPr,"UPtrP",&PAf,"UPtrP",&SAf)
  DllCall("GetProcessAffinityMask","Ptr",hPr,"Ptr",&PAf)
  DllCall("CloseHandle","Ptr",hPr)
  Return NumGet(PAf,0,"Int64")
  }

/*
https://msdn.microsoft.com/en-us/library/windows/desktop/ms686714.aspx
terminates without unloading dlls

By ChoGGi

fTerminateProcess(siProc)
  {
  iPID := fGetPID(siProc)
  hPr := DllCall("OpenProcess","Int",0x0001,"Int",0,"Int",iPID)
  DllCall("TerminateProcess","Ptr",hPr,"Int",0)
  DllCall("CloseHandle","Ptr",hPr)
  }
*/

/*
By heresy
https://autohotkey.com/board/topic/30042-run-ahk-scripts-with-less-half-or-even-less-memory-usage/
*/
fEmptyMem(siProc)
  {
  iPID := fGetPID(siProc)

  iHandle := DllCall("OpenProcess","UInt",0x001F0FFF,"Int",0,"Int",iPID)
  DllCall(psapi.EmptyWorkingSet,"UInt",iHandle)
  DllCall("CloseHandle","Int",iHandle)
  }

/*
returns list of processes (using PID:processame.exe|PID2:processame.exe)

By SKAN, http://goo.gl/6Zwnwu, CD:24/Aug/2014 | MD:25/Aug/2014
*/
fEnumProcesses(iWhich := 0)
  {
  Local tPtr := 0,pPtr := 0,nTTL := 0,LIST := ""
  If !(DllCall(wtsapi32.WTSEnumerateProcesses,"Ptr",0,"UInt",0,"UInt",1,"Ptr*",pPtr,"UInt*",nTTL))
    Return "",DllCall("SetLastError","UInt",-1)
    ;Return "",DllCall("kernel32.dll\SetLastError","UInt",-1)

  tPtr := pPtr

  If iWhich = 0 ;proc:pid|proc:pid|
    {
    Loop % (nTTL)
    LIST .= NumGet( tPtr + 4,"UInt" ) ":" StrGet( NumGet( tPtr + 8 ) ) "|"
      ,tPtr += ( A_PtrSize = 4 ? 16 : 24 )    ; sizeof( WTS_PROCESS_INFO )
    }
  Else ;pid|pid|
    {
    Loop % (nTTL)
    LIST .= NumGet( tPtr + 4,"UInt" ) "|"
      ,tPtr += ( A_PtrSize = 4 ? 16 : 24 )    ; sizeof( WTS_PROCESS_INFO )
    }

  ;DllCall("Wtsapi32.dll\WTSFreeMemory","Ptr",pPtr)
  DllCall(wtsapi32.WTSFreeMemory,"Ptr",pPtr)

  Return LIST,DllCall("SetLastError","UInt",nTTL)
  ;Return LIST,DllCall("kernel32.dll\SetLastError","UInt",nTTL)
  }
/*
so we can change service processes

from ahk manual
Process function Example #4:
*/
fSeDebugPrivilege()
  {
  h := DllCall("OpenProcess","UInt",0x0400,"Int",false,"UInt",DllCall("GetCurrentProcessId"),"Ptr")
  ; Open an adjustable access token with this process (TOKEN_ADJUST_PRIVILEGES = 32)
  DllCall(advapi32.OpenProcessToken,"Ptr",h,"UInt",32,"PtrP",t)
  VarSetCapacity(ti,16,0)  ; structure of privileges
  NumPut(1,ti,0,"UInt")  ; one entry in the privileges array...
  ; Retrieves the locally unique identifier of the debug privilege:
  DllCall(advapi32.LookupPrivilegeValue,"Ptr",0,"Str","SeDebugPrivilege","Int64P",luid)
  NumPut(luid,ti,4,"Int64")
  NumPut(2,ti,12,"UInt")  ; enable this privilege: SE_PRIVILEGE_ENABLED = 2
  ; Update the privileges of this process with the new access token:
  r := DllCall(advapi32.AdjustTokenPrivileges,"Ptr",t,"Int",false,"Ptr",&ti,"UInt",0,"Ptr",0,"Ptr",0)
  DllCall("CloseHandle","Ptr",t)  ; close this access token handle to save memory
  DllCall("CloseHandle","Ptr",h)  ; close this process handle to save memory
  Return r
  }
