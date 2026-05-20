@echo off
setlocal
set "ROOT=%~dp0.."
set "PUB_CACHE=%ROOT%\.toolchains\pub-cache"
set "FLUTTER_SUPPRESS_ANALYTICS=true"
"%ROOT%\.toolchains\flutter\bin\flutter.bat" %*
