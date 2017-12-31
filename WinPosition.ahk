/*
Push new windows to the right by *PushAmount*

Useful for people with NV Surround or Eyefinity (or ultrawide monitors);
who want to have programs display at centre (relative to how they first appear).
The defaults are for three monitors at 5760 (3*1920)

Settings created on first run

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

Global bLoopTitles,iPushAmount,iVisibleZone,iPrimaryWidth,iCloseAmount
      ,iWaitTime,iDelay,oIgnoreList,sIgnoreListTitles,iChoGGi

;by AHK_Scripter
;https://autohotkey.com/board/topic/80581-how-to-detect-a-hung-window/
fIsWindowHung(iHwnd)
  {
  Return DllCall("IsHungAppWindow","Ptr",iHwnd)
  }

;waits for window to become unhung (with timeout)
fWaitForHungWindow(iHwnd,iTimeOutMS := 15000)
  {
  iStartTime := A_TickCount
  Loop
    {
    iIsHung := fIsWindowHung(iHwnd)
    If !iIsHung || A_TickCount - iStartTime > %iTimeOutMS%
      Break
    Sleep 50
    }
  }

;get script filename
SplitPath A_ScriptFullPath,,,,sName
;get settings filename
sProg_Ini := A_ScriptDir "\" sName ".ini"

;missing settings
If !FileExist(sProg_Ini)
  {
  sText := "[Settings]`r`n`r`n;Amount to push windows by`r`nPushAmount=1920`r`n`r`n;If this much of window is on centre monitor then ignore`r`nVisibleZone=50`r`n`r`n;Amount to remove from PushAmount when window is close to PushAmount`r`nCloseAmount=960`r`n`r`n;Don't reposition windows if primary monitor is a different width`r`nPrimaryWidth=5760`r`n`r`n;ms to wait for hung windows before continuing`r`nWaitTime=10000`r`n`r`n;Delay in ms before moving window`r`nDelay=0`r`n`r`n;List of programs to ignore (IgnoreList=Example.exe,Example Space.exe), not case sensitive`r`nIgnoreList=`r`n`r`n;List of window titles to ignore (IgnoreList=Complete Title,- Partial Title), case sensitive`r`nIgnoreListTitles=`r`n`r`n;Show system tray icon`r`nTrayIcon=0`r`n`r`n"
  FileAppend %sText%,%sProg_Ini%
  Run %sProg_Ini%
  }
;read settings
IniRead iPushAmount,%sProg_Ini%,Settings,PushAmount,1920
IniRead iVisibleZone,%sProg_Ini%,Settings,VisibleZone,50
IniRead iPrimaryWidth,%sProg_Ini%,Settings,PrimaryWidth,5760
IniRead iCloseAmount,%sProg_Ini%,Settings,CloseAmount,960
IniRead iWaitTime,%sProg_Ini%,Settings,WaitTime,10000
IniRead iDelay,%sProg_Ini%,Settings,Delay,0
IniRead sIgnoreListT,%sProg_Ini%,Settings,IgnoreList,%A_Space%
IniRead sIgnoreListTitles,%sProg_Ini%,Settings,IgnoreListTitles,%A_Space%
;for stuff not to be included in release
IniRead iChoGGi,%sProg_Ini%,Settings,ChoGGi,0

;show tray menu?
IniRead sTrayIcon,%sProg_Ini%,Settings,TrayIcon,True
;If sTrayIcon = True || sTrayIcon = %True%
;If sTrayIcon = True || sTrayIcon
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
If sIgnoreListT
  {
  oIgnoreList := {}
  Loop Parse,sIgnoreListT,`,
    oIgnoreList[(A_LoopField)] := 1
  VarSetCapacity(sIgnoreListT,0)
  }

SetTitleMatchMode 2

;monitor new windows
DllCall("RegisterShellHookWindow","UInt",A_ScriptHwnd)
iMsgNum := DllCall("RegisterWindowMessage","Str","SHELLHOOK")
OnMessage(iMsgNum,"fShellMessage")

;end of init section
Return

fShellMessage(iWinParam,iLParam)
  {
  ;we only want created windows (HSHELL_WINDOWCREATED = 1)
  If iWinParam != 1
    Return

  ;when projector is primary monitor
  If A_ScreenWidth != %iPrimaryWidth%
    Return

  ;set last found win
  WinWait ahk_id %iLParam%

  ;for misbehaving programs
  Sleep %iDelay%

  ;try to get text from topmost control, which we can't do with hung windows
  ControlGetText sTempVar
  ;and wait for hung window
  fWaitForHungWindow(iLParam,iWaitTime)

  ;get window info
  WinGet sProcName,ProcessName
  WinGetTitle sWinTitle
  WinGetPos iWinXPos,,iWinWidth,iWinHeight

  ;ignore anything already positioned over PushAmount
  If iWinXPos > %iPushAmount%
    Return
  ;if the amount shown on primary is less then VisibleZone ignore
  Else If !(iWinWidth - (iPushAmount - iWinXPos) < iVisibleZone)
    Return

  ;ignore (borderless) fullscreen windows
  Else If (A_ScreenWidth = iWinWidth - 16 || A_ScreenWidth = iWinWidth)
  && (A_ScreenHeight = iWinHeight - 16 || A_ScreenHeight = iWinHeight)
    Return

  ;check ignore list
  Else If oIgnoreList[sProcName]
    Return
  ;loop through sIgnoreListTitles for TitleMatchMode 2
  Else If sIgnoreListTitles
    {
    Loop Parse,sIgnoreListTitles,`,
      {
      ;case sensitive
      If InStr(sWinTitle,A_LoopField,1)
        Return
      }
    }

  ;move the window (dependant on how close it is to the centre monitor)
  If iWinXPos > %iCloseAmount%
    iWinXPos := iWinXPos + iPushAmount - iCloseAmount
  Else
    iWinXPos := iWinXPos + iPushAmount
  WinMove %iWinXPos%

  ;close DWM "switch to 2d mode msg" msg
  If iChoGGi && WinExist("Windows ahk_exe dwm.exe")
    {
    WinActivate
    WinWaitActive
    ControlClick Button3
    }
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
