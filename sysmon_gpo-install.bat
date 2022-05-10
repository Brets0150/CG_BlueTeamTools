@echo off
:: - SYSMON installer scripts.
:: - Managed By Bret.S

:: - Variables for script.
set str_domainName=wowdc1.wowlan.com
set str_sysmonSDP=sdp$\AW_Software\_sysmon_gpo

:: - Check if running as an Admin
net.exe session 1>NUL 2>NUL || (Echo This script requires elevated rights. & Exit /b 1)

:: - Check is SysMon is running
sc query "Sysmon64" | Find "RUNNING"
If "%ERRORLEVEL%" EQU "1" (
goto StartSysmon
)

:: - Check if SysMon is installed, if not install it.
:StartSysmon
net start sysmon64
If "%ERRORLEVEL%" EQU "1" (
goto InstallSysmon
) else ( exit 0 )

:: - Install the SysMon agent from the SDP point.
:InstallSysmon
"\\%str_domainName%\%str_sysmonSDP%\Sysmon64.exe" -i -accepteula
If "%ERRORLEVEL%" EQU "1" (
echo "An Error occured while loading the SysMon Config."
)

exit 0