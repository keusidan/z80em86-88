@echo off
rem mk4img.bat - copy the built MS-DOS 4.00 files into build\msdos4.img (called by scripts/msdos4-img.sh)
rem C: = project root, D: = msdos4. IO.SYS and MSDOS.SYS must be copied first, in this order
imgmount a c:\build\msdos4.img -t floppy
copy d:\src\bios\io.sys a:\
copy d:\src\dos\msdos.sys a:\
copy d:\src\cmd\command\command.com a:\
copy d:\src\cmd\edlin\edlin.com a:\
copy d:\src\cmd\debug\debug.com a:\
copy d:\src\cmd\chkdsk\chkdsk.com a:\
copy d:\src\cmd\sys\sys.com a:\
copy d:\src\cmd\format\format.com a:\
copy d:\src\cmd\attrib\attrib.exe a:\
copy d:\src\cmd\find\find.exe a:\
copy d:\src\cmd\more\more.com a:\
copy c:\build\jpkey.com a:\
copy c:\scripts\msdos4.aut a:\autoexec.bat
dir a: > c:\build\mk4img.txt
