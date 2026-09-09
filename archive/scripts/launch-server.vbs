Dim WshShell
Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "c:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software\Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release"
WshShell.Run """c:\Users\eliran_ha\OneDrive - MBA\Documents\Eliran\MBA\Calibration-software\Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\Maba.VCT.CommServer.Hosts.ConsoleHost.exe""", 1, False
