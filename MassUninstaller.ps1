<#
Mass Uninstaller

Uninstalls and reinstalls software by initiating from 1 computer to multiple computers.
Multi-threaded


Instructions:

    Have a ProgramName.txt in a directory "lists" next to the script, and then add computer names into it. In the style:

    Computername1
    Computername2
    Computername5
    Computername392

    Then, run the script. Follow prompts, wait for finish.

    The ProgramName.txt WILL BE USED AS THE FILTER SYNTAX, PLEASE MAKE THE FILE NAME THE SEARCH FILTER INPUT

    ie.
        Script Location: C:/Scripts/thisScript.ps1
        Your programs: C:/Scripts/lists/Java.txt
            >>> "%Java%" will be used as the filter syntax

Requires:
    Admin

Input:
    User input in output filename
    (Several) program text files with computer names inside.

Output:
    PrograName.csv files that are results of operations

Restrictions:
    Must have the correct program name to start filtering

Other:
    Requires additional directory to be next to the script. "lists"

Dev Notes:
    To simplify the wmi filter syntax, I made it grab the filename as the filter syntax while also appending % to the edges
#>


###  MULTI-THREADING THROTTLE HERE
$throttlelimit = 50
# time between starting each job (in milliseconds)
$timemil = 250

# How does win32_product find its target(s)?    % = wildcard
$wmifiltersyntax = 'Name LIKE "%Cisco IP Comm%"'

# Here's our todolists. 
$rootDir = Get-ChildItem "$PSScriptRoot/lists"


########## Starting Checks

#is my todolist empty
if ($todolist -eq $null)
{
    Write-Warning "Why is your list empty?"
    exit
}

#does my folder exist
if (!(Test-Path $rootDir))
{
    Write-Warning "Why is your lists directory non-existent?"
    Exit
}

#is my job list not empty
if ((Get-Job) -ne $null)
{
    Write-Host "Clear your Powershell's Job list to prevent confusion and errors!"
    Pause
    Exit
}

$filename = Read-Host -Prompt "What would you like to name the results .csv file? (Outputted in same directory as the script file)"
Write-Host -Object ($rootDir.count + " lists to parse for computer names. Continue?")
Pause
########## ending Checks


# Starting Script

foreach ($file in $rootDir)
{
    $todolist = Get-Content $file.fullname
    # counter is for the progress bar. keeps track of how many we grabbed thus far.
    $counter += $todolist.Count
    $baseName = $file.BaseName
    $searchQuery = "Name LIKE " + "`"%" + $baseName + "%`""

    Write-Progress -Activity ("Starting " + $file.basename + " Jobs") -status "Starting" -PercentComplete 0 

    foreach ($computername in $todolist) {

        #throw in our script vars. Now that I think about it, should've been a struct
        Start-Job -Name $computername -ArgumentList $computername,$timemil,$baseName,$searchQuery -ScriptBlock {
            param ($computername,$timemil,$baseName,$searchQuery)

            class ComputerResult
            {
                # This class does nothing but keep data. Basically a struct
                $computerName
                $program
                $result
            }

            $results = New-Object -TypeName ComputerResult
            $results.computerName = $computername
            $results.program = $baseName

            try
            {
                if (!(Test-Connection -ComputerName $computername -Count 1 -Quiet))
                {
                    $result.result = 3
                    return $result
                }

                Invoke-Command -ComputerName $computername -ArgumentList $computername -ScriptBlock {
                    param($computername)

                    $programs = Get-WmiObject -Class win32_product -Filter $searchQuery
                    foreach ($product in $programs)
                    {
                        $product.uninstall()
                    }
                    $result.result = 0
                    return $result
                }

                $result.result = 2
                return $result
            }
            catch
            {
                $result.result = 1
                return $result
            }
        }
        while ((Get-Job -State Running).Count -ge $throttlelimit)
        {
            # Throttle
            Start-Sleep -Seconds 10
            write-Progress -Activity ("Starting " + $file.basename + " Jobs") -Status "Throttling" `
                -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $todolist.Count)) * 100)
        }
        # Update progress while we loop
        write-Progress -Activity ("Starting " + $file.basename + " Jobs") -Status "Starting" `
            -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $todolist.Count)) * 100)
        Start-Sleep -Milliseconds $timemil
    }
}
# Wait script for jobs to finish
while (Get-Job -State Running)
{
    Write-Progress -Activity "Uninstalls" -Status "Awaiting Completion" `
        -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $counter)) * 100)
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
        2 {$object.result = "UninstallFailure"}
        3 {$object.result = "PingFailure"}
        default {$object.result = "UnknownError"}
    }

    $Results += $object

}

# cleanup
Get-Job | Remove-Job

$Results | Export-Csv -Path ($PSScriptRoot + "\" + $filename + ".csv") -NoTypeInformation


