;JXON.ahk,StdOutToVar.ahk

;https://github.com/cocobelgica/AutoHotkey-Util/blob/master/StdOutToVar.ahk (3541fbe on 25 Aug 2014)
StdOutToVar(sCmd,sBreakOnString := 0,sBreakOnStringAdd := 0,iBreakDelay := 0)
  {
  Static sPtr := (A_PtrSize ? "Ptr" : "UInt")
        ,sPtrP := (A_PtrSize ? "Ptr*" : "Int*")
        ,iPtrSize16 := (A_PtrSize == 4 ? 16 : 24)
        ,iPtrSize68 := (A_PtrSize == 4 ? 68 : 104)
        ,iPtrSize44 := (A_PtrSize == 4 ? 44 : 60)
        ,iPtrSize60 := (A_PtrSize == 4 ? 60 : 88)
        ,iPtrSize64 := (A_PtrSize == 4 ? 64 : 96)
	DllCall("CreatePipe", sPtrP, hReadPipe, sPtrP, hWritePipe, sPtr, 0, "UInt", 0)
	DllCall("SetHandleInformation", sPtr, hWritePipe, "UInt", 1, "UInt", 1)

	VarSetCapacity(PROCESS_INFORMATION, iPtrSize16, 0)    ; http://goo.gl/dymEhJ
	cbSize := VarSetCapacity(STARTUPINFO, iPtrSize68, 0) ; http://goo.gl/QiHqq9
	NumPut(cbSize, STARTUPINFO, 0, "UInt")                                ; cbSize
	NumPut(0x100, STARTUPINFO, iPtrSize44, "UInt")        ; dwFlags
	NumPut(hWritePipe, STARTUPINFO, iPtrSize60, sPtr)    ; hStdOutput
	NumPut(hWritePipe, STARTUPINFO, iPtrSize64, sPtr)    ; hStdError

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

;https://github.com/cocobelgica/AutoHotkey-JSON/blob/master/Jxon.ahk (1560aaa on 6 Apr 2016)
Jxon_Load(ByRef src, args*)
{
	static q := Chr(34)

	key := "", is_key := false
	stack := [ tree := [] ]
	is_arr := { (tree): 1 }
	next := q . "{[01234567890-tfn"
	pos := 0
	while ( (ch := SubStr(src, ++pos, 1)) != "" )
	{
		if InStr(" `t`n`r", ch)
			continue
		if !InStr(next, ch, true)
		{
			ln := ObjLength(StrSplit(SubStr(src, 1, pos), "`n"))
			col := pos - InStr(src, "`n",, -(StrLen(src)-pos+1))

			msg := Format("{}: line {} col {} (char {})"
			,   (next == "")      ? ["Extra data", ch := SubStr(src, pos)][1]
			  : (next == "'")     ? "Unterminated string starting at"
			  : (next == "\")     ? "Invalid \escape"
			  : (next == ":")     ? "Expecting ':' delimiter"
			  : (next == q)       ? "Expecting object key enclosed in double quotes"
			  : (next == q . "}") ? "Expecting object key enclosed in double quotes or object closing '}'"
			  : (next == ",}")    ? "Expecting ',' delimiter or object closing '}'"
			  : (next == ",]")    ? "Expecting ',' delimiter or array closing ']'"
			  : [ "Expecting JSON value(string, number, [true, false, null], object or array)"
			    , ch := SubStr(src, pos, (SubStr(src, pos)~="[\]\},\s]|$")-1) ][1]
			, ln, col, pos)

			throw Exception(msg, -1, ch)
		}

		is_array := is_arr[obj := stack[1]]

		if i := InStr("{[", ch)
		{
			val := (proto := args[i]) ? new proto : {}
			is_array? ObjPush(obj, val) : obj[key] := val
			ObjInsertAt(stack, 1, val)

			is_arr[val] := !(is_key := ch == "{")
			next := q . (is_key ? "}" : "{[]0123456789-tfn")
		}

		else if InStr("}]", ch)
		{
			ObjRemoveAt(stack, 1)
			next := stack[1]==tree ? "" : is_arr[stack[1]] ? ",]" : ",}"
		}

		else if InStr(",:", ch)
		{
			is_key := (!is_array && ch == ",")
			next := is_key ? q : q . "{[0123456789-tfn"
		}

		else ; string | number | true | false | null
		{
			if (ch == q) ; string
			{
				i := pos
				while i := InStr(src, q,, i+1)
				{
					val := StrReplace(SubStr(src, pos+1, i-pos-1), "\\", "\u005C")
					static end := A_AhkVersion<"2" ? 0 : -1
					if (SubStr(val, end) != "\")
						break
				}
				if !i ? (pos--, next := "'") : 0
					continue

				pos := i ; update pos

				  val := StrReplace(val,    "\/",  "/")
				, val := StrReplace(val, "\" . q,    q)
				, val := StrReplace(val,    "\b", "`b")
				, val := StrReplace(val,    "\f", "`f")
				, val := StrReplace(val,    "\n", "`n")
				, val := StrReplace(val,    "\r", "`r")
				, val := StrReplace(val,    "\t", "`t")

				i := 0
				while i := InStr(val, "\",, i+1)
				{
					if (SubStr(val, i+1, 1) != "u") ? (pos -= StrLen(SubStr(val, i)), next := "\") : 0
						continue 2

					; \uXXXX - JSON unicode escape sequence
					xxxx := Abs("0x" . SubStr(val, i+2, 4))
					if (A_IsUnicode || xxxx < 0x100)
						val := SubStr(val, 1, i-1) . Chr(xxxx) . SubStr(val, i+6)
				}

				if is_key
				{
					key := val, next := ":"
					continue
				}
			}

			else ; number | true | false | null
			{
				val := SubStr(src, pos, i := RegExMatch(src, "[\]\},\s]|$",, pos)-pos)

			; For numerical values, numerify integers and keep floats as is.
			; I'm not yet sure if I should numerify floats in v2.0-a ...
				static number := "number", integer := "integer"
				if val is %number%
				{
					if val is %integer%
						val += 0
				}
			; in v1.1, true,false,A_PtrSize,A_IsUnicode,A_Index,A_EventInfo,
			; SOMETIMES return strings due to certain optimizations. Since it
			; is just 'SOMETIMES', numerify to be consistent w/ v2.0-a
				else if (val == "true" || val == "false")
					val := %value% + 0
			; AHK_H has built-in null, can't do 'val := %value%' where value == "null"
			; as it would raise an exception in AHK_H(overriding built-in var)
				else if (val == "null")
					val := ""
			; any other values are invalid, continue to trigger error
				else if (pos--, next := "#")
					continue

				pos += i-1
			}

			is_array? ObjPush(obj, val) : obj[key] := val
			next := obj==tree ? "" : is_array ? ",]" : ",}"
		}
	}

	return tree[1]
}
