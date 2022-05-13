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
[bool]$global:debug = $true
[string]$global:SysmonExeFileName = "Sysmon64.exe"
[string]$global:SysmonConfig_Temp = $env:temp + "\config-dnsquery.xml"
[string]$global:SysmonExe_Temp = $env:temp + "\" + $global:SysmonExeFileName
[string]$global:SysmonConfig = "C:\Windows\system32\" + "config-dnsquery.xml"
[string]$global:SysmonExe = "C:\Windows\system32\" + $global:SysmonExeFileName

# Function to install the latest version of the Sysmon.
function Install-Sysmon() {
	Write-Host "Sysmon is not installed."

	# Get the credentials for installing Sysmon.
	Get-AdminCredentials

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
	[string]$MoveCMD = "Move-Item -Path $global:SysmonExe_Temp -Destination $global:SysmonExe -Force"
	Start-Process PowerShell.exe -Wait -Credential $global:ADCreds -ArgumentList "$MoveCMD"

	# Start-BitsTransfer -Credential $global:ADCreds -Source $global:SysmonExe_Temp -Destination $global:SysmonExe
	# Move-Item -Path $global:SysmonExe_Temp -Destination $global:SysmonExe -Force

	#Confirm the Sysmon64.exe was moved successfully. If not exit with error.
	if (!(Test-Path $global:SysmonExe)) {
		Write-Host "Error moving Sysmon64.exe to the Windows System32 directory."
		Exit 1
	}

	# Install the Sysmon DNS configuration.
	Install-SysmonConfig

	# Install Sysmon
	Write-Host "Installing Sysmon..."
	Start-Process -Credential $global:ADCreds -Verb runAs -FilePath "$global:SysmonExe" -ArgumentList "-accepteula -i -c $global:SysmonConfig" -Wait -NoNewWindow

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
	[string]$MoveCMD = "Move-Item -Path $global:SysmonConfig_Temp -Destination $global:SysmonConfig -Force"
	Start-Process PowerShell.exe -Wait -Credential $global:ADCreds -ArgumentList "$MoveCMD"

	# Start-BitsTransfer -Credential $global:ADCreds -Source $global:SysmonConfig_Temp -Destination $global:SysmonConfig

	# Confirmed the Sysmon configuration file was moved successfully. If not exit with error.
	if (!(Test-Path $global:SysmonConfig)) {
		Write-Host "Error moving Sysmon configuration file to the Windows System32 directory."
		Exit 1
	}

}


function Get-MyCredential {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory=$true)]
		[PSCredential]
		[ValidateScript( {
			$_ -ne [PSCredential]::Empty
		})]
		$Credential
	)
		Write-Host "Got credential with username '$($Credential.Username)'"
}

# Function to ask the user for Admin credentials and save them to a global variable.
function Get-AdminCredentials() {

	# Loop until the user enters a valid Admin username and password.
	if (!(Test-Administrator)){
		Write-Host "You are not an administrator."
		Write-Host "Enter the  Admin credentials."

		# Count intiger to keep track of the number of attempts.
		[int]$count = 0

		# Whole loop to get the username and password till the user enters a valid username and password.
		while ( $global:ADCreds -ne [System.Management.Automation.PSCredential]::Empty ) {

			# Increment the count.
			$count++

			# If count is greater than 3, exit the script with an error.
			if ($count -gt 3) {
				Write-Host "You have entered an invalid username and password 3 times. Exiting the script."
				Exit 1
			}

			# Ask the user for the username.
			$global:ADCreds = (Get-Credential "$env:COMPUTERNAME\$env:username" -ErrorAction SilentlyContinue)
		}

		# Check is $global:ADCreds is not null or empty. If it is, exit with error.
		if ( ( $global:ADCreds -ne [System.Management.Automation.PSCredential]::Empty ) -or ($count -gt 3) ) {
			Write-Host "Error getting Admin credentials."
			Exit 1
		}

		# Restart this script. with the new admin credentials. -Credential $global:ADCreds
		Start-Process PowerShell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Credential ($global:ADCreds) -WorkingDirectory 'C:\Windows\System32' -NoNewWindow
		Exit 0
	}

}



# Fuction to test if the user is an administrator.
function Test-Administrator() {

	# Get the current user's identity.
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();

	# Check if the user is an administrator.
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

}

# Check is Sysmon is installed. If not, install it.
if (Get-Item -Path $global:SysmonExe -ErrorAction SilentlyContinue) {
	Write-Host "Sysmon is installed."

	# Set SysmonInstalled boolean to true.
	[bool]$SysmonInstalled = $true

	# Check if Sysmon is running. If not, start it.
	if (!(Get-Process -Name Sysmon64)) {
		Write-Host "Sysmon is not running."

		# Set SysmonRunning boolean to false.
		[bool]$SysmonRunning = $false

		# Start Sysmon.
		Start-Process -Verb runAs -FilePath $global:SysmonExe -ArgumentList "-accepteula -c $global:SysmonConfig"

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

# If $global:debug is true, print the variables.
if ($global:debug) {
	Get-Variable |%{ "Name : {0}`r`nValue: {1}`r`n" -f $_.Name,$_.Value }
}

Exit 0