@echo off

set EXITCODE=1

rem Check for NSIS
IF EXIST "%ProgramFiles%\NSIS\makensis.exe" (
  set NSIS="%ProgramFiles%\NSIS\makensis.exe"
) ELSE IF EXIST "%ProgramFiles(x86)%\NSIS\makensis.exe" (
  set NSIS="%ProgramFiles(x86)%\NSIS\makensis.exe"
) ELSE GOTO NONSIS

rem Check for VC12
IF "%VS120COMNTOOLS%"=="" (
  set COMPILER12="%ProgramFiles%\Microsoft Visual Studio 12.0\Common7\IDE\devenv.com"
) ELSE IF EXIST "%VS120COMNTOOLS%\..\IDE\VCExpress.exe" (
  set COMPILER12="%VS120COMNTOOLS%\..\IDE\VCExpress.exe"
) ELSE IF EXIST "%VS120COMNTOOLS%\..\IDE\devenv.com" (
  set COMPILER12="%VS120COMNTOOLS%\..\IDE\devenv.com"
) ELSE GOTO NOSDK11

del /s /f /q ..\build
del /s /f /q ..\cmake-build
mkdir ..\build

call build.cmd
IF NOT ERRORLEVEL 0 (
  GOTO ERRORCREATINGINSTALLER
)

IF EXIST "..\support\p8-usbcec-driver-installer.exe" (
  copy "..\support\p8-usbcec-driver-installer.exe" "..\build\."
) ELSE (
  rem Check for the Windows DDK
  IF NOT EXIST "C:\WinDDK\7600.16385.1" GOTO NODDK
  set DDK="C:\WinDDK\7600.16385.1"

  call create-driver-installer.cmd
)

cd ..\project

rem Skip to libCEC/x86 when we're running on win32
if "%PROCESSOR_ARCHITECTURE%"=="x86" if "%PROCESSOR_ARCHITEW6432%"=="" goto libcecx86

rem Compile libCEC and cec-client x64
echo. Cleaning libCEC (x64)
%COMPILER12% libcec.sln /Clean "Release|x64"
echo. Compiling libCEC (x64)
%COMPILER12% libcec.sln /Build "Release|x64" /Project LibCecSharp
%COMPILER12% libcec.sln /Build "Release|x64"

:libcecx86
rem Compile libCEC and cec-client Win32
echo. Cleaning libCEC (x86)
%COMPILER12% libcec.sln /Clean "Release|x86"
echo. Compiling libCEC (x86)
%COMPILER12% libcec.sln /Build "Release|x86" /Project LibCecSharp
%COMPILER12% libcec.sln /Build "Release|x86"

rem Clean things up before creating the installer
del /q /f ..\build\LibCecSharp.pdb
del /q /f ..\build\CecSharpTester.pdb
del /q /f ..\build\cec-tray.pdb
del /q /f ..\build\cec-tray.vshost.exe.manifest
del /q /f ..\build\cec-.vshost.exe
del /q /f ..\build\x64\LibCecSharp.pdb
del /q /f ..\build\x64\CecSharpTester.pdb
del /q /f ..\build\x64\cec-tray.pdb
del /q /f ..\build\x64\cec-tray.vshost.exe.manifest
del /q /f ..\build\x64\cec-.vshost.exe

rem Check for sign-binary.cmd, only present on the Pulse-Eight production build system
rem Calls signtool.exe and signs the DLLs with Pulse-Eight's code signing key
IF NOT EXIST "..\support\private\sign-binary.cmd" GOTO CREATEINSTALLER
echo. Signing all binaries
CALL ..\support\private\sign-binary.cmd ..\build\cec-client.exe
CALL ..\support\private\sign-binary.cmd ..\build\cecc-client.exe
CALL ..\support\private\sign-binary.cmd ..\build\CecSharpTester.exe
CALL ..\support\private\sign-binary.cmd ..\build\cec.dll
CALL ..\support\private\sign-binary.cmd ..\build\LibCecSharp.dll
CALL ..\support\private\sign-binary.cmd ..\build\cec-tray.exe
CALL ..\support\private\sign-binary.cmd ..\build\x64\cec-client.exe
CALL ..\support\private\sign-binary.cmd ..\build\x64\CecSharpTester.exe
CALL ..\support\private\sign-binary.cmd ..\build\x64\cec.dll
CALL ..\support\private\sign-binary.cmd ..\build\x64\LibCecSharp.dll
CALL ..\support\private\sign-binary.cmd ..\build\x64\cec-tray.exe

:CREATEINSTALLER
echo. Creating the installer
cd ..\build
copy cec.dll libcec.dll
cd x64
copy cec.dll cec.x64.dll
copy cec-client.exe cec-client.x64.exe
cd ..\..\project
%NSIS% /V1 /X"SetCompressor /FINAL lzma" "libCEC.nsi"

IF NOT EXIST "..\build\libCEC-installer.exe" GOTO :ERRORCREATINGINSTALLER

rem Sign the installer if sign-binary.cmd exists
IF EXIST "..\support\private\sign-binary.cmd" (
  echo. Signing the installer binaries
  CALL ..\support\private\sign-binary.cmd ..\build\libCEC-installer.exe
)

IF "%1%"=="" (
  echo. The installer can be found here: ..\build\libCEC-installer.exe
) ELSE (
  move ..\build\libCEC-installer.exe ..\build\libCEC-%1%-installer.exe
  echo. The installer can be found here: ..\build\libCEC-%1%-installer.exe
)

set EXITCODE=0
GOTO EXIT

:NOSDK11
echo. Visual Studio 2012 was not found on your system.
GOTO EXIT

:NOSIS
echo. NSIS could not be found on your system.
GOTO EXIT

:NODDK
echo. Windows DDK could not be found on your system
GOTO EXIT

:ERRORCREATINGINSTALLER
echo. The installer could not be created. The most likely cause is that something went wrong while compiling.
GOTO RETURNEXIT

:EXIT
cd ..\support

:RETURNEXIT
IF "%1%"=="" (
  echo. exitcode = %EXITCODE%
) ELSE (
  exit %EXITCODE%
)

