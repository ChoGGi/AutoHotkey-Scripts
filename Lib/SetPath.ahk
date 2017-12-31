Global sProg_Ini,sProg_Dir

SplitPath A_ScriptFullPath,,,,sProg_Name
sProg_Ini := A_ScriptDir "\" sProg_Name ".ini"
IniRead sProg_Dir,%sProg_Ini%,Settings,Prog_Dir

If !FileExist(sProg_Dir sProg_Exe)
  {
  If FileExist(A_ScriptDir sProg_Exe)
    {
    sProg_Ini := A_ScriptDir "\" sProg_Name ".ini"
    fSetInstallPath(A_ScriptDir)
    }
  Else If FileExist(A_WorkingDir sProg_Exe)
    {
    sProg_Ini := A_WorkingDir "\" sProg_Name ".ini"
    fSetInstallPath(A_WorkingDir)
    }
  Else If FileExist(A_ProgramFiles "\" sProg_Name sProg_Exe)
    {
    sProg_Ini := A_ProgramFiles "\" sProg_Name "\" sProg_Name ".ini"
    fSetInstallPath(A_ProgramFiles "\" sProg_Name)
    }
  Else
    {
    Loop
      {
      FileSelectFolder sProg_Dir,*%A_ScriptDir%,3,Please select %sProg_Name% directory`n(Eg: %A_ProgramFiles%\%sProg_Name%)
      If ErrorLevel
        ExitApp
      If FileExist(sProg_Dir sProg_Exe)
        {
        sProg_Ini := sProg_Dir "\" sProg_Name ".ini"
        fSetInstallPath(sProg_Dir)
        Break
        }
      }
    }
  }

fSetInstallPath(sPath)
  {
  IniWrite %sPath%,%sProg_Ini%,Settings,Prog_Dir
  sProg_Dir := sPath
  }
