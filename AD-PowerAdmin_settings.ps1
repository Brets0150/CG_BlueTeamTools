#Requires -RunAsAdministrator
<#
.SYNOPSIS
	Only variables and configurations for AD-PowerAdmin.

.VERSION
    0.1

.DESCRIPTION
    Only variables and configurations for AD-PowerAdmin.

.EXAMPLE
    Do not use this script directly. This script is called by the main script.

.LINK
	https://github.com/Brets0150/CG_BlueTeamTools/blob/main/AD-PowerAdmin.ps1

.NOTES
	Author: Bret.s / License: MIT
#>
##############################################################################################
# Daily Inactive Computer clean up settings.
# Specify inactivity range value below
[Int]$global:InactiveDays = 90

# Set the basic search path in AD. You can limit the search to a specific OU.
# Examples
# $SearchOUbase = 'CN=Computers,DC=EXAMPLE,DC=COM'
# $SearchOUbase = 'DC=EXAMPLE,DC=COM'
[string]$global:SearchOUbase = 'OU=Desktops,DC=EXAMPLE,DC=COM'

# The disabled Computers OU location in AD. This is where the computers will be moved to.
[string]$global:DisabledOULocal = 'OU=Disabled.Desktop,OU=Desktops,DC=EXAMPLE,DC=COM'

##############################################################################################
# Kerberos KRBTGT password and account settings.

# The number of days between KRBTGT password updates. Default is 90 days.
[int]$global:krbtgtPwUpdateInterval = 90

##############################################################################################