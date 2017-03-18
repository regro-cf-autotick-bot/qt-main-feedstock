
:: Currently, we only support qtwebit, in future we may support
:: qtwebengine for MSVC 2015 and above. Have left qtwebengine code in
:: from upstream recipe (https://github.com/ContinuumIO/anaconda-recipes/blob/master/qt/bld.bat)
set WEBBACKEND=qtwebkit

:: Add the gnuwin32 tools to PATH - needed for webkit
:: Ruby is also needed but this is supplied by AppVeyor
set PATH=%cd%\gnuwin32\bin;%PATH%

where ruby.exe
if %ERRORLEVEL% neq 0 (
  echo Could not find ruby.exe
  exit /b 1
)

where perl.exe
if %ERRORLEVEL% neq 0 (
  echo Could not find perl.exe
  exit /b 1
)

:: Install a custom python 27 environment for us, to use in building webengine which needs Py27, but avoid feature activation
:: At present (5th July 2016) calling `conda create -y -n python27_qt5_build python=2.7` causes the build to
:: fail immediately after, so I'm bodging around that by not doing it if it exists.  This means you must run
:: the builds twice. Sorry. Time is not on my side here.
if "%WEBBACKEND%" == "qtwebengine" (
  if not exist %SYS_PREFIX%\envs\python27_qt5_build (
    conda create -y -n python27_qt5_build python=2.7
  )
  set "PATH=%SYS_PREFIX%\envs\python27_qt5_build;%SYS_PREFIX%\envs\python27_qt5_build\Scripts;%SYS_PREFIX%\envs\python27_qt5_build\Library\bin;%PATH%"
)

:: Webkit is not part of the distributed Qt5 tarballs anymore in 5.6 or after. 
:: You need to download it separately and move it to the build directory by yourself. 
set SHORT_VERSION=%PKG_VERSION:~0,-2%
if "%DIRTY%" == "" (
    if "%WEBBACKEND%" == "qtwebkit" (
        :: TODO: checksum
        curl -LO "http://download.qt.io/community_releases/%SHORT_VERSION%/%PKG_VERSION%/qtwebkit-opensource-src-%PKG_VERSION%.tar.xz"
        if errorlevel 1 exit 1
        7za x -so qtwebkit-opensource-src-%PKG_VERSION%.tar.xz | 7za x -si -aoa -ttar > NUL 2>&1
        if errorlevel 1 exit 1
        move qtwebkit-opensource-src-%PKG_VERSION% qtwebkit
        if errorlevel 1 exit 1
    )
)

:: WebEngine (Chromium) specific definitions.  Only build this when we decide to 
:: move away from qtwebkit for MSCV >= 2015
if "%WEBBACKEND%" == "qtwebengine" (
  set "WSDK8=C:\\Program\ Files\ (x86)\\Windows\ Kits\\8.1"
  set "WDK=C:\\WinDDK\\7600.16385.1"
  set "INCLUDE=%WSDK8%\Include;%WDK%\inc;%INCLUDE%"
  if "%ARCH%"=="32" (
    set "PATH=%WSDK8%\bin\x86;%WDK$%\bin\x86;%PATH%"
    set "LIB=%LIB%;%WSDK8%\Lib\winv6.3\um\x86"
  ) else (
    set "PATH=%WSDK8%\bin\x64;%WDK$%\bin\amd64;%PATH%"
    set "LIB=%LIB%;%WSDK8%\Lib\winv6.3\um\x64"
  )
  set "GYP_DEFINES=windows_sdk_path='%WSDK8%'"
  set GYP_MSVS_VERSION=2015
  set GYP_GENERATORS=ninja
  set GYP_PARALLEL=1
  set "WDK_DIR=%WDK%"
  set "WindowsSDKDir=%WSDK8%"
) else (
  rmdir /s /q qtwebengine
)

:: Get the paths right 
set "INCLUDE=%LIBRARY_INC%;%INCLUDE%"
set "LIB=%LIBRARY_LIB%;%LIB%"

:: A check here for msinttypes
if %VS_MAJOR% LSS 10 (
  if not exist %PREFIX%/Library/include/stdint.h (
    echo %PREFIX%/include/stdint.h does not exist, please use msinttypes
    exit /b 1
  )
)

:: TODO: should we always be rebuilding configure.exe anyway
:: Mentioned patch no longer applied
goto SKIP_REBUILD_CONFIGURE_EXE
:: If applying 0009-Win32-Re-permit-fontconfig-and-qt-freetype.patch (or
:: any patch that changes configureapp.cpp or any of the bootstrap files
:: in any way that alters the configure result) then configure.exe needs
:: to be rebuilt. Here I duplicate logic from configure.bat because that
:: file conflates needing to rebuild configure.exe with using a git repo
:: clone (OK, we should really remove that conflation instead and always
:: just rebuild configure.exe).

:: Not sure if this needed or not...
:: Patch does not apply cleanly.  Copy file.
:: https://codereview.qt-project.org/#/c/141019/
copy %RECIPE_DIR%\tst_compiler.cpp qtbase\tests\auto\other\compiler\
if errorlevel 1 exit /b 1

pushd qtbase
del /q configure.exe
set QTSRC=%CD%\
pushd tools\configure
set make=jom
set QTVERSION=%PKG_VERSION%
for /f "tokens=1,2,3,4 delims=.= " %%i in ('echo Qt.%QTVERSION%') do (
    set QTVERMAJ=%%j
    set QTVERMIN=%%k
    set QTVERPAT=%%l
)
:: .. end of specifically this bit is untested
echo #### Generated by configure.bat - DO NOT EDIT! ####> Makefile
echo/>> Makefile
set 
echo QTVERSION = %QTVERSION%>> Makefile
rem These must have trailing spaces to avoid misinterpretation as 5>>, etc.
echo QT_VERSION_MAJOR = %QTVERMAJ% >> Makefile
echo QT_VERSION_MINOR = %QTVERMIN% >> Makefile
echo QT_VERSION_PATCH = %QTVERPAT% >> Makefile
echo CXX = cl>>Makefile
echo EXTRA_CXXFLAGS =>>Makefile
rem This must have a trailing space.
echo QTSRC = %QTSRC% >> Makefile
set tmpl=win32
echo/>> Makefile
type Makefile.%tmpl% >> Makefile
%make%
popd
popd
:SKIP_REBUILD_CONFIGURE_EXE

:: We use '-opengl desktop'. Other options need DirectX SDK or Angle (C++11 only)

:: this needs to be CALLed due to an exit statement at the end of configure:
call configure ^
     -prefix %LIBRARY_PREFIX% ^
     -libdir %LIBRARY_LIB% ^
     -bindir %LIBRARY_BIN% ^
     -headerdir %LIBRARY_INC%\qt ^
     -archdatadir %LIBRARY_PREFIX% ^
     -datadir %LIBRARY_PREFIX% ^
     -L %LIBRARY_LIB% ^
     -I %LIBRARY_INC% ^
     -confirm-license ^
     -no-fontconfig ^
     -icu ^
     -no-separate-debug-info ^
     -no-warnings-are-errors ^
     -nomake examples ^
     -nomake tests ^
     -no-warnings-are-errors ^
     -opengl desktop ^
     -opensource ^
     -openssl ^
     -platform win32-msvc%VS_YEAR% ^
     -release ^
     -shared ^
     -qt-freetype ^
     -system-libjpeg ^
     -system-libpng ^
     -system-zlib ^
     -mp
if errorlevel 1 exit /b 1

:: re-enable echoing which is disabled by configure
echo on
     
:: Note - webengine only built when you ask (nmake module-webengine) - so we can skip it easily.
     
nmake Release
if errorlevel 1 exit /b 1

nmake install
if errorlevel 1 exit /b 1
     
:: To rewrite qt.conf contents per conda environment
copy "%RECIPE_DIR%\write_qtconf.bat" "%PREFIX%\Scripts\.qt-post-link.bat"
if errorlevel 1 exit /b 1

