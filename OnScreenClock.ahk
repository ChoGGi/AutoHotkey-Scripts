/*
Add some clocks

Requires:
https://github.com/ChoGGi/AutoHotkey-Scripts/blob/master/Lib/Functions.ahk

Settings file created on first run

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
sLoadDlls := "psapi,ntdll"
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
  sText := "[Settings]`r`n;how many clocks are we showing?`r`nNumOfClocks=0`r`n`r`n;add clocks with Clock*Number*`r`n:Examples:`r`n;Clock1=TopClock,FFFFFF,000000,Essays1743,18,400,3840,150,320,32,5,5,h:m:ss:t ddd d/MM/y`r`n;Clock2=BottomClock,000000,C0C0C0,Essays1743,18,400,3733,1038,107,32,2,5,hh:mmtt`r`n`r`n;clock settings: title,colour,bg colour,font,font size,font weight,x,y,w,h,margin x,margin y,time format`r`n;See Autohotkey help for time format (search for FormatTime)`r`n;use `, to add a ,`r`n"
  FileAppend %sText%,%sProgIni%
  Run %sProgIni%
  }
IniRead iNumOfClocks,%sProgIni%,Settings,NumOfClocks,0

If iNumOfClocks = 0
  ExitApp

Loop %iNumOfClocks%
  {
  iLoopIndex := A_Index
  IniRead sTmpClock,%sProgIni%,Settings,Clock%A_Index%,0
  sTmpClock := StrReplace(sTmpClock,"``,","¢")

  Loop Parse,sTmpClock,`,
    {
    sLF := StrReplace(A_LoopField,"¢",",")
    ;sLF := A_LoopField
    If A_Index = 1
      sTitle := sLF
    Else If A_Index = 2
      sFontColor := sLF
    Else If A_Index = 3
      sBGColor := sLF
    Else If A_Index = 4
      sFont := sLF
    Else If A_Index = 5
      iFontSize := sLF
    Else If A_Index = 6
      iFontWeight := sLF
    Else If A_Index = 7
      iXPos := sLF
    Else If A_Index = 8
      iYPos := sLF
    Else If A_Index = 9
      iWidth := sLF
    Else If A_Index = 10
      iHeight := sLF
    Else If A_Index = 11
      iMarginX := sLF
    Else If A_Index = 12
      iMarginY := sLF
    Else If A_Index = 13
      sClock%iLoopIndex% := sLF
    }

  Gui %A_Index%:Default
  Gui -Caption +ToolWindow
  Gui Color,%sBGColor%
  Gui Font,s%iFontSize% w%iFontWeight%,%sFont%
  Gui Margin,%iMarginX%,%iMarginY%
  Gui Add,Edit,w%iWidth% h%iHeight% voClock%A_Index% c%sFontColor% +ReadOnly -E0x200
  Gui Show,NoActivate w%iWidth% x%iXPos% y%iYPos%,%sTitle%
  }

;set script IO/page priority to very low
fSetIOPriority(iScriptPID)
fSetPagePriority(iScriptPID)

SetTimer lEmptyMem,300000
fEmptyMem(iScriptPID)

Loop
  {
  Loop %iNumOfClocks%
    {
    FormatTime sTmpTime,,% sClock%A_Index%
    Gui %A_Index%:Default
    GuiControl,,oClock%A_Index%,%sTmpTime%
    }
  Sleep 1000
  }
;end init section

lEmptyMem:
  fEmptyMem(iScriptPID)
Return
