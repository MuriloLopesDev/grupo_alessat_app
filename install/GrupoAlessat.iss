[Setup]
AppName=GrupoAlessat
AppVersion=1.0
DefaultDirName={pf}\GrupoAlessat
DefaultGroupName=GrupoAlessat
OutputDir=.
OutputBaseFilename=GrupoAlessatSetup
Compression=lzma
SolidCompression=yes
SetupIconFile=..\assets\icon.ico

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\GrupoAlessat"; Filename: "{app}\grupo_alessat.exe"
Name: "{group}\Desinstalar GrupoAlessat"; Filename: "{uninstallexe}"
Name: "{commondesktop}\GrupoAlessat"; Filename: "{app}\grupo_alessat.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Criar um atalho na área de trabalho"; GroupDescription: "Opções adicionais"

[Run]
Filename: "{app}\grupo_alessat.exe"; Description: "Executar GrupoAlessat"; Flags: nowait postinstall