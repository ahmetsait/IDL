@REM set PATH=C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\CommonExtensions\Microsoft\TestWindow;C:\Program Files (x86)\Microsoft SDKs\F#\3.1\Framework\v4.0\;C:\Program Files (x86)\Microsoft SDKs\TypeScript;C:\Program Files (x86)\MSBuild\12.0\bin;C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\IDE\;C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\BIN;C:\Program Files (x86)\Microsoft Visual Studio 12.0\Common7\Tools;C:\Windows\Microsoft.NET\Framework\v4.0.30319;C:\Program Files (x86)\Microsoft Visual Studio 12.0\VC\VCPackages;C:\Program Files (x86)\HTML Help Workshop;C:\Program Files (x86)\Microsoft Visual Studio 12.0\Team Tools\Performance Tools;C:\Program Files (x86)\Windows Kits\8.1\bin\x86;C:\Program Files (x86)\Microsoft SDKs\Windows\v8.1A\bin\NETFX 4.5.1 Tools\;C:\Windows\System32\WindowsPowerShell\v1.0\;C:\Program Files (x86)\dub;C:\D\dmd2\windows\bin;%PATH%

dmd -m32mscoff -debug -shared -wi -vcolumns "main.d" "lf2.d" "idl.d" "-IC:\D\dmd2\src\druntime\import" "-IC:\D\dmd2\src\phobos" -od"obj\Debug" -of"bin\Debug\IDL.dll"
dmd -m32mscoff -release -O -shared -wi -vcolumns "main.d" "lf2.d" "idl.d" -I"C:\D\dmd2\src\druntime\import" -I"C:\D\dmd2\src\phobos" -od"obj\Release" -of"bin\Release\IDL.dll"
@echo.
@pause