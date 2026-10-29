; Установщик Горец для Windows (Inno Setup 6).
; Собирается в CI (.github/workflows/gorec-android.yml, задача windows):
;   iscc /DAppVersion=1.0.15 /DAppBuild=40215 /DSourceDir=<папка Release> Gorec.iss
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
AppName=Горец
AppVersion={#AppVersion}
AppVerName=Горец {#AppVersion}
AppPublisher=Горец
AppPublisherURL=https://gorec.vip
AppSupportURL=https://t.me/hamvpn13_bot
AppUpdatesURL=https://gorec.vip/download
VersionInfoVersion={#AppVersion}.0
VersionInfoProductName=Горец
DefaultDirName={localappdata}\Programs\Gorec
DefaultGroupName=Горец
DisableProgramGroupPage=yes
DisableDirPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
OutputBaseFilename=Gorec-Windows-Setup
SetupIconFile=..\..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Gorec.exe
UninstallDisplayName=Горец
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
Name: "{group}\Горец"; Filename: "{app}\Gorec.exe"
Name: "{group}\Удалить Горец"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Горец"; Filename: "{app}\Gorec.exe"; Tasks: desktopicon

[Registry]
; Ссылки gorec://login?t=… с сайта («Открыть в приложении») открывают программу
Root: HKCU; Subkey: "Software\Classes\gorec"; ValueType: string; ValueName: ""; ValueData: "URL:Gorec"; Flags: uninsdeletekey
Root: HKCU; Subkey: "Software\Classes\gorec"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\gorec\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\Gorec.exe,0"
Root: HKCU; Subkey: "Software\Classes\gorec\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\Gorec.exe"" ""%1"""

[Run]
; И после обычной установки, и после тихого обновления — сразу открыть программу
Filename: "{app}\Gorec.exe"; Description: "Запустить Горец"; Flags: nowait postinstall

[Code]
// На случай, если программа ещё не успела закрыться — закрываем её сами
function InitializeSetup(): Boolean;
var
  Code: Integer;
begin
  Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM Gorec.exe /IM HiddifyCli.exe', '', SW_HIDE, ewWaitUntilTerminated, Code);
  Result := True;
end;
