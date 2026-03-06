$ErrorActionPreference = "SilentlyContinue"

$output = "C:\Scripts\windows_update_status.txt"

try {

    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

    $SearchResult = $UpdateSearcher.Search("IsInstalled=0 and Type='Software'")

    $total = 0
    $critical = 0
    $security = 0

    foreach ($update in $SearchResult.Updates) {

        $total++

        if ($update.MsrcSeverity -eq "Critical") {
            $critical++
        }

        foreach ($cat in $update.Categories) {
            if ($cat.Name -eq "Security Updates") {
                $security++
            }
        }
    }

    $reboot = 0
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
        $reboot = 1
    }

    # ServiÃ§o Windows Update
    $service = Get-Service wuauserv
    $service_status = if ($service.Status -eq "Running") {1} else {0}

    # Ultima atualizaÃ§Ã£o instalada
    $lastupdate = (Get-HotFix | Sort InstalledOn | Select -Last 1).InstalledOn
    $days_since_update = (New-TimeSpan -Start $lastupdate -End (Get-Date)).Days

    # Grava arquivo
    "TotalUpdates=$total" | Out-File $output
    "CriticalUpdates=$critical" | Out-File $output -Append
    "SecurityUpdates=$security" | Out-File $output -Append
    "RebootRequired=$reboot" | Out-File $output -Append
    "WUServiceRunning=$service_status" | Out-File $output -Append
    "DaysSinceLastUpdate=$days_since_update" | Out-File $output -Append

}
catch {

    "TotalUpdates=0" | Out-File $output
    "CriticalUpdates=0" | Out-File $output -Append
    "SecurityUpdates=0" | Out-File $output -Append
    "RebootRequired=0" | Out-File $output -Append
    "WUServiceRunning=0" | Out-File $output -Append
    "DaysSinceLastUpdate=999" | Out-File $output -Append

}
