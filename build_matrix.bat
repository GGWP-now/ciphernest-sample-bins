@echo off
REM build_matrix.bat — convenience wrapper for build_matrix.ps1
REM
REM Usage:
REM   build_matrix                           :: all configs × all targets
REM   build_matrix -Configs x64_Release      :: single config, all targets
REM   build_matrix -Targets 01,05,13         :: all configs, specific targets
REM   build_matrix -Clean -NoBuild           :: configure only, clean first
REM   build_matrix -Configs x86_Debug,x64_LTCG -Targets 01

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_matrix.ps1" %*
exit /b %ERRORLEVEL%
