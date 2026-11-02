@echo off
rem wpull.bat - copy B: (build\work.img) back into c:\work\. called by scripts/msdos4-work.sh pull
imgmount b c:\build\work.img -t floppy
copy b:\*.* c:\work\
dir b: > c:\build\wpull.txt
