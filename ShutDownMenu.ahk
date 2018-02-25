#NoEnv
#KeyHistory 0
#NoTrayIcon
#SingleInstance Force
SetBatchLines -1
ListLines Off
AutoTrim Off
Process Priority,,A
SetWinDelay -1

OnExit GuiClose

SplitPath A_ScriptName,,,,sProgName
sProgIni := A_ScriptDir "\" sProgName ".ini"

;read ini settings
If !FileExist(sProgIni)
  {
  sText := "[Settings]`r`nShowShutdown=1`r`nShowReboot=1`r`nShowLogoff=1`r`nShowSuspend=0`r`nShowSuspendWake=0`r`nShowHibernate=0`r`nShowHibernateWake=0`r`nShowSuspendForce=0`r`nShowHibernateForce=0`r`nShowHibernateWakeForce=0`r`nShowSuspendWakeForce=0`r`nShowRebootForce=1`r`nShowShutdownForce=1`r`nShowLogoffForce=1`r`nPlaySound=C:\Windows\Media\Windows Shutdown.wav`r`n;RunBeforeShutdown=D:\folder name\example.exe`r`nRunBeforeShutdown=`r`n;Keeps the same selection each time you start`r`nLockCurrentSelection=`r`nCurrentSelection=`r`nWinPos=0:0`r`n"
  FileAppend %sText%,%sProgIni%
  }
IniRead sShowReboot,%sProgIni%,Settings,ShowReboot,1
IniRead sShowShutdown,%sProgIni%,Settings,ShowShutdown,1
IniRead sShowLogoff,%sProgIni%,Settings,ShowLogoff,1
IniRead sShowSuspend,%sProgIni%,Settings,ShowSuspend,0
IniRead sShowSuspendWake,%sProgIni%,Settings,ShowSuspendWake,0
IniRead sShowHibernate,%sProgIni%,Settings,ShowHibernate,0
IniRead sShowHibernateWake,%sProgIni%,Settings,ShowHibernateWake,0
IniRead sShowSuspendForce,%sProgIni%,Settings,ShowSuspendForce,0
IniRead sShowHibernateForce,%sProgIni%,Settings,ShowHibernateForce,0
IniRead sShowHibernateWakeForce,%sProgIni%,Settings,ShowHibernateWakeForce,0
IniRead sShowSuspendWakeForce,%sProgIni%,Settings,ShowSuspendWakeForce,0
IniRead sShowRebootForce,%sProgIni%,Settings,ShowRebootForce,1
IniRead sShowShutdownForce,%sProgIni%,Settings,ShowShutdownForce,1
IniRead sShowLogoffForce,%sProgIni%,Settings,ShowLogoffForce,1
IniRead sPlaySound,%sProgIni%,Settings,PlaySound,% ""
IniRead sRunBeforeShutdown,%sProgIni%,Settings,RunBeforeShutdown,% ""
IniRead sLockCurrentSelection,%sProgIni%,Settings,LockCurrentSelection,% ""
IniRead sCurrentSelection,%sProgIni%,Settings,CurrentSelection,% ""
IniRead sWinPos,%sProgIni%,Settings,WinPos,0:0

;get window position
sArray := StrSplit(sWinPos,":")
iXPos := sArray[1]
iYPos := sArray[2]
;keep GUI on screen
If iYPos > %A_ScreenHeight%
  iYPos := 0
If iXPos > %A_ScreenWidth%
  iXPos := 0

Gui +ToolWindow +AlwaysOnTop +LastFound
Gui Margin,10,5
Gui Add,Text,x2 y0 Section,Select:
Global oReboot,oShutdown,oLogoff,oSuspend,oSuspendWake,oHibernate,oHibernateWake
      ,oRebootForce,oShuthownForce,oLogoffForce,oSuspendForce,oSuspendWakeForce
      ,oHibernateForce,oHibernateWakeForce
fAddButton(sShowReboot,oReboot,"Reboot")
fAddButton(sShowShutdown,oShutdown,"Shutdown")
fAddButton(sShowLogoff,oLogoff,"Logoff")
fAddButton(sShowSuspend,oSuspend,"Suspend")
fAddButton(sShowSuspendWake,oSuspendWake,"Suspend (Disable wake events)")
fAddButton(sShowHibernate,oHibernate,"Hibernate")
fAddButton(sShowHibernateWake,oHibernateWake,"Hibernate (Disable wake events)")
fAddButton(sShowRebootForce,oRebootForce,"Force Reboot")
fAddButton(sShowShutdownForce,oShuthownForce,"Force Shutdown")
fAddButton(sShowLogoffForce,oLogoffForce,"Force Logoff")
fAddButton(sShowSuspendForce,oSuspendForce,"Force Suspend")
fAddButton(sShowSuspendWakeForce,oSuspendWakeForce,"Force Suspend (Disable wake events)")
fAddButton(sShowHibernateForce,oHibernateForce,"Force Hibernate")
fAddButton(sShowHibernateWakeForce,oHibernateWakeForce,"Force Hibernate (Disable wake events)")

;getting the width of the ok button
If InStr(sCurrentSelection,"wake events")
  iButtonLength := StrLen(sCurrentSelection) * 5.5
Else If InStr(sCurrentSelection,"Force")
  iButtonLength := StrLen(sCurrentSelection) * 6.5
Else
  iButtonLength := StrLen(sCurrentSelection) * 8
If !sCurrentSelection
  {
  sCurrentSelection := "Ok"
  iButtonLength := 24
  }

Gui Add,Button,ys+20 xs w%iButtonLength% vOkButton glOkButton Section Default,&%sCurrentSelection%
Gui Show,x%iXPos% y%iYPos% AutoSize,%sProgName%

GuiControl,,%sCurrentSelection%,1
Return

fAddButton(sOption,sName,sLabel)
  {
  If sOption
    Gui Add,Radio,ys+20 xs v%sName% glSelectionChoice Section,%sLabel%
  }

GuiClose:
GuiEscape:
  GoSub lWinPos
ExitApp

lWinPos:
  WinGetPos iXPos,iYPos
  sWinPos := iXPos ":" iYPos
  If sWinPos != :
    IniWrite %sWinPos%,%sProgIni%,Settings,WinPos
Return

lSelectionChoice:
  sCurrentSelection := A_GuiControl

  If InStr(sCurrentSelection,"wake events")
    iButtonLength := StrLen(sCurrentSelection) * 5.5
  Else If InStr(sCurrentSelection,"Force")
    iButtonLength := StrLen(sCurrentSelection) * 6.5
  Else
    iButtonLength := StrLen(sCurrentSelection) * 8

  GuiControl Move,OkButton,w%iButtonLength%
  GuiControl,,OkButton,%sCurrentSelection%
Return

lOkButton:
  GoSub lWinPos
  Gui Submit

  If !sLockCurrentSelection
    IniWrite %sCurrentSelection%,%sProgIni%,Settings,CurrentSelection

  If sRunBeforeShutdown
    RunWait %sRunBeforeShutdown%,,UseErrorLevel

  sTmp := (sCurrentSelection = "Reboot" ? fShutdown(2)
  : sCurrentSelection = "ShutDown" ? fShutdown(9)
  : sCurrentSelection = "Logoff" ? fShutdown(0)
  : sCurrentSelection = "Suspend" ? DllCall("powrprof.dll\SetSuspendState",Int,0,Int,0,Int,0)
  : sCurrentSelection = "Hibernate" ? DllCall("powrprof.dll\SetSuspendState",Int,1,Int,0,Int,0)
  : sCurrentSelection = "SuspendWake" ? DllCall("powrprof.dll\SetSuspendState",Int,0,Int,0,Int,1)
  : sCurrentSelection = "HibernateWake" ? DllCall("powrprof.dll\SetSuspendState",Int,1,Int,0,Int,1)
  : sCurrentSelection = "RebootForce" ? fShutdown(6)
  : sCurrentSelection = "ShutDownForce" ? fShutdown(13)
  : sCurrentSelection = "LogoffForce" ? fShutdown(4)
  : sCurrentSelection = "SuspendForce" ? DllCall("powrprof.dll\SetSuspendState",Int,0,Int,1,Int,0)
  : sCurrentSelection = "HibernateForce" ? DllCall("powrprof.dll\SetSuspendState",Int,1,Int,1,Int,0)
  : sCurrentSelection = "SuspendWakeForce" ? DllCall("powrprof.dll\SetSuspendState",Int,0,Int,1,Int,1)
  : sCurrentSelection = "HibernateWakeForce" ? DllCall("powrprof.dll\SetSuspendState",Int,1,Int,1,Int,1) : "")

  If sPlaySound
    SoundPlay %sPlaySound%,Wait

ExitApp

fShutdown(iCode)
  {
  Shutdown %iCode%
  }
