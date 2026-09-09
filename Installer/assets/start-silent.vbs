' Silent launcher - runs start-all.bat with no visible window
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run Chr(34) & Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\")) & "start-all.bat" & Chr(34), 0, False
