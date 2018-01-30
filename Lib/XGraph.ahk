/*
     __    __  __          __ __       __    __                 _       __
    / /_  / /_/ /_____  _ / // /____ _/ /_  / /________________(_)___  / /_ ____  _______
   / __ \/ __/ __/ __ \(_) // // __ '/ __ \/ //_/ ___/ ___/ __/ / __ \/ __// __ \/ __/ _ \
  / / / / /_/ /_/ /_/ / / // // /_/ / / / / ,< (__) /__/ / / / /_/ / /__/ /_/ / / / // /
 /_/ /_/\__/\__/ .___(_) // / \__,_/_/ /_/_/|_/____/\___/_/ /_/ .___/\__(_)____/_/  \__ /
              /_/     /_//_/                                 /_/                   (___/

  Script      :  XGraph v1.1.1.0 : Real time data plotting.
                 http://ahkscript.org/boards/viewtopic.php?t=3492
                 Created: 24-Apr-2014,  Last Modified: 09-May-2014

  Description :  Easy to use, Light weight, fast, efficient GDI based function library for
                 graphically plotting real time data.

  Author      :  SKAN - Suresh Kumar A N (arian.suresh@gmail.com)
  Demos       :  CPU Load Monitor > http://ahkscript.org/boards/viewtopic.php?t=3413

- -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
*/

XGraph(hCtrl, hBM := 0, ColumnW := 3, LTRB := "0,2,0,2", PenColor := 0x808080, PenSize := 1, SV := 0)
  {

  Static WM_SETREDRAW := 0xB, STM_SETIMAGE := 0x172, PS_SOLID := 0, cbSize := 136, SRCCOPY := 0x00CC0020
    , GPTR := 0x40, OBJ_BMP := 0x7, LR_CREATEDIBSECTION := 0x2000, LR_COPYDELETEORG := 0x8

    , hTargetBM := hBM

; Validate control
  WinGetClass, Class,   ahk_id %hCtrl%
  Control, Style, +0x5000010E,, ahk_id %hCtrl%
  ControlGet, Style, Style,,, ahk_id %hCtrl%
  ControlGet, ExStyle, ExStyle,,, ahk_id %hCtrl%
  ControlGetPos,,, CtrlW, CtrlH,, ahk_id %hCtrl%
  If !(Class == "Static" and Style = 0x5000010E and ExStyle = 0 and CtrlW > 0 and CtrlH > 0)
    Return 0, ErrorLevel := -1

; Validate Bitmap

  ;If (DllCall("GetObjectType",sPtr,hBM) <> OBJ_BMP)
  If DllCall("GetObjectType",sPtr,hBM) != %OBJ_BMP%
      hTargetBM := DllCall("CreateBitmap", "Int",2, "Int",2, "UInt",1, "UInt",16, sPtr,0, sPtr)
    , hTargetBM := DllCall("CopyImage", sPtr,hTargetBM, "UInt",0, "Int",CtrlW, "Int",CtrlH
                          , "UInt",LR_CREATEDIBSECTION|LR_COPYDELETEORG, sPtr)
  Else
    hTargetBM := hBM

  VarSetCapacity(BITMAP,32,0)
  DllCall("GetObject", sPtr,hTargetBM, "Int",(A_PtrSize = 8 ? 32 : 24), sPtr,&BITMAP)
  If NumGet(BITMAP,18,"UInt") < 16 ; Checking if BPP < 16
    Return 0, ErrorLevel := -2
  Else
    BitmapW := NumGet(BITMAP,  4, "UInt"),  BitmapH := NumGet(BITMAP, 8, "UInt")
  If (BitmapW != CtrlW || BitmapH != CtrlH)
    Return 0, ErrorLevel := -3

; Validate Margins and Column width
  ;StringSplit, M, LTRB, `, , %A_Space% ; Left,Top,Right,Bottom
  M := StrSplit(LTRB,",",A_Space) ; Left,Top,Right,Bottom

  MarginL := (M[1]+0 < 0 ? 0 : M[1]), MarginT := (M[2]+0 < 0 ? 0 : M[2])
  MarginR := (M[3]+0 < 0 ? 0 : M[3]), MarginB := (M[4]+0 < 0 ? 0 : M[4])
  ColumnW := (ColumnW+0 < 0 ? 3 : ColumnW & 0xff) ; 1 - 255

; Derive Columns, BitBlt dimensions, Movement coords for Lineto() and MoveToEx()
  Columns := (BitmapW - MarginL - MarginR) // ColumnW
  BitBltW := Columns * ColumnW,                BitBltH := BitmapH - MarginT - MarginB
  MX1     := BitBltW - ColumnW,                    MY1 := BitBltH - 1
  MX2     := MX1 + ColumnW - (PenSize < 1) ;     MY2 := < user defined >

; Initialize Memory Bitmap
  hSourceDC := DllCall("CreateCompatibleDC", sPtr,0, sPtr)
  hSourceBM := DllCall("CopyImage", sPtr,hTargetBM, "UInt",0, "Int",ColumnW * 2 + BitBltW
                       , "Int",BitBltH, "UInt",LR_CREATEDIBSECTION, sPtr)
  DllCall("SaveDC", sPtr,hSourceDC)
  DllCall("SelectObject", sPtr,hSourceDC, sPtr,hSourceBM)

  hTempDC := DllCall("CreateCompatibleDC", sPtr,0, sPtr)
  DllCall("SaveDC", sPtr,hTempDC)
  DllCall("SelectObject", sPtr,hTempDC, sPtr,hTargetBM)

  If hTargetBM != %hBM%
    hBrush := DllCall("CreateSolidBrush", UInt,hBM & 0xFFFFFF, sPtr)
  , VarSetCapacity(RECT, 16, 0)
  , NumPut(BitmapW, RECT, 8, "UInt"),  NumPut(BitmapH, RECT,12, "UInt")
  , DllCall("FillRect", sPtr,hTempDC, sPtr,&RECT, sPtr,hBrush)
  , DllCall("DeleteObject", sPtr,hBrush)

  DllCall("BitBlt", sPtr,hSourceDC, "Int",ColumnW * 2, "Int",0, "Int",BitBltW, "Int",BitBltH
                   , sPtr,hTempDC,   "Int",MarginL, "Int",MarginT, "UInt",SRCCOPY)
  DllCall("BitBlt", sPtr,hSourceDC, "Int",0, "Int",0, "Int",BitBltW, "Int",BitBltH
                   , sPtr,hTempDC,   "Int",MarginL, "Int",MarginT, "UInt",SRCCOPY)

; Validate Pen color / Size
  PenColor   := (PenColor + 0 <> "" ? PenColor & 0xffffff : 0x808080) ; Range: 000000 - ffffff
  PenSize    := (PenSize  + 0 <> "" ? PenSize & 0xf : 1)              ; Range: 0 - 15
  hSourcePen := DllCall("CreatePen", "Int",PS_SOLID, "Int",PenSize, "UInt",PenColor, sPtr)
  DllCall("SelectObject", sPtr,hSourceDC, sPtr,hSourcePen)
  DllCall("MoveToEx", sPtr,hSourceDC, "Int",MX1, "Int",MY1, sPtr,0)

  hTargetDC := DllCall("GetDC", sPtr,hCtrl, sPtr)
  DllCall("BitBlt", sPtr,hTargetDC, "Int",0, "Int",0, "Int",BitmapW, "Int",BitmapH
                   , sPtr,hTempDC,   "Int",0, "Int",0, "UInt",SRCCOPY)

  DllCall("RestoreDC", sPtr,hTempDC, "Int",-1)
  DllCall("DeleteDC",  sPtr,hTempDC)

  DllCall("SendMessage", sPtr,hCtrl, "UInt",WM_SETREDRAW, sPtr,False, sPtr,0)
  hOldBM := DllCall("SendMessage", sPtr,hCtrl, "UInt",STM_SETIMAGE, sPtr,0, sPtr,hTargetBM)
  DllCall("SendMessage", sPtr,hCtrl, "UInt",WM_SETREDRAW, sPtr,True,  sPtr,0)
  DllCall("DeleteObject", sPtr,hOldBM)

; Create / Update Graph structure
  DataSz := (SV = 1 ? Columns * 8 : 0)
  pGraph := DllCall("GlobalAlloc", "UInt",GPTR, sPtr,cbSize + DataSz, sUPtr)
  NumPut(DataSz, pGraph + cbSize - 8)
  VarL := "cbSize / hCtrl / hTargetDC / hSourceDC / hSourceBM / hSourcePen / ColumnW / Columns / "
        . "MarginL / MarginT / MarginR / MarginB / MX1 / MX2 / BitBltW / BitBltH"
  Loop, Parse, VarL, /, %A_Space%
    NumPut(%A_LoopField%, pGraph + 0, (A_Index - 1) * 8)

  Return pGraph
  }

; -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

XGraph_Plot(pGraph, MY2 := "", SetVal := "", Draw := 1)
  {
  Static SRCCOPY := 0x00CC0020

  If !pGraph
    Return "", ErrorLevel := -1
  ;IfEqual, pGraph, 0, Return "",    ErrorLevel := -1

  pData  := pGraph + NumGet(pGraph + 0), DataSz := Numget(pData - 8)
  , hSourceDC := NumGet(pGraph + 24), BitBltW := NumGet(pGraph + 112)
  , hTargetDC := NumGet(pGraph + 16), BitBltH := NumGet(pGraph + 120)
  , ColumnW := NumGet(pGraph + 48)
  , MarginL := NumGet(pGraph + 64), MX1 := NumGet(pGraph + 096)
  , MarginT := NumGet(pGraph + 72), MX2 := NumGet(pGraph + 104)
  ;msgbox % BitBltW + ColumnW
  ;BitBltH := 90
  If MY2
  ;If MY2 != ""
    DllCall("BitBlt", sPtr,hSourceDC, "Int",0, "Int",0
          , "Int",BitBltW + ColumnW, "Int",BitBltH , sPtr,hSourceDC
          , "Int",ColumnW, "Int",0, "UInt",SRCCOPY)
/*
BOOL BitBlt(
  _In_ HDC   hdcDest, hSourceDC
  _In_ int   nXDest, 0
  _In_ int   nYDest, 0
  _In_ int   nWidth, BitBltW + ColumnW
  _In_ int   nHeight, BitBltH
  _In_ HDC   hdcSrc, hSourceDC
  _In_ int   nXSrc, ColumnW
  _In_ int   nYSrc, 0
  _In_ DWORD dwRop 0x00CC0020

; BLACKNESS				= 0x00000042
; CAPTUREBLT			= 0x40000000
; DSTINVERT				= 0x00550009
; MERGECOPY				= 0x00C000CA (...)
; MERGEPAINT			= 0x00BB0226 (...)
; NOMIRRORBITMAP	= 0x80000000
; NOTSRCCOPY			= 0x00330008
; NOTSRCERASE			= 0x001100A6
; PATCOPY				  = 0x00F00021 (whitenessss)
; PATINVERT				= 0x005A0049
; PATPAINT				= 0x00FB0A09
; SRCAND				  = 0x008800C6 (blacknesss)
; SRCCOPY				  = 0x00CC0020 (default)
; SRCERASE				= 0x00440328 (kinda works)
; SRCINVERT				= 0x00660046
; SRCPAINT				= 0x00EE0086 (builds up and stays up)
; WHITENESS				= 0x00FF0062
);
hdcDest [in]
A handle to the destination device context.

nXDest [in]
The x-coordinate, in logical units, of the upper-left corner of the destination rectangle.

nYDest [in]
The y-coordinate, in logical units, of the upper-left corner of the destination rectangle.

nWidth [in]
The width, in logical units, of the source and destination rectangles.

nHeight [in]
The height, in logical units, of the source and the destination rectangles.

hdcSrc [in]
A handle to the source device context.

nXSrc [in]
The x-coordinate, in logical units, of the upper-left corner of the source rectangle.

nYSrc [in]
The y-coordinate, in logical units, of the upper-left corner of the source rectangle.

dwRop [in]
A raster-operation code. These codes define how the color data for the source rectangle is to be combined with the color data for the destination rectangle to achieve the final color.
*/
    ,DllCall("LineTo",   sPtr,hSourceDC, "Int",MX2, "Int",MY2)
    ,DllCall("MoveToEx", sPtr,hSourceDC, "Int",MX1, "Int",MY2, sPtr,0)

  If Draw = 1
     DllCall("BitBlt", sPtr,hTargetDC, "Int",MarginL, "Int",MarginT, "Int",BitBltW, "Int",BitBltH
            ,sPtr,hSourceDC, "Int",0, "Int",0, "UInt",SRCCOPY)

  If !(MY2 = "" || SetVal = "" || DataSz = 0)
  ;If not (MY2 = "" or SetVal = "" or DataSz = 0)
     DllCall("RtlMoveMemory", sPtr,pData, sPtr,pData + 8, sPtr,DataSz - 8)
    ,NumPut(SetVal, pData + DataSz - 8, 0, "Double")

  Return 1
  }

; -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

XGraph_Info(pGraph, FormatFloat := "") {
Static STM_GETIMAGE := 0x173

  If !pGraph
    Return "", ErrorLevel := -1
  ;IfEqual, pGraph, 0, Return "",    ErrorLevel := -1

  T := "`t",  TT := "`t:`t",  LF := "`n", SP := "                "

  pData := pGraph + NumGet(pGraph + 0), DataSz := Numget(pData-8)
  If (FormatFloat != "" && DataSz)
    GoTo, XGraph_Info_Data

  VarL := "cbSize / hCtrl / hTargetDC / hSourceDC / hSourceBM / hSourcePen / ColumnW / Columns / "
        . "MarginL / MarginT / MarginR / MarginB / MX1 / MX2 / BitBltW / BitBltH"
  Loop, Parse, VarL, /, %A_Space%
    Offset := (A_Index - 1) * 8,         %A_LoopField% := NumGet(pGraph + 0, OffSet)
  , RAW    .= SubStr(Offset SP,1,3) T SubStr(A_LoopField SP,1,16) T %A_LoopField% LF

  hTargetBM := DllCall("SendMessage", sPtr,hCtrl, "UInt",STM_GETIMAGE, sPtr,0, sPtr,0)
  VarSetCapacity(BITMAP,32,0)
  DllCall("GetObject", sPtr,hTargetBM, "Int",(A_PtrSize = 8 ? 32 : 24), sPtr,&BITMAP)
  TBMW := NumGet(BITMAP,  4, "UInt"),            TBMH := NumGet(BITMAP, 8, "UInt")
  TBMB := NumGet(BITMAP, 12, "UInt") * TBMH,     TBMZ := Round(TBMB/1024,2)
  TBPP := NumGet(BITMAP, 18, "UShort")
  Adj := (Adj := TBMW - MarginL - BitBltW - MarginR) ? " (-" Adj ")" : ""

  DllCall("GetObject", sPtr,hSourceBM, "Int",(A_PtrSize = 8 ? 32 : 24), sPtr,&BITMAP)
  SBMW := NumGet(BITMAP,  4, "UInt"),            SBMH := NumGet(BITMAP, 8, "UInt")
  SBMB := NumGet(BITMAP, 12, "UInt") * SBMH,     SBMZ := Round(SBMB/1024,2)
  SBPP := NumGet(BITMAP, 18, "UShort")

Return "GRAPH Properties" LF LF
 . "Screen BG Bitmap   " TT TBMW (Adj) "x" TBMH " " TBPP "bpp (" TBMZ " KB)" LF
 . "Margins (L,T,R,B)" TT MarginL "," MarginT "," MarginR "," MarginB LF
 . "Client Area        " TT MarginL "," MarginT "," MarginL+BitBltW-1 "," MarginT+BitBltH-1 LF LF
 . "Memory Bitmap      " TT SBMW         "x" SBMH " " SBPP "bpp (" SBMZ " KB)" LF
 . "Graph Width        " TT BitBltW " px (" Columns " cols x " ColumnW " px)" LF
 . "Graph Height (MY2) " TT BitBltH " px (y0 to y" BitBltH - 1 ")" LF
 . "Graph Array        " TT (DataSz=0 ? "NA" : Columns " cols x 8 bytes = " DataSz " bytes") LF LF
 . "Pen start position " TT MX1 "," BitBltH - 1 LF
 . "LineTo position    " TT MX2 "," "MY2" LF
 . "MoveTo position    " TT MX1 "," "MY2" LF LF
 . "STRUCTURE (Offset / Variable / Raw value)" LF LF RAW

XGraph_Info_Data:

  AFF := A_FormatFloat
  SetFormat, FloatFast, %FormatFloat%
  Loop % DataSz // 8
    Values .= SubStr(A_Index "   ", 1, 4) T NumGet(pData - 8, A_Index * 8, "Double") LF
  SetFormat, FloatFast, %AFF%
  Values := SubStr(Values,1,-1)
  ;StringTrimRight, Values, Values, 1

Return Values
}

; -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

XGraph_SetVal(pGraph, Double := 0, Column := "") {

  If !pGraph
    Return "", ErrorLevel := -1
  ;IfEqual, pGraph, 0, Return "",    ErrorLevel := -1
  pData := pGraph + NumGet(pGraph + 0), DataSz := Numget(pData - 8)
  If !DataSz
    Return 0
  ;IfEqual, DataSz, 0, Return 0

  If Column =
  ;If (Column = "")
       DllCall("RtlMoveMemory", sPtr,pData, sPtr,pData + 8, sPtr,DataSz - 8)
     , pNumPut := pData + DataSz
  Else
    Columns := NumGet(pGraph + 56)
     , pNumPut := pData + (Column < 0 or Column > Columns ? Columns * 8 : Column * 8)

Return NumPut(Double, pNumPut - 8, 0, "Double") - 8
}

; -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

XGraph_GetVal(pGraph, Column := "") {
Static RECT
  If !VarSetCapacity(RECT)
    VarSetCapacity(RECT,16,0)

  If !pGraph
    Return "", ErrorLevel := -1
  ;IfEqual, pGraph, 0, Return "",    ErrorLevel := -1

  pData   := pGraph + NumGet(pGraph + 0),   DataSz  := Numget(pData - 8)
  Columns := NumGet(pGraph + 56)
  If !(Column = "" || DataSz = 0 || Column < 1 || Column > Columns)
    Return NumGet(pData - 8, Column * 8, "Double"),    ErrorLevel := Column

  hCtrl   := NumGet(pGraph + 8),          ColumnW := NumGet(pGraph + 48)
, BitBltW := NumGet(pGraph + 112),          MarginL := NumGet(pGraph + 64)
, BitBltH := NumGet(pGraph + 120),          MarginT := NumGet(pGraph + 72)

, Numput(MarginL, RECT, 0, "Int"),          Numput(MarginT, RECT, 4, "Int")
, DllCall("ClientToScreen", sPtr,hCtrl, sPtr,&RECT)
, DllCall("GetCursorPos", sPtr,&RECT + 8)

, MX := NumGet(RECT, 8, "Int") - NumGet(RECT, 0, "Int")
, MY := NumGet(RECT,12, "Int") - NumGet(RECT, 4, "Int")

, Column := (MX >= 0 and MY >= 0 and MX < BitBltW and MY < BitBltH) ? MX // ColumnW + 1 : 0
Return (DataSz and Column) ? NumGet(pData - 8, Column * 8, "Double") : "",    ErrorLevel := Column
}

; -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

XGraph_GetMean(pGraph, TailCols := "") {

  If !pGraph
    Return "", ErrorLevel := -1
  ;IfEqual, pGraph, 0, Return "",    ErrorLevel := -1

  pData := pGraph + NumGet(pGraph + 0), DataSz := Numget(pData - 8)
  If !DataSz
    Return "",    ErrorLevel := 0
  ;IfEqual, DataSz, 0, Return 0,     ErrorLevel := 0

  Columns := NumGet(pGraph + 56)
  pDataEnd := pGraph + NumGet(pGraph + 0) + (Columns * 8)
  TailCols := (TailCols = "" or TailCols < 1 or Tailcols > Columns) ? Columns : TailCols

  Loop %TailCols%
    Value += NumGet(pDataEnd - (A_Index * 8), 0, "Double")

Return Value / TailCols,            ErrorLevel := TailCols
}

; -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

XGraph_Detach(pGraph)
  {
  Static VarL := "cbSize / hCtrl / hTargetDC / hSourceDC / hSourceBM / hSourcePen"

  If !pGraph
    Return 0
  ;IfEqual, pGraph, 0, Return 0

  Loop Parse,VarL,/,%A_Space%
    %A_LoopField% := NumGet(pGraph + 0, (A_Index - 1) * 8)

  DllCall("ReleaseDC",    sPtr,hCtrl, sPtr,hTargetDC)
  DllCall("RestoreDC",    sPtr,hSourceDC, "Int",-1)
  DllCall("DeleteDC",     sPtr,hSourceDC)
  DllCall("DeleteObject", sPtr,hSourceBM)
  DllCall("DeleteObject", sPtr,hSourcePen)

  Return DllCall("GlobalFree", sPtr,pGraph, sPtr)
  }

; -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -

XGraph_MakeGrid(CellW, CellH, Cols, Rows, GLClr, BGClr, ByRef BMPW := "", ByRef BMPH := "") {
Static LR_Flag1 := 0x2008 ; LR_CREATEDIBSECTION := 0x2000 | LR_COPYDELETEORG := 8
    ,  LR_Flag2 := 0x200C ; LR_CREATEDIBSECTION := 0x2000 | LR_COPYDELETEORG := 8 | LR_COPYRETURNORG := 4
    ,  DC_PEN := 19

  BMPW := CellW * Cols + 1,  BMPH := CellH * Rows + 1
  hTempDC := DllCall("CreateCompatibleDC", sPtr,0, sPtr)
  DllCall("SaveDC", sPtr,hTempDC)

  If DllCall("GetObjectType", sPtr,BGClr) = 0x7
  ;If (DllCall("GetObjectType", sPtr,BGClr) = 0x7)
    hTBM := DllCall("CopyImage", sPtr,BGClr, "Int",0, "Int",BMPW, "Int",BMPH, "UInt",LR_Flag2, sUPtr)
  , DllCall("SelectObject", sPtr,hTempDC, sPtr,hTBM)

  Else
    hTBM := DllCall("CreateBitmap", "Int",2, "Int",2, "UInt",1, "UInt",24, sPtr,0, sPtr)
  , hTBM := DllCall("CopyImage", sPtr,hTBM,  "Int",0, "Int",BMPW, "Int",BMPH, "UInt",LR_Flag1, sUPtr)
  , DllCall("SelectObject", sPtr,hTempDC, sPtr,hTBM)
  , hBrush := DllCall("CreateSolidBrush", "UInt",BGClr & 0xFFFFFF, sPtr)
  , VarSetCapacity(RECT, 16)
  , NumPut(BMPW, RECT, 8, "UInt"),  NumPut(BMPH, RECT, 12, "UInt")
  , DllCall("FillRect", sPtr,hTempDC, sPtr,&RECT, sPtr,hBrush)
  , DllCall("DeleteObject", sPtr,hBrush)

  hPenDC := DllCall("GetStockObject", "Int",DC_PEN, sPtr)
  DllCall("SelectObject",  sPtr,hTempDC, sPtr,hPenDC)
  DllCall("SetDCPenColor", sPtr,hTempDC, "UInt",GLClr & 0xFFFFFF)

  Loop, % Rows + 1 + (X := Y := 0)
    DllCall("MoveToEx", sPtr,hTempDC, "Int",X,    "Int",Y, sPtr,0)
  , DllCall("LineTo",   sPtr,hTempDC, "Int",BMPW, "Int",Y),  Y := Y + CellH

  Loop, % Cols + 1 + (X := Y := 0)
    DllCall("MoveToEx", sPtr,hTempDC, "Int",X, "Int",Y, sPtr,0)
  , DllCall("LineTo",   sPtr,hTempDC, "Int",X, "Int",BMPH),  X := X + CellW

  DllCall("RestoreDC", sPtr,hTempDC, "Int",-1)
  DllCall("DeleteDC",  sPtr,hTempDC)

Return hTBM
}

; -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -