<#
Cisco IP Communicator
Ver. from 8.6.1.0 to 8.6.6.0

Uninstalls and reinstalls software by initiating from 1 computer to multiple computers.
Multi-threaded


Instructions:

    Have a todolist.txt in the same directory as the script, and then add computer names into it. In the style:

    Computername1
    Computername2
    Computername5
    Computername392

    Then, run the script. Follow prompts, wait for finish.

Requires:
    psexec 2.2
    RSAT AD
    Admin
    Up-to-date cisco ip comm. installer. Thus far, implemented .msi files only

Input:
    The 10 variables below, put them inside a Param() if you wish for CLI style initiation.
    Additional input required when running the script by 2 read-host cmdlets for input interaction.

Output:
    results.csv, depends what it is named during the initial startup.
    results.csv shows success of the computer and/or probable cause of error.

Restrictions:
    It will stay within the bounds of the 2 specified application versions. It will not touch the computer
        if it has no version, correct version, or anything else errors out.

Other:
    Most of the heavy work is done at the remote machine. invoke-command does the heavy WMI work "locally" at the remote
        machine. cmdlet/psexec outputs are suppressed in the jobs to keep the log clean. Error codes are passed along in a
        class to keep the errors well-defined/detailed.

Dev Notes:
    You shouldn't really have to go into the body of the script unless you're unhappy with a function.
    Most of the configuration is at the start.

    Querying AD too fast results in errors. Be careful with the job delay time
#>


###  MULTI-THREADING THROTTLE HERE
$throttlelimit = 50
# time between starting each job (in milliseconds)
$timemil = 4000

# Version control - install upgrade
$oldvers = "8.6.1.0"
$newvers = "8.6.6.0"

# How does win32_product find its target(s)?    % = wildcard
$wmifiltersyntax = 'Name LIKE "%Cisco IP Comm%"'

# Here's our todolist.txt
$todolist = Get-Content -Path ($PSScriptRoot + "\todolist.txt") # basically same dir as the script.

# Path to the installer for pushing
$installerPath = "installerpathhere"

# Creating a file name variable. Splitting with \ as delimiter, grabbing last index of array
$installerName = $installerPath.Split("\")[-1]

# cisco custom values. TFTP servers. WHy is the IP values reversed?
$tftp1 = "FOUO"
$tftp2 = "FOUO"


########## Starting Checks
#do i have psexec
try
{
$psexec = Get-ItemProperty -Path "C:\Windows\System32\psexec.exe"
}
catch
{
    Write-Warning "YOU DO NOT HAVE PSEXECv2.2 IN YOUR SYSTEM32"
    pause
    exit
}

#do i have the correct psexec
if ($psexec.VersionInfo.FileVersion -ne "2.2")
{
    Write-Warning "UPDATE YOUR PSEXEC IN YOUR SYSTEM32"
    pause
    exit
}

#do i have AD RSAT
try
{
    Import-Module ActiveDirectory
}
catch
{
    Write-Warning "YOU DO NOT HAVE RSAT INSTALLED, ACTIVE DIRECTORY MODULE MISSING"
    pause
    exit
}


#is my todolist empty
if ($todolist -eq $null)
{
    Write-Warning "Why is your list empty?"
    exit
}

#is my job list not empty
if ((Get-Job) -ne $null)
{
    Write-Host "Clear your Powershell's Job list to prevent confusion and errors!"
    Pause
    Exit
}


Write-Host -Object ("Detected " + $todolist.count + " computers to push. Continue?")
Pause
$filename = Read-Host -Prompt "What would you like to name the results .csv file? (Outputted in same directory as the script file)"
########## ending Checks


# Starting Script


Write-Progress -Activity "Upgrading Cisco IP Comm." -status "Starting" -PercentComplete 0 

foreach ($computername in $todolist) {

    #throw in our script vars. Now that I think about it, should've been a struct
    Start-Job -Name $computername -ArgumentList $oldvers,$newvers,$computername,$installerPath,$installerName,$wmifiltersyntax,$tftp1,$tftp2 -ScriptBlock {
        param ($oldvers,$newvers,$computername,$installerPath,$installerName,$wmifiltersyntax,$tftp1,$tftp2)

        class ComputerResult
        {
            # This class does nothing but keep data. Basically a struct
            $computerName
            $result
            $bldg
            $room
            $organization
            $user
            $lastUpdate
        }

        # Create the result object to return
        $result = New-Object -TypeName ComputerResult
        $result.computerName = $computername

        # Get computer from AD, return if fail
        try
        {
            $testad = get-adcomputer $computername -Properties Location
        }
        catch
        {
            $result.result = 2
            return $result
        }

        # Organize information in our class
        $parseInfo = $testad.location.split(";").trim()
        $bldg = $parseInfo[0]
        $room = $parseInfo[1]
        $squadron = $parseInfo[2]
        $user = $parseInfo[3]
        $lastUpdate = $parseInfo[4]

        $result.FOUO = $bldg.Trim("FOUO")
        $result.FOUO = $room.Trim("FOUO")
        $result.FOUO = $squadron.Trim("FOUO")
        $result.FOUO = $user.Trim("FOUO")
        $result.FOUO = $lastUpdate.Trim("FOUO")

        # Ping and exit if fail
        if (!(Test-Connection -Quiet -Count 2 -ComputerName $computername))
        {
            $result.result = 1
            return $result
        }

        try
        {

            # If this succeeds, it's probably good all the way through
            # exitcode 6 is off-domain if the other tests succeed
            Psexec \\$computername -accepteula -nobanner cmd /c winrm quickconfig /q 1>$null 2>$null

            if ($LASTEXITCODE -eq 6)
            {
                $result.result = 3
                return $result
            }

            # First check if both version are installed at all
            $wmiResults = Get-WmiObject -class win32_product -Filter $wmifiltersyntax -ComputerName $computername
            $oldVersion = $false
            $correctVersion = $false

            foreach ($object in $wmiResults)
            {
                if ($object.Version -eq $newvers)
                {
                    $correctVersion = $true
                }
                elseif ($object.Version -eq $oldvers)
                {
                    $oldVersion = $true
                }
            }

            # Exit if correct=true and old=false
            if ($correctVersion -eq $true -and $oldVersion -eq $false)
            {
                $result.result = 6
                return $result
            }


            # Exit if neither are true
            if ($correctVersion -eq $false -and $oldVersion -eq $false)
            {
                $result.result = 7
                return $result
            }

            # Uninstall and exit if there's both installed.
            if ($correctVersion -eq $true -and $oldVersion -eq $true)
            {
                Invoke-Command -ComputerName $computername -ArgumentList $oldvers,$newvers,$wmifiltersyntax -ScriptBlock {
                    param ($oldvers,$newvers,$wmifiltersyntax)
                    $wmi = Get-WmiObject -class win32_product -Filter $wmifiltersyntax
                    foreach ($key in $wmi)
                    {
                        if ($key.Version -eq $oldvers)
                        {
                            msiexec /x $key.IdentifyingNumber /qn /norestart
                        }
                    }
                }
                $result.result = 0
                return $result
            }
            ################### At this point, we have the old version, and no new version for sure. Proceed to install new, uninstall old, add regkeys.

            # Uninstall
            Invoke-Command -ComputerName $computername -ArgumentList $oldvers,$newvers,$wmifiltersyntax -ScriptBlock {
                param ($oldvers,$newvers,$wmifiltersyntax)
                $wmi = Get-WmiObject -class win32_product -Filter $wmifiltersyntax
                foreach ($key in $wmi)
                {
                    if ($key.Version -eq $oldvers)
                    {
                        msiexec /x $key.IdentifyingNumber /qn /norestart
                    }
                }
            }
            Start-Sleep -Seconds 360

            # Create temporary dir for putting our installer
            try
            {
                New-Item -path "\\$computername\C$" -ItemType Directory -Name "Tempfolder" -Force | Out-Null
            }
            catch
            {
                $result.result = 4
                return $result
            }

            copy -Path $installerPath -Destination "\\$computername\c$\Tempfolder\" -Force

            # Install new version
            psexec \\$computername -s -accepteula -nobanner cmd /c msiexec /i C:\Tempfolder\$installerName /qn /norestart 1>$null 2>$null

            if ($LASTEXITCODE -eq 6)
            {
                $result.result = 3
                return $result
            }

            Remove-Item -Path "\\$computername\c$\Tempfolder" -Recurse

            # Add in the TFTP servers for FOUO. The command looks funky because I don't care what the output is
            Invoke-Command -ComputerName $computername -ArgumentList $tftp1,$tftp2 -ScriptBlock {
                param($tftp1,$tftp2)
                New-ItemProperty -Path "HKLM:\Software\Wow6432Node\Cisco Systems, Inc.\Communicator\" -Name "Tftpserver1" -Value $tftp1 -PropertyType DWORD -Force
                New-ItemProperty -Path "HKLM:\Software\Wow6432Node\Cisco Systems, Inc.\Communicator\" -Name "Tftpserver2" -Value $tftp2 -PropertyType DWORD -Force
                New-ItemProperty -Path "HKLM:\Software\Wow6432Node\Cisco Systems, Inc.\Communicator\" -Name "AlternateTftp" -Value "1" -PropertyType DWORD -Force} `
                    -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null

            $result.result = 0
            return $result
        }
        catch
        {
            $result.result = 5
            return $result
        }
    }
    while ((Get-Job -State Running).Count -ge $throttlelimit)
    {
        # Throttle
        Start-Sleep -Seconds 10
        write-Progress -Activity "Upgrading Cisco IP Comm." -Status "Throttling" `
            -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $todolist.Count)) * 100)
    }
    # Update progress while we loop
    write-Progress -Activity "Upgrading Cisco IP Comm." -Status "Starting" `
        -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $todolist.Count)) * 100)
    Start-Sleep -Milliseconds $timemil
}

# Wait script for jobs to finish
while (Get-Job -State Running)
{
    Write-Progress -Activity "Upgrading Cisco IP Comm." -Status "Awaiting Completion" `
        -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $todolist.Count)) * 100)
    start-sleep -seconds 1
}


$Results = @()


foreach ($object in (Get-Job | Receive-Job) )
{
    
    # Results.
    # Each integer has a meaning, that way it's really small and fast when these clumbsy jobs are finishing.
    # Custom error messages here.
    switch ($object.result)
    {
        0 {$object.result = "Success"}
        1 {$object.result = "PingFailure"}
        2 {$object.result = "ADFailure"}
        3 {$object.result = "OffDomainFailure"}
        4 {$object.result = "PermissionFailure"}
        5 {$object.result = "GeneralFailure"}
        6 {$object.result = "UpToDate"}
        7 {$object.result = "NoIPCommFound"}
        default {$object.result = "UnknownError"}
    }

    $Results += $object

}

# cleanup
Get-Job | Remove-Job

$Results | Export-Csv -Path ($PSScriptRoot + "\" + $filename + ".csv") -NoTypeInformation