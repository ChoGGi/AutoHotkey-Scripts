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

v0.01
Initial Release
*/
#NoEnv
#KeyHistory 0
#NoTrayIcon
#SingleInstance Force
;#Persistent
#InstallKeybdHook
#InstallMouseHook
SetBatchLines -1
ListLines Off
AutoTrim Off
Process Priority,,L
SetWinDelay -1
SendMode Input

sLoadDlls := "dwmapi,psapi,ntdll,msvcrt,shell32"
Global shell32
;fThumbMake(),fSetIOPriority()
#Include <Functions>
iScriptPID := DllCall("GetCurrentProcessId")
hScriptHnd := DllCall("GetModuleHandle",sPtr,0)
;get script filename
SplitPath A_ScriptName,,,,sName
;get settings filename
sProgIni := A_ScriptDir "\" sName ".ini"

;create settings file
If !FileExist(sProgIni)
  {
  sText := "[Hotkeys]`r`nAlt_Hotkey=!`r`nTab_Hotkey=Tab`r`nShift_Tab_Hotkey=+Tab`r`nEsc_Hotkey=Esc`r`n[Settings]`r`n;Programs to ignore`r`n;Exclude_List=googledrivesync.exe,some progam.exe`r`nExclude_List=`r`nWindow_Width=0.55`r`nFont_Size=14`r`nFont_Type=Arial`r`nFont_Colour=Silver`r`nGui_x=Center`r`nGui_y=150`r`n"
  FileAppend %sText%,%sProgIni%
  Run %sProgIni%
  }
Global bDisplay_List_Shown,Alt_Esc,Alt_Hotkey,Tab_Hotkey,Shift_Tab_Hotkey,Esc_Hotkey
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

; Max height
Height_Max_Modifier := 0.50 ; multiplier for screen height (e.g. 0.92 = 92% of screen height max )
; Width
;Listview_Width := A_ScreenWidth * 0.10
Listview_Width := A_ScreenWidth * Window_Width
; Widths
Col_1 := 50 ; icon column
Col_2 := 0 ; hidden column for row number
; col 3 is autosized based on other column sizes
Col_4 := "AutoHdr" ; State
Col_5 := "Auto" ; Status - e.g. Hung
Col_6 := 0 ; HWND (hidden)
; Max height
Height_Max := A_ScreenHeight * Height_Max_Modifier ; limit height of listview
; Colours in RGB hex
Listview_Colour := "4F4F4F" ; does not need converting as only used for background

If Exclude_List
  {
  oExclude_List := {}
  Loop Parse,Exclude_List,`,
    oExclude_List[(A_LoopField)] := 1
  }

OnMessage(0x06,"fWM_ACTIVATE") ; alt tab list window lost focus > hide list
GoSub Initiate_Hotkeys ; initiate Alt-Tab and Alt-Shift-Tab hotkeys and translate some modifier symbols

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

bDisplay_List_Shown := 0
Col_Title_List := "#| |Window|View|Status|WinID"
Col_Title := StrSplit(Col_Title_List,"|")

;set script IO/page priority to very low
fSetIOPriority(iScriptPID)
fSetPagePriority(iScriptPID)

SetTimer lEmptyMem,300000
fEmptyMem(iScriptPID)

Return

lEmptyMem:
  fEmptyMem(iScriptPID)
Return

lDisplay_List:
  ;If bDisplay_List_Shown = 1 ; empty listview and image list if only updating - e.g. when closing a window (mbutton)
  If bDisplay_List_Shown ; empty listview and image list if only updating - e.g. when closing a window (mbutton)
    LV_Delete()
  Else ; not shown - need to create gui for updating listview
    {
    ; Create the ListView gui
    Gui 1:Default
    Gui +AlwaysOnTop +ToolWindow -SysMenu +HwndhMainGUI
    Gui Margin,0,0
    Gui Font,s%Font_Size% c%Font_Colour%,%Font_Type%
    ;LV0x10000 (LVS_EX_DOUBLEBUFFER) LV0x8000 (LVS_EX_BORDERSELECT)
    Gui Add,ListView,w%Listview_Width% AltSubmit -Multi NoSort -Hdr +LV0x10000 +LV0x8000 Background%Listview_Colour% Count10 gListView_Event HWNDhListView1,%Col_Title_List%
    LV_ModifyCol(2, "Integer") ; sort hidden column 2 as numbers
    ;create preview window
    sHiddenColor := "EEAA99"
    Gui Thumb:Default
    Gui +AlwaysOnTop +ToolWindow -SysMenu +HwndhThumbnailId
    Gui Color,%sHiddenColor%
    Gui Margin,0,0
    Gui Show,AutoSize NoActivate,Preview
    Gui 1:Default
    }

  ;list of thumbnails to be removed after gui destroy
  oThumbnails := {}

  ImageListID1 := IL_Create(10,5,1) ; Create an ImageList so that the ListView can display some icons
  LV_SetImageList(ImageListID1,1) ; Attach the ImageLists to the ListView so that it can later display the icons

  ;List windows and icons:
  WinGet aWindow_List,List ; Gather a list of running programs
  Window_Found_Count := 0
  GuiControl -Redraw,%hListView1%
  Loop % aWindow_List
    {
    wid := aWindow_List%A_Index%
    WinGetTitle sWinTitle,ahk_id %wid%
    WinGet sWinStyle,Style,ahk_id %wid%

    If (sWinStyle & WS_DISABLED || !sWinTitle) ; skip unimportant windows ; ! sWinTitle or
      Continue

    WinGet sProcName,ProcessName,ahk_id %wid%
    If oExclude_List[sProcName]
      Continue

    WinGet sExStyle,ExStyle,ahk_id %wid%
    Parent := fConvertBase(DllCall("GetWindow","uint",wid))
    WinGet Style_parent,Style,ahk_id %Parent%
    Owner := fConvertBase(DllCall("GetWindow","uint",wid,"uint","4"))
    WinGet Style_Owner,Style,ahk_id %Owner%
    If (((sExStyle & WS_EX_TOOLWINDOW) && !(Parent)) ; filters out program manager, etc
        || (!(sExStyle & WS_EX_APPWINDOW)
        && (((Parent) && ((Style_parent & WS_DISABLED) = 0)) ; These 2 lines filter out windows that have a parent or owner window that is NOT disabled -
        || ((Owner) && ((Style_Owner & WS_DISABLED) = 0))))) ; NOTE - some windows result in blank value so must test for zero instead of using NOT operator!
      Continue

    ;WinGetClass Win_Class, ahk_id %wid%
    ;hw_popup := fConvertBase(10,16,DllCall("GetLastActivePopup", "uint", wid))
    ;Dialog := 0 ; init/reset
    ;If (Win_Class = "#32770" && sWinStyle & WS_POPUP && es & WS_EX_DLGMODALFRAME)
    ;  Continue
      ;Dialog := 1 ; found a Dialog window

    ;Get Window Icon:
    ; check status of window - if window is responding or "Hung"
    Responding := DllCall("SendMessageTimeout","UInt",wid,"UInt",WM_NULL,"Int",0,"Int",0,"UInt",SMTO_ABORTIFHUNG,"UInt",iWinTimeout,"UInt*",0)
    ;retrieve icon
    SendMessage WM_GETICON,ICON_BIG,0,,ahk_id %wid%
    hIcon := ErrorLevel
    If !hIcon
      {
      hIcon := DllCall("GetClassLongPtr",sPtr,wid,Int,GCLP_HICON)
      If !hIcon
        {
        ;get proc path
        WinGet sProcPath,ProcessPath,ahk_id %wid%
        ;retrieve icon
        hIcon := DllCall(shell32.ExtractAssociatedIcon,sPtr,hScriptHnd,Str,sProcPath,"Int*",0) ;only supports 32x32
        }
      }
    ;add to icon list
    DllCall("ImageList_ReplaceIcon",UInt,ImageListID1,Int,-1,UInt,hIcon)

    Window_Found_Count += 1

    ;Window__Store_attributes(Window_Found_Count,wid) ; Index, wid, parent (or blank if none)
    Window%Window_Found_Count% := wid                  ; store ahk_id's to a list
    ;Window_Parent%Window_Found_Count% := ID_Parent      ; store Parent ahk_id's to a list to later see if window is owned
    Title%Window_Found_Count% := sWinTitle               ; store titles to a list
    ;hw_popup%Window_Found_Count% := hw_popup             ; store the active popup window to a list (eg the find window in notepad)
    ;WinGet sProcName%Window_Found_Count%,ProcessName,ahk_id %wid% ; store processes to a list
    ;WinGet PID%Window_Found_Count%,PID,ahk_id %wid% ; store pid's to a list
    ;Dialog%Window_Found_Count% := Dialog  ; 1 if found a Dialog window, else 0

    WinGet iMinMax,MinMax,ahk_id %wid%
    State%Window_Found_Count% := (iMinMax = 0 ? ""
      : iMinMax = -1 ? "Min" : "Max")

    If sExStyle & 0x8
      State%Window_Found_Count% := State%Window_Found_Count% "Top"

    If Responding
      Status%Window_Found_Count% := ""
    Else
      {
      Status%Window_Found_Count% := "Hung"
      Status_Found := 1
      }

    LV_Add("Icon" . Window_Found_Count,"",Window_Found_Count,Title%Window_Found_Count%,State%Window_Found_Count%,Status%Window_Found_Count%,Window%Window_Found_Count%)
    }
  GuiControl +Redraw,%hListView1%

  ;List windows and icons
  If Window_Found_Count = 0
    {
    Window_Found_Count := 1
    LV_Add("","","","","","") ; No Windows Found! - avoids an error on selection if nothing is added
    }

  GoSub Gui_Resize_and_Position
  ;If bDisplay_List_Shown = 1 ; resize gui for updating listview
  If bDisplay_List_Shown ; resize gui for updating listview
    {
    Gui 1:Show,AutoSize x%Gui_x% y%Gui_y%,Alt-Tab
    If Selected_Row > %Window_Found_Count% ; less windows now - select last one instead of default 1st row
      Selected_Row := Window_Found_Count
    LV_Modify(Selected_Row,"Focus Select Vis") ; select 1st entry since nothing selected
    }
  bDisplay_List_Shown := 1 ; Gui 1 is shown back in Alt_Tab_Common_Function() for initial creation
Return

Gui_Resize_and_Position:
  DetectHiddenWindows On ; retrieving column widths to enable calculation of col 3 width
  ;If bDisplay_List_Shown = 0 ; resize listview columns - no need to resize columns for updating listview
  If !bDisplay_List_Shown ; resize listview columns - no need to resize columns for updating listview
    {
    LV_ModifyCol(1,Col_1) ; icon column
    LV_ModifyCol(2,Col_2) ; hidden column for row number
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
  lv_h := 4 + lv_header_h + (lv_row_h * Window_Found_Count)
  GuiControl Move,SysListView321,h%lv_h%

  DetectHiddenWindows Off
Return

ListView_Event:
  If A_GuiEvent = Normal ; activate lv item
    Alt_Tab_Common_Function(0)
  If A_GuiEvent = DoubleClick ; activate clicked window
    GoSub lListView_Destroy
  If A_GuiEvent = K ; letter was pressed, select next window name starting with that letter
    GoSub Key_Pressed_1st_Letter

  LV_GetText(sState,Selected_Row,4)
  LV_GetText(sHung,Selected_Row,5)
  If (sHung || sState != "Min")
    {
    Gui Thumb:Show,NoActivate
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
  Else
    Gui Thumb:Hide,NoActivate
Return

~Alt Up::GoSub lListView_Destroy

Initiate_Hotkeys:
  Use_AND_Symbol := "" ; initiate
  ; If both Alt and Tab are modifier keys, write Tab as a word not a modifier symbol, else Alt-Tab is invalid hotkey
  If Alt_Hotkey contains #,!,^,+
    {
    If Tab_Hotkey contains #,!,^,+
      Replace_Modifier_Symbol("Tab_Hotkey","Tab_Hotkey")
    }
  Else If Alt_Hotkey contains XButton1,XButton2
    Use_AND_Symbol := " & "
  Else If Tab_Hotkey contains WheelUp,WheelDown
    Use_AND_Symbol := " & "
  Hotkey %Alt_Hotkey%%Use_AND_Symbol%%Tab_Hotkey%, Alt_Tab, On ; turn on alt-tab hotkey here to be able to turn it off for simple switching of apps in script
  Hotkey %Alt_Hotkey%%Use_AND_Symbol%%Shift_Tab_Hotkey%, Alt_Shift_Tab, On ; turn on alt-tab hotkey here to be able to turn it off for simple switching of apps in script

  Replace_Modifier_Symbol("Alt_Hotkey","Alt_Hotkey2")
Return

Alt_Tab: ; alt-tab hotkey
  Alt_Tab_Common_Function()
Return

Alt_Shift_Tab: ; alt-shift-tab hotkey
  Alt_Tab_Common_Function("Alt_Shift_Tab")
Return

Alt_Tab_Common_Function(Key := "Alt_Tab") ; Key = "Alt_Tab" or "Alt_Shift_Tab"
  {
  Global
  ;If bDisplay_List_Shown = 0
  If !bDisplay_List_Shown
    {
    WinGet Active_ID,ID,A
    GoSub lDisplay_List

    ;Alt_Tab_Common__Highlight_Active_Window
    Active_ID_Found := 0 ; init
    Loop % Window_Found_Count ; select active program in list (not always the top item)
      {
      LV_GetText(RowText,A_Index,2)  ; Get hidden column numbers
      ;user did a quick alt-tab with a hung window (no RowText so just abort)
      If RowText = %A_Space%
        {
        GoSub lListView_Destroy
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

    If (GetKeyState(Alt_Hotkey2, "P") || GetKeyState(Alt_Hotkey2)) ; Alt key still pressed, else gui not shown
      {
      Gui 1:Show,AutoSize x%Gui_x% y%Gui_y%,Alt-Tab
      Hotkeys_Toggle_Temp_Hotkeys("On") ; (state = "On" or "Off") ; ensure hotkeys are on
      }
    }

  Selected_Row := LV_GetNext(0,"F")
  If Key
    {
    If Key = Alt_Tab
      {
      Selected_Row += 1
      If (Selected_Row > Window_Found_Count)
        Selected_Row := 1
      }
    Else If Key = Alt_Shift_Tab
      {
      Selected_Row -= 1
      If Selected_Row < 1
        Selected_Row := Window_Found_Count
      }
    }
  LV_Modify(Selected_Row,"Focus Select Vis") ; get selected row and ensure selection is visible
  ;GuiControl Focus,%hListView1% ; workaround for gui tab bug - GoSub not activated when already activated button clicked on again
  }

Alt_Esc: ; abort switching
  Alt_Esc := 1
  GoSub lListView_Destroy
Return


Alt_Esc_Check_Alt_State: ; hides alt-tab gui - shows again if alt still pressed
  GoSub Alt_Esc
  If (GetKeyState(Alt_Hotkey2,"P") || GetKeyState(Alt_Hotkey2)) ; Alt key still pressed - show alt-tab again
    GoSub Alt_Tab
Return

Key_Pressed_1st_Letter:
  Key_Pressed_ASCII := A_EventInfo
  Get__Selected_Row_and_RowText()
  If Key_Pressed_ASCII = 40 ; Down arrow
    {
    GoSub Alt_Tab
    Return
    }
  If Key_Pressed_ASCII = 38 ; Up arrow
    {
    GoSub Alt_Shift_Tab
    Return
    }

  Loop % Window_Found_Count
    {
    Selected_Row += 1
    If Selected_Row > %Window_Found_Count% ; wrap around to start
      Selected_Row := 1
    LV_GetText(List_Title_Text,Selected_Row,2) ; hidden number column

    ; Check for parent's title for typing first letter
    ;If Window_Parent%List_Title_Text% !=
    ;If Window_Parent%List_Title_Text%
    ;  WinGetTitle List_Title_Text,% "ahk_id " Window_Parent%List_Title_Text%
    ;Else
      WinGetTitle List_Title_Text,% "ahk_id " Window%List_Title_Text%
    ;StringUpper, List_Title_Text, List_Title_Text ; need to match against upper case when alt is held down
    List_Title_Text := Format("{:U}",List_Title_Text)
    ; convert to ASCII key code
    List_Title_Text := Asc(List_Title_Text)

    If Key_Pressed_ASCII = %List_Title_Text%
      {
      LV_Modify(Selected_Row,"Focus Select Vis")
      Break
      }
    }
Return

lListView_Destroy:
  Hotkeys_Toggle_Temp_Hotkeys("Off") ; (state = "On" or "Off")
  Gui 1: Default
  If Alt_Esc != 1 ; i.e. not called from Alt_Esc
    Get__Selected_Row_and_RowText()
  bDisplay_List_Shown := 0
  If RowText != %A_Space%
    {
    If Status%RowText% = Hung  ; do not activate a Hung window (O/S unstable)
      Alt_Esc := 1
    If Alt_Esc != 1 ; i.e. not called from Alt_Esc
      {
      wid := Window%RowText%
      ;hw_popup := hw_popup%RowText%
      WinGet wid_MinMax,MinMax,ahk_id %wid%
      If wid_MinMax = -1 ;minimised
        WinRestore ahk_id %wid%
      ;If hw_popup
      ;  WinActivate ahk_id %hw_popup%
      ;Else
        WinActivate ahk_id %wid%
      }
    Else If Alt_Esc = 1 ; WM_ACTIVATE - clicked outside alt-tab gui 1
      WinActivate ahk_id %Active_ID%
    }
  Else If Alt_Esc = 1
    WinActivate ahk_id %Active_ID%

  Gui 1: Destroy ; destroy after switching to avoid re-activation of some windows
  Gui Thumb: Destroy
  Status_Found := "" ; reset
  Alt_Esc := "" ; reset
  ;remove old thumbnails
  Loop % oThumbnails.MaxIndex()
    fThumbRemove(oThumbnails[A_Index])
    ;fThumbRemove(oThumbnails.Pop())
  ;less mem usage
  fEmptyMem(iScriptPID)
Return

Hotkeys_Toggle_Temp_Hotkeys(state) ; (state = "On" or "Off")
  {
  Global
  ; UseErrorLevel in case of exiting script before hotkey created
  Hotkey %Alt_Hotkey%%Use_AND_Symbol%%Esc_Hotkey%,Alt_Esc,%state% UseErrorLevel ; abort
  Hotkey %Alt_Hotkey%%Use_AND_Symbol%WheelUp,Alt_Shift_Tab,%state% UseErrorLevel ; previous window
  Hotkey %Alt_Hotkey%%Use_AND_Symbol%WheelDown,Alt_Tab,%state% UseErrorLevel ; next window
  }

Get__Selected_Row_and_RowText()
  {
  Global
  ;If ListView1__Disabled = 1 ; don't update - for statusbar (timer)
  ;  Return
  Selected_Row := LV_GetNext(0,"F")
  LV_GetText(RowText,Selected_Row,2)  ; Get the row's 2nd column's text for real order number (hidden column).
  }

Replace_Modifier_Symbol(Variable_Name,New_Variable_Name)
  {
  ; replace 1st modifier symbol in Alt_Hotkey,etc with its equivalent text (for hotkey up event compatability)
  Global
  %New_Variable_Name% := %Variable_Name%

  %New_Variable_Name% := StrReplace(%New_Variable_Name%,"#","LWin")
  %New_Variable_Name% := StrReplace(%New_Variable_Name%,"!","Alt")
  %New_Variable_Name% := StrReplace(%New_Variable_Name%,"^","Control")
  %New_Variable_Name% := StrReplace(%New_Variable_Name%,"+","Shift")
  %New_Variable_Name% := StrReplace(%New_Variable_Name%,A_Space "&" A_Space)
  }

fWM_ACTIVATE(wParam)
  {
  ;If (wParam = 0 && A_Gui = 1 && bDisplay_List_Shown = 1) ; i.e. don't trigger when submitting gui
  If (wParam = 0 && A_Gui = 1 && bDisplay_List_Shown) ; i.e. don't trigger when submitting gui
    {
    Alt_Esc := 1
    GoSub Alt_Esc ; hides alt-tab gui
    }
  }
