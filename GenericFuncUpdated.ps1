function Install-Firefox {
<#
.SYNOPSIS
Installs Firefox.
Requires the other generic functions to be defined in order for this to work
Uses psexec, AD RSAT, and WMI

.PARAMETER ComputerName
Input remote computer name

.PARAMETER root
Defined in the script somewhere. Main folder for all repositories.

.PARAMETER root
Defined in the script somewhere. Name/directory of remote folder to create for temp purposes.

.PARAMETER dirName
The local repository name

.PARAMETER localFolder
Full path to the local repo folder. Please leave this alone.

.PARAMETER uninstall
Option to make it uninstall based on the UninstallNames
Uses Uninstall function

.PARAMETER quietUninstall
Ask for consent on uninstallation finds if $true. False is not recommended

.PARAMETER exeSilentArgs
exe silent args

.PARAMETER cmdArgs
cmd silent args

.PARAMETER batArgs
bat silent args

.PARAMETER singleExecutableName
If you wish to ignore all other executable in the folder, define this.

.PARAMETER remoteTempFolderDir
This is defined outside this function. Temporary remote folder's name.

.PARAMETER UninstallNames
Names to search in WMI SQL syntax

.PARAMETER forceTestTempDel
If TestComputerConnection finds a pre-existing temp folder, delete silently?

.EXAMPLE
Install on remote computer
    Install-Firefox -Computername MWD-22CompName

Add some silent options
    Install-Firefox -Computername MDS233-DC -forceTestTempDel -quietUninstall

Uninstall
    Install-Firefox -Computername MDS233-DC -forceTestTempDel -quietUninstall -uninstall
#>
[CmdletBinding()]
param (
[Parameter(Mandatory=$true,HelpMessage='Enter a computer name')]
[string]$ComputerName,
[string]$dirName = "Firefox",
[string]$localFolder = $root + "\" + $dirName,
[switch]$uninstall = $false,
[switch]$quietUninstall = $false,
[string]$exeSilentArgs = "-ms",
[string]$msiSilentArgs = "/quiet /i",
[string]$msuSilentArgs = "",
[string]$cmdArgs = "",
[string]$batArgs = "",
[string]$singleExecutableName = "",
[string]$remoteTempFolderDir = "\\" + $ComputerName + "\C$\" + $remoteTemp,
[array]$UninstallNames = @("Firefox"),
[switch]$forceTestTempDel
)
    # Test connection
    TestComputerConnection -ComputerName $ComputerName -remoteTempFolderDir $remoteTempFolderDir -force $forceTestTempDel

    # Default action is to install
    if ($uninstall -eq $false)
    {
        Write-Verbose -Message "Detected installer option"
        # Check for items, then copy over
        if ($dirName -ne "" -and (Get-ChildItem -LiteralPath $localFolder) -ne $null)
        {
            try
            {
                # Create temp folder
                Write-Verbose -Message "Creating temp folder at remote machine"
                New-Item -ItemType Directory -Path $remoteTempFolderDir
            }
            catch
            {
                Write-Warning -Message ("Something happened while trying to create temp directory at " + $ComputerName)
                Throw "Exiting with failure"
            }

            Write-Verbose -Message ("Copying items from " + $localFolder + " to " + $remoteTempFolderDir)
            # Copy over
            Copy-Item -Recurse -Path $localFolder -Destination $remoteTempFolderDir
        }
        
        # Install
        Write-Verbose -Message "Starting Installer"
        Installer -localFolder $localFolder `
                  -remoteTempFolderDir $remoteTempFolderDir `
                  -compname $ComputerName `
                  -exeSilentArgs $exeSilentArgs `
                  -msiSilentArgs $msiSilentArgs `
                  -msuSilentArgs $msuSilentArgs `
                  -cmdArgs $cmdArgs `
                  -batArgs $batArgs `
                  -singleExecutableName $singleExecutableName
        
        # If there was items moved, clean up remote machine
        if ($dirName -ne "" -and (Get-ChildItem -LiteralPath $localFolder) -ne $null)
        {
            Write-Verbose -Message "Cleaning"
            Remove-Item -Recurse -Path $remoteTempFolderDir -Force
        }
        
        Write-Verbose -Message "Installer finished successfully"
    }

    else
    {
        Write-Verbose -Message "Detected Uninstaller option"
        Uninstaller -ComputerName $ComputerName -UninstallNames $UninstallNames -quietUninstall $quietUninstall
    }
    Write-Verbose -Message "Finished, exiting."
}