@echo off
:: - SYSMON GPO installer scripts.
:: - Managed By Bret.S
:: - Blog : htttps://CyberGladius.com
:: - Twitter : @CyberGladius
:: - GitHub : https://github.com/Brets0150/CG_BlueTeamTools
:: - Version : 1.0
:: - Date : 2022-06-24
:: - Description : This script is meant to be used with a "Startup Script GPO" to install the Sysmon.
::                 The will script will check is Sysmon is running, if not it will install it, if it is then update the config.

:: - Variables for script. You MUST update these variable to match your system.
set FileServerFQDN=DC1.testlab.com
set SysmonSDPSharePath=sdp$\Sysmon
set SysmonConfig=sysmonconfig-export.xml
set SysmonExe=Sysmon64.exe
:: - Check if running as an Admin
net.exe session 1>NUL 2>NUL || ( echo This script requires elevated rights. & exit /b 1 )

:: - Check is SysMon is running. If not try to start it. If it is running, update the config.
sc query "Sysmon64" | Find "RUNNING"
If %ERRORLEVEL% GTR 0 (
goto StartSysmon
) else ( goto UpdateSysmon )

:: - Try to start Sysmon, if start fails install Sysmon. If start if good, update the config.
:StartSysmon
net start Sysmon64
If %ERRORLEVEL% GTR 0 (
goto InstallSysmon
) else ( goto UpdateSysmon )

:: - Update the SysMon agent from the SDP point. Check if update is good, then exit.
:UpdateSysmon
"\\%FileServerFQDN%\%SysmonSDPSharePath%\%SysmonExe%" -c "\\%FileServerFQDN%\%SysmonSDPSharePath%\%SysmonConfig%"
If %ERRORLEVEL% GTR 0 (
echo "An Error occured while install the SysMon." & exit /b 1
) else ( exit /b 0 )

:: - Install the SysMon agent from the SDP point. Check if install is good, then exit.
:InstallSysmon
"\\%FileServerFQDN%\%SysmonSDPSharePath%\%SysmonExe%" -accepteula -i "\\%FileServerFQDN%\%SysmonSDPSharePath%\%SysmonConfig%"
If %ERRORLEVEL% GTR 0 (
echo "An Error occured while install the SysMon." & exit /b 1
) else ( exit /b 0 )

exit /b 0