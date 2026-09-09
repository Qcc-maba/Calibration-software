#define AppName "Calibration Software"
#define AppVersion "1.6.9"
#define AppPublisher "MBA"
#define AppURL "http://localhost:3000"
#define ServiceName "MabaCalibrationServer"
#define ServiceDisplayName "Maba Calibration Server"

; Where the built web app comes from. Defaults assume a `BUILD_STANDALONE=true next build` inside
; ..\app. The app cannot actually be built there today (Next's resolver fails on the pnpm symlinks
; under OneDrive, and `next build` needs symlink rights the standalone copy step does not have), so
; it is built in a plain local folder and pointed at here. Also note the layout differs: a build
; whose tracing root is the repo nests the server under standalone\app, a standalone project root
; puts it directly in standalone\.
;
;   ISCC.exe setup.iss ^
;     /DWebAppStandalone="C:\tmp\maba-app\.next\standalone" ^
;     /DWebAppStatic="C:\tmp\maba-app\.next\static" ^
;     /DWebAppPublic="C:\tmp\maba-app\public"
#ifndef WebAppStandalone
  #define WebAppStandalone "..\app\.next\standalone\app"
#endif
#ifndef WebAppStatic
  #define WebAppStatic "..\app\.next\static"
#endif
#ifndef WebAppPublic
  #define WebAppPublic "..\app\public"
#endif

[Setup]
AppId={{8F3A2C1D-4B5E-4F6A-9D2E-1C3B5A7F8E9D}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
AllowNoIcons=yes
OutputDir=.
OutputBaseFilename=CalibrationSoftware-Setup-v{#AppVersion}
SetupIconFile=
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
; Restart Manager cannot stop our Windows Service; it caused "cannot close applications" and DLL lock (error 5).
; We stop the service and processes explicitly in NextButtonClick(wpReady) + PrepareToInstall.
CloseApplications=no
RestartApplications=no
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\CalibrationLauncher.exe

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "webapp";       Description: "Web Application (Next.js)";   Types: full custom; Flags: fixed
Name: "consolehost";  Description: "VCT Console Host (.NET)";      Types: full custom; Flags: fixed

[Dirs]
Name: "{app}\webapp";
Name: "{app}\webapp\.next\static";
Name: "{app}\consolehost";
Name: "{app}\consolehost\Settings";
Name: "{app}\assets";
Name: "{app}\logs";

[InstallDelete]
; Clean old webapp files to prevent stale content on upgrade
Type: filesandordirs; Name: "{app}\webapp\.next"
Type: filesandordirs; Name: "{app}\webapp\node_modules"
Type: files; Name: "{app}\webapp\server.js"
Type: filesandordirs; Name: "{app}\webapp\public"

; The ComServer binaries, so a DLL that a newer build no longer ships cannot stay behind and be
; loaded by name. Only the loose files at this level are removed - Settings\ is a subfolder and is
; left alone on purpose, because a station's tuned VCT.json / ComServerSettings.json live there and
; are shipped onlyifdoesntexist.
Type: files; Name: "{app}\consolehost\*.dll"
Type: files; Name: "{app}\consolehost\*.exe"
Type: files; Name: "{app}\consolehost\*.config"
Type: files; Name: "{app}\consolehost\*.xml"
Type: files; Name: "{app}\consolehost\*.pdb"

; Launcher scripts: an .bat or .ps1 dropped by an older build and since renamed would otherwise sit
; in assets\ forever, and the wrong one is easy to run by hand.
Type: files; Name: "{app}\assets\*.ps1"
Type: files; Name: "{app}\assets\*.bat"
Type: files; Name: "{app}\assets\*.vbs"

; Wipe previous run logs (upgrade / reinstall over same folder)
Type: filesandordirs; Name: "{app}\logs"
Type: files; Name: "{app}\install.log"
Type: files; Name: "{app}\uninstall.log"
Type: files; Name: "{app}\consolehost\*.log"

[UninstallDelete]
; Runtime logs are not registered as installed files ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â must delete explicitly on uninstall
Type: filesandordirs; Name: "{app}\logs"
Type: files; Name: "{app}\install.log"
Type: files; Name: "{app}\uninstall.log"
Type: files; Name: "{app}\consolehost\*.log"

[Files]
; --- Web App (Next.js standalone) ---
Source: "{#WebAppStandalone}\*";            DestDir: "{app}\webapp";           Components: webapp; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#WebAppStatic}\*";                DestDir: "{app}\webapp\.next\static"; Components: webapp; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "{#WebAppPublic}\*";                DestDir: "{app}\webapp\public";    Components: webapp; Flags: recursesubdirs createallsubdirs ignoreversion

; --- Console Host ---
; Settings\ is excluded here and shipped explicitly below: this recursive copy is ignoreversion,
; which would overwrite a station's tuned VCT.json / ComServerSettings.json on every upgrade.
; *.bak is excluded because a config backup left next to the exe (e.g. .exe.config.aws.bak from
; a database switch) carries the previous connection string, password included.
Source: "..\Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\*"; DestDir: "{app}\consolehost"; Components: consolehost; Excludes: "*.log,*.pdb,*.bak,Settings\*"; Flags: recursesubdirs createallsubdirs ignoreversion

; --- Console Host baseline settings ---
; Without these the host starts but does nothing useful: ComServerSettings.CreateDefaultSettings()
; leaves Modules empty, so neither Hydra2BLCore nor Datron9100BLCore is loaded, and
; VCTSettings.CreateDefaultSettings() has no Datron9100-GPIB tunnel. A fresh install therefore
; had no logger and no GPIB master until someone hand-wrote the JSON.
;
; onlyifdoesntexist: the live files belong to the station once it has been configured. The
; .default.json copies are rewritten by the app itself on every Read(), so they are not shipped.
Source: "assets\Settings\VCT.json";                DestDir: "{app}\consolehost\Settings"; Components: consolehost; Flags: onlyifdoesntexist uninsneveruninstall
Source: "assets\Settings\ComServerSettings.json";  DestDir: "{app}\consolehost\Settings"; Components: consolehost; Flags: onlyifdoesntexist uninsneveruninstall
Source: "assets\Settings\HydraBL_Settings.json";   DestDir: "{app}\consolehost\Settings"; Components: consolehost; Flags: onlyifdoesntexist uninsneveruninstall

; --- Desktop / Start-menu launcher (runs start-all.bat hidden: service + WS + webapp) ---
Source: "CalibrationLauncher\bin\Release\CalibrationLauncher.exe"; DestDir: "{app}"; Flags: ignoreversion

; --- Launcher scripts ---
Source: "assets\start-webapp.bat";          DestDir: "{app}\assets";           Flags: ignoreversion
; Resolves REMOTE_DATABASE_URL for the station before launching node - env.js requires it
; and the shipped .env carries only the _PROD / _STAGE variants.
Source: "assets\start-webapp.ps1";          DestDir: "{app}\assets";           Flags: ignoreversion
; Copies this station's logs to \\maba-srv\maba2000\Eliran\<folder>\<COMPUTERNAME> so a problem on
; a customer machine can be investigated without going there. Called by start-webapp.ps1.
Source: "assets\publish-logs.ps1";          DestDir: "{app}\assets";           Flags: ignoreversion

; NI-488.2 is deliberately NOT shipped or installed here - see Installer\DRIVERS.md. Bundling NI's
; online installer added 7 MB and, far worse, several hundred MB of download that turned a 3-minute
; installation into 15. Stations are set up with the driver separately.
Source: "assets\start-consolehost.bat";     DestDir: "{app}\assets";           Flags: ignoreversion
Source: "assets\start-all.bat";             DestDir: "{app}\assets";           Flags: ignoreversion
Source: "assets\start-silent.vbs";          DestDir: "{app}\assets";           Flags: ignoreversion
Source: "..\scripts\Install-Service.ps1";   DestDir: "{app}";                  Flags: ignoreversion
Source: "..\scripts\Uninstall-Service.ps1"; DestDir: "{app}";                  Flags: ignoreversion
Source: "..\scripts\run-project.ps1";       DestDir: "{app}";                  Flags: ignoreversion

; --- Environment config ---
; Generated by scripts\New-StationEnv.ps1: only the settings a station reads. Shipping
; app\.env verbatim put the staging database password, the SQL admin connection string,
; the SMTP password and seven test accounts onto every customer machine.
Source: "assets\.env.station";             DestDir: "{app}\webapp";           DestName: ".env"; Flags: ignoreversion
Source: "..\app\.env.example";              DestDir: "{app}\webapp";           DestName: ".env.example"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}";                 Filename: "{app}\CalibrationLauncher.exe"; WorkingDir: "{app}"
Name: "{group}\Uninstall {#AppName}";       Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}";         Filename: "{app}\CalibrationLauncher.exe"; WorkingDir: "{app}"; Tasks: desktopicon
; start-silent.vbs rather than the launcher exe: it runs start-all.bat with no window at all, which
; is what you want at logon. start-all.bat takes a lock, so a second logon cannot start a second copy.
Name: "{commonstartup}\{#AppName}";         Filename: "{app}\assets\start-silent.vbs"; WorkingDir: "{app}\assets"; Tasks: autostart

[Tasks]
; Ticked by default: the launcher is how a station is started, and the Windows service only brings
; up the ComServer and the WebSocket - the web UI is not running after a reboot until someone runs
; it. Leaving this off meant a default or silent install put no icon anywhere except the Start menu.
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

; A calibration station should be usable straight after a reboot. The Windows service already
; restores the ComServer and the WebSocket on its own; this is what brings back the web UI, which
; otherwise waits for somebody to run the launcher. Offered as a task so a shared or developer
; machine can decline - on those, a hidden node at every logon is not wanted.
Name: "autostart"; Description: "Start the station automatically when Windows starts"; GroupDescription: "Station setup:"


[Run]
; Launch web app (optional, user can close) - all other steps handled by CurStepChanged with logging
Filename: "{app}\CalibrationLauncher.exe"; Description: "Launch {#AppName} now"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Uninstall steps handled by CurUninstallStepChanged with logging

[Code]
var
  InstallLogPath: String;

// ===== Logging =====

procedure WriteLog(const Msg: String);
var
  Lines: TArrayOfString;
  Timestamp: String;
begin
  Timestamp := GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':');
  SetLength(Lines, 1);
  Lines[0] := '[' + Timestamp + '] ' + Msg;

  if InstallLogPath = '' then
    InstallLogPath := ExpandConstant('{app}\install.log');

  if not SaveStringsToFile(InstallLogPath, Lines, True) then
  begin
    // Fallback: write to temp if app dir not ready
    InstallLogPath := ExpandConstant('{tmp}\calibration-install.log');
    SaveStringsToFile(InstallLogPath, Lines, True);
  end;
end;

procedure WriteLogSection(const Title: String);
var
  Lines: TArrayOfString;
begin
  SetLength(Lines, 2);
  Lines[0] := '';
  Lines[1] := '======== ' + Title + ' ========';
  if InstallLogPath <> '' then
    SaveStringsToFile(InstallLogPath, Lines, True);
end;

{ Post-install runs eight external commands, each hidden and each blocking. Without this the wizard
  sits on a full progress bar showing nothing for minutes and looks hung - which is exactly what was
  reported. Inno's own gauge is finished by then, so it is reused as a post-install gauge: reset to
  0..100 once and driven per step. No explicit message pump is needed - and none is available:
  AppProcessMessages does not exist in Inno Pascal Script. Exec runs its own message loop, so a
  caption set just before it is painted as soon as the step starts. }
procedure SetInstallStatus(const Text: String; const Position: Integer);
begin
  WizardForm.StatusLabel.Caption := Text;
  if Position >= 0 then
  begin
    WizardForm.ProgressGauge.Style := npbstNormal;
    WizardForm.ProgressGauge.Position := Position;
  end;
end;

function RunAndLog(const Step, Filename, Params: String): Boolean;
var
  ResultCode: Integer;
  ExecOk: Boolean;
begin
  WriteLog(Step + ' - Executing: ' + Filename + ' ' + Params);

  ExecOk := Exec(Filename, Params, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);

  if not ExecOk then
  begin
    WriteLog(Step + ' - FAILED: Could not execute process');
    Result := False;
  end
  else if ResultCode <> 0 then
  begin
    WriteLog(Step + ' - WARNING: Exit code = ' + IntToStr(ResultCode));
    Result := False;
  end
  else
  begin
    WriteLog(Step + ' - OK (exit code 0)');
    Result := True;
  end;
end;

// ===== Prerequisite Checks =====

function NodeJsInstalled: Boolean;
var
  NodePath: String;
begin
  Result := RegQueryStringValue(HKLM, 'SOFTWARE\Node.js', 'InstallPath', NodePath) or
            RegQueryStringValue(HKLM64, 'SOFTWARE\Node.js', 'InstallPath', NodePath);
  if not Result then
    Result := FileExists(ExpandConstant('{pf}\nodejs\node.exe')) or
              FileExists(ExpandConstant('{pf64}\nodejs\node.exe'));
end;

function DotNetInstalled: Boolean;
var
  Version: String;
  ReleaseVal: Cardinal;
begin
  Result := RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Version', Version) and
            (CompareStr(Version, '4.8') >= 0);
  if not Result then
    if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full', 'Release', ReleaseVal) then
      Result := (ReleaseVal >= 528040);
end;

{ NI-488.2 (GPIB). The driver itself is not bundled - see Installer\DRIVERS.md. Without it the
  GPIB-USB-HS+ adapter is dead (Device Manager code 28) and the Datron 9100 master never answers:
  the server logs "[GPIB] write error addr 18: iberr=14 (EBUS)" every two seconds and no measurement
  ever reaches the graph. Detect it so that failure is called out at install time instead. }
function GpibDriverInstalled: Boolean;
begin
  { gpib-32.dll is the 32-bit DLL the ComServer loads, so on x64 it lives in SysWOW64 - the sys
    constant is System32 here and will not hold it. The Wow6432Node key is checked explicitly
    because HKLM in a 64-bit install reads the 64-bit view, and NI-488.2 registers under the
    32-bit one.
    NOTE: never write a brace-delimited constant inside a Pascal comment - its closing brace ends
    the comment, which is what broke the v1.6.3 build. }
  Result := FileExists(ExpandConstant('{sys}\gpib-32.dll')) or
            FileExists(ExpandConstant('{win}\SysWOW64\gpib-32.dll')) or
            FileExists(ExpandConstant('{win}\System32\gpib-32.dll')) or
            RegKeyExists(HKLM, 'SOFTWARE\National Instruments\NI-488.2') or
            RegKeyExists(HKLM64, 'SOFTWARE\National Instruments\NI-488.2') or
            RegKeyExists(HKLM, 'SOFTWARE\Wow6432Node\National Instruments\NI-488.2');
end;

function ServiceExists: Boolean;
var
  ResultCode: Integer;
begin
  Exec(ExpandConstant('{sys}\sc.exe'), 'query {#ServiceName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := (ResultCode = 0);
end;

function ServiceIsRunning: Boolean;
var
  ResultCode: Integer;
begin
  { Same binary as Windows Service â€” do not taskkill while STATE is RUNNING. }
  Exec(ExpandConstant('{sys}\cmd.exe'), ExpandConstant('/c "sc query {#ServiceName} | findstr RUNNING"'), '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := (ResultCode = 0);
end;

// ===== Stop service + processes so consolehost DLLs can be replaced (upgrade / reinstall) =====

procedure StopCalibrationProcesses;
var
  ResultCode: Integer;
  I: Integer;
  HadService: Boolean;
begin
  WriteLogSection('STOP CALIBRATION PROCESSES (unlock DLLs for Setup)');
  HadService := ServiceExists;

  if HadService then
  begin
    WriteLog('PowerShell Stop-Service -Force...');
    Exec('powershell.exe',
      ExpandConstant('-NoProfile -ExecutionPolicy Bypass -Command "Stop-Service -Name ''{#ServiceName}'' -Force -ErrorAction SilentlyContinue"'),
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(4000);
    WriteLog('sc stop...');
    Exec(ExpandConstant('{sys}\sc.exe'), 'stop {#ServiceName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(6000);
  end
  else
    WriteLog('Service not registered - skip sc stop');

  if ServiceIsRunning then
    WriteLog('WARNING: Service still RUNNING â€” skipping taskkill ConsoleHost (would terminate the service process). Close the app or run Setup as Administrator.')
  else
  begin
    for I := 1 to 5 do
    begin
      WriteLog('taskkill ConsoleHost /T attempt ' + IntToStr(I));
      Exec('taskkill.exe', '/F /T /IM Maba.VCT.CommServer.Hosts.ConsoleHost.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(2500);
    end;
  end;

  if HadService then
  begin
    WriteLog('sc delete service (releases DLL locks; recreated in post-install)...');
    Exec(ExpandConstant('{sys}\sc.exe'), 'delete {#ServiceName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    WriteLog('sc delete exit code: ' + IntToStr(ResultCode));
    Sleep(5000);
  end;

  if ServiceIsRunning then
    WriteLog('WARNING: Service still RUNNING â€” skipping second taskkill batch.')
  else
  begin
    for I := 1 to 3 do
    begin
      WriteLog('taskkill ConsoleHost after sc delete attempt ' + IntToStr(I));
      Exec('taskkill.exe', '/F /T /IM Maba.VCT.CommServer.Hosts.ConsoleHost.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(2000);
    end;
  end;

  WriteLog('taskkill CalibrationLauncher.exe /T');
  Exec('taskkill.exe', '/F /T /IM CalibrationLauncher.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(1500);

  WriteLog('Stop node listeners on port 3000...');
  Exec('powershell.exe',
    '-NoProfile -ExecutionPolicy Bypass -Command "Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique | ForEach-Object { if ($_) { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue } }"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Sleep(3000);

  WriteLog('Stop calibration processes complete');
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if CurPageID = wpReady then
  begin
    if InstallLogPath = '' then
      InstallLogPath := ExpandConstant('{tmp}\calibration-install.log');
    StopCalibrationProcesses;
  end;
end;

// ===== Download Helper =====

function DownloadAndInstall(const Url, InstallerName, DisplayName, Args: String): Boolean;
var
  TempFile: String;
  ResultCode: Integer;
  PsCmd: String;
begin
  Result := False;
  TempFile := ExpandConstant('{tmp}\') + InstallerName;

  WriteLog('Downloading ' + DisplayName + ' from ' + Url);
  PsCmd := 'powershell.exe';
  if not Exec(PsCmd,
    '-ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri ''' + Url + ''' -OutFile ''' + TempFile + ''' -UseBasicParsing"',
    '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    WriteLog('Download ' + DisplayName + ' - FAILED: Could not execute PowerShell');
    MsgBox('Failed to download ' + DisplayName + '.', mbError, MB_OK);
    Exit;
  end;

  if ResultCode <> 0 then
  begin
    WriteLog('Download ' + DisplayName + ' - FAILED: exit code ' + IntToStr(ResultCode));
    MsgBox('Failed to download ' + DisplayName + ' (exit code ' + IntToStr(ResultCode) + ').', mbError, MB_OK);
    Exit;
  end;
  WriteLog('Download ' + DisplayName + ' - OK');

  // MSI files must be run via msiexec.exe
  if Pos('.msi', LowerCase(TempFile)) > 0 then
  begin
    WriteLog('Installing ' + DisplayName + ' (MSI): msiexec.exe /i "' + TempFile + '" ' + Args);
    if not Exec('msiexec.exe', '/i "' + TempFile + '" ' + Args, '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
    begin
      WriteLog('Install ' + DisplayName + ' - FAILED: Could not execute msiexec.exe');
      MsgBox('Failed to run ' + DisplayName + ' installer.', mbError, MB_OK);
      Exit;
    end;
  end
  else
  begin
    WriteLog('Installing ' + DisplayName + ' (EXE): ' + TempFile + ' ' + Args);
    if not Exec(TempFile, Args, '', SW_SHOW, ewWaitUntilTerminated, ResultCode) then
    begin
      WriteLog('Install ' + DisplayName + ' - FAILED: Could not execute installer');
      MsgBox('Failed to run ' + DisplayName + ' installer.', mbError, MB_OK);
      Exit;
    end;
  end;

  if (ResultCode = 0) or (ResultCode = 3010) then
  begin
    WriteLog('Install ' + DisplayName + ' - OK (exit code ' + IntToStr(ResultCode) + ')');
    Result := True;
  end
  else
  begin
    WriteLog('Install ' + DisplayName + ' - FAILED (exit code ' + IntToStr(ResultCode) + ')');
  end;
end;

// ===== Setup Initialization (Prerequisites) =====

function InitializeSetup: Boolean;
var
  NeedNode, NeedDotNet: Boolean;
begin
  // Log starts in temp until {app} is known
  InstallLogPath := ExpandConstant('{tmp}\calibration-install.log');

  WriteLogSection('INSTALLATION STARTED');
  WriteLog('Installer version: {#AppVersion}');
  WriteLog('Target directory: ' + ExpandConstant('{autopf}\{#AppName}'));
  WriteLog('Windows version: ' + GetWindowsVersionString);

  Result := True;

  // Check .NET
  NeedDotNet := not DotNetInstalled;
  if NeedDotNet then
    WriteLog('Prerequisite check: .NET Framework 4.8 - NOT FOUND')
  else
    WriteLog('Prerequisite check: .NET Framework 4.8 - OK');

  // Check Node.js
  NeedNode := not NodeJsInstalled;
  if NeedNode then
    WriteLog('Prerequisite check: Node.js - NOT FOUND')
  else
    WriteLog('Prerequisite check: Node.js - OK');

  if NeedDotNet then
  begin
    WriteLog('Prompting user to install .NET Framework 4.8');
    if MsgBox('.NET Framework 4.8 is required but was not detected.' + #13#10 +
              'Do you want to download and install it now?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      if not DownloadAndInstall(
        'https://go.microsoft.com/fwlink/?linkid=2088631',
        'ndp48-web.exe',
        '.NET Framework 4.8',
        '/q /norestart') then
      begin
        if MsgBox('.NET Framework 4.8 installation failed.' + #13#10 +
                  'Do you want to continue anyway?', mbConfirmation, MB_YESNO) <> IDYES then
        begin
          WriteLog('User chose to abort after .NET install failure');
          Result := False;
          Exit;
        end;
        WriteLog('User chose to continue despite .NET install failure');
      end;
    end
    else
      WriteLog('User skipped .NET installation');
  end;

  if NeedNode then
  begin
    WriteLog('Prompting user to install Node.js');
    if MsgBox('Node.js 18+ is required but was not detected.' + #13#10 +
              'Do you want to download and install it now?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      if not DownloadAndInstall(
        'https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi',
        'node-setup.msi',
        'Node.js',
        '/qn') then
      begin
        if MsgBox('Node.js installation failed.' + #13#10 +
                  'Do you want to continue anyway?', mbConfirmation, MB_YESNO) <> IDYES then
        begin
          WriteLog('User chose to abort after Node.js install failure');
          Result := False;
          Exit;
        end;
        WriteLog('User chose to continue despite Node.js install failure');
      end;
    end
    else
      WriteLog('User skipped Node.js installation');
  end;

  { GPIB is optional: a station with only serial instruments does not need it. Warn rather than
    block, but do say so plainly - the symptom otherwise is a silent one (no data in the graph). }
  if GpibDriverInstalled then
    WriteLog('Prerequisite check: NI-488.2 (GPIB) - OK')
  else
  begin
    { Recorded, not shown. The dialog interrupted every install of a serial-only station to talk
      about hardware it does not have, and Setup no longer installs the driver anyway. }
    WriteLog('Prerequisite check: NI-488.2 (GPIB) - NOT FOUND. Serial instruments work; ' +
             'install NI-488.2 separately if this station gets a GPIB master.');
  end;

  WriteLogSection('PREREQUISITES COMPLETE');
end;

// ===== Pre-Install: Kill running processes =====

{ Where the previous installation put itself, from Inno's own uninstall key. Empty when there is
  no previous install, or when it was recorded under the other registry view. }
function PreviousInstallPath: String;
var
  Key: String;
  Value: String;
begin
  Result := '';
  { The AppId is written out rather than taken from SetupSetting("AppId"): the [Setup] value is
    brace-escaped ("{{8F3A..."), and emitting it into a Pascal literal would produce a key name
    with a doubled brace that silently matches nothing. }
  Key := 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8F3A2C1D-4B5E-4F6A-9D2E-1C3B5A7F8E9D}_is1';

  if RegQueryStringValue(HKLM64, Key, 'InstallLocation', Value) then
    Result := RemoveBackslash(Value)
  else if RegQueryStringValue(HKLM, Key, 'InstallLocation', Value) then
    Result := RemoveBackslash(Value);
end;

{ Remove an installation that lived somewhere else.

  Every build shares one AppId, one service name and one set of shortcuts, so installing to a
  different folder does not leave two working stations - it leaves one working station and one
  orphan: files nobody runs, that no longer appear in Add/Remove Programs, and whose ComServer can
  still wake up and take COM ports or port 3000 from the real one. Seven of those accumulated on
  the bench in a single day of testing.

  Deliberately narrow: it only touches a folder that still looks like one of ours, and never the
  folder being installed into. }
procedure RemoveOrphanedInstall(const NewPath: String);
var
  OldPath: String;
begin
  OldPath := PreviousInstallPath;

  if OldPath = '' then
    Exit;
  if CompareText(AddBackslash(OldPath), AddBackslash(NewPath)) = 0 then
    Exit;                                { same folder - this is a normal upgrade }
  if not DirExists(OldPath) then
    Exit;

  { Proof it is ours before deleting anything. }
  if not (FileExists(OldPath + '\CalibrationLauncher.exe') or
          FileExists(OldPath + '\consolehost\Maba.VCT.CommServer.Hosts.ConsoleHost.exe')) then
  begin
    WriteLog('Previous install at ' + OldPath + ' does not look like ours - left untouched.');
    Exit;
  end;

  WriteLog('Previous installation found in a different folder: ' + OldPath);
  WriteLog('Removing it so its ComServer cannot compete for the serial ports or port 3000.');

  if DelTree(OldPath, True, True, True) then
    WriteLog('Removed ' + OldPath)
  else
    WriteLog('WARNING: could not fully remove ' + OldPath + ' - delete it by hand.');
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  NeedsRestart := False;

  if InstallLogPath = '' then
    InstallLogPath := ExpandConstant('{tmp}\calibration-install.log');

  WriteLogSection('PREPARE TO INSTALL - Second pass stop processes');
  StopCalibrationProcesses;
end;

// ===== Post-Install Steps (with logging) =====

procedure CurStepChanged(CurStep: TSetupStep);
var
  LogSrc: String;
begin
  if CurStep = ssInstall then
  begin
    if InstallLogPath = '' then
      InstallLogPath := ExpandConstant('{tmp}\calibration-install.log');
    WriteLogSection('ssInstall - final stop pass before file extraction');
    StopCalibrationProcesses;

    { After the processes are down, so nothing in the old folder is still holding a file open. }
    WriteLogSection('ssInstall - remove a previous install left in another folder');
    RemoveOrphanedInstall(ExpandConstant('{app}'));
  end;

  if CurStep = ssPostInstall then
  begin
    // Copy the temp log to the final install directory
    LogSrc := InstallLogPath;
    InstallLogPath := ExpandConstant('{app}\install.log');
    if LogSrc <> InstallLogPath then
      CopyFile(LogSrc, InstallLogPath, False);

    WriteLogSection('POST-INSTALL CONFIGURATION');
    WriteLog('Install directory: ' + ExpandConstant('{app}'));

    { The gauge is at 100% from copying files; reclaim it for the eight configuration steps, which
      is the part that actually takes the time. }
    WizardForm.ProgressGauge.Min := 0;
    WizardForm.ProgressGauge.Max := 100;
    WizardForm.ProgressGauge.Position := 0;

    { Setup does not install the driver, but it does say whether GPIB will work. This is the line
      that turns a later "no data in the graph" from a mystery into a one-line answer. }
    if GpibDriverInstalled then
      WriteLog('GPIB: NI-488.2 present - GPIB masters (e.g. Datron 9100) can be used')
    else
      WriteLog('GPIB: NI-488.2 absent - serial instruments work, GPIB masters will not until the ' +
               'driver is installed separately');

    // Step 0: Set write permissions (Program Files is read-only for non-admins)
    SetInstallStatus('Setting folder permissions...', 10);
    WriteLogSection('STEP 0 - Set Directory Permissions');
    RunAndLog('Set logs permissions',
      'icacls.exe',
      '"' + ExpandConstant('{app}\logs') + '" /grant Everyone:(OI)(CI)F /T');
    RunAndLog('Set webapp permissions',
      'icacls.exe',
      '"' + ExpandConstant('{app}\webapp') + '" /grant Everyone:(OI)(CI)M /T');
    { VCTSettings.Read() calls Save() on every read, so the Settings folder is written at runtime.
      Under Program Files that fails for a non-elevated run (launcher / console) and the failure is
      only traced, never surfaced. The service runs as LocalSystem and would not have noticed. }
    RunAndLog('Set consolehost Settings permissions',
      'icacls.exe',
      '"' + ExpandConstant('{app}\consolehost\Settings') + '" /grant Everyone:(OI)(CI)M /T');

    // Step 1: Verify critical files exist
    SetInstallStatus('Verifying installed files...', 20);
    WriteLogSection('STEP 1 - Verify Files');
    if FileExists(ExpandConstant('{app}\consolehost\Maba.VCT.CommServer.Hosts.ConsoleHost.exe')) then
      WriteLog('ConsoleHost.exe - FOUND')
    else
      WriteLog('ConsoleHost.exe - MISSING (critical!)');

    if FileExists(ExpandConstant('{app}\webapp\server.js')) then
      WriteLog('webapp/server.js - FOUND')
    else
      WriteLog('webapp/server.js - MISSING (critical!)');

    if FileExists(ExpandConstant('{app}\webapp\.env')) then
      WriteLog('webapp/.env - FOUND')
    else
      WriteLog('webapp/.env - MISSING (will use defaults)');

    if FileExists(ExpandConstant('{app}\webapp\.next\routes-manifest.json')) then
      WriteLog('webapp/.next/routes-manifest.json - FOUND')
    else
      WriteLog('webapp/.next/routes-manifest.json - MISSING');

    if DirExists(ExpandConstant('{app}\webapp\node_modules')) then
      WriteLog('webapp/node_modules/ - FOUND')
    else
      WriteLog('webapp/node_modules/ - MISSING (critical!)');

    if DirExists(ExpandConstant('{app}\webapp\.next\static')) then
      WriteLog('webapp/.next/static/ - FOUND')
    else
      WriteLog('webapp/.next/static/ - MISSING');

    if DirExists(ExpandConstant('{app}\webapp\public')) then
      WriteLog('webapp/public/ - FOUND')
    else
      WriteLog('webapp/public/ - MISSING');

    // Step 1.5: Ensure .env has all required variables
    SetInstallStatus('Writing station configuration...', 30);
    WriteLogSection('STEP 1.5 - Patch .env with missing variables');
    if FileExists(ExpandConstant('{app}\webapp\.env')) then
    begin
      RunAndLog('Patch .env - NEXT_PUBLIC_CALIBRATION_USE_MOCK',
        'powershell.exe',
        '-ExecutionPolicy Bypass -Command "' +
        '$envFile = ''' + ExpandConstant('{app}\webapp\.env') + '''; ' +
        '$content = Get-Content $envFile -Raw -ErrorAction SilentlyContinue; ' +
        'if ($content -notmatch ''NEXT_PUBLIC_CALIBRATION_USE_MOCK'') { ' +
        '  Add-Content $envFile \"`nNEXT_PUBLIC_CALIBRATION_USE_MOCK=`\"false`\"\"; ' +
        '  Write-Host ''Added NEXT_PUBLIC_CALIBRATION_USE_MOCK'' ' +
        '} else { Write-Host ''Already present'' }"');
      RunAndLog('Patch .env - NEXT_PUBLIC_WEBSOCKET_URL',
        'powershell.exe',
        '-ExecutionPolicy Bypass -Command "' +
        '$envFile = ''' + ExpandConstant('{app}\webapp\.env') + '''; ' +
        '$content = Get-Content $envFile -Raw -ErrorAction SilentlyContinue; ' +
        'if ($content -notmatch ''NEXT_PUBLIC_WEBSOCKET_URL'') { ' +
        '  Add-Content $envFile \"`nNEXT_PUBLIC_WEBSOCKET_URL=`\"ws://localhost:5001/ws/`\"\"; ' +
        '  Write-Host ''Added NEXT_PUBLIC_WEBSOCKET_URL'' ' +
        '} else { Write-Host ''Already present'' }"');
    end
    else
      WriteLog('.env not found - will use .env.example copy');

    // Step 2: Database connection test
    SetInstallStatus('Testing the database connection...', 40);
    WriteLogSection('STEP 2 - Database Connection Test');
    if FileExists(ExpandConstant('{app}\consolehost\Maba.VCT.CommServer.Hosts.ConsoleHost.exe')) then
    begin
      if not RunAndLog('DB Test',
        ExpandConstant('{app}\consolehost\Maba.VCT.CommServer.Hosts.ConsoleHost.exe'),
        '--test-db') then
      begin
        WriteLog('DB Test - Database connection failed. Installation will continue.');
        if MsgBox('Database connection test failed.' + #13#10 +
                  'The application may not work correctly without a database.' + #13#10 +
                  'Check install.log for details.' + #13#10#13#10 +
                  'Continue anyway?', mbConfirmation, MB_YESNO) <> IDYES then
        begin
          WriteLog('User chose to abort after DB test failure');
          Exit;
        end;
        WriteLog('User chose to continue despite DB test failure');
      end;
    end
    else
      WriteLog('DB Test - SKIPPED: ConsoleHost.exe not found');

    // Step 3: Register WebSocket URL for HttpListener (delete first if upgrade left duplicate)
    SetInstallStatus('Registering the WebSocket address...', 55);
    WriteLogSection('STEP 3 - WebSocket URL Registration');
    RunAndLog('URL ACL remove existing reservation',
      'netsh.exe',
      'http delete urlacl url=http://localhost:5001/ws/');
    RunAndLog('URL ACL add',
      'netsh.exe',
      'http add urlacl url=http://localhost:5001/ws/ user=Everyone');

    // Step 4: Stop existing service if running
    SetInstallStatus('Removing any previous service...', 65);
    WriteLogSection('STEP 4 - Service Setup');
    if ServiceExists then
    begin
      WriteLog('Existing service found - stopping and removing');
      RunAndLog('Stop existing service',
        ExpandConstant('{sys}\sc.exe'),
        'stop {#ServiceName}');
      Sleep(3000);
      RunAndLog('Delete existing service',
        ExpandConstant('{sys}\sc.exe'),
        'delete {#ServiceName}');
      Sleep(2000);
    end
    else
      WriteLog('No existing service found');

    // Step 5: Install Windows Service
    SetInstallStatus('Installing the Windows service...', 75);
    WriteLogSection('STEP 5 - Install Windows Service');
    RunAndLog('Create service',
      ExpandConstant('{sys}\sc.exe'),
      'create {#ServiceName} binPath= "' + ExpandConstant('{app}\consolehost\Maba.VCT.CommServer.Hosts.ConsoleHost.exe') + '" start= auto DisplayName= "{#ServiceDisplayName}"');

    // Step 5b: Allow non-admin users to start/stop this service (net start/stop, launcher, sc without elevation)
    // SDDL: AU = Authenticated Users, RPWPCR = start, stop, pause, continue, interrogate (read status)
    SetInstallStatus('Granting service permissions...', 82);
    WriteLogSection('STEP 5b - Service permissions for standard users');
    if not RunAndLog('Grant Authenticated Users service control (sc sdset)',
      ExpandConstant('{sys}\sc.exe'),
      'sdset {#ServiceName} D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;RPWPCR;;;AU)') then
      WriteLog('WARNING: sc sdset failed â€” users may need Administrator to start/stop the service');

    // Step 6: Start the service
    SetInstallStatus('Starting the calibration server...', 90);
    WriteLogSection('STEP 6 - Start Service');
    Sleep(2000);
    if not RunAndLog('Start service',
      ExpandConstant('{sys}\sc.exe'),
      'start {#ServiceName}') then
    begin
      WriteLog('Service failed to start. Checking service state...');
      RunAndLog('Query service state',
        ExpandConstant('{sys}\sc.exe'),
        'query {#ServiceName}');
    end;

    // Step 7: Verify service is running
    Sleep(3000);
    SetInstallStatus('Verifying the service is running...', 97);
    WriteLogSection('STEP 7 - Verify Service Running');
    if ServiceExists then
    begin
      RunAndLog('Final service check',
        ExpandConstant('{sys}\sc.exe'),
        'query {#ServiceName}');
    end
    else
      WriteLog('Service verification - WARNING: Service not found after install');

    SetInstallStatus('Installation complete.', 100);

    WriteLogSection('INSTALLATION COMPLETE');
    WriteLog('Log file saved to: ' + InstallLogPath);
    WriteLog('To troubleshoot issues, share this file with support.');
  end;
end;

// ===== Uninstall (with logging) =====

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    InstallLogPath := ExpandConstant('{app}\uninstall.log');

    WriteLogSection('UNINSTALL STARTED');

    { Stop service before taskkill â€” same exe as service; killing first would break graceful stop. }
    if ServiceExists then
    begin
      WriteLog('PowerShell Stop-Service...');
      Exec('powershell.exe',
        ExpandConstant('-NoProfile -ExecutionPolicy Bypass -Command "Stop-Service -Name ''{#ServiceName}'' -Force -ErrorAction SilentlyContinue"'),
        '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Sleep(4000);
      WriteLog('sc stop...');
      Exec(ExpandConstant('{sys}\sc.exe'), 'stop {#ServiceName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      WriteLog('Stop service exit code: ' + IntToStr(ResultCode));
      Sleep(3000);
    end
    else
      WriteLog('Service not registered - skip sc stop');

    if ServiceIsRunning then
      WriteLog('WARNING: Service still RUNNING â€” skipping taskkill ConsoleHost (would terminate the service process).')
    else
    begin
      WriteLog('taskkill ConsoleHost (cleanup after stop or standalone process)');
      Exec('taskkill.exe', '/F /IM Maba.VCT.CommServer.Hosts.ConsoleHost.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;

    Exec('powershell.exe',
      '-NoProfile -ExecutionPolicy Bypass -Command "Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }"',
      '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Sleep(2000);

    if ServiceExists then
    begin
      WriteLog('Deleting service...');
      Exec(ExpandConstant('{sys}\sc.exe'), 'delete {#ServiceName}', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      WriteLog('Delete service exit code: ' + IntToStr(ResultCode));
    end
    else
      WriteLog('Service not found - skipping service removal');

    if not ServiceIsRunning then
    begin
      WriteLog('Final taskkill ConsoleHost (orphans after service removal)');
      Exec('taskkill.exe', '/F /IM Maba.VCT.CommServer.Hosts.ConsoleHost.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    end;

    WriteLog('Removing WebSocket URL reservation...');
    Exec('netsh.exe', 'http delete urlacl url=http://localhost:5001/ws/', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    WriteLog('URL ACL removal exit code: ' + IntToStr(ResultCode));

    WriteLogSection('UNINSTALL COMPLETE');
  end;
end;
