/*
Alt-Tab replacement with preview
Original script: http://www.autohotkey.com/forum/viewtopic.php?t=6422
Edits: removed most of the configurable options, added preview, and changed UI

Requires:
https://github.com/ChoGGi/AutoHotkey-Scripts/blob/master/Lib/Functions.ahk

Settings file created on first run

Keys:
Alt+Tab - move forwards in window stack
Alt+Shift+Tab - move backwards in window stack
Alt+Esc - cancel switching window
Mouse wheel over the taskbar scrolls the list - Middle button selects a window in this mode.
Left click selects, Double leftclick switches to
Press corresponding number to select that window

v0.03
Code cleanup
Preview window was sometimes staying open when it shouldn't
Changed priority to Above Normal
v0.02
Code cleanup
Slightly less loading
Select window with number
v0.01
Initial Release
*/
#NoEnv
#KeyHistory 0
#NoTrayIcon
#SingleInstance Force
#InstallKeybdHook
#InstallMouseHook
SetBatchLines -1
ListLines Off
AutoTrim Off
Process Priority,,A
SetWinDelay -1
SendMode Input

sDlls := "dwmapi,psapi,ntdll,msvcrt,shell32"
Global shell32
;fThumbMake(),fSetIOPriority()
#Include <Functions>
hScriptHnd := DllCall("GetModuleHandle",sPtr,0)
;get script filename
SplitPath A_ScriptName,,,,sProgName
;get settings filename
sProgIni := A_ScriptDir "\" sProgName ".ini"

;make some global vars for functions
Global bDisplay_List_Shown,Alt_Esc,iScriptPID := DllCall("GetCurrentProcessId")

;create settings file
If !FileExist(sProgIni)
  {
  sText := "[Hotkeys]`r`nAlt_Hotkey=!`r`nTab_Hotkey=Tab`r`nShift_Tab_Hotkey=+Tab`r`nEsc_Hotkey=Esc`r`n[Settings]`r`n;Programs to ignore`r`n;Exclude_List=googledrivesync.exe,some progam.exe`r`nExclude_List=`r`nWindow_Width=0.55`r`nFont_Size=14`r`nFont_Type=Arial`r`nFont_Colour=Silver`r`nGui_x=Center`r`nGui_y=150`r`n"
  FileAppend %sText%,%sProgIni%
  Run %sProgIni%
  }
; Hotkeys
IniRead Alt_Hotkey,%sProgIni%,Hotkeys,Alt_Hotkey,!
IniRead Tab_Hotkey,%sProgIni%,Hotkeys,Tab_Hotkey,Tab
IniRead Shift_Tab_Hotkey,%sProgIni%,Hotkeys,Shift_Tab_Hotkey,+Tab
IniRead Esc_Hotkey,%sProgIni%,Hotkeys,Esc_Hotkey,Esc
; Other
IniRead Exclude_List,%sProgIni%,Settings,Exclude_List,% ""
IniRead Window_Width,%sProgIni%,Settings,Window_Width,0.55
IniRead Font_Size,%sProgIni%,Settings,Font_Size,14
IniRead Font_Type,%sProgIni%,Settings,Font_Type,Essays1743
IniRead Font_Colour,%sProgIni%,Settings,Font_Colour,Silver
IniRead Gui_x,%sProgIni%,Settings,Gui_x,Center
IniRead Gui_y,%sProgIni%,Settings,Gui_y,150

; Width
Listview_Width := A_ScreenWidth * Window_Width
; Widths
Col_1 := "Auto" ; Window number
Col_2 := "Auto" ; icon column
; col 3 is autosized based on other column sizes
Col_4 := "Auto" ; State
Col_5 := "Auto" ; Status - e.g. Hung
Col_6 := 0 ; HWND (hidden)
Listview_Colour := "4F4F4F"

sWhichKey := "Alt_Tab"

If Exclude_List
  {
  oExcludeList := {}
  Loop Parse,Exclude_List,`,
    oExcludeList[(A_LoopField)] := 1
  }

OnMessage(0x06,"fWM_ACTIVATE") ;alt tab list window lost focus > hide list

; initiate Alt-Tab and Alt-Shift-Tab hotkeys and translate some modifier symbols
Use_AND_Symbol := ""
; If both Alt and Tab are modifier keys, write Tab as a word not a modifier symbol, else Alt-Tab is invalid hotkey
If Alt_Hotkey contains #,!,^,+
  {
  If Tab_Hotkey contains #,!,^,+
    {
    If InStr(Tab_Hotkey,"#")
      Tab_Hotkey := StrReplace(Tab_Hotkey,"#","LWin")
    If InStr(Tab_Hotkey,"!")
      Tab_Hotkey := StrReplace(Tab_Hotkey,"!","Alt")
    If InStr(Tab_Hotkey,"^")
      Tab_Hotkey := StrReplace(Tab_Hotkey,"^","Control")
    If InStr(Tab_Hotkey,"+")
      Tab_Hotkey := StrReplace(Tab_Hotkey,"+","Shift")
    If InStr(Tab_Hotkey," & ")
      Tab_Hotkey := StrReplace(Tab_Hotkey," & ")
    }
  }
Else If Alt_Hotkey contains XButton1,XButton2,WheelUp,WheelDown
  Use_AND_Symbol := " & "

Hotkey %Alt_Hotkey%%Use_AND_Symbol%%Tab_Hotkey%, lAlt_Tab_HK, On ; turn on alt-tab hotkey here to be able to turn it off for simple switching of apps in script
Hotkey %Alt_Hotkey%%Use_AND_Symbol%%Shift_Tab_Hotkey%, lAlt_Shift_Tab_HK, On ; turn on alt-tab hotkey here to be able to turn it off for simple switching of apps in script

WS_EX_DLGMODALFRAME := 0x1
WS_EX_APPWINDOW := 0x40000
WS_EX_TOOLWINDOW := 0x80
WS_DISABLED := 0x8000000
WS_POPUP := 0x80000000
SMTO_ABORTIFHUNG := 0x0002
GCLP_HICON := -14
WM_NULL := 0x0
WM_GETICON := 0x7F
ICON_BIG := 1
iWinTimeout := 150
bFirstRun := 1

bDisplay_List_Shown := 0
Col_Title_List := "Icon|Num|Window|View|Status|WinID"
Col_Title := StrSplit(Col_Title_List,"|")

;set script IO/page priority to very low
fSetIOPriority(iScriptPID)
fSetPagePriority(iScriptPID)

;create main win gui
Gui 1:Default
Gui +AlwaysOnTop +ToolWindow -SysMenu +HwndhMainGUI
Gui Margin,0,0
Gui Font,s%Font_Size% c%Font_Colour%,%Font_Type%
;LV0x10000 (LVS_EX_DOUBLEBUFFER) LV0x8000 (LVS_EX_BORDERSELECT)
Gui Add,ListView,w%Listview_Width% AltSubmit -Multi NoSort -Hdr +LV0x10000 +LV0x8000 Background%Listview_Colour% Count10 gListView_Event HWNDhListView1,%Col_Title_List%
LV_ModifyCol(2,"Integer") ; sort column 2 as numbers
;create preview win gui
sHiddenColor := "EEAA99"
Gui Thumb:+AlwaysOnTop +ToolWindow -SysMenu +HwndhThumbnailId
Gui Thumb:Color,%sHiddenColor%
Gui Thumb:Margin,0,0

SetTimer lEmptyMem,300000
fEmptyMem(iScriptPID)

Return

lEmptyMem:
  fEmptyMem(iScriptPID)
Return

lDisplay_List:
  ; empty listview and image list if only updating - e.g. when closing a window (mbutton)
  ;If bDisplay_List_Shown
    LV_Delete()

  ;list of thumbnails to be removed after gui destroy
  oThumbnails := {}
  oWindowList := {}
  iWinCount := 0

  oImageListID1 := IL_Create(10,5,1) ; Create an ImageList so that the ListView can display some icons
  LV_SetImageList(oImageListID1,1) ; Attach the ImageLists to the ListView so that it can later display the icons

  ;Gather a list of running programs
  WinGet aWinList,List
  GuiControl -Redraw,%hListView1%
  Loop %aWinList%
    {
    hWinId := aWinList%A_Index%

    WinGetTitle sWinTitle,ahk_id %hWinId%
    WinGet sWinStyle,Style,ahk_id %hWinId%
    WinGet sProcName,ProcessName,ahk_id %hWinId%

    ; skip unimportant windows / blank titles / exclude list
    If (sWinStyle & WS_DISABLED || !sWinTitle || !sProcName || oExcludeList[sProcName])
      Continue

/*SKIP THESE
Now Playing
ahk_class WindowsForms10.Window.8.app.0.378734a

If the RegEx title matching mode is active, ahk_class accepts a regular expression.
*/

    WinGet sExStyle,ExStyle,ahk_id %hWinId%
    Parent := fConvertBase(DllCall("GetWindow","uint",hWinId))
    WinGet Style_parent,Style,ahk_id %Parent%
    Owner := fConvertBase(DllCall("GetWindow","uint",hWinId,"uint","4"))
    WinGet Style_Owner,Style,ahk_id %Owner%
    If (((sExStyle & WS_EX_TOOLWINDOW) && !(Parent)) ; filters out program manager, etc
        || (!(sExStyle & WS_EX_APPWINDOW)
        && (((Parent) && ((Style_parent & WS_DISABLED) = 0)) ; These 2 lines filter out windows that have a parent or owner window that is NOT disabled -
        || ((Owner) && ((Style_Owner & WS_DISABLED) = 0))))) ; NOTE - some windows result in blank value so must test for zero instead of using NOT operator!
      Continue

    ;WinGetClass Win_Class, ahk_id %hWinId%
    ;hw_popup := fConvertBase(10,16,DllCall("GetLastActivePopup", "uint", hWinId))
    ;Dialog := 0 ; init/reset
    ;If (Win_Class = "#32770" && sWinStyle & WS_POPUP && es & WS_EX_DLGMODALFRAME)
    ;  Continue
      ;Dialog := 1 ; found a Dialog window

    ; check status of window - if window is responding or "Hung"
    Responding := DllCall("SendMessageTimeout","UInt",hWinId,"UInt",WM_NULL,"Int",0,"Int",0,"UInt",SMTO_ABORTIFHUNG,"UInt",iWinTimeout,"UInt*",0)
    If Responding
      {
      ;try getting icon from window
      SendMessage WM_GETICON,ICON_BIG,0,,ahk_id %hWinId%
      hIcon := ErrorLevel
      If !hIcon
        {
        ;try getting it from WNDCLASSEX structure
        hIcon := DllCall("GetClassLongPtr",sPtr,hWinId,Int,GCLP_HICON)
        If !hIcon
          {
          ;get proc path
          WinGet sProcPath,ProcessPath,ahk_id %hWinId%
          ;get it from the file instead
          hIcon := DllCall(shell32.ExtractAssociatedIcon,sPtr,hScriptHnd,Str,sProcPath,"Int*",0)
          }
        }
      }
    Else ;use default icon
      hIcon := DllCall(shell32.ExtractAssociatedIcon,sPtr,hScriptHnd,Str,A_ScriptFullPath,"Int*",0)
    ;add to icon list
    IL_Add(oImageListID1,"HICON:" hIcon)

    iWinCount++

    Window%iWinCount% := hWinId                  ; store ahk_id's to a list
    Title%iWinCount% := sWinTitle               ; store titles to a list
    ;hw_popup%iWinCount% := hw_popup             ; store the active popup window to a list (eg the find window in notepad)
    ;Dialog%iWinCount% := Dialog  ; 1 if found a Dialog window, else 0

    WinGet iMinMax,MinMax,ahk_id %hWinId%
    State%iWinCount% := (iMinMax = 0 ? ""
      : iMinMax = -1 ? "Min" : "Max")
    If sExStyle & 0x8
      State%iWinCount% := State%iWinCount% "Top"

    If Responding
      Status%iWinCount% := ""
    Else
      {
      Status%iWinCount% := "Hung"
      Status_Found := 1
      }

    LV_Add("Icon" . iWinCount,"",iWinCount,Title%iWinCount%,State%iWinCount%,Status%iWinCount%,Window%iWinCount%)
    }
  GuiControl +Redraw,%hListView1%

  ;List windows and icons
  If iWinCount = 0
    {
    iWinCount := 1
    LV_Add("","","","","","") ; No Windows Found! - avoids an error on selection if nothing is added
    }

  DetectHiddenWindows On ; retrieving column widths to enable calculation of col 3 width
  If !bDisplay_List_Shown ; resize listview columns - no need to resize columns for updating listview
    {
    LV_ModifyCol(1,Col_1) ; icon column
    LV_ModifyCol(2,Col_2) ; row number
    ; col 3 - see below
    LV_ModifyCol(4,Col_4) ; State
    If Status_Found
      LV_ModifyCol(5,Col_5) ; Status
    Else
      LV_ModifyCol(5,0) ; Status
    LV_ModifyCol(6,Col_6) ; HWND (hidden)
    Loop 7
      {
      SendMessage 0x1000+29,A_Index -1,0,,ahk_id %hListView1% ; LVM_GETCOLUMNWIDTH (0x1000+29)
      Width_Column_%A_Index% := ErrorLevel
      }
    Col_3_w := Listview_Width - Width_Column_1 - Width_Column_2 - Width_Column_4 - Width_Column_5 - Width_Column_6 - 4 ; total width of columns - 4 for border
    LV_ModifyCol(3,Col_3_w) ; resize title column
    }

  ;Automatically resize listview vertically
  SendMessage 0x1000+31,0,0,SysListView321,ahk_id %hMainGUI% ; LVM_GETHEADER (0x1000+31)
  WinGetPos,,,,lv_header_h,ahk_id %ErrorLevel%
  VarSetCapacity(rect,16,0)
  SendMessage 0x1000+14,0,&rect,SysListView321,ahk_id %hMainGUI% ; LVM_GETITEMRECT (0x1000+14) ; LVIR_BOUNDS
  y1 := 0
  y2 := 0
  Loop 4
    {
    y1 += *(&rect + 3 + A_Index)
    y2 += *(&rect + 11 + A_Index)
    }
  lv_row_h := y2 - y1
  lv_h := 4 + lv_header_h + (lv_row_h * iWinCount)
  GuiControl Move,SysListView321,h%lv_h%

  DetectHiddenWindows Off

  ;If bDisplay_List_Shown ; resize gui for updating listview
    ;{
    Gui 1:Show,AutoSize x%Gui_x% y%Gui_y%,Alt-Tab
    If Selected_Row > %iWinCount% ; less windows now - select last one instead of default 1st row
      Selected_Row := iWinCount
    LV_Modify(Selected_Row,"Focus Select Vis") ; select 1st entry since nothing selected
    ;}
  bDisplay_List_Shown := 1 ; Gui 1 is shown back in Alt_Tab_Common_Function() for initial creation
Return

ListView_Event:
  ;activate lv item
  If A_GuiEvent = Normal
    {
    sWhichKey := ""
    GoSub lAlt_Tab
    }

  ;activate clicked window
  If A_GuiEvent = DoubleClick
    Goto lListView_Hide

  ;letter was pressed, select index num or up/down arrow to switch to next
  If A_GuiEvent = K
    {
    If A_EventInfo = 40 ; Down arrow
      {
      sWhichKey := "Alt_Tab"
      GoSub lAlt_Tab
      Return
      }
    If A_EventInfo = 38 ; Up arrow
      {
      sWhichKey := "Alt_Shift_Tab"
      GoSub lAlt_Tab
      Return
      }

    ;select row by typed number
    siKeyboardKey := Chr(A_EventInfo)
    If siKeyboardKey Is Not Integer
      Return

    LV_Modify(siKeyboardKey,"Focus Select Vis")
    Selected_Row := LV_GetNext(0,"F")
    LV_GetText(RowText,Selected_Row,2)
    }

  If !bIsVisible
    Return

  LV_GetText(sState,Selected_Row,4)
  LV_GetText(sHung,Selected_Row,5)
  ;don't show thumbnail for min/hung programs
  If (InStr(sState,"Min") || sHung)
    Gui Thumb:Hide
  Else
    {
    ;preview only works if dwm is enabled (Desktop Window Manager)
    Dllcall(dwmapi.DwmIsCompositionEnabled,"int*",bIsDWMEnabled)
    If bIsDWMEnabled
      {
      Gui Thumb:Show,AutoSize NoActivate,Preview
      ;Update Preview
      ;get win id from list view
      LV_GetText(iHWND,Selected_Row,6)
      ;hide background bits
      WinSet TransColor,%sHiddenColor%,ahk_id %hThumbnailId%
      ;get height from thumb source win
      WinGetPos,,,iWinWidth,iWinHeight,ahk_id %iHWND%
      ;resize for thumbs
      iWinWidth //= 2
      iWinHeight //= 2
      ;get main win size
      WinGetPos iGUIX,iGUIY,,iGUIHeight,ahk_id %hMainGUI%
      ;move/resize preview window
      WinMove ahk_id %hThumbnailId%,,%iGUIX%,% iGUIY + iGUIHeight + 10,% iWinWidth - 4,% iWinHeight + 4
      ;show thumb
      iThumbnail := fThumbMake(iHWND,hThumbnailId)
      ;add to list (removed later)
      oThumbnails.Push(iThumbnail)
      }
    }
Return

;abort switching
lAlt_Esc_HK:
  Alt_Esc := 1
  GoSub lListView_Hide
Return

~Alt Up::
  If bDisplay_List_Shown ;needed or it'll select after hiding GUI
    GoSub lListView_Hide
Return

lAlt_Shift_Tab_HK:
  sWhichKey := "Alt_Shift_Tab"
  GoTo lAlt_Tab

lAlt_Tab_HK:
  sWhichKey := "Alt_Tab"
  GoTo lAlt_Tab

lAlt_Tab:
  bIsVisible := 1
  If !bDisplay_List_Shown
    {
    WinGet Active_ID,ID,A
    GoSub lDisplay_List

    Active_ID_Found := 0 ; init
    Loop %iWinCount% ; select active program in list (not always the top item)
      {
      LV_GetText(RowText,A_Index,2)  ; Get hidden column numbers

      ;user did a quick alt-tab with a hung window (no RowText so just abort)
      If RowText = %A_Space%
        {
        GoSub lListView_Hide
        Return
        }

      If Window%RowText% = %Active_ID%
        {
        Active_ID_Found := A_Index
        Break
        }
      }
    If Active_ID_Found
      LV_Modify(Active_ID_Found,"Focus Select Vis")
    Gui 1:Show,AutoSize x%Gui_x% y%Gui_y%,Alt-Tab
    Hotkeys_Toggle_Temp_Hotkeys("On") ; (state = "On" or "Off") ; ensure hotkeys are on
    }

  Selected_Row := LV_GetNext(0,"F")
  ;If sWhichKey
  ;  {
    If sWhichKey = Alt_Tab
      {
      Selected_Row++
      If (Selected_Row > iWinCount)
        Selected_Row := 1
      }
    Else If sWhichKey = Alt_Shift_Tab
      {
      Selected_Row--
      If Selected_Row < 1
        Selected_Row := iWinCount
      }
  ;  }
  LV_Modify(Selected_Row,"Focus Select Vis") ; get selected row and ensure selection is visible
  ;GuiControl Focus,%hListView1% ; workaround for gui tab bug - GoSub not activated when already activated button clicked on again
Return

GuiClose:
GuiEscape:
  Gui Thumb:Hide
Return

lListView_Hide:
  Hotkeys_Toggle_Temp_Hotkeys("Off") ; (state = "On" or "Off")
  ;Gui 1: Default
  If Alt_Esc != 1 ; i.e. not called from Alt_Esc
    {
    Selected_Row := LV_GetNext(0,"F")
    LV_GetText(RowText,Selected_Row,2)  ; Get the row's 2nd column's text for real order number (hidden column).
    }

  bDisplay_List_Shown := 0
  If RowText != %A_Space%
    {
    If Status%RowText% = Hung  ; do not activate a Hung window (O/S unstable)
      Alt_Esc := 1
    If Alt_Esc != 1 ; i.e. not called from Alt_Esc
      {
      wid := Window%RowText%
      WinGet wid_MinMax,MinMax,ahk_id %wid%
      If wid_MinMax = -1 ;minimised
        WinRestore ahk_id %wid%
      WinActivate ahk_id %wid%
      }
    Else If Alt_Esc = 1 ; WM_ACTIVATE - clicked outside alt-tab gui 1
      WinActivate ahk_id %Active_ID%
    }
  Else If Alt_Esc = 1
    WinActivate ahk_id %Active_ID%

  Gui 1:Hide
  Gui Thumb:Hide

  Status_Found := "" ; reset
  Alt_Esc := "" ; reset
  ;remove old thumbnails
  Loop % oThumbnails.Length()
    fThumbRemove(oThumbnails[A_Index])
  ;less mem usage
  fEmptyMem(iScriptPID)

  bIsVisible := 0
Return

Hotkeys_Toggle_Temp_Hotkeys(state) ; (state = "On" or "Off")
  {
  Global
  ; UseErrorLevel in case of exiting script before hotkey created
  Hotkey %Alt_Hotkey%%Use_AND_Symbol%%Esc_Hotkey%,lAlt_Esc_HK,%state% UseErrorLevel ; abort
  Hotkey %Alt_Hotkey%%Use_AND_Symbol%WheelUp,lAlt_Shift_Tab_HK,%state% UseErrorLevel ; previous window
  Hotkey %Alt_Hotkey%%Use_AND_Symbol%WheelDown,lAlt_Tab_HK,%state% UseErrorLevel ; next window
  }

fWM_ACTIVATE(wParam)
  {
  ;If (wParam = 0 && A_Gui = 1 && bDisplay_List_Shown)
  If (wParam = 0 && bDisplay_List_Shown) ; i.e. don't trigger when submitting gui
    {
    Alt_Esc := 1
    GoSub lListView_Hide
    }
  }
