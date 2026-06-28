@echo off
setlocal
pushd "%~dp0"
call "%~dp0..\..\scripts\flutter.cmd" %*
set "EXIT_CODE=%errorlevel%"
popd
exit /b %EXIT_CODE%
