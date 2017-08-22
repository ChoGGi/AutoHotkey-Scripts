/*
Loops through process list every %Delay%
also checks list on window created

See ProcessChanger.ini to setup

Requires:
https://github.com/ChoGGi/AutoHotkey-Scripts/blob/master/Lib/Processes.ahk

v0.01
Initial Release
*/
#KeyHistory 0
#NoEnv
#NoTrayIcon
#SingleInstance Force
SetBatchLines -1
Process Priority,,L
ListLines Off
SetWinDelay -1

;make some vars global for ShellMessage function
Global ProcessList,AffinityList,AffinityListCustom

;EnumProcesses()/Affinity_Set()/SeDebugPrivilege()
#Include <Processes>

;so we can fiddle with service processes
SeDebugPrivilege()

;get script filename
SplitPath A_ScriptFullPath,,,,Name

;ScriptINI := A_WorkingDir Name ".ini"
;overridden with mine (should be above for generic sake)
ScriptINI := A_ScriptDir "\" Name ".ini"

;read lists
IniRead ProcessList,%ScriptINI%,Settings,ProcessList,0
IniRead AffinityList,%ScriptINI%,Settings,AffinityList,0
IniRead AffinityListCustom,%ScriptINI%,Settings,AffinityListCustom,0
IniRead RunList,%ScriptINI%,Settings,RunList,0
IniRead KillList,%ScriptINI%,Settings,KillList,0
IniRead Delay,%ScriptINI%,Settings,Delay,300000
;get ini filetime
FileGetTime FileTime,%ScriptINI%

Gui +LastFound
hWnd := WinExist()

DllCall("RegisterShellHookWindow",UInt,hWnd)
MsgNum := DllCall("RegisterWindowMessage",Str,"SHELLHOOK")
OnMessage(MsgNum,"ShellMessage")

Loop
  {

  ;check if ini changed
  FileGetTime FileTimeLoop,%ScriptINI%
  If (FileTimeLoop != FileTime)
    {
    ;update FileTime with new time
    FileTime := FileTimeLoop
    ;re-read lists
    IniRead ProcessList,%ScriptINI%,Settings,ProcessList,0
    IniRead AffinityList,%ScriptINI%,Settings,AffinityList,0
    IniRead AffinityListCustom,%ScriptINI%,Settings,AffinityListCustom,0
    IniRead RunList,%ScriptINI%,Settings,RunList,0
    IniRead KillList,%ScriptINI%,Settings,KillList,0
    IniRead Delay,%ScriptINI%,Settings,Delay,300000
    }

  ;Parse run list
  Loop Parse,RunList,`,
    {
    StringSplit TempArray,A_LoopField,|
    Process Exist,%TempArray2%
    If (ErrorLevel = 0)
      Run %TempArray1%\%TempArray2%,%TempArray1%,UseErrorLevel
    }

  ;Parse kill list
  Loop Parse,KillList,`,
    Process Close,%A_LoopField%

  ;get list of processes
  pList := EnumProcesses()
  ;loop em
  Loop Parse,pList,|
    {
    StringSplit pListArray,A_LoopField,@,%A_Space%

    ;skip PID 0 and 4
    if (pListArray1 = 0 || pListArray1 = 4)
      Continue

    ;set process affinities (to last 4 cores, well technically 2 with HT)
    Loop Parse,AffinityList,`,
      {
      If (A_LoopField = pListArray2)
        Affinity_Set("0x0f00",pListArray1)
      }

    ;set process affinities (custom)
    Loop Parse,AffinityListCustom,`,
      {
      StringSplit TempArray,A_LoopField,:
      If (TempArray1 = pListArray2)
        {
        affinity := "0x" TempArray2
        Affinity_Set(affinity,pListArray1)
        }
      }

    ;set process priorities
    Loop Parse,ProcessList,`,
      {
      StringSplit TempArray,A_LoopField,:
      ;apply priority
      If (TempArray1 = pListArray2)
        Process Priority,%pListArray1%,%TempArray2%
      }
    }

  ;loop delay
  Sleep %Delay%

  }

;sets aff/pri on created windows
ShellMessage(wParam,lParam)
  {
  ;HSHELL_WINDOWCREATED = 1 HSHELL_WINDOWACTIVATED = 4
  If (wParam != 1)
    Return

  ;wait a bit
  Sleep 50

  ;blank titles
  WinGetTitle aWinTitle,ahk_id %lParam%
  If (aWinTitle = "")
    Return
  ;minimized windows
  WinGet aMinMax,MinMax,ahk_id %lParam%
  If (aMinMax = -1)
    Return

  ;get PID/exe name
  WinGet aWinPID,PID,ahk_id %lParam%
  WinGet aWinName,ProcessName,ahk_id %lParam%

  ;REMOVE FOR RELEASE
  ;processes to skip
  If (aWinName = "scite.exe")
    Return
  ;REMOVE FOR RELEASE

  ;set process affinities (to last 4 cores, well technically 2 with HT)
  Loop Parse,AffinityList,`,
    {
    If (A_LoopField = aWinName)
      Affinity_Set("0x0f00",aWinPID)
    }

  ;set process affinities (custom)
  Loop Parse,AffinityListCustom,`,
    {
    StringSplit TempArray,A_LoopField,:
    If (TempArray1 = aWinName)
      {
      affinity := "0x" TempArray2
      Affinity_Set(affinity,aWinPID)
      }
    }

  ;set process priorities
  Loop Parse,ProcessList,`,
    {
    StringSplit TempArray,A_LoopField,:
    ;apply priority
    If (TempArray1 = aWinName)
      Process Priority,%aWinPID%,%TempArray2%
    ;VirtualBox.exe>VBoxSVC.exe>VirtualBox.exe (VMs)
    ;VBoxSVC doesn't have a window, and you can't change opened VirtualBox.exe after vm has started (added in vbox 5something)
    If (aWinName = "VirtualBox.exe")
      Process Priority,VBoxSVC.exe,L
    }

  }
