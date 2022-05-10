<#
.SYNOPSIS
	Automatically disable inactive Computers.
.DESCRIPTION
	This script uses PowerShell the will automatically disable and move Computers that are inactive for more that X number of days.
.EXAMPLE
	PS> ./AutoDisableInactiveComputers.ps1 -DaysInactive=90 -BaseOU="OU=Computers,DC=domain,DC=local" -DisabledOU="OU=Disabled Computers,DC=domain,DC=local"

.LINK
	https://github.com/
.NOTES
	Author: Bret.s / License: MIT
#>

# If -Days is not set, default to 90 days
$DaysInactive = $ARGV["Days"] | "90"    # 90 days

# If -BaseOU is not set, output error message and exit script.
$BaseOU = $ARGV["BaseOU"] | Write-Output "Error: BaseOU is not set." -ForegroundColor Red -ErrorAction Stop && exit 1

# If the -DisabledOU is not set, output error message and exit script.
$DisabledOU = $ARGV["DisabledOU"] | Write-Output "Error: DisabledOU is not set." -ForegroundColor Red -ErrorAction Stop && exit 1

# $TimeInactive variable converts $DaysInactive to LastLogonTimeStamp property format for the -Filter switch to work
$TimeInactive = [datetime]::today() - $DaysInactive

#$str_Days = (Get-Date).Adddays(-($DaysInactive))

# Identify and collect inactive computer accounts:

# Get hashtable of inactive computers that are inactive for more than $DaysInactive and currently enabled.
$InactiveComputers = Get-ADObject -Filter "(LastLogonTimeStamp < $TimeInactive) AND (Enabled = 'True')" -BaseOU $BaseOU `
                    -Recurse -ResultType hashtable -ResultPageSize 2000 -resultSetSize $null `
                    -Properties Name, OperatingSystem, SamAccountName, DistinguishedName, LastLogonDate

# For each computer in the hashtable, disable the account and move it to the DisabledOU.
foreach ($Computer in $InactiveComputers.Keys) {

 ForEach-Object {

    $str_oldDesc = (Get-ADComputer -Identity $_ -Prop description).Description
    $str_oldOU = $_.DistinguishedName
    Disable-ADAccount $_
    Set-ADComputer $_ -Description "$str_oldDesc -- Account disabled $(Get-Date -format "yyyy-MM-dd") by System. OLD-OU: $str_oldOU"
    Move-ADObject $_ -targetpath $str_DisabledOuLocal
    Write-Output $_.DistinguishedName
}

