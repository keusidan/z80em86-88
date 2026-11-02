@echo off
rem wpush.bat - copy c:\work\*.* into B: (build\work.img). called by scripts/msdos4-work.sh push
imgmount b c:\build\work.img -t floppy
copy c:\work\*.* b:\
dir b: > c:\build\wpush.txt
