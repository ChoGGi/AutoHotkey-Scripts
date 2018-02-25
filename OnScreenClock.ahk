/*
Add some clocks

Requires:
https://github.com/ChoGGi/AutoHotkey-Scripts/blob/master/Lib/Functions.ahk

Settings file created on first run

v0.02
Shows full time/date on mouseover
Added option for update delay
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

;fEmptyMem(),fSetIOPriority(),fSetPagePriority()
sDlls := "psapi,ntdll"
#Include <Functions>
;pid of script
Global iScriptPID := DllCall("GetCurrentProcessId")
;get script filename
SplitPath A_ScriptName,,,,sProgName
;get settings filename
sProgIni := A_ScriptDir "\" sProgName ".ini"

;missing settings
If !FileExist(sProgIni)
  {
  sText := "[Settings]`r`n;How many clocks are we showing?`r`nNumOfClocks=1`r`n`r`n;Delay between updates (defaults to one second)`r`nUpdateDelay=1000`r`n`r`n;add clocks with Clock*Number*`r`n:Examples:`r`nClock1=TopClock,FFFFFF,000000,Essays1743,18,400,0,150,320,32,5,5,h:m:ss:t ddd d/MM/y`r`n;Clock2=BottomClock,000000,C0C0C0,Essays1743,18,400,3733,1038,107,32,2,5,hh:mmtt`r`n`r`n;clock settings: title,colour,bg colour,font,font size,font weight,x,y,w,h,margin x,margin y,time format`r`n;See Autohotkey help for time format (search for FormatTime)`r`n;use `, to add a ,`r`n"
  FileAppend %sText%,%sProgIni%
  Run %sProgIni%
  }
IniRead iNumOfClocks,%sProgIni%,Settings,NumOfClocks,0
IniRead iUpdateDelay,%sProgIni%,Settings,UpdateDelay,1000

If iNumOfClocks = 0
  {
  MsgBox 4096,No Clocks,You don't have any clocks setup in`n%sProgIni%
  ExitApp
  }

Loop %iNumOfClocks%
  {
  iLoopIndex := A_Index
  IniRead sClockSettings,%sProgIni%,Settings,Clock%A_Index%,0
  sClockSettings := StrReplace(sClockSettings,"``,","¢")

  Loop Parse,sClockSettings,`,
    {
    sLF := StrReplace(A_LoopField,"¢",",")
    sTmp := (A_Index = 1 ? sTitle := sLF
    : A_Index = 2 ? sFontColor := sLF
    : A_Index = 3 ? sBGColor := sLF
    : A_Index = 4 ? sFont := sLF
    : A_Index = 5 ? iFontSize := sLF
    : A_Index = 6 ? iFontWeight := sLF
    : A_Index = 7 ? iXPos := sLF
    : A_Index = 8 ? iYPos := sLF
    : A_Index = 9 ? iWidth := sLF
    : A_Index = 10 ? iHeight := sLF
    : A_Index = 11 ? iMarginX := sLF
    : A_Index = 12 ? iMarginY := sLF
    : A_Index = 13 ? sClock%iLoopIndex% := sLF : "")
    }

  Gui %A_Index%:Default
  Gui -Caption +ToolWindow
  Gui Color,%sBGColor%
  Gui Font,s%iFontSize% w%iFontWeight%,%sFont%
  Gui Margin,%iMarginX%,%iMarginY%
  Gui Add,Edit,w%iWidth% h%iHeight% voClock%A_Index% c%sFontColor% +ReadOnly -E0x200
  Gui Show,NoActivate w%iWidth% x%iXPos% y%iYPos%,%sTitle%
  }
VarSetCapacity(sClockSettings,0)

;set script IO/page priority to very low
fSetIOPriority(iScriptPID)
fSetPagePriority(iScriptPID)

SetTimer lEmptyMem,300000
fEmptyMem(iScriptPID)

;for tooltips
OnMessage(0x200,"fWM_MOUSEMOVE")

Loop
  {
  Loop %iNumOfClocks%
    {
    ;update time
    FormatTime sTmpTime,,% sClock%A_Index%
    Gui %A_Index%:Default
    GuiControl,,oClock%A_Index%,%sTmpTime%
    ;update tooltip
    FormatTime sTmpTime
    oClock%A_Index%_TT := sTmpTime
    }
  Sleep %iUpdateDelay%
  }

;end init section

lEmptyMem:
  fEmptyMem(iScriptPID)
Return

fWM_MOUSEMOVE()
  {
  Static sPrevControl,_TT

  ;remove tooltip if mouse not over gui
  If !A_Gui
    {
    Tooltip
    Return
    }

  ;same control or blank control
  If (A_GuiControl = sPrevControl || A_GuiControl = A_Space)
    Return

  SetTimer DisplayToolTip,-500
  sPrevControl := A_GuiControl
  Return

  DisplayToolTip:
    ToolTip % %sPrevControl%_TT
    SetTimer RemoveToolTip,-10000
  Return

  RemoveToolTip:
    ToolTip
  Return
  }
