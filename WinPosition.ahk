/*
Push new windows to the right by *PushAmount*

Useful for people with NV Surround or Eyefinity;
who want to have programs display in centre monitor.
The defaults are for three monitors at 5760 (3*1920)

Settings created on first run

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

Global bLoopTitles,iPushAmount,iVisibleZone,iPrimaryWidth,iVisibleAmount
      ,iWaitTime,iDelay,oIgnoreList,sIgnoreListTitles,iChoGGi

;fWaitForHungWindow()
#Include <Functions>

/*
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
    If !(iIsHung) || (A_TickCount - iStartTime > iTimeOutMS)
      Break
    Sleep 50
    }
  }
*/

;get script filename
SplitPath A_ScriptFullPath,,,,sName
;get settings filename
sProg_Ini := A_ScriptDir "\" sName ".ini"

;missing settings
If !FileExist(sProg_Ini)
  {
  sText := "[Settings]`r`n`r`n;Amount to push windows by`r`nPushAmount=1920`r`n`r`n;If this much of window is on centre monitor then ignore`r`nVisibleZone=50`r`n`r`n;Amount to remove from PushAmount when pushing from VisibleZone`r`nVisibleAmount=960`r`n`r`n;Don't reposition windows if primary monitor is a different width`r`nPrimaryWidth=5760`r`n`r`n;ms to wait for hung windows before continuing`r`nWaitTime=10000`r`n`r`n;Delay in ms before moving window`r`nDelay=0`r`n`r`n;List of programs to ignore (IgnoreList=Example.exe,Example Space.exe)`r`nIgnoreList=`r`n`r`n;List of window titles to ignore (IgnoreList=Complete Title,- Partial Title)`r`nIgnoreListTitles=`r`n`r`n;Show system tray icon`r`nTrayIcon=0`r`n`r`n"
  FileAppend %sText%,%sProg_Ini%
  Run %sProg_Ini%
  }
;read settings
IniRead iPushAmount,%sProg_Ini%,Settings,PushAmount,1920
IniRead iVisibleZone,%sProg_Ini%,Settings,VisibleZone,50
IniRead iPrimaryWidth,%sProg_Ini%,Settings,PrimaryWidth,5760
IniRead iVisibleAmount,%sProg_Ini%,Settings,VisibleAmount,960
IniRead iWaitTime,%sProg_Ini%,Settings,WaitTime,10000
IniRead iDelay,%sProg_Ini%,Settings,Delay,0
IniRead sIgnoreListT,%sProg_Ini%,Settings,IgnoreList,%A_Space%
IniRead sIgnoreListTitles,%sProg_Ini%,Settings,IgnoreListTitles,%A_Space%
;for stuff not to be included in release
IniRead iChoGGi,%sProg_Ini%,Settings,ChoGGi,0

;show tray menu?
IniRead sTrayIcon,%sProg_Ini%,Settings,TrayIcon,True
If (sTrayIcon = "True" || sTrayIcon = True)
  {
  ;remove default items
  Menu Tray,NoStandard

  If (iChoGGi)
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
oIgnoreList := {}
Loop Parse,sIgnoreListT,`,
  oIgnoreList[(A_LoopField)] := 1
VarSetCapacity(sIgnoreListT,0)

SetTitleMatchMode 2

;monitor new windows
DllCall("RegisterShellHookWindow","UInt",A_ScriptHwnd)
iMsgNum := DllCall("RegisterWindowMessage","Str","SHELLHOOK")
OnMessage(iMsgNum,"fShellMessage")

Return

;sets aff/pri on created windows
fShellMessage(iWinParam,iLParam)
  {
  ;we only want created windows (HSHELL_WINDOWCREATED = 1)
  If (iWinParam != 1)
    Return

  ;when projector is primary monitor
  If (A_ScreenWidth != iPrimaryWidth)
    Return

  ;set last found win
  WinWait ahk_id %iLParam%

  ;get process.exe name
  WinGet sProcName,ProcessName

  ;for misbehaving programs
  Sleep %iDelay%

  ;try to get text from topmost control, which we can't do with hung programs
  ControlGetText sTempVar
  ;wait for hung windows
  fWaitForHungWindow(iLParam,iWaitTime)

  WinGetTitle sWinTitle
  WinGetPos iWinXPos,,iWinWidth

  ;anything already positioned over *iPushAmount*
  If (iWinXPos > iPushAmount)
    Return
  ;if window is visible on centre monitor then ignore it, unless it's larger then push amount
  Else If (iPushAmount - iWinXPos < iWinWidth) && !(iWinWidth > iPushAmount)
    Return
  ;if it's showing less then *iVisibleZone* then don't ignore, unless it's larger then push amount
  Else If !(iWinWidth - iPushAmount - iWinXPos < iVisibleZone) && !(iWinWidth > iPushAmount)
    Return

  ;check ignore list
  If (oIgnoreList[sProcName] || oIgnoreList[sWinTitle])
    Return
  ;loop through sIgnoreListTitles for TitleMatchMode 2
  Else Loop Parse,sIgnoreListTitles,`,
    {
    If WinExist(A_LoopField)
      Return
    }

  ;get position of window, if it's on the left monitor push to middle
  If (iWinXPos < iPushAmount)
    {
    ;but don't push it too much if it's somewhat visible
    If (iPushAmount - iWinXPos < iWinWidth) && (iWinWidth - iPushAmount - iWinXPos < iVisibleZone)
      iWinXPos := iWinXPos + iPushAmount - iVisibleAmount
    Else
      iWinXPos := iWinXPos + iPushAmount
    WinMove %iWinXPos%
    }

  ;close DWM "switch to 2d mode msg" msg
  If (iChoGGi && WinExist("Windows ahk_exe dwm.exe"))
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

/*
HSHELL_WINDOWCREATED
1
A top-level, unowned window has been created. The window exists when the system calls this hook.
HSHELL_WINDOWDESTROYED
2
A top-level, unowned window is about to be destroyed. The window still exists when the system calls this hook.
HSHELL_ACTIVATESHELLWINDOW
3
The shell should activate its main window.
HSHELL_WINDOWACTIVATED
4
The activation has changed to a different top-level, unowned window.
HSHELL_GETMINRECT
5
A window is being minimized or maximized. The system needs the coordinates of the minimized rectangle for the window.
A script may monitor it to Minimize a window to the tray.
HSHELL_REDRAW
6
The title of a window in the task bar has been redrawn.
A script may monitor it to activate a window whenever its contents are changed.
HSHELL_TASKMAN
7
The user has selected the task list. A shell application that provides a task list should return TRUE to prevent Windows from starting its task list.
HSHELL_LANGUAGE
8
Keyboard language was changed or a new keyboard layout was loaded.
HSHELL_SYSMENU
9
HSHELL_ENDTASK
10
HSHELL_ACCESSIBILITYSTATE
11
The accessibility state has changed.
HSHELL_APPCOMMAND
12
The user completed an input event (for example, pressed an application command button on the mouse or an application command key on the keyboard), and the application did not handle the WM_APPCOMMAND message generated by that input.
If the Shell procedure handles the WM_COMMAND message, it should not call CallNextHookEx. See the Return Value section for more information.
for 12 iLParam is:
APPCOMMAND_BROWSER_BACKWARD = 1
APPCOMMAND_BROWSER_FORWARD = 2
APPCOMMAND_BROWSER_REFRESH = 3
APPCOMMAND_BROWSER_STOP = 4
APPCOMMAND_BROWSER_SEARCH = 5
APPCOMMAND_BROWSER_FAVORITES = 6
APPCOMMAND_BROWSER_HOME = 7
APPCOMMAND_VOLUME_MUTE = 8
APPCOMMAND_VOLUME_DOWN = 9
APPCOMMAND_VOLUME_UP = 10
APPCOMMAND_MEDIA_NEXTTRACK = 11
APPCOMMAND_MEDIA_PREVIOUSTRACK = 12
APPCOMMAND_MEDIA_STOP = 13
APPCOMMAND_MEDIA_PLAY_PAUSE = 14
APPCOMMAND_LAUNCH_MAIL = 15
APPCOMMAND_LAUNCH_MEDIA_SELECT = 16
APPCOMMAND_LAUNCH_APP1 = 17
APPCOMMAND_LAUNCH_APP2 = 18
APPCOMMAND_BASS_DOWN = 19
APPCOMMAND_BASS_BOOST = 20
APPCOMMAND_BASS_UP = 21
APPCOMMAND_TREBLE_DOWN = 22
APPCOMMAND_TREBLE_UP = 23
APPCOMMAND_MICROPHONE_VOLUME_MUTE = 24
APPCOMMAND_MICROPHONE_VOLUME_DOWN = 25
APPCOMMAND_MICROPHONE_VOLUME_UP = 26
APPCOMMAND_HELP = 27
APPCOMMAND_FIND = 28
APPCOMMAND_NEW = 29
APPCOMMAND_OPEN = 30
APPCOMMAND_CLOSE = 31
APPCOMMAND_SAVE = 32
APPCOMMAND_PRINT = 33
APPCOMMAND_UNDO = 34
APPCOMMAND_REDO = 35
APPCOMMAND_COPY = 36
APPCOMMAND_CUT = 37
APPCOMMAND_PASTE = 38
APPCOMMAND_REPLY_TO_MAIL = 39
APPCOMMAND_FORWARD_MAIL = 40
APPCOMMAND_SEND_MAIL = 41
APPCOMMAND_SPELL_CHECK = 42
APPCOMMAND_DICTATE_OR_COMMAND_CONTROL_TOGGLE = 43
APPCOMMAND_MIC_ON_OFF_TOGGLE = 44
APPCOMMAND_CORRECTION_LIST = 45

HSHELL_WINDOWREPLACED
13
A top-level window is being replaced. The window exists when the system calls this hook.
HSHELL_WINDOWREPLACING
14
HSHELL_HIGHBIT
15
HSHELL_FLASH
16
HSHELL_RUDEAPPACTIVATED
17/32772
*/
