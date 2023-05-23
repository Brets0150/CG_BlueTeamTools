<#
.SYNOPSIS
	Test a new system for basic security configurations and settings.
.DESCRIPTION
	This script uses PowerShell to test for different basic security configurations and settings. The script will output a simple yes or no if a test where passed.
.EXAMPLE
	PS> ./Test-NewSystemSecurity.ps1

.LINK
	https://github.com/
.NOTES
	Author: Dalen.c & Bret.s / License: MIT
#>

function Test-AdministratorPassword {
  [string]$Username = "Administrator"
  [bool]$PasswordSet = $false

  # Retrieve information about the local user account
  $User = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue

  # Check if the user object exists and if password is required
  if ($null -ne $User -and $User.PasswordRequired) {
    $PasswordSet = $true
  }

  # Return the value indicating if password is set for Administrator account
  return $PasswordSet
}

function Test-AccountExists {
  param (
    [string]$Username
  )

  [bool]$AccountExists = $false

  # Retrieve information about the local user account
  $Account = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue

  # Check if the account object exists
  if ($null -ne $Account) {
    $AccountExists = $true
  }

  # Return the value indicating if the account exists
  return $AccountExists
}

function Test-IsAdministrator {
  param (
    [string]$Username
  )

  [bool]$IsAdministrator = $false

  [string]$AdministratorsGroup = "Administrators"
  $GroupMembers = net localgroup "$AdministratorsGroup" | Select-String -Pattern $Username

  if ($GroupMembers) {
    $IsAdministrator = $true
  }

  # Return the value indicating if the selected account is an administrator
  return $IsAdministrator
}

function Test-AccountDisabled {
  param (
    [string]$Username
  )

  [bool]$IsDisabled = $false

  $Account = Get-LocalUser -Name $Username -ErrorAction SilentlyContinue

  if ($null -ne $Account) {
    if ($Account.Enabled -eq $false) {
      $IsDisabled = $true
    }
  }

  # Return the value indicating if the account is disabled
  return $IsDisabled
}

function Test-WindowsUpToDate {
  [bool]$IsUpToDate = $false

  $UpdateSession = New-Object -ComObject Microsoft.Update.Session
  $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
  $SearchResult = $UpdateSearcher.Search("IsInstalled=0")

  if ($SearchResult.Updates.Count -eq 0) {
    $IsUpToDate = $true
  }

  return $IsUpToDate
}

# Invoke-Main function that calls other functions
function Invoke-Main {
  $Results = @()

  [bool]$ResultAdminPassword = Test-AdministratorPassword
  $Results += [PSCustomObject]@{
    Step   = "Administrator Password Set"
    Result = $ResultAdminPassword
  }

  [bool]$ResultAdminDisabled = Test-AccountDisabled -Username "Administrator"
  $Results += [PSCustomObject]@{
    Step   = "Administrator Account Disabled"
    Result = $ResultAdminDisabled
  }

  [bool]$ResultGuestDisabled = Test-AccountDisabled -Username "Guest"
  $Results += [PSCustomObject]@{
    Step   = "Guest Account Disabled"
    Result = $ResultGuestDisabled
  }

  [bool]$ResultWowrackExists = Test-AccountExists -Username "WOWRACK"
  $Results += [PSCustomObject]@{
    Step   = "WOWRACK Account Created"
    Result = $ResultWowrackExists
  }

  if ($ResultWowrackExists) {
    [bool]$ResultWowrackIsAdmin = Test-IsAdministrator -Username "WOWRACK"
  }
  else {
    [bool]$ResultWowrackIsAdmin = $false
  }
  $Results += [PSCustomObject]@{
    Step   = "WOWRACK Account Is Administrator"
    Result = $ResultWowrackIsAdmin
  }

  [bool]$ResultWindowsUpdate = Test-WindowsUpToDate
  $Results += [PSCustomObject]@{
    Step   = "Windows Up To Date"
    Result = $ResultWindowsUpdate
  }

  # Output the results as a table
  $Results | Format-Table -AutoSize
  }

# Call the Invoke-Main function
Invoke-Main

exit 0