#define AppVersion '1.1.0'
#define AppName 'Webcam Settings'
#define AppCompany 'Dunkel & Iwer GbR'

[Files]
DestDir: {app}; Source: ..\src\WebcamConfigurationTool\bin\Release\*; Excludes: "*.pdb"; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion
DestDir: {app}; Source: additional\*; Flags: recursesubdirs overwritereadonly ignoreversion replacesameversion

[Icons]
Name: {group}\{#AppName}; Filename: {app}\WebcamConfigurationTool.exe; WorkingDir: {app}; IconFilename: {app}\WebcamConfigurationTool.exe; IconIndex: 0; Languages: 
Name: {commondesktop}\{#AppName}; Filename: {app}\WebcamConfigurationTool.exe; IconFilename: {app}\WebcamConfigurationTool.exe; IconIndex: 0

Name: {group}\Deinstallieren; Filename: {uninstallexe}; Languages: en
Name: {group}\Uninstall; Filename: {uninstallexe}; Languages: de

[Run]
[Run]
Filename: {app}\NDP472-KB4054531-Web.exe; StatusMsg: "Microsoft .NET Framework is being installed. Please wait..."; Parameters: "/NoRestart /Passive /ShowFinalError /ShowRmui"; Check: Not IsDotNetDetected
Filename: {app}\WebcamConfigurationTool.exe; WorkingDir: {app}; Flags: nowait postinstall; Description: {#AppName} starten

[Setup]
AppCopyright=Dunkel & Iwer GbR
AppName={#AppName}
AppVerName={#AppName} {#AppVersion}
DefaultDirName={pf}\eKiwi-Blog.de\{#AppName}
ShowLanguageDialog=yes
AppID={{3499B84F-FCAB-4308-B8F2-6D66F4D1D492}
VersionInfoVersion={#AppVersion}
VersionInfoCompany=Dunkel & Iwer GbR
VersionInfoDescription={#AppName}
LanguageDetectionMethod=uilanguage
DefaultGroupName=eKiwi-Blog.de\{#AppName}
ShowUndisplayableLanguages=false
OutputBaseFilename=webcam_setup
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
AppPublisher=Dunkel & Iwer GbR
AppPublisherURL=https://www.ekiwi-blog.de
AppSupportURL=https://www.ekiwi-blog.de
AppUpdatesURL=https://www.ekiwi-blog.de
;WizardImageFile=Icon_inst.bmp
;WizardSmallImageFile=Icon_inst_small.bmp
ChangesAssociations=true
SignTool=kSign /d $qWebcam Tool$q /du $qhttps://www.ekiwi-blog.de$q /v $f
SignedUninstaller=yes

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl"

[UninstallDelete]
Name: {app}; Type: filesandordirs

[Code]
function GetUninstallString(): String;
var
  sUnInstPath: String;
  sUnInstallString: String;
begin
  sUnInstPath := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{3499B84F-FCAB-4308-B8F2-6D66F4D1D492}_is1';
  sUnInstallString := '';
  if not RegQueryStringValue(HKLM, sUnInstPath, 'UninstallString', sUnInstallString) then
    RegQueryStringValue(HKCU, sUnInstPath, 'UninstallString', sUnInstallString);
  Result := sUnInstallString;
end;


/////////////////////////////////////////////////////////////////////
function IsUpgrade(): Boolean;
begin
  Result := (GetUninstallString() <> '');
end;


/////////////////////////////////////////////////////////////////////
function UnInstallOldVersion(): Integer;
var
  sUnInstallString: String;
  iResultCode: Integer;
begin
// Return Values:
// 1 - uninstall string is empty
// 2 - error executing the UnInstallString
// 3 - successfully executed the UnInstallString

  // default return value
  Result := 0;

  // get the uninstall string of the old app
  sUnInstallString := GetUninstallString();
  if sUnInstallString <> '' then begin
    sUnInstallString := RemoveQuotes(sUnInstallString);
    if Exec(sUnInstallString, '/SILENT /NORESTART /SUPPRESSMSGBOXES','', SW_HIDE, ewWaitUntilTerminated, iResultCode) then
      Result := 3
    else
      Result := 2;
  end else
    Result := 1;
end;

/////////////////////////////////////////////////////////////////////
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep=ssInstall) then
  begin
    if (IsUpgrade()) then
    begin
      UnInstallOldVersion();
      Sleep(2000);
    end;
  end;
end;


// determines if .NET 4.7 is installed
function IsDotNetDetected(): boolean;
var
    key: string;
    release: cardinal;
    success: boolean;
    install: cardinal;
begin

    key := 'SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full';

    // check if the install bit is set
    success := RegQueryDWordValue(HKLM, key, 'Install', install);

    // and that the release number is greater than 460805, which is the version
    // that's bundled into the installer
    success := success and RegQueryDWordValue(HKLM, key, 'Release', release);
    success := success and (release >= 460805);

    result := success
end;