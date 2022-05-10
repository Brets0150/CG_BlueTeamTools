function Get-UserCredentials {
    $obj_userCreds = Get-Credential
}

# Function that takes credidentials and runs a set of commands on a remote system.
function Invoke-OsQueryInstall {
    # Check that all parameters are passed.
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [System.Management.Automation.PSCredential]$UserCreds,
        [Parameter(Position=1, Mandatory=$true)]
        [string]$RemoteHost
    )

    Invoke-Command -ScriptBlock {
        Copy-Item -Path "\\wowdc1.wowlan.com\sdp$\msi-launcher.msi" -Destination ".\msi-launcher.msi"
        Start-Process .\msi-launcher.msi /q
    } -ComputerName $RemoteHost -Credential $UserCreds
}

# $obj_g_UserCreds = Get-UserCredentials
Invoke-OsQueryInstall -UserCreds $obj_g_UserCreds -RemoteHost "10.15.1.2"