<#
Printer Discovery Script

Queries computers for what printers are installed, and takes the portname.
Dependent on the workstations and laptops to bring back some results of get-wmiobject
Multi-threaded

Computer names are built in the script by the base input (FOUO,FOUO), then tries both W and L (FOUOL,FOUOW),
    following by further input for PASCODE (FOUO,FOUO). AD Filter syntax goes by this FOUO*


Instructions:

    Run the script in any fashion, user input will be prompted.

Requires:
    RSAT AD
    Admin

Input:
    Several read-host will ask for input.

Output:
    Text file of the valid printers.

Restrictions:
    Machines must have wmiobjects returning some valid results. If there's no IP in the object.PortName, then it won't work.

Other:
    Some printers are not good anymore, so they are scrubbed at the end by testing for their IP.

Dev Notes:
    -match "^[\d]"
        Let's use this for matching for numeric at first index
#>
$throttlelimit = 50
$timemil = 100
Write-Host "[*]Starting script for Printer Discovery"
Write-Host "[*]Checking prereqs..."


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


#is my job list not empty
if ((Get-Job) -ne $null)
{
    Write-Host "[*]Clear your Powershell's Job list? (CTRL-C if not)"
    Pause
    Get-Job | Remove-Job
}


Write-Host "[*]Finished prereqs, starting main script"
Start-Sleep -Seconds 2


$adFilterInput = Read-Host "What base are you? (R/L)"
if ($adFilterInput.ToLower() -eq "l")
{
    $base = "FOUO"
}
elseif ($adFilterInput.ToLower() -eq "r")
{
    $base="FOUO"
}
else
{
    Write-Warning "Invalid input"
    Pause
    Throw "Invalid input for adFilterInput"
}


$pascodeInput = Read-Host "What PASCODE are you wanting to scan? (4 characters max)"
if ($pascodeInput.Length -gt 4 -or $pascodeInput -eq $null)
{
    Write-Warning "Invalid input"
    pause
    Throw "Invalid input for pascodeInput"
}


# we're only gonna grab workstations and laptops


$workstationFilter = $base + "W-" + $pascodeInput + "*"
$laptopFilter = $base + "L-" + $pascodeInput + "*"


Write-Host "[*]Grabbing Active Directory..."
$workstations = @()
$workstations = Get-ADComputer -Filter {Name -LIKE $workstationFilter}
$laptops = @()
$laptops = Get-ADComputer -Filter {Name -LIKE $laptopFilter}


#combine
$machines = @()
$machines += $workstations
$machines += $laptops


$filename = Read-Host -Prompt "What would you like to name the results .csv file? (Outputted in same directory as the script file)"
Write-Host -Object ("Detected " + $machines.count + " computers to query. Continue?")
Pause


################################################## Operations

Write-Progress -Activity "Discovering Printers" -status "Starting" -PercentComplete 0
foreach ($computername in $machines.Name) {

    Start-Job -Name $computername -ArgumentList $computername -ScriptBlock {
        param ($computername)
        # Ping and exit if fail
        if (!(Test-Connection -Quiet -Count 2 -ComputerName $computername))
        {
            return "Fail"
        }


        # grab win32_printer objects
        try
        {
            $printerList = Get-WmiObject -Class win32_printer -ComputerName $computername
        }
        catch
        {
            return "Fail"
        }


        $returnedList = @()
        # filter for relevant ones. Must have numeric as first index for the IP. We'll sort through them later.
        foreach ($printer in $printerList)
        {
            if ($printer.PortName -match "^[\d]")
            {
                $returnedList += $printer
            }
        }
        # returning an array of printer class objects that may have possible IPs.
        return $returnedList
    }

    while ((Get-Job -State Running).Count -ge $throttlelimit)
    {
        # Throttle
        Start-Sleep -Seconds 10
        write-Progress -Activity "Discovering Printers" -Status "Throttling" `
            -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $machines.Count)) * 100)
    }
    # Update progress while we loop
    write-Progress -Activity "Discovering Printers" -Status "Starting" `
        -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $machines.Count)) * 100)
    Start-Sleep -Milliseconds $timemil
}

# Wait script for jobs to finish
while (Get-Job -State Running)
{
    Write-Progress -Activity "Discovering Printers" -Status "Awaiting Completion" `
        -PercentComplete (((((Get-Job -State Failed).Count + (Get-Job -State Completed).Count) / $machines.Count)) * 100)
    start-sleep -seconds 1
}


Write-Host "[*]Returning results from work..."
$Results = @()

# extract.
foreach ($array in (Get-Job | Receive-Job) )
{
    # we shoudl have an array of printer objects now

    # filter through the underscores and add to the results
    foreach ($printer in $array)
    {
        # detect underscore. whyyyyyyy
        if ($printer.PortName -match "_")
        {
            # what a monster of a function. im sorry
            $printer.PortName = $printer.PortName.substring(0,$printer.Portname.indexof("_")-1)
            $Results += $printer.Portname
            Continue
        }
        $Results += $printer.Portname
        Continue
    }
}


$FinalResults = @()
$Results = $Results | Sort-Object | Get-Unique


Write-Progress -Activity "Discovering Printers" -Status "Compiling" -PercentComplete 100
Write-Host "[*]Finalizing results..."
#final test of the working IPs
foreach ($ip in $Results)
{
    if (Test-Connection -Quiet -count 1 $ip)
    {
        $FinalResults += $ip
    } 
}


# cleanup
Get-Job | Remove-Job
$FinalResults > ($PSScriptRoot + "\" + $filename + ".txt")
Write-Host "[*]Finished. Outputted the results file in the $PSScriptRoot directory."