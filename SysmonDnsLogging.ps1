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
[string]$global:SysmonExeFileName = "Sysmon64.exe"
[string]$global:SysmonConfig_Temp = $env:temp + "\\config-dnsquery.xml"
[string]$global:SysmonExe_Temp = $env:temp + "\\" + $global:SysmonExeFileName
#
[string]$global:SysmonConfig = $env:windows + "\\system32\\" + "config-dnsquery.xml"
[string]$global:SysmonExe = $env:windows + "\\system32\\" + $global:SysmonExeFileName

# Function to install the latest version of the Sysmon.
function Install-Sysmon() {
	Write-Host "Sysmon is not installed."

	# Download the Sysmon installer
	[string]$SysmonInstallerZip = "Sysmon.zip"
	[string]$SysmonUrl = "https://download.sysinternals.com/files/Sysmon.zip"
	[string]$SysmonZipFile = $env:temp + "\\" + $SysmonInstallerZip

	# Check is Sysmon Zip exists, if not download it.
	if (!Test-Path $SysmonZipFile) {
		Write-Host "Downloading Sysmon installer..."
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		Invoke-WebRequest -Uri $SysmonUrl -OutFile $SysmonZipFile
	}

	# Confirm the Sysmon zip was downloaded.
	if (!Test-Path $SysmonZipFile) {
		Write-Host "Sysmon installer failed to download."
		Exit 1
	}

	Write-Host "Sysmon installer downloaded."

	# Extract the downloaded zip file to the temp directory.
	Write-Host "Extracting Sysmon installer..."
	Expand-Archive $SysmonZipFile -DestinationPath $env:temp

	# Confirm the Sysmon installer was extracted.
	if (!Test-Path $global:SysmonExe_Temp) {
		Write-Host "Sysmon installer failed to extract."
		Exit 1
	}

	# Delete the Sysmon installer ZIP file.
	Write-Host "Deleting Sysmon Zip..."
	Remove-Item $SysmonZipFile -Force -Recurse -ErrorAction SilentlyContinue

	# Move the Sysmon64.exe to the Windows System32 directory.
	Write-Host "Moving Sysmon64.exe to the Windows System32 directory..."
	Move-Item -Path $global:SysmonExe_Temp -Destination $global:SysmonExe

	#Confirm the Sysmon64.exe was moved successfully. If not exit with error.
	if (!Test-Path $Sysmon64Destination) {
		Write-Host "Error moving Sysmon64.exe to the Windows System32 directory."
		Exit 1
	}

	# Install the Sysmon DNS configuration.
	Install-SysmonConfig

	# Install Sysmon
	Write-Host "Installing Sysmon..."
	Start-Process -Verb runAs -FilePath "$global:SysmonExe" -ArgumentList "-accepteula -i -c $global:SysmonConfig" -Wait -NoNewWindow

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
		Break
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
	if (!(Test-Path $global:SysmonConfig_Temp)) {
		Write-Host "Error creating Sysmon configuration file."
		Exit 1
	}

	# Move the Sysmon configuration file to the Windows System32 directory.
	Write-Host "Moving Sysmon configuration file to the Windows System32 directory..."
	Move-Item -Path $global:SysmonConfig_Temp -Destination $global:SysmonConfig

	# Confirmed the Sysmon configuration file was moved successfully. If not exit with error.
	if (!Test-Path $global:SysmonConfig) {
		Write-Host "Error moving Sysmon configuration file to the Windows System32 directory."
		Exit 1
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

# Confirm that Sysmon is installed.
if (!$SysmonInstalled) {
	Write-Host "Sysmon is not installed."
	Exit 1
}



exit 0