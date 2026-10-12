; Установщик ХамВПН для Windows (Inno Setup 6).
; Собирается в CI (.github/workflows/hamvpn-android.yml, задача windows):
;   iscc /DAppVersion=1.0.15 /DAppBuild=40215 /DSourceDir=<папка Release> HamVPN.iss
;
; Ставится в профиль пользователя (без прав администратора и без окна UAC),
; поэтому обновление из самой программы проходит тихо: программа запускает
; этот установщик с /VERYSILENT, закрывается, а установщик заменяет файлы
; и открывает новую версию.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef AppBuild
  #define AppBuild "0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{AB0D1DEC-E0CD-486C-B918-679194EBE019}
AppName=ХамВПН
AppVersion={#AppVersion}
AppVerName=ХамВПН {#AppVersion}
AppPublisher=ХамВПН
AppPublisherURL=https://hamvpn.net
AppSupportURL=https://t.me/hamvpn13_bot
AppUpdatesURL=https://hamvpn.net/download
VersionInfoVersion={#AppVersion}.0
VersionInfoProductName=ХамВПН
DefaultDirName={localappdata}\Programs\HamVPN
DefaultGroupName=ХамВПН
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
OutputBaseFilename=HamVPN-Windows-Setup
SetupIconFile=..\..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\HamVPN.exe
UninstallDisplayName=ХамВПН
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force
RestartApplications=no

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"

[Tasks]
Name: "desktopicon"; Description: "Значок на рабочем столе"; GroupDescription: "Дополнительно:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ХамВПН"; Filename: "{app}\HamVPN.exe"
Name: "{group}\Удалить ХамВПН"; Filename: "{uninstallexe}"
Name: "{autodesktop}\ХамВПН"; Filename: "{app}\HamVPN.exe"; Tasks: desktopicon

[Registry]
; Ссылки hamvpn://login?t=… с сайта («Открыть в приложении») открывают программу
Root: HKCU; Subkey: "Software\Classes\hamvpn"; ValueType: string; ValueName: ""; ValueData: "URL:HamVPN"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\hamvpn"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\hamvpn\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\HamVPN.exe,0"
Root: HKCU; Subkey: "Software\Classes\hamvpn\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\HamVPN.exe"" ""%1"""

[Run]
; И после обычной установки, и после тихого обновления — сразу открыть программу
Filename: "{app}\HamVPN.exe"; Description: "Запустить ХамВПН"; Flags: nowait postinstall

[Code]
// На случай, если программа ещё не успела закрыться — закрываем её сами
function InitializeSetup(): Boolean;
var
  Code: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM HamVPN.exe /IM HiddifyCli.exe', '', SW_HIDE, ewWaitUntilTerminated, Code);
  Result := True;
end;
