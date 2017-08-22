Global Prog_Ini,Prog_Dir
SplitPath A_ScriptFullPath,,,,Prog_Name
Prog_Ini := A_ScriptDir "\" Prog_Name ".ini"
IniRead Prog_Dir,%Prog_Ini%,Settings,Prog_Dir
If (!FileExist(Prog_Dir Prog_Exe))
  {
  If (FileExist(A_ScriptDir Prog_Exe))
    SetInstallPath(A_ScriptDir)
  Else If (FileExist(A_WorkingDir Prog_Exe))
    SetInstallPath(A_WorkingDir)
  Else If (FileExist(ProgramFiles "\" Prog_Name Prog_Exe))
    SetInstallPath(ProgramFiles "\" Prog_Name)
  Else
    {
    Loop
      {
      FileSelectFolder Prog_Dir,*%A_ScriptDir%,3,Please select %Prog_Name% directory (Eg: %ProgramFiles%\%Prog_Name%)
      If (ErrorLevel = 1)
        ExitApp
      If (FileExist(Prog_Dir Prog_Exe))
        {
        SetInstallPath(Prog_Dir)
        Break
        }
      }
    }
  }
SetInstallPath(PATH)
  {
  IniWrite %PATH%,%Prog_Ini%,Settings,Prog_Dir
  Prog_Dir := PATH
  }
