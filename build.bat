@echo off

set BREW=.\brew\brew.bat
set COMPILE=.\brew\build\invoke-compiler.bat

set PRELIMINARIES=0-preliminaries\README.md
set REPRESENTING_VALUES=2-representing-values\README.md
set UTILITIES=A-utilities\README.md

:: Forth
set LANG=forth
set LANG_CHAPTER=1-forth\README.md

echo build.bat: brewing %LANG%...
call %BREW% %LANG_CHAPTER% %PRELIMINARIES% %UTILITIES%

echo build.bat: building %LANG%...
call %COMPILE% /nologo %LANG%.cpp /link /out:%LANG%.exe setargv.obj

:: Lisp
set LANG=lisp
set LANG_CHAPTER=3-lisp\README.md

echo build.bat: brewing %LANG%...
call %BREW% %LANG_CHAPTER% %PRELIMINARIES% %UTILITIES% %REPRESENTING_VALUES%

echo build.bat: building %LANG%...
call %COMPILE% /nologo %LANG%.cpp /link /out:%LANG%.exe setargv.obj

:: Smalltalk
set LANG=smalltalk
set LANG_CHAPTER=6-smalltalk\README.md

echo build.bat: brewing %LANG%...
call %BREW% %LANG_CHAPTER% %PRELIMINARIES% %UTILITIES% %REPRESENTING_VALUES%

echo build.bat: building %LANG%...
call %COMPILE% /nologo %LANG%.cpp /link /out:%LANG%.exe setargv.obj
