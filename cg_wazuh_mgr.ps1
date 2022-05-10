<#
.SYNOPSIS
	Manage and update Wazuh agents remotely.
.DESCRIPTION
	This script uses PowerShell Remoting to connect to a Wazuh agent and execute commands.
.EXAMPLE
	PS> .\wazuh-agent-control.ps1

.LINK
	https://github.com/
.NOTES
	Author: Bret.s / License: MIT
#>

# Get this scripts current working directory.
$str_current_dir = $PSScriptRoot

# A function thats takes a given IP, User credentials, and a commands as a argument, then execute the command on the remote host and return the output.
function Execute-Command {
    $_strip = $args[0]
    $obj_userCreds = $args[1]
    $str_command = $args[3]


}

# Function that ask the user, with a popup window, for their credentials as returns a credential object with the user credentials.
function Get-UserCredentials {
    $obj_userCreds = Get-Credential
}

# Download a file from a URL and save it to a local path.
function Download-File {
    # Example: Download-File "https://raw.githubusercontent.com/wazuh/wazuh/3.9/extensions/agent/agent.ps1" "C:\folder\" "agent.ps1"
    $str_url = $args[0]
    $str_scriptPath = $args[1]
    $str_outfileName = $args[2]
    $str_fulloutfileName = "$str_scriptPath/$str_outfileName"
    # Check is null and or empty.
    if ($str_url -eq $null) {
        $str_error = "URL is required."
        return
    }
    if ($str_url -eq "") {
        $str_error = "URL is empty."
        return
    }
    # Download the file at the given URL.
    Invoke-WebRequest -Uri $str_url -OutFile $str_fulloutfileName -UseBasicParsing
    # Check if the file was downloaded.
    if (!(Test-Path $str_fulloutfileName)) {
        $str_error = "File was not downloaded."
        return
    }
    # Check if the file is empty.
    if (Get-Content $str_fulloutfileName -Count -eq 0) {
        $str_error = "File is empty."
        return
    }
}

# copy a file from a SMB share to a local path.
function Copy-SMBFile {
    # Example: Copy-File "\\\\
    $str_smbShare = $args[0]
    $str_scriptPath = $args[1]
    $str_outfileName = $args[2]
    $str_fulloutfileName = "$str_scriptPath/$str_outfileName"
    # Check is null and or empty.
    if ($str_smbShare -eq $null) {
        $str_error = "SMB Share is required."
        return
    }
    if ($str_smbShare -eq "") {
        $str_error = "SMB Share is empty."
        return
    }
    # Copy the file from the SMB share.
    Copy-Item -Path $str_smbShare -Destination $str_fulloutfileName 
    # Check if the file was copied.
    if (!(Test-Path $str_fulloutfileName)) {
        $str_error = "File was not copied."
        return
    }
    # Check if the file is empty.
    if (Get-Content $str_fulloutfileName -Count -eq 0) {
        $str_error = "File is empty."
        return
    }
}


Write-Output $str_current_dir

$obj_g_UserCreds = Get-UserCredentials
