#Requires -RunAsAdministrator
<#
.SYNOPSIS
	A collection of functions to help manage, and harden Windows Active Directory.

.VERSION
    0.1

.DESCRIPTION
    This is a collection of functions to help manage, and harden Windows Active Directory. This tool is

.EXAMPLE
	PS> Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
	PS> Invoke-WebRequest https://github.com/Brets0150/CG_BlueTeamTools/blob/main/AD-PowerAdmin.ps1-O ./SysmonDnsLogging.ps1
	PS> ./AD-PowerAdmin.ps1

.LINK
	https://github.com/Brets0150/CG_BlueTeamTools/blob/main/AD-PowerAdmin.ps1

.NOTES
	Author: Bret.s / License: MIT
#>

#=======================================================================================
# Global Variables and Settings.
Param (
    [Parameter(Mandatory=$false,Position=1)][bool]$Unattended,
    [Parameter(Mandatory=$false,Position=2)][ValidateSet("krbtgt-RotateKey")][string]$JobName
)

# The number of days between KRBTGT password updates.
[int]$global:krbtgtPwUpdateInterval = 1
[string]$global:ThisScript = ([io.fileinfo]$MyInvocation.MyCommand.Definition).FullName

# Rename the terminal window, cuz it looks cool. =P
$host.UI.RawUI.WindowTitle = "AD PowerAdmin - CyberGladius.com"

#=======================================================================================
# Base checks.

# Check if the script is running with PowerShell version 5 or higher.
# If not, throw an error and exit.
if ($host.Version.Major -lt 5){
    Write-Output "This script requires PowerShell 5 or higher."
    exit 1
}

# check if $global:ThisScript is empty or null, if yes, display an error message and end the script.
if ($null -eq $global:ThisScript -or $global:ThisScript -eq "") {
    Write-Host "Error: Could not determine the path to this script. Please ensure that the script is being run from a PowerShell prompt (i.e. not from a script or batch file)." -ForegroundColor Red
    exit 1
}

# Check if $global:ThisScript is a real file, if not, display an error message and end the script.
if (!(Test-Path -Path $global:ThisScript)) {
    Write-Host "Error: Could not determine the path to this script. Please ensure that the script is being run from a PowerShell prompt (i.e. not from a script or batch file)." -ForegroundColor Red
    exit 1
}
#=======================================================================================
# Functions


# Function to display the main menu options for AD-PowerAdmin
function Show-Menu {
    # Clear-Host

    Write-Host '
     ______      __                 ________          ___
    / ____/_  __/ /_  ___  _____   / ____/ /___ _____/ (_)_  _______
   / /   / / / / __ \/ _ \/ ___/  / / __/ / __ `/ __  / / / / / ___/
  / /___/ /_/ / /_/ /  __/ /     / /_/ / / /_/ / /_/ / / /_/ (__  )
  \____/\__, /_.___/\___/_/      \____/_/\__,_/\__,_/_/\__,_/____/
       /____/   Presents
    ___    ____        ____                          ___       __          _
   /   |  / __ \      / __ \____ _      _____  _____/   | ____/ /___ ___  (_)___
  / /| | / / / /_____/ /_/ / __ \ | /| / / _ \/ ___/ /| |/ __  / __ `__ \/ / __ \
 / ___ |/ /_/ /_____/ ____/ /_/ / |/ |/ /  __/ /  / ___ / /_/ / / / / / / / / / /
/_/  |_/_____/     /_/    \____/|__/|__/\___/_/  /_/  |_\__,_/_/ /_/ /_/_/_/ /_/
'
    Write-Host "================ AD-PowerAdmin Tools ================"
    Write-Host "1: Press '1' to get a Ad AD Admin account Audit Report."
    Write-Host "2: Press '2' for this option."
    Write-Host "3: Press '3' to Update the KRBTGT password."
    Write-Host "Q: Press 'Q' to quit."
}

# Funcation to build a list of AD Users with Adinistrative Rights, including the Domain Admin and Enterprise Admins.
Function Get-ADAdmins() {
    [PSCustomObject]$ADAdmins = @()

    # Append $ADAdmins with members of the Domain Admins
    $ADAdmins = Get-ADGroupMember -Identity "Domain Admins" -Recursive

    # Append $ADAdmins with members of the Enterprise Admins
    $ADAdmins += Get-ADGroupMember -Identity "Enterprise Admins" -Recursive

    # Remove duplicates from $ADAdmins
    $ADAdmins = $ADAdmins | Select-Object -Unique

    # Return the list of AD Admins
    return $ADAdmins
}

# Fuction to takes a list of AD Users and gets their account details.
Function Get-ADAdminAudit() {
    # Loop through each AD Admin User
    Get-ADAdmins | ForEach-Object {
        # Get the AD User's details
        Get-ADUser -Identity $_.DistinguishedName -Properties Name, SamAccountName, DistinguishedName, LastLogonDate
    } | Format-List -Property Name, SamAccountName, DistinguishedName, LastLogonDate
}

# Take a link and download the file to the current directory.
Function Get-DownloadFile {

    Param(
        [Parameter(Mandatory=$True,Position=1)][string]$URL,
        [Parameter(Mandatory=$False,Position=2)][string]$OutFileName
    )

    # Enable Tls12
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # If $OutFileName not given, Get the file name from the link
    if ($OutFileName -eq $null) {
        $OutFileName = $env:temp+'\'+$URL.Split('/').Last()
    }

    # Download the file
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $OutFileName

        # Confrim the file was downloaded.
        if (Test-Path -Path $OutFileName) {
            Write-Host "File downloaded successfully." -ForegroundColor Green
        }
        else {
            Write-Host "File download failed." -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "Error: Could not download the file." -ForegroundColor Red
        exit 1
    }

    # Return the file name
    return $OutFileName
}

# Function that will create a scheduled task that runs a command at a specified time.
# Example: New-ScheduledTask -ActionString "Taskmgr.exe" -ActionArguments "/q" -ScheduleRunTime "09:00" -Recurring Once -TaskName "Test" -TaskDiscription "Just a Test"
Function New-ScheduledTask {

    Param(
        [Parameter(Mandatory=$True,Position=1)]
        [string]$ActionString,
        [Parameter(Mandatory=$True,Position=2)]
        [string]$ActionArguments,
        [Parameter(Mandatory=$True,Position=3)]
        [string]$ScheduleRunTime,
        [Parameter(Mandatory=$True,Position=4)][ValidateSet("Daliy","Weekly","Monthly","Once")]
        [string]$Recurring,
        [Parameter(Mandatory=$True,Position=5)]
        [string]$TaskName,
        [Parameter(Mandatory=$True,Position=6)]
        [string]$TaskDiscription
    )

    # Get the current user's name
    [string]$UserName = "$env:UserDomain\$env:UserName"

    # Create $trigger based on $Recurring
    if ($Recurring -eq "Daliy") {
        $Trigger = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At $ScheduleRunTime
    }
    elseif ($Recurring -eq "Weekly") {
        $Trigger = New-ScheduledTaskTrigger -WeeksInterval 1 -At $ScheduleRunTime
    }
    elseif ($Recurring -eq "Monthly") {
        $Trigger = New-ScheduledTaskTrigger -MonthsInterval 1 -At $ScheduleRunTime
    }
    elseif ($Recurring -eq "Once") {
        $Trigger = New-ScheduledTaskTrigger -Once -At $ScheduleRunTime
    }

    try {
        $Action    = (New-ScheduledTaskAction -Execute $ActionString -Argument $ActionArguments)
        $Principal = New-ScheduledTaskPrincipal -UserId $UserName -RunLevel Highest
        $Settings  = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable -WakeToRun
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Description $TaskDiscription
    }
    catch {
        Write-Host "Unable to create schedule task."
        Write-Output $_
        return $false
    }

    return $true
}

### FUNCTION: Confirm Generated Password Meets Complexity Requirements
# Source: https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/password-must-meet-complexity-requirements
Function Test-PasswordIsComplex() {

    Param(
        [Parameter(Mandatory=$True,Position=1)]
        [String]$StringToTest
    )

	Process {
		$criteriaMet = 0

		# Upper Case Characters (A through Z, with diacritic marks, Greek and Cyrillic characters)
		If ($StringToTest -cmatch '[A-Z]') {$criteriaMet++}

		# Lower Case Characters (a through z, sharp-s, with diacritic marks, Greek and Cyrillic characters)
		If ($StringToTest -cmatch '[a-z]') {$criteriaMet++}

		# Numeric Characters (0 through 9)
		If ($StringToTest -match '\d') {$criteriaMet++}

		# Special Chracters (Non-alphanumeric characters, currency symbols such as the Euro or British Pound are not counted as special characters for this policy setting)
		If ($StringToTest -match '[\^~!@#$%^&*_+=`|\\(){}\[\]:;"''<>,.?/]') {$criteriaMet++}

		# Check If It Matches Default Windows Complexity Requirements
		If ($criteriaMet -lt 3) {Return $false}
		If ($StringToTest.Length -lt 8) {Return $false}
		Return $true
	}
}

# Function to create a random 64 character long password and return it.
Function New-RandomPassword([int]$PasswordNrChars) {
	Process {
		$Iterations = 0
        Do {
			If ($Iterations -ge 20) {
				EXIT
			}
			$Iterations++
			$pwdBytes = @()
			$rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
			Do {
				[byte[]]$byte = [byte]1
				$rng.GetBytes($byte)
				If ($byte[0] -lt 33 -or $byte[0] -gt 126) {
					CONTINUE
				}
                $pwdBytes += $byte[0]
			}
			While ($pwdBytes.Count -lt $PasswordNrChars)
				$NewPassword = ([char[]]$pwdBytes) -join ''
			}
        Until (Test-PasswordIsComplex $NewPassword)
        Return $NewPassword
	}
}

# Function to update the KRBTGT password in the Active Directory Domain.
Function Update-KRBTGTPassword {

    Param(
        [Parameter(Mandatory=$False,Position=1)]
        [bool]$OverridePwd
    )

    # If [bool]$OverridePwd is unset, empty, or null, set it to $false.
    If ($null -eq $OverridePwd -or $OverridePwd -eq $false -or $OverridePwd -eq "") {
        $OverridePwd = $false
    }

    # Get the current domain
    [string]$Domain = (Get-ADDomain).NetbiosName

    # if the current running user is a member of the Domain Admins group.
    if ( $null -eq ((Get-ADGroupMember -Identity "Domain Admins") | Where-Object {$_.SamAccountName -eq $env:UserName}) ) {
        # If the current user is not a member of the Domain Admins group, then exit the script.
        Write-Host "You are not a member of the Domain Admins group. Please contact your Domain Administrator."
        return
    }

    # Try to connect to the Active Directory Domain, if fails, display error message and return the main menu.
    try {
        $ADTest = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$Domain")
    } catch {
        Write-Host "Unable to connect to the Active Directory Domain. Please check the Domain Name and try again."
        Write-Host "$ADTest"
        Write-Host "$_"
        return
    }

    # Get KRBTGT AD Object with all properties and attributes, store in $KRBTGTObject.
    $KRBTGTObject = Get-ADUser -Filter {sAMAccountName -eq 'krbtgt'} -Properties *

    # Get a Intiger of days between the current date and the PasswordLastSet of the KRBTGT AD Object.
    [int]$KRBTGTLastUpdateDays = (Get-Date).DayOfYear - $KRBTGTObject.PasswordLastSet.DayOfYear

    # Check if the current KRBTGT password last update time is less than 90 days.
    if ( ($KRBTGTLastUpdateDays -lt $global:krbtgtPwUpdateInterval) -and ($OverridePwd -eq $false) ) {
        # If the current KRBTGT password last update time is less than 90 days, then exit the script.
        Write-Host "The current KRBTGT password last update time is less than $global:krbtgtPwUpdateInterval days."
        Write-Host "Days since last update: $KRBTGTLastUpdateDays"
    }

    # If the current KRBTGT password last update time is greater than 90 days, then update the krbtgt user password.
    if ( ($KRBTGTLastUpdateDays -gt $global:krbtgtPwUpdateInterval) -or $OverridePwd ) {

        try {
            [int]$PassLength = 64

            # Generate A New Password With The Specified Length (Text)
            [string]$NewKRBTGTPassword = (New-RandomPassword $PassLength).ToString()

            # Convert the NewKRBTGTPassword to SecureString
            $NewKRBTGTPasswordSecure = ConvertTo-SecureString -String $NewKRBTGTPassword -AsPlainText -Force

            # Update the krbtgt user password with a random password genorated by the New-RandomPassword function.
            Set-ADAccountPassword -Identity $KRBTGTObject.DistinguishedName -Reset -NewPassword $NewKRBTGTPasswordSecure

            # Update the KRBTGT object variable.
            $KRBTGTObject = Get-ADUser -Filter {sAMAccountName -eq 'krbtgt'} -Properties *

            # check if the password was updated successfully by checking if the PasswordLastSet equal to the current date and time.
            if ( $KRBTGTObject.PasswordLastSet.DayOfYear -eq (Get-Date).DayOfYear ) {
                # If the password was updated successfully, then display a success message.
                Write-Host "The KRBTGT password was updated successfully." -ForegroundColor Green

                # If $OverridePwd is not true, then add the scheduled task to update the KRBTGT password.
                If ($OverridePwd -eq $false) {
                    # Get the time it will be 10 hours and 10 minutes from the current time.
                    $NextUpdateTime = (Get-Date).AddHours(10).AddMinutes(10)

                    [string]$ThisScriptsFullName = $global:ThisScript

                    # Create a schedule task to run the Update-KRBTGTPassword function X number of hours after first password update.
                    New-ScheduledTask -ActionString "$ThisScriptsFullName" -ActionArguments '-Unattended $true -JobName "krbtgt-RotateKey"' -ScheduleRunTime $NextUpdateTime `
                    -Recurring Once -TaskName "KRBTGT-Final-Update" -TaskDiscription "KRBTGT second password update, to run once."

                    # Check if the scheduled task named "KRBTGT-Final-Update" was created successfully.
                    if ($null -eq (Get-ScheduledTask -TaskName "KRBTGT-Final-Update")) {
                        # If the scheduled task was not created successfully, then display an error message.
                        Write-Host "The KRBTGT password update task was not created successfully." -ForegroundColor Red
                        return
                    }
                }
            } else {
                # If the password was not updated successfully, then display an error message.
                Write-Host "The KRBTGT password was not updated successfully." -ForeGroundColor Red
                return
            }
        }
        catch {
            Write-Host "Unable to update the KRBTGT password. Please check the Domain Name and try again."
            Write-Output $_
            return
        }
    }
}

# Function to download and install PowerShell 7.0 and upgrade the current PowerShell version.
Function Install-PS7 {
    Write-Host "Installing PowerShell 7.2..."
    # Dwonloaded File and Path.
    [string]$PowerShell7Exe = "$env:temp\PS7.msi"
    # Download the latest version of PowerShell 7.0.
    $DownloadCheck = (Get-DownloadFile -URL "https://github.com/PowerShell/PowerShell/releases/download/v7.2.4/PowerShell-7.2.4-win-x64.msi" -OutFileName $PowerShell7Exe)
    if ( $DownloadCheck -ne $False ) {

        [string]$MsiInstaller = "C:\Windows\System32\msiexec.exe"
        [string]$ArgumentList = "/package $PowerShell7Exe /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1"

        # Install the latest version of PowerShell 7.0.
        Start-Process -FilePath $MsiInstaller -ArgumentList $ArgumentList -Wait -NoNewWindow

        # If the installation was successful, then display a success message.
        Write-Host "PowerShell 7.0 was successfully installed." -ForegroundColor Green
    }
}

# Function to seartch AD for Computer Objects that have been inactive for more than X days.
Function Search-InactiveComputers {
    # Parameters for this function.
    Param(
        [Parameter(Mandatory=$true,Position=1)]
        [string]$SearchOUbase
        [Parameter(Mandatory=$true,Position=2)]
        [string]$DisabledOULocal
        [Parameter(Mandatory=$true,Position=3)]
        [string]$InactiveDays
    )


    # Specify inactivity range value below
    $InactiveDays = 90

    # $time variable converts $DaysInactive to LastLogonTimeStamp property format for the -Filter switch to work
    $InactiveDate = (Get-Date).Adddays(-($InactiveDays))

    # Eet the basic search path in AD. You can limit the search to a specific OU.
    # Examples
    # $SearchOUbase = 'CN=Computers,DC=EXAMPLE,DC=COM'
    # $SearchOUbase = 'DC=EXAMPLE,DC=COM'
    $SearchOUbase = 'OU=Desktops,DC=EXAMPLE,DC=COM'

    # The disabled Computers OU location in AD.
    $DisabledOULocal = 'OU=Disabled.Desktop,OU=Desktops,DC=EXAMPLE,DC=COM'

    # Search for Computers that have been inactive for more than X days.
    $InactiveComputerObjects = Get-ADComputer -SearchBase $SearchOUbase -Filter {LastLogonTimeStamp -lt $InactiveDate -and Enabled -eq $true} `
    -ResultPageSize 2000 -resultSetSize $null -Properties Name, OperatingSystem, SamAccountName, DistinguishedName, LastLogonDate

    #For each inactive computer, Disable the Computer AD object, update the discription, and move the computer to the Disabled.Desktop OU.
    $InactiveComputerObjects | ForEach-Object {
        # Current Computer Object.
        $CurrentComputerObject = $_
        # Get the old(currently) set computer discription.
        $ComputerOldDescription = (Get-ADComputer -Identity $CurrentComputerObject -Prop Description).Description

        #Get the old OU location of the computer.
        $ComputerOldOU = $CurrentComputerObject.DistinguishedName

        # Get all groups the computer is a member of. Foreach group, remove the computer from the group.
        $ComputersGroupMemberships = Get-ADPrincipalGroupMembership $CurrentComputerObject.DistinguishedName
        $ComputersGroupMemberships | ForEach-Object {
            # If $_.DistinguishedName not equal to "Domain Computers", then remove the computer from the group.
            if ($_.DistinguishedName -ne 'Domain Computers') {
                Remove-ADPrincipalGroupMembership -Identity $CurrentComputerObject -MemberOf $_.DistinguishedName
            }
        }

        # Disable the computer in AD.
        Disable-ADAccount $CurrentComputerObject
        # Update the computer description.
        Set-ADComputer $CurrentComputerObject -Description "$ComputerOldDescription -- Account disabled $(Get-Date -format "yyyy-MM-dd") by AD-PowerAdmin. OLD-OU: $ComputerOldOU"
        # Move the computer to the Disabled.Desktop OU.
        Move-ADObject $CurrentComputerObject -targetpath $DisabledOULocal
        # Write the computer name to the log file.
        Write-Output $CurrentComputerObject.DistinguishedName
    }

}

# Function that runs a collection of function that nned to be performed daily on Active Directory.
function Start-DailyADTasks {
    # Run the function to update the KRBTGT password.
    Update-KRBTGTPassword -OverridePwd $false
    # Run the function to search for inactive computers.
    Search-InactiveComputers
}

#=======================================================================================
# Main

#Check Unattended Mode is true, if true, then run the script without prompting the user.
if ($Unattended) {
    # Check is a JobName was passed, if not, display error messga can exit.
    if ($JobName -eq $null) {
        Write-Host "Error: No JobName was passed to the script. Unattended mode can only be used with a JobName."
        Exit 1
    }

    # if JobName is "krbtgt-RotateKey", then run the krbtgt-RotateKey functions.
    if ($JobName -eq "krbtgt-RotateKey") {
        # Update the KRBTGT password in the Active Directory Domain.
        Update-KRBTGTPassword -OverridePwd $true
    }

    # if JobName is "Daliy", then run the Start-DailyADTacks functions.
    if ($JobName -eq "Daily") {
        # Run the function to update the KRBTGT password.
        Start-DailyADTasks
    }

    # Exit the script
    Exit 0
}

# Display the main menu and wait for the user to select an option.
do {
    Show-Menu
    $Selection = Read-Host "Please make a selection"
    switch ($selection) {
    '1' {
        Get-ADAdminAudit
    }

    '2' {
        Write-Host "Hello World!"
    }

    '3' {
        Update-KRBTGTPassword -OverridePwd $false
    }

    't' {
         Write-Host $global:ThisScript
        # New-ScheduledTask -ActionString "Taskmgr.exe" -ScheduleRunTime "09:00" -Recurring Once -TaskName "Test" -TaskDiscription "Just a Test"
    }

    'psu' {
        Install-PS7
    }

    }
    pause
} until ($Selection -eq 'q')
# Exit 0