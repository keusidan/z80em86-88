@echo off
rem msdos4.bat - (8.3 filename) nmake MS-DOS 4.00 sources (called by scripts/msdos4-build.sh)
rem usage: msdos4.bat [nmake args]    C: = project root, D: = msdos4
rem SETENV.BAT points at tools\lib and tools\inc, but the files are in tools\bld\lib and tools\bld\inc
d:
set CL=
set LINK=
set MASM=
set COUNTRY=usa-ms
set BAKROOT=d:
set LIB=d:\src\tools\bld\lib
set INIT=d:\src\tools
set INCLUDE=d:\src\tools\bld\inc
set PATH=d:\src\tools;z:\
cd \src
nmake %1 %2 %3 %4 > c:\build\msdos4.log
