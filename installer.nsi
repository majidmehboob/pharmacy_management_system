!define APPNAME "Pharmacy Management System"
!define EXE "pharmacy_management_system.exe"

Name "${APPNAME}"
OutFile "PharmacyManagementSetup.exe"

InstallDir "$PROGRAMFILES64\${APPNAME}"

RequestExecutionLevel admin

Page directory
Page instfiles

Section

SetOutPath "$INSTDIR"

; Copy EVERYTHING from Release folder
File /r "C:\Users\Majid Mehboob\Desktop\pharmacy_management_system\build\windows\x64\runner\Release\*"

CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXE}"
CreateShortcut "$SMPROGRAMS\${APPNAME}.lnk" "$INSTDIR\${EXE}"

WriteUninstaller "$INSTDIR\Uninstall.exe"

SectionEnd

Section "Uninstall"

Delete "$DESKTOP\${APPNAME}.lnk"
Delete "$SMPROGRAMS\${APPNAME}.lnk"

RMDir /r "$INSTDIR"

SectionEnd