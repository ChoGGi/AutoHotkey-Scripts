/*
Sets Priority, IO Priority, Page Priority, and Affinity (also has run/kill list)
Loops through process list every *Delay*
also checks list when new processes created

ProcessChanger.exe "Process name.exe" will show the affinity mask (or use " | more" to view it in console)
(you can set affinity in taskmgr)

Requires:
https://github.com/ChoGGi/AutoHotkey-Scripts/blob/master/Lib/Functions.ahk

Settings file created on first run

v0.03
Code cleanup
Ability to pipe process affinity mask to console
Added list option for set Page Priority
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
OnExit lExitApp

;fEnumProcesses(),fSeDebugPrivilege(),fSetIOPriority(),fEmptyMem(),fAffinitySet(),fAffinityGet(),fShellHook()
sDlls := "wtsapi32,advapi32,ntdll,psapi"
#Include <Functions>

;pid of script
Global iScriptPID := DllCall("GetCurrentProcessId")
;get script filename
SplitPath A_ScriptName,,,,sProgName
;get settings filename
sProgIni := A_ScriptDir "\" sProgName ".ini"

;user wants an affinity mask
If A_Args[1]
  {
  Integer := "Integer"
  SetFormat Integer,Hex
  For iIndex,sInputFile in A_Args
    {
    sProcAff := fAffinityGet(sInputFile)
    sProcAff := StrReplace(sProcAff,"0x")
    FileAppend %sProcAff%,*
    InputBox sTempVar,%sInputFile% Affinity Mask:,,,300,100,,,,,%sProcAff%
    }
  ExitApp
  }
;check and remove any extra running copies
Else
  {
  oProcList := fEnumProcesses(1)
  For iPID,sProcName in oProcList
    {
    If (sProcName = sProgName ".exe" && iPID != iScriptPID)
      Process Close,% iPID
    }
  }

;make global var
Global sDefaultAffinity,oPriorityList,oIOPriorityList,oAffinityListCustom
  ,oAffinityList,oKillList,oPagePriorityList

;missing settings
If !FileExist(sProgIni)
  {
  sText := "[Settings]`r`n;WARNING: Parent processes will pass settings onto their children (if you make explorer low, anything started by explorer will also be low)`r`n`r`n;Set priority (CPU usage: Prioritise CPU time for processes, be very careful using Realtime)`r`n;L=Low B=BelowNormal N=Normal A=AboveNormal H=High R=Realtime`r`n;PriorityList=ExampleProgram.exe|L,Example2 Program.exe|BelowNormal`r`nPriorityList=`r`n`r`n;Set io priority (Disk usage: Lower is good for background tasks that churn disk; downloaders/music players/so on)`r`n;0=Very low 1=Low 2=Normal (3=High: not working for now)`r`n;IOPriorityList=ExampleProgram.exe|0,Example2 Program.exe|)`r`nIOPriorityList=`r`n`r`n;Set page priority (Memory usage: Lower means more likely removed from working set if needed)`r`n;1=Very low 2=Low 3=Medium 4=Below normal 5=Normal`r`n;PagePriorityList=ExampleProgram.exe|1,Example2 Program.exe|5`r`nPagePriorityList=`r`n`r`n;Set affinity of these processes to *DefaultAffinity* (CPU core usage, Max amount of cores allowed to be used by process)`r`n;AffinityList=ExampleProgram.exe,Example2 Program.exe`r`nAffinityList=`r`n;Default is last four cores (c00=last 2,fc0=last 6)`r`n;" sProgName ".exe 'Example Program.exe' (show the affinity mask)`r`n;You can set affinity in taskmgr`r`nDefaultAffinity=f00`r`n`r`n;Set custom affinity for certain processes (fff = all cores)`r`n;AffinityListCustom=ExampleProgram.exe|fff,Example2 Program.exe|3f`r`nAffinityListCustom=`r`n`r`n;If these programs aren't running then start them`r`n;RunList=ExampleProgram.exe|C:\Program Files\Example,Example2 Program.exe|C:\Utils`r`nRunList=`r`n`r`n;If these programs are running then kill them`r`n;KillList=ExampleProgram.exe,Example2 Program.exe`r`nKillList=`r`n`r`n;Time to check process list (default is 5 mins)`r`n;Also checks every time new process started`r`nDelay=300000`r`n`r`n;Show system tray icon (only checked on startup)`r`nTrayIcon=True`r`n"
  FileAppend %sText%,%sProgIni%
  Run %sProgIni%
  }
;read settings
GoSub lReadSettings

;get ini filetime
FileGetTime iFileTime,%sProgIni%

;for stuff not to be included in release
IniRead iChoGGi,%sProgIni%,Settings,ChoGGi,0

;show tray menu?
IniRead sTrayIcon,%sProgIni%,Settings,TrayIcon,True
;If sTrayIcon = True || sTrayIcon = %True%
If sTrayIcon In True,1
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

;maybe works for hidden windows?
;EVENT_OBJECT_CREATE
;hWinEventHook := fSetWinEventHook(,0x8000,0x8000,,"fWinProcCallback")

;set script IO/page priority to very low
fSetIOPriority(iScriptPID)
fSetPagePriority(iScriptPID)

fEmptyMem(iScriptPID)

;so we can fiddle with service processes
fSeDebugPrivilege()

;monitor new processes (RegisterShellHookWindow doesn't get all processes)
;https://autohotkey.com/board/topic/56984-new-process-notifier/#entry358038
;Get WMI service object.
oWinMgmts := ComObjGet("winmgmts:")
;Create sink objects for receiving event noficiations.
ComObjConnect(createSink := ComObjCreate("WbemScripting.SWbemSink"), "ProcessCreate_")
;ComObjConnect(deleteSink := ComObjCreate("WbemScripting.SWbemSink"), "ProcessDelete_")

;oWinMgmts.ExecNotificationQueryAsync(deleteSink
;  , "Select * from __InstanceDeletionEvent"
;Register for process creation notifications:
oWinMgmts.ExecNotificationQueryAsync(createSink
  , "Select * from __InstanceCreationEvent"
;check every 1 second
  . " within " 1
  . " where TargetInstance ISA 'Win32_Process'")

;fires every %iDelay%
Loop
  {
  ;check if ini changed
  FileGetTime iFileTimeLoop,%sProgIni%
  If iFileTimeLoop != %iFileTime%
    {
    ;update iFileTime with new time
    iFileTime := iFileTimeLoop
    ;re-read lists/delay
    GoSub lReadSettings
    }

  ;get list of processes
  oProcList := fEnumProcesses(1)
  ;loop em
  For iPID,sProcName in oProcList
    {
    ;set process priority
    If oPriorityList[sProcName]
      Process Priority,%iPID%,% oPriorityList[sProcName]

    ;set process IO priority (it's either -1,0,1,2,3 so we need to use > -2)
    If oIOPriorityList[sProcName] > -2
      fSetIOPriority(iPID,oIOPriorityList[sProcName])

    ;set process Page priority (1-5)
    If oPagePriorityList[sProcName]
      fSetPagePriority(iPID,oPagePriorityList[sProcName])

    ;set default process affinity (0-fff)
    If oAffinityList[sProcName]
      fAffinitySet(iPID,sDefaultAffinity)

    ;set process affinity (custom)
    If oAffinityListCustom[sProcName]
      fAffinitySet(iPID,oAffinityListCustom[sProcName])

    ;kill process
    If oKillList[sProcName]
      Process Close,%iPID%
    }

  ;loop run list
  For sProcName,sPath in oRunList
    {
    Process Exist,%sProcName%
    If !ErrorLevel
      Run %sPath%\%sProcName%,%sPath%,UseErrorLevel
    }

  ;free some mem
  fEmptyMem(iScriptPID)

  ;loop delay
  Sleep %iDelay%
  }

;end of init section

lExitApp:
  ;IniWrite 0,%sProgIni%,Settings,Running
ExitApp

;fShellMessage(iWinParam,iLParam)
ProcessCreate_OnObjectReady(obj)
  {
  ;sProcName := obj.TargetInstance.Name
  ;iWinPID := obj.TargetInstance.ProcessID

  ;set process priority
  If oPriorityList[obj.TargetInstance.Name]
    Process Priority,% obj.TargetInstance.ProcessID,% oPriorityList[obj.TargetInstance.Name]

  ;set process IO priority
  If oIOPriorityList[obj.TargetInstance.Name] > -2
    fSetIOPriority(obj.TargetInstance.ProcessID,oIOPriorityList[obj.TargetInstance.Name])

  ;set process Page priority
  If oPagePriorityList[obj.TargetInstance.Name]
    fSetPagePriority(obj.TargetInstance.ProcessID,oPagePriorityList[obj.TargetInstance.Name])

  ;set process affinity (to last 4 cores, technically 2 with HT)
  If oAffinityList[obj.TargetInstance.Name]
    fAffinitySet(obj.TargetInstance.ProcessID,sDefaultAffinity)

  ;set process affinity (custom)
  If oAffinityListCustom[obj.TargetInstance.Name]
    fAffinitySet(obj.TargetInstance.ProcessID,oAffinityListCustom[obj.TargetInstance.Name])
  }

lListVars:
  ListVars
Return

lSettings:
  Run %sProgIni%
Return

lHideTray:
  IniWrite False,%sProgIni%,Settings,TrayIcon
  Menu Tray,NoIcon
Return

lReload:
  Reload
Return

lExit:
  ExitApp
Return

lReadSettings:
  IniRead oPriorityList,%sProgIni%,Settings,PriorityList,0
  IniRead oIOPriorityList,%sProgIni%,Settings,IOPriorityList,0
  IniRead oPagePriorityList,%sProgIni%,Settings,PagePriorityList,0
  IniRead oAffinityList,%sProgIni%,Settings,AffinityList,0
  IniRead oAffinityListCustom,%sProgIni%,Settings,AffinityListCustom,0
  IniRead oKillList,%sProgIni%,Settings,KillList,0
  IniRead oRunList,%sProgIni%,Settings,RunList,0
  IniRead sDefaultAffinity,%sProgIni%,Settings,DefaultAffinity,0f00
  IniRead iDelay,%sProgIni%,Settings,Delay,300000

  ;create associative arrays
  fCreateList("oPriorityList",oPriorityList)
  fCreateList("oIOPriorityList",oIOPriorityList)
  fCreateList("oPagePriorityList",oPagePriorityList)
  fCreateList("oAffinityListCustom",oAffinityListCustom)
  fCreateList("oAffinityList",oAffinityList,0)
  fCreateList("oKillList",oKillList,0)
  fCreateList("oRunList",oRunList)
Return

fCreateList(oList,sList,bWhich := 1)
  {
  %oList% := {}

  If bWhich
    {
    Loop Parse,sList,`,
      oTmpArray := StrSplit(A_LoopField,"|")
        ,%oList%[(Trim(oTmpArray[1]))] := Trim(oTmpArray[2])
    Return
    }

  Loop Parse,sList,`,
    %oList%[(Trim(A_LoopField))] := 1
  }
