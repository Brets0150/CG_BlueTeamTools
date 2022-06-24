#Requires -RunAsAdministrator
<#
.SYNOPSIS
	A script to clean up inactive computers in Active Directory.

.VERSION
    1.0

.DESCRIPTION
    A script to clean up inactive computers in Active Directory. Should be set up as a scheduled task.

.EXAMPLE
	PS> Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
	PS> Invoke-WebRequest https://raw.githubusercontent.com/Brets0150/CG_BlueTeamTools/main/Clean-InactiveComputers.ps1 ./Clean-InactiveComputers.ps1
	PS> ./Clean-InactiveComputers.ps1

.LINK
	https://github.com/Brets0150/CG_BlueTeamTools/blob/main/Clean-InactiveComputers.ps1

.NOTES
	Author: Bret.s / License: MIT
#>

#=======================================================================================
# Specify inactivity range value below
$InactiveDays = 90

# $time variable converts $DaysInactive to LastLogonTimeStamp property format for the -Filter switch to work
$InactiveDate = (Get-Date).Adddays(-($InactiveDays))

# Set the basic search path in AD. You can limit the search to a specific OU.
# Examples
# $SearchOUbase = 'CN=Computers,DC=EXAMPLE,DC=COM'
# $SearchOUbase = 'DC=EXAMPLE,DC=COM'
$SearchOUbase = 'OU=Desktops,DC=EXAMPLE,DC=COM'

# The disabled Computers OU location in AD.
$DisabledOULocal = 'OU=Disabled.Desktop,OU=Desktops,DC=EXAMPLE,DC=COM'

# Search for Computers that have been inactive for more than X days.
$InactiveComputerObjects = Get-ADComputer -SearchBase $SearchOUbase -Filter {LastLogonTimeStamp -lt $InactiveDate -and Enabled -eq $true} `
-ResultPageSize 2000 -resultSetSize $null -Properties Name, OperatingSystem, SamAccountName, DistinguishedName, LastLogonDate

# Check if $InactiveComputerObjects is empty. If it is, then no computers are inactive.
if ($null -ne $InactiveComputerObjects) {

    #For each inactive computer, Disable the Computer AD object, update the discription, and move the computer to the Disabled.Desktop OU.
    $InactiveComputerObjects | ForEach-Object {
        # Current Computer Object.
        $CurrentComputerObject = $_
        # Get the old(currently) set computer discription.
        $ComputerOldDescription = (Get-ADComputer -Identity $CurrentComputerObject -Prop Description).Description

        #Get the old OU location of the computer.
        $ComputerOldOU = $CurrentComputerObject.DistinguishedName

        # Get all groups the computer is a member of.
        $ComputersGroupMemberships = Get-ADPrincipalGroupMembership $CurrentComputerObject.DistinguishedName

        # Foreach group, remove the computer from the group.
        $ComputersGroupMemberships | ForEach-Object {
            # If $_.DistinguishedName not equal to "Domain Computers", then remove the computer from the group.
            if ($_.name -ne 'Domain Computers') {
                Remove-ADPrincipalGroupMembership -Identity $CurrentComputerObject -MemberOf $_.DistinguishedName -Confirm:$False
            }
        }

        # Disable the computer in AD.
        Disable-ADAccount $CurrentComputerObject

        # Update the computer description.
        Set-ADComputer $CurrentComputerObject -Description "$ComputerOldDescription -- Account disabled $(Get-Date -format "yyyy-MM-dd") by AD-PowerAdmin. :: OLD-OU: $ComputerOldOU"

        # Move the computer to the Disabled.Desktop OU.
        Move-ADObject $CurrentComputerObject -targetpath $DisabledOULocal
    }
}
exit 0