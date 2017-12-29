/*
A simple GUI for extracting tracks from MKVs
Using MKVToolNix (mkvextract/mkvmerge)
https://mkvtoolnix.download

mkvextractAGUI Example.mkv

Requires:
https://github.com/cocobelgica/AutoHotkey-JSON/blob/master/Jxon.ahk (1560aaa on 6 Apr 2016)
https://github.com/cocobelgica/AutoHotkey-Util/blob/master/StdOutToVar.ahk (3541fbe on 25 Aug 2014)
SetPath (see lib dir)

v0.01
Initial Release
*/
#NoEnv
#KeyHistory 0
#SingleInstance Force
;#SingleInstance Off
#NoTrayIcon
SetBatchLines -1
ListLines Off
AutoTrim Off
SetWinDelay -1

#Include <JXON>
#Include <StdOutToVar>

Global Jxon_Load,StdOutToVar,sProg_Ini,sProg_Dir,sProg_Exe,sProg_Name,TitleName
      ,ExtractTracks,OverWriteFiles,OutputDir,OutExt,OutputName,BatchFile
      ,TrackListing,ExtractToMKA,ExitAfter,Merge_Exe

sProg_Exe := "\mkvextract.exe"
Merge_Exe := "\mkvmerge.exe"
#Include <SetPath>

If (A_Args.Length())
  sInFile := A_Args[1]
Else
  {
  FileSelectFile sInFile,,,,Matroska Files (*.mk*)
  If ErrorLevel
    ExitApp
  }

IniRead ExtractToMKA,%sProg_Ini%,Settings,ExtractToMKA,0
IniRead OverWriteFiles,%sProg_Ini%,Settings,OverWriteFiles,1
IniRead ExitAfter,%sProg_Ini%,Settings,ExitAfter,1
IniRead sWinPos,%sProg_Ini%,Settings,WinPos,0:0
sArray := StrSplit(sWinPos,":")
iXPos := sArray[1]
iYPos := sArray[2]
;keep GUI on screen
If (iYPos > A_ScreenHeight)
  iYPos := A_ScreenHeight // 3
If (iXPos > A_ScreenWidth)
  iXPos := A_ScreenWidth // 3
IniRead GuiHeight,%sProg_Ini%,Settings,Height,400
IniRead GuiWidth,%sProg_Ini%,Settings,Width,680

Gui +ToolWindow +LastFound +AlwaysOnTop +Resize +OwnDialogs
Gui Margin,10,5

Gui Add,Text,x2 y0 vInfoText,Loading File...
TrackListing := MakeTrackListing(sInFile)
ListAmount := (TrackListing.MaxIndex() + 3)
Gui Add,ListView,vTrackList gToggleSelectList Checked Count%ListAmount% r%ListAmount%,Track|Type|Codec|Misc
;stop drawing till list populated
GuiControl -Redraw,TrackList
Loop % TrackListing.MaxIndex()
  LV_Add("",TrackListing[A_Index][1],TrackListing[A_Index][2],TrackListing[A_Index][3],TrackListing[A_Index][4])
GuiControl +Redraw,TrackList
;let list know column 1 can be sorted by num
LV_ModifyCol(1,"Integer")
;resize the other columns
LV_ModifyCol(2,50)
LV_ModifyCol(3,125)
LV_ModifyCol(4,430)

Gui Show,x%iXPos% y%iYPos%,%sProg_Name%: %TitleName%
GuiControl Text,InfoText,Choose tracks to extract:
GuiControl Move,InfoText,W300

Gui Add,Button,y0 x0 gButtonExtract vButtonExtract Default,&Extract
Gui Add,Button,y0 x0 gGuiClose vCancelBut,Cancel
Gui Add,Button,y0 x0 gToggleSelect vToggleSelect,&Toggle Select
Gui Add,Button,y0 x0 gButtonBatchFile vBatchFile,&Batch File
Gui Add,Text,y0 x0 vBatchFileDrop,Batch "Drop Zone"
Gui Add,CheckBox,y0 x0 vExtractToMKA,MKA
Gui Add,CheckBox,y0 x0 vOverWriteFiles,Overwrite?
Gui Add,CheckBox,y0 x0 vExitAfter,Exit after
;tooltips
SplitPath sInFile,,OutputDir,OutExt,OutputName
ButtonExtract_TT := "Extract file(s) to " OutputDir
CancelBut_TT := "Exit without doing anything."
ToggleSelect_TT := "Toggle checkmarks."
BatchFile_TT := "Create a batch file with currently selected options and " OutputDir "\*.mkv`n`nYou can also select tracks then drag and drop files on this button or the ""Drop Zone"" if you don't want the whole folder included"
ExtractToMKA_TT := "Extract file(s) to " OutputDir "\" OutputName ".mka (to preserve metadata)"
OverWriteFiles_TT := "Overwrite existing file(s) or automagically rename if existing`n`nBy default files will be extracted to " OutputDir "\" OutputName ".Track*Number*." OutExt """"
ExitAfter_TT := "Exit after starting extraction process"

GuiControl,,ExtractToMKA,%ExtractToMKA%
GuiControl,,OverWriteFiles,%OverWriteFiles%
GuiControl,,ExitAfter,%ExitAfter%

Gui Show,x%iXPos% y%iYPos% w%GuiWidth% h%GuiHeight%,%sProg_Name%: %TitleName%

;for tooltips
OnMessage(0x200,"WM_MOUSEMOVE")
Return

GuiSize:
  GuiControl Move,TrackList, % "W" . (A_GuiWidth - 10) . " H" . (A_GuiHeight - 55)
  GuiControlGet TrackList,Pos
  TrackHeight := (TrackListH + 25)
  GuiControl Move,ButtonExtract, % "X" . (5) . " Y" . (TrackHeight)
  GuiControlGet ButtonExtract,Pos
  GuiControl Move,CancelBut, % "X" . (ButtonExtractW + 10) . " Y" . (TrackHeight)

  GuiControlGet CancelBut,Pos
  GuiControl Move,ToggleSelect, % "X" . (CancelButX + CancelButW + 30) . " Y" . (TrackHeight)
  GuiControlGet ToggleSelect,Pos
  GuiControl Move,BatchFile, % "X" . (ToggleSelectX + ToggleSelectW + 10) . " Y" . (TrackHeight)
  GuiControlGet BatchFile,Pos
  GuiControl Move,BatchFileDrop, % "X" . (BatchFileX + BatchFileW + 10) . " Y" . (TrackHeight + 5)

  TrackWidth := (TrackListW)
  GuiControlGet ExtractToMKA,Pos
  GuiControl Move,ExtractToMKA, % "X" . (TrackWidth - ExtractToMKAW) . " Y" . (TrackHeight + 5)
  GuiControlGet ExtractToMKA,Pos
  GuiControl Move,OverWriteFiles, % "X" . (ExtractToMKAX - ExtractToMKAW - 35) . " Y" . (TrackHeight + 5)
  GuiControlGet OverWriteFiles,Pos
  GuiControl Move,ExitAfter, % "X" . (OverWriteFilesX - 70) . " Y" . (TrackHeight + 5)

  ;gui might be showing some misplaced controls on startup so refresh it
  Gui Show
Return

GuiDropFiles:
  If (A_GuiControl = "BatchFile" or A_GuiControl = "BatchFileDrop")
    {
    GoSub BatchFileDrop
    }
  Else If (A_GuiControl = "TrackList")
    {
    LV_Delete()
    ;we only want the first file dropped
    Loop Parse,A_GuiEvent,`n
      {
      SplitPath A_LoopField,,OutputDir,OutExt,OutputName
      TrackListing := MakeTrackListing(A_LoopField)
      Break
      }
    ;stop drawing till list populated
    GuiControl -Redraw,TrackList
    Loop % TrackListing.MaxIndex()
      LV_Add("",TrackListing[A_Index][1],TrackListing[A_Index][2],TrackListing[A_Index][3],TrackListing[A_Index][4])
    GuiControl +Redraw,TrackList
    }
Return

GuiClose:
GuiEscape:
  iScript_PID := DllCall("GetCurrentProcessId")
  WinGetPos iXPosT,iYPosT,GuiWidth,GuiHeight,ahk_pid %iScript_PID%
  If (iXPosT)
    iXPos := iXPosT
  If (iYPosT)
    iYPos := iYPosT
  GuiControlGet ExtractToMKA
  GuiControlGet OverWriteFiles
  GuiControlGet ExitAfter

  IniWrite %ExtractToMKA%,%sProg_Ini%,Settings,ExtractToMKA
  IniWrite %OverWriteFiles%,%sProg_Ini%,Settings,OverWriteFiles
  IniWrite %ExitAfter%,%sProg_Ini%,Settings,ExitAfter
  sWinPos := iXPos ":" iYPos
  IniWrite %sWinPos%,%sProg_Ini%,Settings,WinPos
  ;IniWrite %GuiWidth%,%sProg_Ini%,Settings,Width
  ;IniWrite %GuiHeight%,%sProg_Ini%,Settings,Height
ExitApp

ToggleSelectList:
  If (A_GuiEvent = "DoubleClick")
    ToggleListView(A_EventInfo)
Return

ToggleSelect:
  Loop % LV_GetCount()
    ToggleListView(A_index)
Return

ButtonBatchFile:
  BatchFileList(0)
Return

BatchFileDrop:
  BatchFileList(1)
Return

BatchFileList(WHICH)
  {
  ;see if anything is checked
  TempNumber := 0
  Loop
    {
    TempNumber := LV_GetNext(TempNumber,"Checked")
    If Not TempNumber
      Break
    RowNumber := TempNumber
    }
  ;nothing checked off, so probably misclick
  If !(RowNumber)
    Return

  DirTmp := OutputDir
  NameTmp := OutputName
  BatchFile := True
  BatchFileOutput := ""

  If !(WHICH)
    {
    Loop Files,%DirTmp%\*.mkv
      {
      SplitPath A_LoopFileLongPath,,OutputDir,,OutputName
      BatchFileOutput .= ExtractFiles() "`n"
      }
    }
  Else If (WHICH)
    {
    Loop Parse,A_GuiEvent,`n
      {
      SplitPath A_LoopField,,OutputDir,,OutputName
      BatchFileOutput .= ExtractFiles() "`n"
      }
    }

  FileDelete %DirTmp%\%NameTmp%-Batch.bat
  FileAppend %BatchFileOutput%,%DirTmp%\%NameTmp%-Batch.bat
  OutputDir := DirTmp
  OutputName := NameTmp
  BatchFile := False
  }

;fired on extraction
ButtonExtract:
  ;see if anything is checked
  TempNumber := 0
  Loop
    {
    TempNumber := LV_GetNext(TempNumber,"Checked")
    If Not TempNumber
      Break
    RowNumber := TempNumber
    }
  ;nothing checked off, so probably misclick
  If !(RowNumber)
    Return

  ExtractFiles()

  If (ExitAfter)
    GoTo GuiClose
Return

ExtractFiles()
  {
  ;update control vars
  Gui Submit,NoHide

  If (ExtractToMKA)
    {
    If (OverWriteFiles = 0 && FileExist(OutputDir "\" OutputName ".mka"))
      ExtractTracks := sProg_Dir Merge_Exe " --output " """" OutputDir "\" OutputName "-" A_TickCount ".mka"""
    Else
      ExtractTracks := sProg_Dir Merge_Exe " --output " """" OutputDir "\" OutputName ".mka"""
    ;reset some vars
    VideoT_Index := ""
    AudioT_Index := ""
    SubtitlesT_Index := ""
    VideoT := 0
    AudioT := 0
    SubtitlesT := 0
    }
  Else
    {
    ExtractTracks := sProg_Dir sProg_Exe " tracks " """" OutputDir "\" OutputName "." OutExt """"
    }
  ;I'm lazy so we're sorting by track column
  LV_ModifyCol(1,"Sort")

  Loop % LV_GetCount()
    {
    SendMessage 4140,A_index - 1,0xF000,SysListView321
    IsChecked := (ErrorLevel >> 12) - 1
    If (IsChecked)
      {
      ;indexes start at 0...
      Index := A_Index - 1

      ;MsgBox % TrackListing[A_Index][3]

      ;build extraction list
      If (ExtractToMKA)
        {
        If (TrackListing[A_Index][2] = "audio")
          {
          AudioT_Index .= "," Index
          AudioT++
          }
        Else If (TrackListing[A_Index][2] = "subtitles")
          {
          SubtitlesT_Index .= "," Index
          SubtitlesT++
          }
        Else If (TrackListing[A_Index][2] = "video")
          {
          VideoT_Index .= "," Index
          VideoT++
          }
        }
      Else
        {
        ;name extensions of common subtitle tracks
        If (InStr(TrackListing[A_Index][3],"VobSub") > 0)
          ExtractTracks .= BuildTrack(Index,"idx")
        Else If (InStr(TrackListing[A_Index][3],"SubRip/SRT") > 0)
          ExtractTracks .= BuildTrack(Index,"srt")
        Else If (InStr(TrackListing[A_Index][3],"HDMV PGS") > 0)
          ExtractTracks .= BuildTrack(Index,"pgs.sup")
        Else If (InStr(TrackListing[A_Index][3],"SubStationAlpha") > 0)
          ExtractTracks .= BuildTrack(Index,"ass")
        ;audio
        Else If (InStr(TrackListing[A_Index][3],"AC-3") > 0)
          ExtractTracks .= BuildTrack(Index,"ac3")
        Else If (InStr(TrackListing[A_Index][3],"AAC") > 0)
          ExtractTracks .= BuildTrack(Index,"aac")
        Else If (InStr(TrackListing[A_Index][3],"MP3") > 0)
          ExtractTracks .= BuildTrack(Index,"mp3")
        Else If (InStr(TrackListing[A_Index][3],"Vorbis") > 0)
          ExtractTracks .= BuildTrack(Index,"ogg")
        Else If (InStr(TrackListing[A_Index][3],"Opus") > 0)
          ExtractTracks .= BuildTrack(Index,"opus")
        Else If (InStr(TrackListing[A_Index][3],"FLAC") > 0)
          ExtractTracks .= BuildTrack(Index,"flac")
        Else If (InStr(TrackListing[A_Index][3],"DTS") > 0)
          ExtractTracks .= BuildTrack(Index,"dts")
        Else If (InStr(TrackListing[A_Index][3],"PCM") > 0)
          ExtractTracks .= BuildTrack(Index,"wav")
        ;video
        Else If (InStr(TrackListing[A_Index][3],"HEVC") > 0)
          ExtractTracks .= BuildTrack(Index,"hevc")
        Else If (InStr(TrackListing[A_Index][3],"AVC") > 0)
          ExtractTracks .= BuildTrack(Index,"avc")
        Else If (InStr(TrackListing[A_Index][3],"MPEG-4") > 0)
          ExtractTracks .= BuildTrack(Index,"mp4")
        Else If (InStr(TrackListing[A_Index][3],"MPEG") > 0)
          ExtractTracks .= BuildTrack(Index,"mpeg")
        Else If (InStr(TrackListing[A_Index][3],"Theora") > 0)
          ExtractTracks .= BuildTrack(Index,"ogv")
        Else If (InStr(TrackListing[A_Index][3],"DIV") > 0)
          ExtractTracks .= BuildTrack(Index,"divx")
        Else If (InStr(TrackListing[A_Index][3],"VP8") > 0)
          ExtractTracks .= BuildTrack(Index,"vp8")
        Else If (InStr(TrackListing[A_Index][3],"VP9") > 0)
          ExtractTracks .= BuildTrack(Index,"vp9")
        ;the rest
        Else
          ExtractTracks .= BuildTrack(Index,TrackListing[A_Index][2])
        }
      }
    }

  If (ExtractToMKA)
    {
    BuildTrackMKA(VideoT,VideoT_Index," --no-video"," --video-tracks ")
    BuildTrackMKA(AudioT,AudioT_Index," --no-audio"," --audio-tracks ")
    BuildTrackMKA(SubtitlesT,SubtitlesT_Index," --no-subtitles"," --subtitle-tracks ")
    ExtractTracks := ExtractTracks " """ OutputDir "\" OutputName "." OutExt """"
    }

  If (BatchFile)
    Return ExtractTracks
  Else
    Run %ExtractTracks%
  }

BuildTrack(INDEX,EXT)
  {
  If !(OverWriteFiles) && (FileExist(OutputDir "\" OutputName ".Track" INDEX "." EXT))
    Return A_Space INDEX ":""" OutputDir "\" OutputName """.Track" INDEX "-" A_TickCount "." EXT
  Return A_Space INDEX ":""" OutputDir "\" OutputName """.Track" INDEX "." EXT
  }

BuildTrackMKA(NAME,INDEX,SKIPFILE,INCLUDEFILE)
  {
  If !(NAME)
    {
    ExtractTracks := ExtractTracks SKIPFILE
    }
  Else
    {
    INDEX := StrReplace(INDEX,",",,,1)
    ExtractTracks := ExtractTracks INCLUDEFILE INDEX
    }
  }

MakeTrackListing(FILENAME)
  {
  SplitPath FILENAME,TitleName
  Gui Show,,%sProg_Name%: %TitleName%

  JSONFile := StdOutToVar(sProg_Dir Merge_Exe " -J " """" FILENAME """")
  ;parse track listing
  TempList := []
  For key,value in Jxon_Load(JSONFile).tracks
    TempList.Push([value.id,value.type,value.codec,MakeMediaObject(value)])
  Return TempList
  }

MakeMediaObject(VALUE)
  {
  If (VALUE.properties.pixel_dimensions)
    {
    If (VALUE.properties.pixel_dimensions != VALUE.properties.display_dimensions)
      TempObject .= "| Pixel: " VALUE.properties.pixel_dimensions " \ Disp: " VALUE.properties.display_dimensions
    Else
      TempObject .= "| Res: " VALUE.properties.pixel_dimensions
    }
  If (VALUE.properties.audio_sampling_frequency)
    TempObject .= "| Rate: " VALUE.properties.audio_sampling_frequency
  If (VALUE.properties.audio_channels)
    TempObject .= "| Channels: " VALUE.properties.audio_channels
  If (VALUE.properties.language != "" && VALUE.properties.language != "und")
    TempObject .= "| Lang: " VALUE.properties.language
  If (VALUE.properties.track_name)
    TempObject .= "| Name: " VALUE.properties.track_name
  ;remove starting |
  If (InStr(TempObject,"|"))
    {
    FoundLen := StrLen(TempObject)
    TempObject := SubStr(TempObject,3,FoundLen)
    }
  Return TempObject
  }

;from ahk manual
;GUI Example: Display context-senstive help (via ToolTip)
WM_MOUSEMOVE()
  {
  Static CurrControl,PrevControl,_TT
  CurrControl := A_GuiControl
  ;If (CurrControl <> PrevControl && ! InStr(CurrControl," "))
  If (CurrControl <> PrevControl && ! InStr(CurrControl,A_Space))
    {
    ToolTip
    SetTimer DisplayToolTip,1000
    PrevControl := CurrControl
    }
  Return

  DisplayToolTip:
    SetTimer DisplayToolTip,Off
    ToolTip % %CurrControl%_TT
    SetTimer RemoveToolTip,50000
  Return

  RemoveToolTip:
    SetTimer RemoveToolTip,Off
    ToolTip
  Return
  }

;By Leef_me
;https://autohotkey.com/board/topic/80262-check-which-checkboxes-are-unchecked/
ToggleListView(RowNum)
  {
  SendMessage 4140,RowNum - 1,0xF000,SysListView321
  IsChecked := (ErrorLevel >> 12) - 1
  If (!IsChecked)
    LV_Modify(RowNum,"+Check")
  Else
    LV_Modify(RowNum,"-Check")
  }
