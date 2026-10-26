Unicode true
!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"

!ifndef VERSION
!error "VERSION, RID, REPO_ROOT, PAYLOAD_DIR and OUTPUT_FILE are required"
!endif
Name "ChirpOS ${VERSION} (${RID})"
OutFile "${OUTPUT_FILE}"
InstallDir "$LOCALAPPDATA\Programs\ChirpOS"
RequestExecutionLevel user
SetCompressor /SOLID lzma
ShowInstDetails show
ShowUninstDetails show
VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "ChirpOS Setup"
VIAddVersionKey "FileDescription" "ChirpOS ${RID} installer"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "LegalCopyright" "ChirpOS contributors"
!define MUI_ICON "${REPO_ROOT}/shared/AppIcon.ico"
!define MUI_UNICON "${REPO_ROOT}/shared/AppIcon.ico"
!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${REPO_ROOT}/LICENSE"
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\ChirpOS.exe"
!define MUI_FINISHPAGE_RUN_NOTCHECKED
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "TradChinese"

LangString CloseApp ${LANG_ENGLISH} "Please quit ChirpOS from its tray menu, then click Retry."
LangString CloseApp ${LANG_SIMPCHINESE} "请先从系统托盘退出啾啾，然后点击重试。"
LangString CloseApp ${LANG_TRADCHINESE} "請先從系統匣結束啾啾，然後按重試。"
LangString RuntimePrompt ${LANG_ENGLISH} "ChirpOS needs Microsoft .NET 10 Desktop Runtime (${RID}). Download and install it now? Windows may ask for administrator permission."
LangString RuntimePrompt ${LANG_SIMPCHINESE} "啾啾需要微软 .NET 10 桌面运行时（${RID}）。现在下载并安装吗？Windows 可能会请求管理员权限。"
LangString RuntimePrompt ${LANG_TRADCHINESE} "啾啾需要微軟 .NET 10 桌面執行階段（${RID}）。現在下載並安裝嗎？Windows 可能會要求系統管理員權限。"
LangString RuntimeFailed ${LANG_ENGLISH} "The runtime could not be prepared. See the details above. Check your connection and allow Microsoft's installer, then Retry; Cancel leaves ChirpOS unchanged."
LangString RuntimeFailed ${LANG_SIMPCHINESE} "运行环境未准备完成，请查看上方详情。检查网络并允许微软安装器运行，然后重试；取消将保留现有啾啾。"
LangString RuntimeFailed ${LANG_TRADCHINESE} "執行環境尚未準備完成，請查看上方詳情。檢查網路並允許微軟安裝程式執行，然後重試；取消將保留現有啾啾。"
LangString RestartNeeded ${LANG_ENGLISH} "Microsoft's installer requires a restart. Restart Windows, then run ChirpOS Setup again. Your existing app and data have not been replaced."
LangString RestartNeeded ${LANG_SIMPCHINESE} "微软安装器要求重启。请重启 Windows 后重新运行啾啾安装包。现有应用和数据尚未替换。"
LangString RestartNeeded ${LANG_TRADCHINESE} "微軟安裝程式要求重新啟動。請重新啟動 Windows 後再次執行啾啾安裝程式。現有應用程式與資料尚未替換。"
LangString PowerShellMissing ${LANG_ENGLISH} "Windows PowerShell is required to prepare the runtime. Please enable Windows PowerShell and run Setup again."
LangString PowerShellMissing ${LANG_SIMPCHINESE} "安装引导需要 Windows PowerShell。请启用 Windows PowerShell 后重试。"
LangString PowerShellMissing ${LANG_TRADCHINESE} "安裝引導需要 Windows PowerShell。請啟用 Windows PowerShell 後重試。"
LangString CopyFailed ${LANG_ENGLISH} "Could not replace ChirpOS. Quit the app and retry, or check write access to your installation folder."
LangString CopyFailed ${LANG_SIMPCHINESE} "无法替换啾啾。请退出应用后重试，或检查安装目录的写入权限。"
LangString CopyFailed ${LANG_TRADCHINESE} "無法替換啾啾。請結束應用程式後重試，或檢查安裝資料夾的寫入權限。"

Var PowerShell

!macro RequireClosed Prefix
Function ${Prefix}RequireClosed
  retry:
    System::Call 'kernel32::OpenMutexW(i 0x100000, i 0, w "Local\ChirpOS.Desktop") p.r0'
    ${If} $0 != 0
      System::Call 'kernel32::CloseHandle(p r0)'
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$(CloseApp)" IDRETRY retry
      Abort
    ${EndIf}
FunctionEnd
!macroend
!insertmacro RequireClosed ""
!insertmacro RequireClosed "un."

Function .onInit
  SetShellVarContext current
  SetRegView 64
  ; Run the native PowerShell, even from this 32-bit NSIS bootstrapper.
  StrCpy $PowerShell "$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
  IfFileExists "$PowerShell" found
  StrCpy $PowerShell "$SYSDIR\WindowsPowerShell\v1.0\powershell.exe"
  IfFileExists "$PowerShell" found
  MessageBox MB_OK|MB_ICONSTOP "$(PowerShellMissing)"
  Abort
  found:
FunctionEnd

Section "ChirpOS"
  Call RequireClosed
  InitPluginsDir
  SetOutPath "$PLUGINSDIR"
  File "${REPO_ROOT}/platforms/windows/installer/Ensure-Runtime.ps1"
  File "${REPO_ROOT}/platforms/windows/installer/runtime.json"
  runtimeCheck:
    DetailPrint "Checking Microsoft .NET Desktop Runtime (${RID})..."
    nsExec::ExecToLog '"$PowerShell" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\Ensure-Runtime.ps1" -Runtime ${RID} -Action Check -Manifest "$PLUGINSDIR\runtime.json"'
    Pop $0
    ${If} $0 == 0
      Goto runtimeReady
    ${ElseIf} $0 == 10
      MessageBox MB_OKCANCEL|MB_ICONINFORMATION "$(RuntimePrompt)" IDOK installRuntime
      Abort
    ${Else}
      Goto runtimeFailed
    ${EndIf}
  installRuntime:
    DetailPrint "Downloading and installing Microsoft .NET Desktop Runtime..."
    nsExec::ExecToLog '"$PowerShell" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\Ensure-Runtime.ps1" -Runtime ${RID} -Action Install -Manifest "$PLUGINSDIR\runtime.json"'
    Pop $0
    ${If} $0 == 0
      Goto runtimeReady
    ${ElseIf} $0 == 3010
      MessageBox MB_OK|MB_ICONINFORMATION "$(RestartNeeded)"
      SetErrorLevel 3010
      Abort
    ${EndIf}
  runtimeFailed:
    MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "$(RuntimeFailed)" IDRETRY runtimeCheck
    Abort
  runtimeReady:
  Call RequireClosed
  SetOutPath "$INSTDIR"
  ; Stage before renaming so a locked executable cannot be partially overwritten.
  File /oname=ChirpOS.new.exe "${PAYLOAD_DIR}/ChirpOS.exe"
  ClearErrors
  IfFileExists "$INSTDIR\ChirpOS.exe" 0 installNew
  Delete "$INSTDIR\ChirpOS.previous.exe"
  Rename "$INSTDIR\ChirpOS.exe" "$INSTDIR\ChirpOS.previous.exe"
  IfErrors copyFailed
  installNew:
  Rename "$INSTDIR\ChirpOS.new.exe" "$INSTDIR\ChirpOS.exe"
  IfErrors restoreOld
  Delete "$INSTDIR\ChirpOS.previous.exe"
  File "${REPO_ROOT}/LICENSE"
  File "${REPO_ROOT}/platforms/windows/README.md"
  File "${REPO_ROOT}/platforms/windows/Verify-Windows.cmd"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\ChirpOS"
  CreateShortcut "$SMPROGRAMS\ChirpOS\ChirpOS.lnk" "$INSTDIR\ChirpOS.exe"
  CreateShortcut "$SMPROGRAMS\ChirpOS\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  ; Preserve an existing login preference while updating the executable location.
  ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "ChirpOS"
  ${If} $0 != ""
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "ChirpOS" '$\"$INSTDIR\ChirpOS.exe$\"'
  ${EndIf}
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChirpOS" "DisplayName" "ChirpOS"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChirpOS" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChirpOS" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChirpOS" "DisplayIcon" "$INSTDIR\ChirpOS.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChirpOS" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChirpOS" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChirpOS" "NoRepair" 1
  Goto complete
  restoreOld:
    Rename "$INSTDIR\ChirpOS.previous.exe" "$INSTDIR\ChirpOS.exe"
  copyFailed:
    Delete "$INSTDIR\ChirpOS.new.exe"
    MessageBox MB_OK|MB_ICONSTOP "$(CopyFailed)"
    Abort
  complete:
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  SetRegView 64
  Call un.RequireClosed
  ReadRegStr $0 HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "ChirpOS"
  ${If} $0 == '$\"$INSTDIR\ChirpOS.exe$\"'
    DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "ChirpOS"
  ${EndIf}
  Delete "$INSTDIR\ChirpOS.exe"
  Delete "$INSTDIR\LICENSE"
  Delete "$INSTDIR\README.md"
  Delete "$INSTDIR\Verify-Windows.cmd"
  Delete "$INSTDIR\Uninstall.exe"
  Delete "$SMPROGRAMS\ChirpOS\ChirpOS.lnk"
  Delete "$SMPROGRAMS\ChirpOS\Uninstall.lnk"
  RMDir "$SMPROGRAMS\ChirpOS"
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChirpOS"
  ; Keep %LOCALAPPDATA%\ChirpOS settings, Life List and the shared .NET runtime.
SectionEnd
