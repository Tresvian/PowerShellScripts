<#
DRA Mass Mover
Run As Administrator


Instructions:

    Have a todolist.txt in the same directory as the script, and then add computer names into it. In the style:

    Computername1
    Computername2
    Computername5
    Computername392

    Then, run the script. Follow prompts, wait for finish.

    I believe this allows many different objects to be used. Use FQN

Requires:
    RSAT AD
    Admin

Input:
    $filename
        The file name of the results. Outputted in the same directory as the script.
    $Server
        Requires the FOUO address. Otherwise, read-host can detect.
    $todolist
        Todolist.txt in the same directory as the script.
    $destinationOU
        Which group all the computers from todolist will be removed from..

Output:
    results.csv, depends what it is named during the initial startup.

Restrictions:
    Server load, speed, errors.

Other:
    None

Dev Notes:
    None
#>
param(
$filename = (Read-Host -Prompt "What would you like to name the results .csv file? (Outputted in same directory as the script file)"),
$Server = $null,
$destinationOU = (Read-Host -Prompt "What's the destination OU?"),
$todolist = (Get-Content -Path ($PSScriptRoot + "\todolist.txt"))
)


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


if (!(Test-Path -literalpath "C:\Program Files (x86)\NetIQ\DRA Extensions")) {
    Write-Warning "!WARNING! DRAEXTENSIONSINSTALLER NOT DETECTED. Required for computer deletion"
    Pause
    Exit
}


if ($todolist -eq $null)
{
    Write-Warning "Why is your list empty?"
    exit
}


if ($Server -eq $null)
{
    Write-Host "DRA server options:"
    Write-Host "(0) FOUO"
    Write-Host "(1) FOUO"
    Write-Host "(2) FOUO"
    Write-Host "(3) FOUO"
    Write-Host "(4) FOUO"
    Write-Host "(5) FOUO"
    Write-Host "(6) FOUO"
    Write-Host "(7) FOUO"
    Write-Host "(8) FOUO"
    Write-Host "(9) FOUO"

    $serverInput = Read-Host "Which server would you like to use? (Input number only)"
    switch ($serverInput)
    {
        0 {$Server = "FOUO"}
        1 {$Server = "FOUO"}
        2 {$Server = "FOUO"}
        3 {$Server = "FOUO"}
        4 {$Server = "FOUO"}
        5 {$Server = "FOUO"}
        6 {$Server = "FOUO"}
        7 {$Server = "FOUO"}
        8 {$Server = "FOUO"}
        9 {$Server = "FOUO"}
        default {Throw "Error, invalid input"}
    }

}


$CompletionList = @()


Write-Host -Object ("Detected " + $todolist.count + " computers to move. Continue?")
Pause


Write-Host "Starting creation. If you get a lot of 500 internal errors, choose a different server."
Start-Sleep -Seconds 5

class ComputerResult
{
    $computerName
    $result
}
foreach ($comp in $todolist)
{

$result = New-Object -TypeName ComputerResult
$result.computerName = $comp

    if (Move-DRAComputer -Domain $env:USERDNSDOMAIN -TargetContainer $destinationOU -Identifier $comp)
    {
        $result.result = "Success"
        $CompletionList += $result
        Write-Host "[*] $comp was moved to $destinationOU"
    }
    else
    {
        $result.result = "Fail"
        $CompletionList += $result
        Write-Host "[*] $comp failed move"
    }
}


$CompletionList | Export-Csv -Path ($PSScriptRoot + "\" + $filename + ".csv") -NoTypeInformation
$Results = @()
$CompletionList = @()
$todolist = @()
$Server = $null