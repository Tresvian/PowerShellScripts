<#
DRA Mass Computer Creator
Run As Administrator


Instructions:

    Have a todolist.txt in the same directory as the script, and then add computer names into it. In the style:

    Computername1
    Computername2
    Computername5
    Computername392

    Then, run the script. Follow prompts, wait for finish.

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
    $destinationGroup
        Which group all the computers from todolist will be removed from..
    $bldg
        Which building number to use
    $room
        Which room to use
    $squadron
        Which squadron (Taken from DRA squadrons list.)

Output:
    results.csv, depends what it is named during the initial startup.

Restrictions:
    Server load, speed, errors.

Other:
    None

Dev Notes:
    Add-Dracomputer cmdlet has the OUs pointing to the FOUO OUs. Please change for any other OU.
#>
param(
$filename = (Read-Host -Prompt "What would you like to name the results .csv file? (Outputted in same directory as the script file)"),
$Server = $null,
$todolist = (Get-Content -Path ($PSScriptRoot + "\todolist.txt")),
$bldg = (Read-Host "What building number to use?"),
$room = (Read-Host "What room number to use?"),
$squadron = (Read-Host "What squadron?")
)


if (!(Test-Path -literalpath "C:\Program Files (x86)\NetIQ\DRA Extensions")) {
    Write-Warning "!WARNING! DRAEXTENSIONSINSTALLER NOT DETECTED. Required for computer deletion"
    Pause
    Exit
}


if ($todolist.count -eq 0)
{
throw ("Your computer list is empty. Verify todolist.txt is in the directory: " + $PSScriptRoot)

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

Write-Host -Object ("$($todolist.count) is the total count of machines to create using squadron $squadron room $room building $bldg.")
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

    if (
        Add-DRAComputer `
        -Domain $env:USERDNSDOMAIN `
        -DRARestServer $Server `
        -DRAHostServer $Server `
        -DRAHostPort FOUO`
        -DRARestPort FOUO`
        -Properties `
        @{DistinguishedName="FOUO_FQN_PATH_COMPUTERNAME”; `
        Location="BLDG: $bldg; RM: $room"; `
        AccountDisabled=$false; `
        AccountThatCanAddComputerToDomain=”FOUO_FQN_PATH_SECURITYGROUP”; `
        o=”FOUO”; `
        l=”FOUO”}
    )
    {
        $result.result = "Success"
        $CompletionList += $result
        Write-Host "[*] $comp was created"
    }
    else
    {
        $result.result = "Fail"
        $CompletionList += $result
        Write-Host "[*] $comp failed creation"
    }
}


$CompletionList | Export-Csv -Path ($PSScriptRoot + "\" + $filename + ".csv") -NoTypeInformation
$Results = @()
$CompletionList = @()
$todolist = @()
$Server = $null