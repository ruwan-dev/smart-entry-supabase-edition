[Setup]
AppId={{8B4F9C2D-1E3A-4F71-B536-12A456C9F28E}
AppName=Smart Entry
AppVersion=1.0.2
AppPublisher=OrbitView Innovations
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DefaultDirName={autopf}\Smart Entry
DisableProgramGroupPage=yes
OutputDir=.\Installer
OutputBaseFilename=SmartEntry_Setup_v1.0.2
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=windows\runner\resources\app_icon.ico

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Flutter Application Files
Source: "build\windows\x64\runner\Release\smart_entry.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Node.js Portable Binary
Source: "node.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: ".puppeteerrc.cjs"; DestDir: "{app}"; Flags: ignoreversion

; WhatsApp Server Source Code and Modules
Source: "whatsapp_server\*"; DestDir: "{app}\whatsapp_server"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "whatsapp_server\.puppeteerrc.cjs"; DestDir: "{app}\whatsapp_server"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Smart Entry"; Filename: "{app}\smart_entry.exe"
Name: "{autodesktop}\Smart Entry"; Filename: "{app}\smart_entry.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\smart_entry.exe"; Description: "{cm:LaunchProgram,Smart Entry}"; Flags: nowait postinstall skipifsilent
