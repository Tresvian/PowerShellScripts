<#
Template

Instructions:

Requires:

Input:

Output:

Restrictions:

Other:

Dev Notes:
    I recommend using a class object to be thrown into the -ArgumentList of the Start-Job loop.
#>


###  MULTI-THREADING THROTTLE HERE
$throttlelimit = 50

# time between starting each job (in milliseconds)
$timemil = 250

# your computer list
$todolist = Get-Content -Path ($PSScriptRoot + "\todolist.txt") # basically same dir as the script.


Write-Progress -Activity "Activity Name Here" -status "Starting" -PercentComplete 0 
foreach ($computername in $todolist) {

    # throw in our script vars. Start spawning processes
    Start-Job -Name $computername -ArgumentList $computername,$timemil -ScriptBlock {
        param ($computername,$timemil)

        class ComputerResult
        {
            # This class does nothing but keep data. Basically a struct
            $computerName
            $result
        }

        $results = New-Object -TypeName ComputerResult
        $results.computerName = $computername
        $results.program = $baseName

        try
        {
            if (!(Test-Connection -ComputerName $computername -Count 1 -Quiet))
            {
                $result.result = 2
                return $result
            }

            $result.result = 0
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
        write-Progress -Activity "Activity Name Here" -Status "Throttling" `
            -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $todolist.Count)) * 100)
    }
    # Update progress while we loop
    write-Progress -Activity "Activity Name Here" -Status "Starting" `
        -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $todolist.Count)) * 100)
    Start-Sleep -Milliseconds $timemil
}


# Wait script for jobs to finish
while (Get-Job -State Running)
{
    Write-Progress -Activity "Activity Name Here" -Status "Awaiting Completion" `
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
        1 {$object.result = "ExceptionFailure"}
        2 {$object.result = "PingFailure"}
        # THIS should NEVER happen vvvv
        default {$object.result = "UnknownError"}
    }

    $Results += $object

}

# cleanup
Get-Job | Remove-Job

# Export results here. Same dir as script
$Results | Export-Csv -Path ($PSScriptRoot + "\" + $filename + ".csv") -NoTypeInformation