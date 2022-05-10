@echo off
:: - SYSMON installer + DNS Monitor scripts.
:: - Managed By Bret.S

:: - Variables for script.
set str_domainName=wowdc1.wowlan.com
set str_sysmonSDP=sdp$\AW_Software\_sysmon_gpo

:: - Check if running as an Admin
net.exe session 1>NUL 2>NUL || (Echo This script requires elevated rights. & Exit /b 1)

:: - Check is the SysMon DNS config file exists, if not make it.
if not exist "C:\WINDOWS\config-dnsquery.xml" (
	(
	echo ^<Sysmon schemaversion="4.21"^>
	echo  ^<EventFiltering^>
	echo   ^<DnsQuery onmatch="exclude" /^>
	echo  ^</EventFiltering^>
	echo ^</Sysmon^>
	) > C:\WINDOWS\config-dnsquery.xml
)

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
) else (
goto LoadDNSConfig
)

:: - Install the SysMon agent from the SDP point.
:InstallSysmon
"\\%str_domainName%\%str_sysmonSDP%\Sysmon64.exe" -i -accepteula
If "%ERRORLEVEL%" EQU "1" (
echo "An Error occured while installing SysMon."
pasue
) else ( goto LoadDNSConfig )

:: - Load the DNS Config into SysMon
:LoadDNSConfig
"C:\WINDOWS\Sysmon64.exe" -c "C:\WINDOWS\config-dnsquery.xml"
If "%ERRORLEVEL%" EQU "1" (
echo "An Error occured while loading the SysMon Config."
pasue
)

exit 0