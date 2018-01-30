/*
text := StdOutToVar(MKV_Dir "\mkvinfo.exe -s " """" InFile """")
=
D:\Media\MKVtoolnix\mkvinfo.exe -s "Path to some file"

https://github.com/cocobelgica/AutoHotkey-Util/blob/master/StdOutToVar.ahk

sBreakOnString = stop and kill *sCmd* if we encounter this string
sBreakOnStringAdd = only stop if we also have this string as well
iBreakDelay = add a delay in ms while checking
*/

Global sPtr := (A_PtrSize ? "Ptr" : "UInt")
StdOutToVar(sCmd,sBreakOnString := 0,sBreakOnStringAdd := 0,iBreakDelay := 0)
  {
	DllCall("CreatePipe", "PtrP", hReadPipe, "PtrP", hWritePipe, sPtr, 0, "UInt", 0)
	DllCall("SetHandleInformation", sPtr, hWritePipe, "UInt", 1, "UInt", 1)

	VarSetCapacity(PROCESS_INFORMATION, (A_PtrSize == 4 ? 16 : 24), 0)    ; http://goo.gl/dymEhJ
	cbSize := VarSetCapacity(STARTUPINFO, (A_PtrSize == 4 ? 68 : 104), 0) ; http://goo.gl/QiHqq9
	NumPut(cbSize, STARTUPINFO, 0, "UInt")                                ; cbSize
	NumPut(0x100, STARTUPINFO, (A_PtrSize == 4 ? 44 : 60), "UInt")        ; dwFlags
	NumPut(hWritePipe, STARTUPINFO, (A_PtrSize == 4 ? 60 : 88), sPtr)    ; hStdOutput
	NumPut(hWritePipe, STARTUPINFO, (A_PtrSize == 4 ? 64 : 96), sPtr)    ; hStdError

	if !DllCall(
	(Join Q C
		"CreateProcess",             ; http://goo.gl/9y0gw
		sPtr,  0,                   ; lpApplicationName
		sPtr,  &sCmd,                ; lpCommandLine
		sPtr,  0,                   ; lpProcessAttributes
		sPtr,  0,                   ; lpThreadAttributes
		"UInt", true,                ; bInheritHandles
		"UInt", 0x08000000,          ; dwCreationFlags
		sPtr,  0,                   ; lpEnvironment
		sPtr,  0,                   ; lpCurrentDirectory
		sPtr,  &STARTUPINFO,        ; lpStartupInfo
		sPtr,  &PROCESS_INFORMATION ; lpProcessInformation
	)) {
		DllCall("CloseHandle", sPtr, hWritePipe)
		DllCall("CloseHandle", sPtr, hReadPipe)
		return ""
	}

	DllCall("CloseHandle", sPtr, hWritePipe)
	VarSetCapacity(buffer, 4096, 0)
  If sBreakOnString
    {
    ;exit during process execution
    While DllCall("ReadFile", sPtr, hReadPipe, sPtr, &buffer, "UInt", 4096, "UIntP", dwRead, sPtr, 0)
      {
      sOutput .= StrGet(&buffer, dwRead, "CP0")

      If (!sBreakOnStringAdd && If InStr(sOutput,sBreakOnString))
        {
        ;got what we want so kill off process
        Process Close,% NumGet(PROCESS_INFORMATION,2 * A_PtrSize,"UInt")
        Break
        }
      Else If (InStr(sOutput,sBreakOnString) && InStr(sOutput,sBreakOnStringAdd))
        {
        Process Close,% NumGet(PROCESS_INFORMATION,2 * A_PtrSize,"UInt")
        Break
        }
      ;wait a bit
      Sleep %iBreakDelay%
      }
    }
  Else
    {
    While DllCall("ReadFile", sPtr, hReadPipe, sPtr, &buffer, "UInt", 4096, "UIntP", dwRead, sPtr, 0)
      sOutput .= StrGet(&buffer, dwRead, "CP0")
    }

	DllCall("CloseHandle", sPtr, NumGet(PROCESS_INFORMATION, 0))         ; hProcess
	DllCall("CloseHandle", sPtr, NumGet(PROCESS_INFORMATION, A_PtrSize)) ; hThread
	DllCall("CloseHandle", sPtr, hReadPipe)
	Return sOutput
  }
