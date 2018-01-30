/*
Push new windows to the right by *PushAmount*

Useful for people with NV Surround or Eyefinity (or ultrawide monitors);
who want to have programs display at centre (relative to how they first appear).
The defaults are for three monitors at 5760 (3*1920)

Settings created on first run

v0.03
Code cleanup
v0.02
Wasn't pushing properly on certain wide windows
v0.01
Initial Release
*/
#NoEnv
#KeyHistory 0
#NoTrayIcon
#SingleInstance Force
SetBatchLines -1
ListLines Off
AutoTrim Off
Process Priority,,L
SetWinDelay -1
OnExit lUnloadHook

Global bLoopTitles,iPushAmount,iVisibleZone,iPrimaryWidth,iCloseAmount
      ,iWaitTime,iDelay,oIgnoreList,sIgnoreListTitles,iChoGGi

sLoadDlls := "psapi,ntdll"
;fEmptyMem(),fWaitForHungWindow(),fShellHook(),fSetIOPriority()
#Include <Functions>

;pid of script
Global iScriptPID := DllCall("GetCurrentProcessId")
;get script filename
SplitPath A_ScriptName,,,,sName
;get settings filename
sProgIni := A_ScriptDir "\" sName ".ini"

;missing settings
If !FileExist(sProgIni)
  {
  sText := "[Settings]`r`n`r`n;Amount to push windows by`r`nPushAmount=1920`r`n`r`n;If this much of window is on centre monitor then ignore`r`nVisibleZone=50`r`n`r`n;Amount to remove from PushAmount when window is close to PushAmount`r`nCloseAmount=960`r`n`r`n;Don't reposition windows if primary monitor is a different width`r`nPrimaryWidth=5760`r`n`r`n;ms to wait for hung windows before continuing`r`nWaitTime=10000`r`n`r`n;Delay in ms before moving window`r`nDelay=0`r`n`r`n;List of programs to ignore (IgnoreList=Example.exe,Example Space.exe), not case sensitive`r`nIgnoreList=`r`n`r`n;List of window titles to ignore (IgnoreList=Complete Title,- Partial Title), case sensitive`r`nIgnoreListTitles=`r`n`r`n;Show system tray icon`r`nTrayIcon=0`r`n"
  FileAppend %sText%,%sProgIni%
  Run %sProgIni%
  }
;read settings
IniRead iPushAmount,%sProgIni%,Settings,PushAmount,1920
IniRead iVisibleZone,%sProgIni%,Settings,VisibleZone,50
IniRead iPrimaryWidth,%sProgIni%,Settings,PrimaryWidth,5760
IniRead iCloseAmount,%sProgIni%,Settings,CloseAmount,960
IniRead iWaitTime,%sProgIni%,Settings,WaitTime,10000
IniRead iDelay,%sProgIni%,Settings,Delay,0
IniRead sIgnoreListTmp,%sProgIni%,Settings,IgnoreList,%A_Space%
IniRead sIgnoreListTitles,%sProgIni%,Settings,IgnoreListTitles,%A_Space%
;for stuff not to be included in release
IniRead iChoGGi,%sProgIni%,Settings,ChoGGi,0

;show tray menu?
IniRead sTrayIcon,%sProgIni%,Settings,TrayIcon,True
If sTrayIcon
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

;build array for ignore list
If sIgnoreListTmp
  {
  oIgnoreList := {}
  Loop Parse,sIgnoreListTmp,`,
    oIgnoreList[(A_LoopField)] := 1
  VarSetCapacity(sIgnoreListTmp,0)
  }

SetTitleMatchMode 2

;monitor new windows
fShellHook("fShellMessage")

;set script IO/page priority to very low
fSetIOPriority(iScriptPID)
fSetPagePriority(iScriptPID)

SetTimer lEmptyMem,300000
fEmptyMem(iScriptPID)

;end of init section
Return

lUnloadHook:
  ;IniWrite 0,%sProgIni%,Settings,Running
  fShellHook()
ExitApp

lEmptyMem:
  fEmptyMem(iScriptPID)
Return

fShellMessage(iWinParam,iLParam)
  {
  ;we only want created windows (HSHELL_WINDOWCREATED = 1)
  If iWinParam != 1
    Return

  ;when projector is primary monitor
  If A_ScreenWidth != %iPrimaryWidth%
    Return

  ;for misbehaving programs
  Sleep %iDelay%

  ;try to get text from topmost control, which we can't do with hung windows
  ControlGetText sTempVar
  ;and wait for hung window
  fWaitForHungWindow(iLParam,iWaitTime)

  ;get window info
  WinGet sProcName,ProcessName,ahk_id %iLParam%
  WinGetTitle sWinTitle,ahk_id %iLParam%
  WinGetPos iWinXPos,,iWinWidth,iWinHeight,ahk_id %iLParam%

  ;ignore anything already positioned over PushAmount
  If iWinXPos > %iPushAmount%
    Return
  ;if the amount shown on primary is less then VisibleZone ignore
  If !(iWinWidth - (iPushAmount - iWinXPos) < iVisibleZone)
    Return

  ;ignore (borderless) fullscreen windows
  If (A_ScreenWidth = iWinWidth - 16 || A_ScreenWidth = iWinWidth)
  && (A_ScreenHeight = iWinHeight - 16 || A_ScreenHeight = iWinHeight)
    Return

  ;check ignore list
  If oIgnoreList[sProcName]
    Return
  ;loop through sIgnoreListTitles for TitleMatchMode 2
  If (sIgnoreListTitles && InStr(sIgnoreListTitles,sWinTitle,1))
    Return
  /*
    {
    Loop Parse,sIgnoreListTitles,`,
      {
      case sensitive
      If InStr(sWinTitle,A_LoopField,1)
        Return
      }
    }
  */
  ;move the window (dependant on how close it is to the centre monitor)
  iWinXPos := (iWinXPos > iCloseAmount ? iWinXPos + iPushAmount - iCloseAmount
            : iWinXPos + iPushAmount)
  WinMove ahk_id %iLParam%,,%iWinXPos%

  ;close DWM "switch to 2d mode msg" msg
  If (iChoGGi && WinExist("Windows ahk_exe dwm.exe"))
    {
    WinActivate ahk_id %iLParam%
    WinWaitActive ahk_id %iLParam%,,5
    ControlClick Button3
    }

  ;free some mem
  fEmptyMem(iScriptPID)
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
