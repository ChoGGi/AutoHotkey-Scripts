/*
text := StdOutToVar(MKV_Dir "\mkvinfo.exe -s " """" InFile """")
=
D:\Media\MKVtoolnix\mkvinfo.exe -s "Path to some file"

https://github.com/cocobelgica/AutoHotkey-Util/blob/master/StdOutToVar.ahk

sBreakOnString = stop and kill *sCmd* if we encounter this string
sBreakOnStringAdd = only stop if we also have this string as well
iBreakDelay = add a delay in ms while checking
*/

StdOutToVar(sCmd,sBreakOnString := 0,sBreakOnStringAdd := 0,iBreakDelay := 0)
  {
	DllCall("CreatePipe", "PtrP", hReadPipe, "PtrP", hWritePipe, "Ptr", 0, "UInt", 0)
	DllCall("SetHandleInformation", "Ptr", hWritePipe, "UInt", 1, "UInt", 1)

	VarSetCapacity(PROCESS_INFORMATION, (A_PtrSize == 4 ? 16 : 24), 0)    ; http://goo.gl/dymEhJ
	cbSize := VarSetCapacity(STARTUPINFO, (A_PtrSize == 4 ? 68 : 104), 0) ; http://goo.gl/QiHqq9
	NumPut(cbSize, STARTUPINFO, 0, "UInt")                                ; cbSize
	NumPut(0x100, STARTUPINFO, (A_PtrSize == 4 ? 44 : 60), "UInt")        ; dwFlags
	NumPut(hWritePipe, STARTUPINFO, (A_PtrSize == 4 ? 60 : 88), "Ptr")    ; hStdOutput
	NumPut(hWritePipe, STARTUPINFO, (A_PtrSize == 4 ? 64 : 96), "Ptr")    ; hStdError

	if !DllCall(
	(Join Q C
		"CreateProcess",             ; http://goo.gl/9y0gw
		"Ptr",  0,                   ; lpApplicationName
		"Ptr",  &sCmd,                ; lpCommandLine
		"Ptr",  0,                   ; lpProcessAttributes
		"Ptr",  0,                   ; lpThreadAttributes
		"UInt", true,                ; bInheritHandles
		"UInt", 0x08000000,          ; dwCreationFlags
		"Ptr",  0,                   ; lpEnvironment
		"Ptr",  0,                   ; lpCurrentDirectory
		"Ptr",  &STARTUPINFO,        ; lpStartupInfo
		"Ptr",  &PROCESS_INFORMATION ; lpProcessInformation
	)) {
		DllCall("CloseHandle", "Ptr", hWritePipe)
		DllCall("CloseHandle", "Ptr", hReadPipe)
		return ""
	}

	DllCall("CloseHandle", "Ptr", hWritePipe)
	VarSetCapacity(buffer, 4096, 0)
  If (sBreakOnString)
    {
    ;exit during process execution
    While DllCall("ReadFile", "Ptr", hReadPipe, "Ptr", &buffer, "UInt", 4096, "UIntP", dwRead, "Ptr", 0)
      {
      sOutput .= StrGet(&buffer, dwRead, "CP0")

      If !(sBreakOnStringAdd) && (If InStr(sOutput,sBreakOnString))
        {
        ;got what we want so kill off process
        Process Close,% NumGet(PROCESS_INFORMATION,2 * A_PtrSize,"UInt")
        Break
        }
      Else If InStr(sOutput,sBreakOnString) && InStr(sOutput,sBreakOnStringAdd)
        {
        Process Close,% NumGet(PROCESS_INFORMATION,2 * A_PtrSize,"UInt")
        Break
        }
      ;wait a bit
      Sleep %iDelay%
      }
    }
  Else
    {
    While DllCall("ReadFile", "Ptr", hReadPipe, "Ptr", &buffer, "UInt", 4096, "UIntP", dwRead, "Ptr", 0)
      sOutput .= StrGet(&buffer, dwRead, "CP0")
    }

	DllCall("CloseHandle", "Ptr", NumGet(PROCESS_INFORMATION, 0))         ; hProcess
	DllCall("CloseHandle", "Ptr", NumGet(PROCESS_INFORMATION, A_PtrSize)) ; hThread
	DllCall("CloseHandle", "Ptr", hReadPipe)
	Return sOutput
  }
