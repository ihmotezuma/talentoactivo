Set WshShell = CreateObject("WScript.Shell")
strPath = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
WshShell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & strPath & "\TalentoActivo.ps1""", 0, False
MsgBox "TalentoActivo se esta ejecutando en segundo plano. Para detenerlo, finaliza 'Windows PowerShell' desde el Administrador de tareas.", 64, "TalentoActivo"
