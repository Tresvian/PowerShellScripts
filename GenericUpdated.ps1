<#

replace with install-firefox and current 4 funcs
Standardized silent remote cmdlet installer and uninstaller.

Requires you to have a local repository of installers.
Requires Psexec
Requires RSAT installed for testing machines and getting AD existence.


#>

# Local repos
$functionFolders = @(
"Chrome",
"DamewareFix",
"DeployApp",
"Firefox"
)

# Root of all installers
$root = "C:\Powershell.UsefulFunctions"

# Directory for temp stuff at remote machines - do not add \
$remoteTemp = "UsefulFunctionsTemp"

function Installer (
# prepares parameters and conditions for ForEachInstaller
    [string]$localFolder,
    [string]$remoteTempFolderDir,
    [string]$compname,
    [string]$exeSilentArgs,
    [string]$msiSilentArgs,
    [string]$msuSilentArgs,
    [string]$cmdArgs,
    [string]$batArgs,
    [string]$singleExecutableName = ""
)
{
    # Grab objects inside the designated folder. If there is any.
    $bin = Get-ChildItem -Path $localFolder
    $bincount = $bin.count


    Write-Verbose -Message "Importing $bincount items."


    if ($bin -eq $null)
    {
        Throw "Local folder empty"
    }


    Write-Verbose -Message "Testing temporary folder directory."


    if ((Test-Path -LiteralPath $remoteTempFolderDir) -eq $false)
    {
        Throw "Temp folder not found at remote computer"
    }


    Write-Verbose -Message "Running through prepatory phase for installer function"
    Write-Verbose -Message ("Currently using exe args: " + $exeSilentArgs)
    Write-Verbose -Message ("Currently using msi args: " + $msiSilentArgs)
    Write-Verbose -Message ("Currently using msu args: " + $msusilentArgs)
    Write-Verbose -Message ("Currently using cmd args: " + $cmdArgs)
    Write-Verbose -Message ("Currently using bat args: " + $batArgs)
    

    if ($singleExecutableName -ne "")
    {
        Write-Verbose -Message ("Currently using single file: " + $singleExecutableName)
        Write-Verbose -Message "Using single executable mode."


        foreach ($file in $this.m_subFolderContents | where {$_ -eq $singleExecutableName})
        {
            Write-Verbose -Message ("Installing " + $file.Name + " on " + $compname)

            $targetLocalFilePathTrim = "\\" + $compname + "\C$\"
            $targetLocalFilePath = $remoteTempFolderDir.Replace($targetLocalFilePathTrim,"C:\")
            $targetLocalFilePath += "\" + $file.name

            $result = ForeachInstaller `
                -file $file `
                -compname $compname `
                -targetLocalFilePath $targetLocalFilePath `
                -exeSilentArgs $exeSilentArgs `
                -msiSilentArgs $msiSilentArgs `
                -msusilentArgs $msusilentArgs `
                -cmdArgs $cmdArgs `
                -batArgs $batArgs
            Write-Verbose -Message ("Error code " + $file.Name + " on " + $compname + ":" + $result)
        }
    }


    elseif ($bin | where {$_.Name -eq "Deploy-Application.exe"})
    {
        Write-Verbose -Message "Using DeployApp mode."
        $arg = $remoteTempFolderDir + "\Deploy-Application.exe -DeployMode 'NonInteractive'"
        & psexec \\$compname -AcceptEula -nobanner $arg
    }


    else
    {
        Write-Verbose -Message "Using default executable mode."
        foreach ($file in $bin)
        {
            Write-Verbose -Message ("Installing " + $file.Name + " on " + $compname)

            $targetLocalFilePathTrim = "\\" + $compname + "\C$\"
            $targetLocalFilePath = $remoteTempFolderDir.Replace($targetLocalFilePathTrim,"C:\")
            $targetLocalFilePath += "\" + $file.name

            $result = ForeachInstaller `
                -file $file `
                -compname $compname `
                -targetLocalFilePath $targetLocalFilePath `
                -exeSilentArgs $exeSilentArgs `
                -msiSilentArgs $msiSilentArgs `
                -msusilentArgs $msusilentArgs `
                -cmdArgs $cmdArgs `
                -batArgs $batArgs
            Write-Verbose -Message ("Error code " + $file.Name + " on " + $compname + ":" + $result)
        }
    }
}


function TestComputerConnection ([string]$ComputerName, [string]$remoteTempFolderDir, [switch]$force = $false)
{
    Write-Verbose "Pinging machine"
    $test = Test-Connection -ComputerName $ComputerName -Quiet -Count 2 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

    Write-Verbose "Getting machine from AD"
    $testad = Get-ADComputer $ComputerName -ErrorAction SilentlyContinue

    if (!($test)) {
        Write-Warning "Computer not pingable"
    }
    if (!($testad)) {
        Write-Warning "Computer not in Active Directory"
    }

    if ($test -eq $false -or $testad -eq $null) {
        throw "Exiting with computer test fail."
    }

    Write-Verbose "Passed AD get, and ping"

    try {
        # Test if remote folder exists, then either delete, or ask to delete.
        $testpast = Test-Path $remoteTempFolderDir
        if ($testpast -eq $true -and $force -eq $false) {
            $input = Read-Host "UsefulFunctionsTemp detected at $ComputerName, would you like to delete and start new temp folder (y/n)?"
            if ($input -eq "y") {
                Remove-Item "\\$ComputerName\c$\UsefulFunctionsTemp" -Recurse -Force
            }
        }
        elseif ($testpast -eq $true)
        {
            Remove-Item "\\$ComputerName\c$\UsefulFunctionsTemp" -Recurse -Force
        }
    }
    catch {
        Throw "$_ unhandled exception occured at recurse deletion. Exiting."
    }
}
 

function ForeachInstaller (
    $file,
    $compname,
    $targetLocalFilePath,
    $exeSilentArgs,
    $msiSilentArgs,
    $msusilentArgs,
    $cmdArgs,
    $batArgs
)
<#
$file will come from a Get-Childitem variable looped through Foreach
$targetLocalFilePath is prepared outside the function to be local to the remote machine.
    necessary for psexec who works on local items.
#>
{
    switch ($file.Extension)
    {
        ".exe"
        {
            $args = $targetLocalFilePath + " " + $exeSilentArgs
            Write-Verbose -Message ("Arg passed to psexec " + $args)
            Write-Verbose -Message ("Installing " + $file.Name + " to " + $compname +  " with psexec using args " + $exeSilentArgs)
            psexec \\$compname -accepteula -nobanner C:\windows\system32\cmd.exe $args
            return $LASTEXITCODE
        }
        ".msi"
        {
            $args = $msiSilentArgs + " " +  $targetLocalFilePath
            Write-Verbose -Message ("Installing " + $file.Name + " to " + $compname  + " with psexec using args " + $msiSilentArgs)
            psexec \\$compname -accepteula -nobanner C:\windows\system32\msiexec.exe $args 2>$null
            return $LASTEXITCODE
        }
        ".msu"
        {
            $args = $targetLocalFilePath + " " + $msusilentArgs
            Write-Verbose -Message ("Installing " + $file.Name + " to " + $compname + " with psexec using args " + $msusilentArgs)
            psexec \\$compname -accepteula -nobanner C:\windows\system32\wusa.exe $args 2>$null
            return $LASTEXITCODE
        }
        ".cmd"
        {
            $args = $targetLocalFilePath + " " + $cmdArgs
            Write-Verbose -Message ("Installing " + $file.Name + " to " + $compname + " with psexec using args " + $cmdArgs)
            psexec \\$compname -accepteula -nobanner C:\windows\system32\cmd.exe /c $args 2>$null
            return $LASTEXITCODE
        }
        ".bat"
        {
            $args = $targetLocalFilePath + " " + $batArgs
            Write-Verbose -Message ("Installing " + $file.Name + " to " + $compname + " with psexec using args " + $batArgs)
            psexec \\$compname -accepteula -nobanner C:\windows\system32\cmd.exe /c $args 2>$null
            return $LASTEXITCODE
        }
        default
        {
            Write-Warning -Message ("[ForeachInstaller] No file argument found for " + $file.name)
            $LASTEXITCODE = "N/A"
            return $LASTEXITCODE
        }
    }
}


function Uninstaller (
[string]$ComputerName,
[switch]$quietUninstall,
[array]$UninstallNames
)
{

    Write-Verbose -Message ("Querying " + $ComputerName + " with WMI class Win32_Product for software")
        
    $foundPrograms = @()
    foreach ($name in $UninstallNames)
    {
        # There's several keys that they have program names for.
        # We're choosing DisplayName since it's what
        # is seen during UninstallPrograms
        Write-Verbose -Message ("Attempting to find $name in Win32_Product")
        $foundPrograms += Get-WmiObject -Class win32_product -ComputerName $ComputerName -Filter "Name LIKE '%$name%'"
    }

    Write-Verbose -Message ("Finished query, found " + $foundPrograms.count + " items.")
            
    if ($foundPrograms.count -ne 0)
    {
        Write-Verbose -Message ("Finding uninstall keys in found keys")

        # Begin going through each key and invoke it.
        $successfulops = 0
        foreach ($key in $foundPrograms)
        {
            # Check if its defined. just in case.
            if ($key.Uninstall -ne $null)
            {
                
                # Check for silent option, otherwise ask for consent ;)
                if ($quietUninstall -eq $true)
                {
                    $result = $key.uninstall()
                }
                else
                {
                    Write-Host -Object ("Attempting uninstallation on: " + $key.Name)
                    $userinput = Read-Host -Prompt "Attempt uninstall? (Y/N)"

                    if ($userinput.ToLower() -eq "n")
                    {
                        continue
                    }

                    $result = $key.uninstall()
                }

                # These are common success codes
                if ($result.ReturnValue -eq 0 -or -$result.ReturnValue -eq 3030)
                {
                    Write-Verbose -Message ($key.Name + " : " + "Successful uninstall")
                    $successfulops += 1
                }

                # This is "USUALLY" permission denied. I'm not gonna ask for SYSTEM
                elseif ($result.ReturnValue -eq 1603)
                {
                    Write-Warning -Message ($key.Name + " : " + "Do you have Admin? Permission denied 1603")
                }

                # This error is RPC
                elseif ($result.ReturnValue -eq 2147549445)
                {
                    Write-Warning -Message ($key.Name + " : " + "Error 2147549445 with RPC. Computer off domain, or something wrong.")
                }

                # All else fails. idk
                else
                {
                    Write-Warning -Message ($key.Name + " : " + "Undefined error" + $result.ReturnValue)
                }
            }
            else
            {
                Write-Warning -Message $key.Name
                Write-Warning "This should not happen. Uninstall method not defined."
            }
        }

        # Finish point
        Write-Verbose -Message ("Completed " + $successfulops + " of " + $foundPrograms.count)
    }

    else
    {
        Write-Warning -Message "Did not find any keys. Either names not matched, or no uninstall key present."
    }
}