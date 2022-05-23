# -Requires -RunAsAdministrator
<#
.SYNOPSIS
	Downlaod, install, and configure the latest version of the Sysmon for DNS logging.
.DESCRIPTION
	This script uses PowerShell the will automatically download, install, and configure the latest version of the Sysmon for DNS logging.
	It will also monitor log files for DNS queries for a given domain name.
	If the given Domain Name is found in the log files, the script will send an email to the specified email address.
.EXAMPLE
	PS> ./SysmonDnsLogging.ps1

.LINK
	https://github.com/
.NOTES
	Author: Bret.s / License: MIT
#>

#====================================================================================================================
# Global Variables
[bool]$global:debug = $false
[string]$global:SysmonProcessName = "Sysmon64"
[string]$global:SysmonExeFileName = "Sysmon64.exe"
[string]$global:SysmonConfig_Temp = $env:temp + "\config-dnsquery.xml"
[string]$global:SysmonExe_Temp = $env:temp + "\" + $global:SysmonExeFileName
[string]$global:SysmonConfig = "C:\Windows\" + "config-dnsquery.xml"
[string]$global:SysmonExe = "C:\Windows\" + $global:SysmonExeFileName

# Function to install the latest version of the Sysmon.
function Install-Sysmon() {
	Write-Host "Sysmon is not installed."

	# Download the Sysmon installer
	[string]$SysmonInstallerZip = "Sysmon.zip"
	[string]$SysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
	[string]$SysmonZipFile = $env:temp + "\" + $SysmonInstallerZip

	# Check is Sysmon Zip exists, if not download it.
	if (!(Test-Path $SysmonZipFile)) {
		Write-Host "Downloading Sysmon installer..."
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		Invoke-WebRequest -Uri $SysmonUrl -OutFile $SysmonZipFile
	}

	# Confirm the Sysmon zip was downloaded.
	if (!(Test-Path $SysmonZipFile)) {
		Write-Host "Sysmon installer failed to download."
		Exit 1
	}
	Write-Host "Sysmon installer downloaded."

	# Extract the downloaded zip file to the temp directory.
	Write-Host "Extracting Sysmon installer..."
	Expand-Archive -Path $SysmonZipFile -DestinationPath $env:temp -Force

	# Confirm the Sysmon installer was extracted.
	if (!(Test-Path $global:SysmonExe_Temp)) {
		Write-Host "Sysmon installer failed to extract."
		Exit 1
	}

	# Delete the Sysmon installer ZIP file.
	Write-Host "Deleting Sysmon Zip..."
	Remove-Item $SysmonZipFile -Force -Recurse -ErrorAction SilentlyContinue

	# Move the Sysmon64.exe to the Windows System32 directory.
	Write-Host "Moving Sysmon64.exe to the Windows System32 directory..."
	Move-Item -Path $global:SysmonExe_Temp -Destination $global:SysmonExe -Force

	#Confirm the Sysmon64.exe was moved successfully. If not exit with error.
	if (!(Test-Path $global:SysmonExe)) {
		Write-Host "Error moving Sysmon64.exe to the Windows System32 directory."
		Exit 1
	}

	# Install the Sysmon DNS configuration.
	Install-SysmonDnsConfig

	# Install Sysmon
	Write-Host "Installing Sysmon..."
	# cmd.exe "$global:SysmonExe -accepteula -i -c $global:SysmonConfig"
	Start-Process -FilePath "$global:SysmonExe" -ArgumentList "-accepteula -i $global:SysmonConfig" -Wait -NoNewWindow

	# Wait for Sysmon to install
	Write-Host "Waiting for Sysmon to install..."
	while (!(Test-Path $global:SysmonExe)) { Start-Sleep -s 1 }
	Write-Host "Sysmon installed."

}

# Function to create the Sysmon configuration file.
function Install-SysmonDnsConfig() {
	Write-Host "Creating Sysmon configuration file..."

	# Check if the Sysmon configuration file exists.
	if (Test-Path $global:SysmonConfig) {
		Write-Host "Sysmon configuration file already exists."	# If it does, do nothing.
		return $true
	}

	# If it doesn't, create the file.
	Write-Host "Sysmon configuration file does not exist."
	Write-Host "Creating Sysmon configuration file..."

	# Create the Sysmon configuration file.
	Set-Content -Path $global:SysmonConfig_Temp -Value '
	<Sysmon schemaversion="4.21">
	<EventFiltering>
		<DnsQuery onmatch="exclude" />
	</EventFiltering>
	</Sysmon>' -Force

	# Confirm that the file was created in temp. If not, exit the script with an error.
	if ( ! (Test-Path $global:SysmonConfig_Temp) ) {
		Write-Host "Error creating Sysmon configuration file."
		Exit 1
	}

	# Move the Sysmon configuration file to the Windows System32 directory.
	Write-Host "Moving Sysmon configuration file to the Windows System32 directory..."
	Move-Item -Path $global:SysmonConfig_Temp -Destination $global:SysmonConfig -Force

	# Confirmed the Sysmon configuration file was moved successfully. If not exit with error.
	if ( ! (Test-Path $global:SysmonConfig) ) {
		Write-Host "Error moving Sysmon configuration file to the Windows System32 directory."
		Exit 1
	}

}

# Function to check if Sysymon is installed and running, if it is not, install it. If it is installed and not running, start it.
function Start-Sysmon() {
	Write-Host "Checking if Sysmon is installed and running..."

	# Check if Sysmon is installed.
	if (!(Test-Path $global:SysmonExe)) {
		Write-Host "Sysmon is not installed."
		Install-Sysmon
	}

	# Check if Sysmon is running.
	if (!(Get-Process -Name "$global:SysmonProcessName" -ErrorAction SilentlyContinue)) {
		Write-Host "Sysmon is not running."
		Start-Process -FilePath "$global:SysmonExe" -ArgumentList "-accepteula -c $global:SysmonConfig" -Wait -NoNewWindow
	}

	# Confirm that Sysmon is running.
	if (!(Get-Process -Name "$global:SysmonProcessName" -ErrorAction SilentlyContinue)) {
		Write-Host "Sysmon failed to start."
		Exit 1
	}
	Write-Host "Sysmon is running."
}

# A function that take a variable, asks the user if the variable is correct, if the user enters 'n', then return $false, if the user enters 'y', then return $true.
# If the user enters anything other than 'y' or 'n', then ask them to enter 'y' or 'n'.
function Confirm-ToProceed() {

	# check if required varible is set.
	param(
		[Parameter(Mandatory=$true)]
		[string]
		[ValidateScript( {
			$_ -ne [string]::Empty
		})]
		$MessageToUser
	)

	# Check if the user entered 'y' or 'n'. If not, ask them to enter 'y' or 'n'.
	while (!($ConfirmToProceed.Character -eq 'y' -or $ConfirmToProceed.Character -eq 'n')) {

		Write-Host -ForegroundColor Yellow "$MessageToUser"
		Write-Host -ForegroundColor Yellow "Enter 'y' to proceed, 'n' to exit."

		$ConfirmToProceed = $Host.UI.RawUI.ReadKey()
		Switch ($ConfirmToProceed.Character) {
			Y       { $true }
			N       { $false }
			default {}
		}
		Write-Host " "
	}
}

# Function that takes a $DomainName, then searches the EventLog for matching EventID with the DomainName in the message feild.
Function Get-DNSQueryRecord() {
	param(
		[Parameter(Mandatory=$true)]
		[ValidateScript( {
			$_ -ne [string]::Empty
		})]
		$DomainName
	)

	# The number of hour back in time to look at.
	[int]$HourBackToSearch = 2

	# Search the event log.
	try {
		Write-Output "Searching for DNS queries for $DomainName..."
		Get-WinEvent -FilterHashtable @{
			Logname = 'Microsoft-Windows-Sysmon/Operational'
			ID = 22
			StartTime =  [datetime]::Today.AddHours(-$HourBackToSearch)
			EndTime = [datetime]::Today
		} | Select-Object -Property Message | Where-Object {$_ -like "*$DomainName*"} | Format-List
	}
	catch {
		{Write-Host -ForegroundColor Red "No DNS queries found for $DomainName."}
	}

}

# -----------------------------------------------------------------------------------#

# Main function to start the script.
Start-Sysmon

# Ask the user if they want to proceed. If they ask them what domain name to monitor for.
if (Confirm-ToProceed "Do you want to monitor for a specific domain name?") {

	# Pre-state for the loop.
	$Confirm = $false

	# Ask the user if they want to monitor DNS queries.
	while ($Confirm -eq $false) {

		[string]$DomainName = Read-Host -Prompt 'Enter the FQDN that you are lookig for?'

		if ($DomainName -ne '' -or $null -ne $DomainName) {
			$Confirm = Confirm-ToProceed -MessageToUser "Do you want to monitor DNS queries for `"$DomainName`"?"
		}

	}

	# Infinat loop to Search the logs for the DNS events related to the given domain name.
	while ($true) {
		Clear-Host
		Get-DNSQueryRecord $DomainName
		Start-Sleep -Seconds 60
	}

	# Get-DNSQueryRecord $DomainName

}

Exit 0