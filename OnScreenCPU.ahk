/*
Shows CPU cores usage and memory usage (far right)

Settings file created on first run

Requires:
https://github.com/ChoGGi/AutoHotkey-Scripts/blob/master/Lib/Functions.ahk

https://github.com/ChoGGi/AutoHotkey-Scripts/blob/master/Lib/XGraph.ahk
https://autohotkey.com/boards/viewtopic.php?t=3492

v0.01
Initial Release

Uses NtQuerySystemInformation function from:
https://github.com/jNizM/AHK_Scripts/blob/master/src/performance_counter/NtQuery_CPU_Usage.ahk
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
OnExit GuiClose

;fEmptyMem(),fSetIOPriority(),fGetUsageCPUCores(),fMemoryLoad()
sLoadDlls := "ntdll,psapi"
#Include <Functions>

Global iCores := fGetUsageCPUCores().MaxIndex()
#Include <XGraph>
;#Include <XGraph.org>

;pid of script
iScriptPID := DllCall("GetCurrentProcessId")
;get script filename
SplitPath A_ScriptName,,,,sName
;get settings filename
sProgIni := A_ScriptDir "\" sName ".ini"

;defaults
iDisplayRate := 2000
iSampleRate := 500
sWinPos := "0:0"
iColumnWidth := 27
;missing settings
If !FileExist(sProgIni)
  {
  sText := "[Settings]`r`nDisplayRate=" iDisplayRate "`r`nSampleRate=" iSampleRate "`r`nColumnWidth=" iColumnWidth "`r`nWinPos=" sWinPos "`r`n"
  FileAppend %sText%,%sProgIni%
  Run %sProgIni%
  }
;read stored
IniRead iDisplayRate,%sProgIni%,Settings,DisplayRate,%iDisplayRate%
IniRead iSampleRate,%sProgIni%,Settings,SampleRate,%iSampleRate%
IniRead iColumnWidth,%sProgIni%,Settings,ColumnWidth,%iColumnWidth%
IniRead sWinPos,%sProgIni%,Settings,WinPos,%sWinPos%
sArray := StrSplit(sWinPos,":")
iXPos := sArray[1]
iYPos := sArray[2]
;keep GUI on screen
If iYPos > %A_ScreenHeight%
  iYPos := A_ScreenHeight // 3
If iXPos > %A_ScreenWidth%
  iXPos := A_ScreenWidth // 3

;build gui
BGCustomColor := "000000"
Gui +LastFound -Caption +ToolWindow +HwndhGraphWin
Gui Margin,0,0
Gui Font,q0
;add cpu cores
Loop % iCores
  {
  Gui Add,Text,ys w%iColumnWidth% h102 hwndhGraph%A_Index%
  Gui Add,Text,ys w1 h102 +0x7
  pGraph%A_Index% := XGraph(hGraph%A_Index%,,,"0,2,0,0",0x0000FF,3)
  }
;avail mem graph
Gui Add,Text,ys w%iColumnWidth% h102 hwndhGraphMem
pGraphMem := XGraph(hGraphMem,,,"0,2,0,0",0x0000FF,3)
;show gui
Gui Show,x%iXPos% y%iYPos% AutoSize NoActivate
;hide graph background
WinSet TransColor,%BGCustomColor%,ahk_id %hGraphWin%

;set script IO/page priority to very low
fSetIOPriority(iScriptPID)
fSetPagePriority(iScriptPID)

fEmptyMem(iScriptPID)

SetTimer lUpdateData,%iSampleRate%
SetTimer lUpdateGraph,%iDisplayRate%
SetTimer lEmptyMem,300000
GoSub lUpdateData
GoSub lUpdateGraph

;end of init section
Return

lUpdateData:
  iCPULoad := fGetUsageCPUCores()
  iMemLoad := fMemoryLoad()
Return

lUpdateGraph:
  Loop % iCores
    XGraph_Plot(pGraph%A_Index%,100 - Round(iCPULoad[A_Index]),Round(iCPULoad[A_Index]))
  XGraph_Plot(pGraphMem,100 - iMemLoad,iMemLoad)
Return

lEmptyMem:
  fEmptyMem(iScriptPID)
Return

GuiClose:
  Loop % iCores
    XGraph_Detach(pGraph%A_Index%)
  XGraph_Detach(pGraphMem)
ExitApp
