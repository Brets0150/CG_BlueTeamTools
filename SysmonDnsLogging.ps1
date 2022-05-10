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
[string]$global:SysmonConfig = $env:temp + "\\config-dnsquery.xml"
[string]$global:SysmonExe = $env:temp + "\\Sysmon64.exe"

# Function to install the latest version of the Sysmon.
function Install-Sysmon() {
	Write-Host "Sysmon is not installed."
	# Download the Sysmon installer
	[string]$SysmonInstallerZip = "Sysmon.zip"
	[string]$SysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
	[string]$SysmonZipFile = $env:temp + "\\" + $SysmonInstallerZip

	if (Test-Path $global:SysmonExe) {
		Write-Host "Sysmon installer already downloaded."
	} else {
		Write-Host "Downloading Sysmon installer..."
		Invoke-WebRequest $SysmonUrl -OutFile $SysmonZipFile

		# Extract the downloaded zip file to the temp directory.
		Write-Host "Extracting Sysmon installer..."
		Expand-Archive $SysmonZipFile -DestinationPath $env:temp

		# Delete the Sysmon installer ZIP file.
		Write-Host "Deleting Sysmon installer..."
		# Remove-Item $SysmonZipFile -Force -Recurse -ErrorAction SilentlyContinue
	}
	# Install the Sysmon DNS configuration.
	Install-SysmonConfig
	# Install Sysmon
	Write-Host "Installing Sysmon..."
	Start-Process -Verb runAs -FilePath $global:SysmonExe -ArgumentList "-accepteula","-i","-c",$global:SysmonConfig

	# Wait for Sysmon to install
	Write-Host "Waiting for Sysmon to install..."
	while (!(Test-Path $global:SysmonExe)) { Start-Sleep -s 1 }
	Write-Host "Sysmon installed."
}

# Function to create the Sysmon configuration file.
function Install-SysmonConfig() {
	Write-Host "Creating Sysmon configuration file..."
	# Check if the Sysmon configuration file exists.
	if (Test-Path $global:SysmonConfig) {
		Write-Host "Sysmon configuration file already exists."	# If it does, do nothing.
	} else {
		# If it doesn't, create the file.
		Write-Host "Sysmon configuration file does not exist."
		Write-Host "Creating Sysmon configuration file..."
		Set-Content -Path $global:SysmonConfig -Value '
		<Sysmon schemaversion="4.21">
		<EventFiltering>
			<DnsQuery onmatch="exclude" />
		</EventFiltering>
		</Sysmon>' -Force
		# Confirm that the file was moved correctly. If not, exit the script with an error.
		if (!(Test-Path $global:SysmonConfig)) {
			Write-Host "Error creating Sysmon configuration file."
			Exit 1
		}
	}
}

# Check is Sysmon is installed. If not, install it.
if (Get-Item -Path $SysmonExe -ErrorAction SilentlyContinue) {
	Write-Host "Sysmon is installed."
	# Set SysmonInstalled boolean to true.
	[bool]$SysmonInstalled = $true

	# Check if Sysmon is running. If not, start it.
	if (!(Get-Process -Name Sysmon64)) {
		Write-Host "Sysmon is not running."
		# Set SysmonRunning boolean to false.
		[bool]$SysmonRunning = $false
		# Start Sysmon.
		Start-Process -Verb runAs -FilePath $global:SysmonExe -ArgumentList "-accepteula","-c",$global:SysmonConfig
		# Wait for Sysmon to start.
		Write-Host "Waiting for Sysmon to start..."
		while (!(Get-Process -Name Sysmon64)) { Start-Sleep -s 1 }
		Write-Host "Sysmon started."
		# Set SysmonRunning boolean to true.
		[bool]$SysmonRunning = $true
	}
} else {
	Install-Sysmon
}

