@echo off

set SRCDIR=.\src\
set DOCDIR=.\docs\
set BINDIR=.\bin\
set BREW=.\brew\brew.bat
set BREWOPTS=-output-docs-dir %DOCDIR% -output-source-dir %SRCDIR%
::set BREWOPTS=
set COMPILE=.\brew\tools\invoke-compiler.bat /Z7 /Fo%BINDIR%

set PRELIMINARIES=0-preliminaries\README.md
set REPRESENTING_VALUES=2-representing-values\README.md
set BYTECODE=4-bytecode\README.md
set PARSING=5-parsing\README.md
set UTILITIES=A-utilities\README.md

if not exist %BINDIR% mkdir %BINDIR%
if not exist %SRCDIR% mkdir %SRCDIR%
if not exist %DOCDIR% mkdir %DOCDIR%

:: Forth
set LANG=forth
set LANG_CHAPTER=1-forth\README.md

echo build.bat: brewing %LANG%...
call %BREW% %BREWOPTS% %LANG_CHAPTER% %PRELIMINARIES% %UTILITIES%

echo build.bat: building %LANG%...
call %COMPILE% /nologo %SRCDIR%\%LANG%.cpp /link /out:%BINDIR%%LANG%.exe setargv.obj

:: Lisp
set LANG=lisp
set LANG_CHAPTER=3-lisp\README.md

echo build.bat: brewing %LANG%...
call %BREW% %BREWOPTS% %LANG_CHAPTER% %PRELIMINARIES% %UTILITIES% %REPRESENTING_VALUES%

echo build.bat: building %LANG%...
call %COMPILE% /nologo %SRCDIR%\%LANG%.cpp /link /out:%BINDIR%%LANG%.exe setargv.obj

:: Smalltalk
set LANG=smalltalk
set LANG_CHAPTER=6-smalltalk\README.md

echo build.bat: brewing %LANG%...
call %BREW% %BREWOPTS% %LANG_CHAPTER% %PRELIMINARIES% %UTILITIES% %REPRESENTING_VALUES% %BYTECODE% %PARSING%

echo build.bat: building %LANG%...
call %COMPILE% /nologo %SRCDIR%\%LANG%.cpp /link /out:%BINDIR%%LANG%.exe setargv.obj
