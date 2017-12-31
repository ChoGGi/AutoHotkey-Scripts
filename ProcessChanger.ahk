/*
Sets Priority, IO Priority, and Affinity (also has run/kill list)
Loops through process list every *Delay*
also checks list on window created

ProcessChanger.exe "Process name" will return the affinity mask
(you can set affinity in taskmgr)

Requires:
https://github.com/ChoGGi/AutoHotkey-Scripts/blob/master/Lib/Processes.ahk

Settings file created on first run

v0.02
Added list option for IO priority (IOPriorityList)
Changed ProcessList to PriorityList
Swapped around RunList splitter to bring it in alignment with other lists
Uses associative arrays to check, rather than parsing loops (speed up)
v0.01
Initial Release

Thanks to SKAN,Coco,heresy for functions!
*/
#NoEnv
#KeyHistory 0
#NoTrayIcon
#SingleInstance Off
SetBatchLines -1
ListLines Off
AutoTrim Off
Process Priority,,L
SetWinDelay -1

;fEnumProcesses(),fSeDebugPrivilege(),fSetIOPriority(),fEmptyMem(),fAffinitySet()
sLoadDlls := "wtsapi32:advapi32:ntdll" ;skip psapi (fEmptyMem() dll)
;sLoadDlls := "wtsapi32:advapi32:ntdll:psapi"
#Include <Processes>

;user wants an affinity mask
If A_Args.Length()
  {
  For iIndex,sInputFile in A_Args
    fGetAffMask(sInputFile)
  }

;make some vars global
Global oPriorityList,oIOPriorityList,oAffinityList
      ,oAffinityListCustom,sDefaultAffinity,oKillList

;pid of script so we can ignore below
Global iScript_PID := DllCall("GetCurrentProcessId")

;set script IO to very low
fSetIOPriority(iScript_PID)

;so we can fiddle with service processes
fSeDebugPrivilege()

;get script filename
SplitPath A_ScriptFullPath,,,,sName
;get settings filename
sProg_Ini := A_ScriptDir "\" sName ".ini"
;missing settings
If !FileExist(sProg_Ini)
  {
  sText := "[Settings]`r`n;L=Low B=BelowNormal N=Normal A=AboveNormal H=High R=Realtime`r`n;Ex: (ExampleProgram.exe:L,Example2 Program.exe:BelowNormal)`r`nPriorityList=`r`n`r`n;0=very low 1=low 2=normal`r`n;Ex: (ExampleProgram.exe:0,Example2 Program.exe:2)`r`nIOPriorityList=`r`n`r`n;Sets affinity of these processes to *DefaultAffinity*`r`n;Ex: (ExampleProgram.exe,Example2 Program.exe)`r`nAffinityList=`r`n;Default is last four cores (c00=last 2,fc0=last 6)`r`n;You can use ProcessChanger.exe 'Process name' to get affinity mask (you can set affinity in taskmgr)`r`nDefaultAffinity=f00`r`n`r`n;Set custom affinity`r`n;Ex: (ExampleProgram.exe:0fff,Example2 Program.exe:003f)`r`nAffinityListCustom=`r`n`r`n;If these programs aren't running then start them`r`n;Ex: (ExampleProgram.exe|C:\Program Files\Example,Example2 Program.exe|C:\Utils)`r`nRunList=`r`n`r`n;If these programs are running then kill them`r`n;Ex: (ExampleProgram.exe,Example2 Program.exe)`r`nKillList=`r`n`r`n;Time to check process list (default:5 mins)`r`n;Also checks every time new window opened`r`nDelay=300000`r`n`r`n;Show system tray icon (only checked on startup)`r`nTrayIcon=True`r`n"
  FileAppend %sText%,%sProg_Ini%
  Run %sProg_Ini%
  }
;read settings
GoSub lReadSettings

;get ini filetime
FileGetTime iFileTime,%sProg_Ini%

;for stuff not to be included in release
IniRead iChoGGi,%sProg_Ini%,Settings,ChoGGi,0

;show tray menu?
IniRead sTrayIcon,%sProg_Ini%,Settings,TrayIcon,True
If sTrayIcon = True || sTrayIcon = %True%
  {
  ;remove default items
  Menu Tray,NoStandard

  If iChoGGi
    Menu Tray,Add,&List Vars,lListVars
  Menu Tray,Add,&Settings,lSettings
  Menu Tray,Add,&Hide Tray Icon,lHideTray
  Menu Tray,Add
  Menu Tray,Add,&Reload,lReload
  Menu Tray,Add,&Exit,lExit

  ;show tray
  Menu Tray,Icon
  }

;monitor new windows
DllCall("RegisterShellHookWindow","UInt",A_ScriptHwnd)
iMsgNum := DllCall("RegisterWindowMessage","Str","SHELLHOOK")
OnMessage(iMsgNum,"fShellMessage")

;fires every %iDelay%
Loop
  {
  ;check if ini changed
  FileGetTime iFileTimeLoop,%sProg_Ini%
  If iFileTimeLoop != %iFileTime%
    {
    ;update iFileTime with new time
    iFileTime := iFileTimeLoop
    ;re-read lists/delay
    GoSub lReadSettings
    }

  ;get list of processes
  sProcList := fEnumProcesses()
  ;loop em
  Loop Parse,sProcList,|
    {
    oProcListArray := StrSplit(A_LoopField,":")

    ;set process priority
    If oPriorityList[oProcListArray[2]]
      Process Priority,% oProcListArray[1],% oPriorityList[oProcListArray[2]]

    ;set process IO priority (it's either 0,1,2 so we need to use > -1)
    If oIOPriorityList[oProcListArray[2]] > -1
      fSetIOPriority(oProcListArray[1],oIOPriorityList[oProcListArray[2]])

    ;set default process affinity
    If oAffinityList[oProcListArray[2]]
      fAffinitySet(sDefaultAffinity,oProcListArray[1])

    ;set process affinity (custom)
    If oAffinityListCustom[oProcListArray[2]]
      fAffinitySet(oAffinityListCustom[oProcListArray[2]],oProcListArray[1])

    ;kill process
    If oKillList[oProcListArray[2]]
      Process Close,% oProcListArray[1]
    }

  ;parse run list
  Loop Parse,sRunList,`,
    {
    oTempArray := StrSplit(A_LoopField,"|")
    Process Exist,% oTempArray[1]
    If !ErrorLevel
      Run % oTempArray[2] "\" oTempArray[1],% oTempArray[1],UseErrorLevel
    }

  ;blank some vars
  VarSetCapacity(sProcList,0)
  VarSetCapacity(oProcListArray,0)
  VarSetCapacity(oTempArray,0)
  ;free some mem (uncomment psapi above to use)
  ;fEmptyMem(iScript_PID)
  ;loop delay
  Sleep %iDelay%
  }
;end of init section
ExitApp

fGetAffMask(sInputFile)
  {
  SetFormat Integer,Hex
  sProcAff := fAffinityGet(sInputFile)
  sProcAff := StrReplace(sProcAff,"0x")

  FileAppend %sInputFile%:%sProcAff%,*
  InputBox sTempVar,%sInputFile% Affinity Mask:,,,300,100,,,,,%sProcAff%
  ExitApp
  }

fShellMessage(iWinParam,iLParam)
  {
  ;we only want created windows (HSHELL_WINDOWCREATED = 1)
  If iWinParam != 1
    Return

  ;blank titles
  WinGetTitle sWinTitle,ahk_id %iLParam%
  ;skip script exe
  WinGet iWinPID,PID,ahk_id %iLParam%
  If !sWinTitle || iWinPID = %iScript_PID%
    Return

  ;get process name
  WinGet sProcName,ProcessName,ahk_id %iLParam%

  ;set process priority
  If oPriorityList[sProcName]
    {
    Process Priority,%iWinPID%,% oPriorityList[sProcName]
    ;WORKAROUND:
    ;VBoxSVC doesn't have a detectable window, and you can't change opened
    ;VirtualBox.exe after vm has started (added in v5something)
    If sProcName = VirtualBox.exe
      Process Priority,VBoxSVC.exe,L
    }

  ;set process IO priority
  If oIOPriorityList[sProcName] > -1
    {
    fSetIOPriority(iWinPID,oIOPriorityList[sProcName])
    ;WORKAROUND (see above):
    If sProcName = VirtualBox.exe
      fSetIOPriority("VBoxSVC",oIOPriorityList["VBoxSVC.exe"])
    }

  ;set process affinity (to last 4 cores, technically 2 with HT)
  If oAffinityList[sProcName]
    fAffinitySet(sDefaultAffinity,iWinPID)

  ;set process affinity (custom)
  If oAffinityListCustom[sProcName]
    fAffinitySet(oAffinityListCustom[sProcName],iWinPID)

  }

lListVars:
  ListVars
Return

lSettings:
  Run %sProg_Ini%
Return

lHideTray:
  IniWrite False,%sProg_Ini%,Settings,TrayIcon
  Menu Tray,NoIcon
Return

lReload:
  Reload
Return

lExit:
  ExitApp
Return

lReadSettings:
  IniRead sPriorityListT,%sProg_Ini%,Settings,PriorityList,0
  IniRead sIOPriorityListT,%sProg_Ini%,Settings,IOPriorityList,0
  IniRead sAffinityListT,%sProg_Ini%,Settings,AffinityList,0
  IniRead sAffinityListCustomT,%sProg_Ini%,Settings,AffinityListCustom,0
  IniRead sKillListT,%sProg_Ini%,Settings,KillList,0
  IniRead sRunList,%sProg_Ini%,Settings,RunList,0
  IniRead sDefaultAffinity,%sProg_Ini%,Settings,DefaultAffinity,0f00
  IniRead iDelay,%sProg_Ini%,Settings,Delay,300000

  ;create associative arrays instead of using parsing loops
  fCreateList("oPriorityList",sPriorityListT)
  fCreateList("oIOPriorityList",sIOPriorityListT)
  fCreateList("oAffinityListCustom",sAffinityListCustomT)
  fCreateListSimple("oAffinityList",sAffinityListT)
  fCreateListSimple("oKillList",sKillListT)

  ;blank some vars
  VarSetCapacity(oTempArray,0)
  VarSetCapacity(sPriorityListT,0)
  VarSetCapacity(sIOPriorityListT,0)
  VarSetCapacity(sAffinityListT,0)
  VarSetCapacity(sAffinityListCustomT,0)
  VarSetCapacity(sKillListT,0)
Return

fCreateList(oList,sList)
  {
  %oList% := {}
  Loop Parse,sList,`,
    {
    oTempArray := StrSplit(A_LoopField,":")
    %oList%[(oTempArray[1])] := oTempArray[2]
    }
  }

fCreateListSimple(oList,sList)
  {
  %oList% := {}
  Loop Parse,sList,`,
    %oList%[(A_LoopField)] := 1
  }
