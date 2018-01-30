Global sProgIni,sProgDir

SplitPath A_ScriptFullPath,,,,sProgName
sProgIni := A_ScriptDir "\" sProgName ".ini"
IniRead sProgDir,%sProgIni%,Settings,Prog_Dir

If !FileExist(sProgDir sProgExe)
  {
  If FileExist(A_ScriptDir sProgExe)
    {
    sProgIni := A_ScriptDir "\" sProgName ".ini"
    fSetInstallPath(A_ScriptDir)
    }
  Else If FileExist(A_WorkingDir sProgExe)
    {
    sProgIni := A_WorkingDir "\" sProgName ".ini"
    fSetInstallPath(A_WorkingDir)
    }
  Else If FileExist(A_ProgramFiles "\" sProgName sProgExe)
    {
    sProgIni := A_ProgramFiles "\" sProgName "\" sProgName ".ini"
    fSetInstallPath(A_ProgramFiles "\" sProgName)
    }
  Else
    {
    Loop
      {
      FileSelectFolder sProgDir,*%A_ScriptDir%,3,Please select %sProgName% directory`n(Eg: %A_ProgramFiles%\%sProgName%)
      If ErrorLevel
        ExitApp
      If FileExist(sProgDir sProgExe)
        {
        sProgIni := sProgDir "\" sProgName ".ini"
        fSetInstallPath(sProgDir)
        Break
        }
      }
    }
  }

fSetInstallPath(sPath)
  {
  IniWrite %sPath%,%sProgIni%,Settings,Prog_Dir
  sProgDir := sPath
  }
