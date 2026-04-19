#define AppName "Calibration Software"
#define AppVersion "1.5.1"
#define AppPublisher "MBA"
#define AppURL "http://localhost:3000"
#define ServiceName "MabaCalibrationServer"
#define ServiceDisplayName "Maba Calibration Server"

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
Name: "{app}\assets";
Name: "{app}\logs";

[InstallDelete]
; Clean old webapp files to prevent stale content on upgrade
Type: filesandordirs; Name: "{app}\webapp\.next"
Type: filesandordirs; Name: "{app}\webapp\node_modules"
Type: files; Name: "{app}\webapp\server.js"
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
Source: "..\app\.next\standalone\app\*";    DestDir: "{app}\webapp";           Components: webapp; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "..\app\.next\static\*";            DestDir: "{app}\webapp\.next\static"; Components: webapp; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "..\app\public\*";                  DestDir: "{app}\webapp\public";    Components: webapp; Flags: recursesubdirs createallsubdirs ignoreversion

; --- Console Host ---
Source: "..\Systems\VCT\ComServer\ComServer.Hosts.ConsoleHost\bin\Release\*"; DestDir: "{app}\consolehost"; Components: consolehost; Excludes: "*.log,*.pdb"; Flags: recursesubdirs createallsubdirs ignoreversion

; --- Desktop / Start-menu launcher (runs start-all.bat hidden: service + WS + webapp) ---
Source: "CalibrationLauncher\bin\Release\CalibrationLauncher.exe"; DestDir: "{app}"; Flags: ignoreversion

; --- Launcher scripts ---
Source: "assets\start-webapp.bat";          DestDir: "{app}\assets";           Flags: ignoreversion
Source: "assets\start-consolehost.bat";     DestDir: "{app}\assets";           Flags: ignoreversion
Source: "assets\start-all.bat";             DestDir: "{app}\assets";           Flags: ignoreversion
Source: "assets\start-silent.vbs";          DestDir: "{app}\assets";           Flags: ignoreversion
Source: "..\Install-Service.ps1";           DestDir: "{app}";                  Flags: ignoreversion
Source: "..\Uninstall-Service.ps1";         DestDir: "{app}";                  Flags: ignoreversion
Source: "..\run-project.ps1";               DestDir: "{app}";                  Flags: ignoreversion

; --- Environment config ---
Source: "..\app\.env";                      DestDir: "{app}\webapp";           DestName: ".env"; Flags: ignoreversion
Source: "..\app\.env.example";              DestDir: "{app}\webapp";           DestName: ".env.example"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}";                 Filename: "{app}\CalibrationLauncher.exe"; WorkingDir: "{app}"
Name: "{group}\Uninstall {#AppName}";       Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}";         Filename: "{app}\CalibrationLauncher.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

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

  WriteLogSection('PREREQUISITES COMPLETE');
end;

// ===== Pre-Install: Kill running processes =====

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

    // Step 0: Set write permissions (Program Files is read-only for non-admins)
    WriteLogSection('STEP 0 - Set Directory Permissions');
    RunAndLog('Set logs permissions',
      'icacls.exe',
      '"' + ExpandConstant('{app}\logs') + '" /grant Everyone:(OI)(CI)F /T');
    RunAndLog('Set webapp permissions',
      'icacls.exe',
      '"' + ExpandConstant('{app}\webapp') + '" /grant Everyone:(OI)(CI)M /T');

    // Step 1: Verify critical files exist
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
    WriteLogSection('STEP 3 - WebSocket URL Registration');
    RunAndLog('URL ACL remove existing reservation',
      'netsh.exe',
      'http delete urlacl url=http://localhost:5001/ws/');
    RunAndLog('URL ACL add',
      'netsh.exe',
      'http add urlacl url=http://localhost:5001/ws/ user=Everyone');

    // Step 4: Stop existing service if running
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
    WriteLogSection('STEP 5 - Install Windows Service');
    RunAndLog('Create service',
      ExpandConstant('{sys}\sc.exe'),
      'create {#ServiceName} binPath= "' + ExpandConstant('{app}\consolehost\Maba.VCT.CommServer.Hosts.ConsoleHost.exe') + '" start= auto DisplayName= "{#ServiceDisplayName}"');

    // Step 5b: Allow non-admin users to start/stop this service (net start/stop, launcher, sc without elevation)
    // SDDL: AU = Authenticated Users, RPWPCR = start, stop, pause, continue, interrogate (read status)
    WriteLogSection('STEP 5b - Service permissions for standard users');
    if not RunAndLog('Grant Authenticated Users service control (sc sdset)',
      ExpandConstant('{sys}\sc.exe'),
      'sdset {#ServiceName} D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;RPWPCR;;;AU)') then
      WriteLog('WARNING: sc sdset failed â€” users may need Administrator to start/stop the service');

    // Step 6: Start the service
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
    WriteLogSection('STEP 7 - Verify Service Running');
    if ServiceExists then
    begin
      RunAndLog('Final service check',
        ExpandConstant('{sys}\sc.exe'),
        'query {#ServiceName}');
    end
    else
      WriteLog('Service verification - WARNING: Service not found after install');

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
